import Foundation
import Observation
import PapagaioCore

/// A biblioteca de arquivos do app: o que está salvo, o que está processando e
/// o que falhou.
///
/// É aqui que o app finalmente **chama o pipeline**. Antes disso a transcrição e
/// o resumo existiam só em `PapagaioCore` e na CLI — gravar pelo app produzia um
/// `.m4a` e nada mais.
@MainActor
@Observable
final class Biblioteca {
    private(set) var arquivos: [Arquivo] = []
    /// Arquivos removidos da listagem principal, mas ainda recuperáveis. A
    /// mídia continua no container até a exclusão definitiva.
    private(set) var arquivosNaLixeira: [Arquivo] = []

    /// Fase corrente por arquivo. Chaveado pelo `UUID` cru porque é o que a view
    /// tem em mãos na navegação.
    private(set) var fases: [UUID: PipelineDeArquivo.Fase] = [:]
    private(set) var erros: [UUID: String] = [:]

    /// O Whisper e o Qwen juntos podem ocupar 13,7 GB. A fila mantém os
    /// pedidos em ordem de chegada e permite que somente um deles carregue os
    /// modelos por vez.
    private var filaDeProcessamento: [ArquivoID] = []
    private var arquivoEmProcessamento: ArquivoID?
    private var identificadorDaExecucao: UUID?
    private var tarefaDeProcessamento: Task<Void, Never>?

    /// Uma operação de lixeira pode suspender ao salvar no SwiftData. Rastrear
    /// os itens em transição evita dois cliques concorrentes e também impede
    /// que um item seja re-enfileirado enquanto está sendo removido.
    private var operacoesDeLixeiraEmAndamento: Set<ArquivoID> = []
    private(set) var erroDaLixeira: String?

    let armazenamento: Armazenamento

    /// De onde os pesos são carregados. A `ContentView` mantém isto igual à
    /// pasta ativa do `ModelosViewModel` — pode ser a do container ou uma
    /// escolhida pelo usuário.
    var pastaDeModelos: URL

    /// Controla somente a entrada automática de áudios novos na fila. A fila
    /// continua sendo o único caminho para qualquer processamento manual ou
    /// automático, mantendo um único par de modelos carregado por vez.
    var processamentoAutomatico = true

    private let repositorio: SwiftDataRepository
    private let ciclo = CicloDeVidaDeModelos()
    private let espaco: EspacoID

    init() throws {
        let armazenamento = try Armazenamento.padrao()
        self.armazenamento = armazenamento
        self.pastaDeModelos = armazenamento.pastaDeModelos
        self.repositorio = SwiftDataRepository(
            modelContainer: try SwiftDataRepository.containerLocal()
        )
        self.espaco = Self.espacoIndividual()
    }

    /// O espaço individual é um só e precisa sobreviver a relançamentos: sem
    /// isto, cada abertura criaria um espaço novo e a lista voltaria vazia.
    private static func espacoIndividual() -> EspacoID {
        let chave = "espacoIndividual"
        if let guardado = UserDefaults.standard.string(forKey: chave),
           let id = UUID(uuidString: guardado) {
            return EspacoID(rawValue: id)
        }
        let novo = UUID()
        UserDefaults.standard.set(novo.uuidString, forKey: chave)
        return EspacoID(rawValue: novo)
    }

    // MARK: - Ciclo de vida

    func preparar() async {
        await ciclo.iniciarMonitoramento()
        await carregar()
    }

    func carregar() async {
        do {
            arquivos = try await repositorio.listar(espaco: espaco)
            arquivosNaLixeira = try await repositorio.listarNaLixeira(espaco: espaco)
        } catch {
            erros[UUID()] = "Não foi possível abrir a biblioteca: \(error)"
        }
    }

    // MARK: - Entrada de áudio

    /// Registra um áudio recém-gravado ou importado. Com o processamento
    /// automático ativo ele entra na fila; caso contrário fica pronto para a
    /// pessoa iniciar pela aba Transcrição. As notas são criadas antes da fila,
    /// para que os saves do pipeline apenas as preservem junto de transcrição
    /// e resumo.
    func registrar(
        titulo: String,
        pastaRelativa: String,
        duracao: TimeInterval,
        notas: [NotaDaConversa] = []
    ) async {
        let arquivo = Arquivo(
            titulo: titulo,
            duracao: duracao,
            pastaRelativa: pastaRelativa,
            espaco: espaco,
            notas: notas
        )
        do {
            try await repositorio.salvar(arquivo)
        } catch {
            erros[arquivo.id.rawValue] = "Não foi possível salvar: \(error)"
            return
        }
        arquivos.insert(arquivo, at: 0)
        if processamentoAutomatico {
            enfileirarProcessamento(arquivo)
        }
    }

    // MARK: - Lixeira

    /// Move um arquivo para a lixeira. O item ativo nunca pode ser movido:
    /// o pipeline pode estar lendo seu áudio. Para um item aguardando na fila,
    /// removemos a entrada **antes** do primeiro `await`; caso contrário o
    /// pipeline poderia iniciá-lo enquanto o SwiftData salva o soft delete.
    func moverParaLixeira(_ arquivo: Arquivo) async {
        guard arquivoEmProcessamento != arquivo.id,
              !operacoesDeLixeiraEmAndamento.contains(arquivo.id)
        else { return }

        let indiceNaFila = filaDeProcessamento.firstIndex(of: arquivo.id)
        if let indiceNaFila { filaDeProcessamento.remove(at: indiceNaFila) }

        let chave = arquivo.id.rawValue
        let faseAnterior = fases[chave]
        let erroAnterior = erros[chave]
        fases[chave] = nil
        erros[chave] = nil
        erroDaLixeira = nil
        operacoesDeLixeiraEmAndamento.insert(arquivo.id)
        defer { operacoesDeLixeiraEmAndamento.remove(arquivo.id) }

        do {
            try await repositorio.moverParaLixeira(arquivo.id)
            arquivos.removeAll { $0.id == arquivo.id }

            var movido = arquivo
            movido.apagadoEm = Date()
            arquivosNaLixeira.removeAll { $0.id == arquivo.id }
            arquivosNaLixeira.insert(movido, at: 0)
        } catch {
            // O registro continuou ativo porque o soft delete não foi salvo;
            // devolvemos a posição anterior da fila em vez de perder trabalho.
            fases[chave] = faseAnterior
            erros[chave] = erroAnterior
            if let indiceNaFila {
                filaDeProcessamento.insert(
                    arquivo.id,
                    at: min(indiceNaFila, filaDeProcessamento.count)
                )
                iniciarProximoProcessamentoSeNecessario()
            }
            erroDaLixeira = "Não foi possível mover o arquivo para a lixeira: \(error.localizedDescription)"
        }
    }

    /// Restaura o arquivo para Todos os arquivos sem iniciar processamento de
    /// novo. Se ele tiver sido removido enquanto aguardava, a pessoa escolhe
    /// explicitamente quando reprocessá-lo — nunca carregamos modelos de surpresa.
    @discardableResult
    func restaurarDaLixeira(_ arquivo: Arquivo) async -> Bool {
        guard !operacoesDeLixeiraEmAndamento.contains(arquivo.id) else { return false }

        erroDaLixeira = nil
        operacoesDeLixeiraEmAndamento.insert(arquivo.id)
        defer { operacoesDeLixeiraEmAndamento.remove(arquivo.id) }

        do {
            try await repositorio.restaurar(arquivo.id)
            arquivosNaLixeira.removeAll { $0.id == arquivo.id }

            var restaurado = arquivo
            restaurado.apagadoEm = nil
            arquivos.removeAll { $0.id == arquivo.id }
            arquivos.append(restaurado)
            arquivos.sort { $0.criadoEm > $1.criadoEm }
            return true
        } catch {
            erroDaLixeira = "Não foi possível recuperar o arquivo: \(error.localizedDescription)"
            return false
        }
    }

    /// Exclusão irreversível. O repositório remove o registro, a pasta relativa
    /// correta e todos os arquivos derivados apenas neste ponto.
    func apagarDefinitivamente(_ arquivo: Arquivo) async {
        guard arquivo.apagadoEm != nil,
              arquivosNaLixeira.contains(where: { $0.id == arquivo.id }),
              arquivoEmProcessamento != arquivo.id,
              !operacoesDeLixeiraEmAndamento.contains(arquivo.id)
        else {
            erroDaLixeira = "Mova o arquivo para a lixeira antes de apagá-lo definitivamente."
            return
        }

        erroDaLixeira = nil
        operacoesDeLixeiraEmAndamento.insert(arquivo.id)
        defer { operacoesDeLixeiraEmAndamento.remove(arquivo.id) }

        do {
            try await repositorio.apagar(arquivo.id)
            arquivosNaLixeira.removeAll { $0.id == arquivo.id }
            filaDeProcessamento.removeAll { $0 == arquivo.id }
            fases[arquivo.id.rawValue] = nil
            erros[arquivo.id.rawValue] = nil
        } catch {
            erroDaLixeira = "Não foi possível apagar o arquivo definitivamente: \(error.localizedDescription)"
        }
    }

    func estaEmOperacaoDeLixeira(_ arquivo: Arquivo) -> Bool {
        operacoesDeLixeiraEmAndamento.contains(arquivo.id)
    }

    func dispensarErroDaLixeira() {
        erroDaLixeira = nil
    }

    // MARK: - Processamento

    var processando: Bool {
        arquivoEmProcessamento != nil || !filaDeProcessamento.isEmpty
    }

    func enfileirarProcessamento(_ arquivo: Arquivo) {
        guard arquivoEmProcessamento != arquivo.id,
              !operacoesDeLixeiraEmAndamento.contains(arquivo.id),
              !filaDeProcessamento.contains(arquivo.id) else { return }

        erros[arquivo.id.rawValue] = nil
        filaDeProcessamento.append(arquivo.id)
        iniciarProximoProcessamentoSeNecessario()
    }

    func estaProcessando(_ arquivo: Arquivo) -> Bool {
        arquivoEmProcessamento == arquivo.id
    }

    func estaNaFila(_ arquivo: Arquivo) -> Bool {
        filaDeProcessamento.contains(arquivo.id)
    }

    private func iniciarProximoProcessamentoSeNecessario() {
        guard arquivoEmProcessamento == nil else { return }

        while let proximoID = filaDeProcessamento.first {
            filaDeProcessamento.removeFirst()
            guard let arquivo = arquivos.first(where: { $0.id == proximoID }) else {
                continue
            }

            let execucao = UUID()
            arquivoEmProcessamento = proximoID
            identificadorDaExecucao = execucao
            tarefaDeProcessamento = Task { [weak self] in
                await self?.executarProcessamento(arquivo, execucao: execucao)
            }
            return
        }
    }

    private func executarProcessamento(_ arquivo: Arquivo, execucao: UUID) async {
        let chave = arquivo.id.rawValue
        defer { finalizarProcessamento(chave, execucao: execucao) }

        // Sem os pesos, o Whisper falharia lá dentro com um erro de carga. Dizer
        // o que falta é mais útil que repassar o erro do llama.cpp.
        let preflight = Preflight(pastaDeModelos: pastaDeModelos).avaliar()
        if preflight != .pronto, preflight != .termicoCritico {
            erros[chave] = preflight.mensagem
            return
        }

        erros[chave] = nil
        fases[chave] = .transcrevendo
        let promptDeEntidades = await PromptDeEntidades.construir(para: arquivo)

        // Criado por execução, e descarregado no fim: os dois modelos somam
        // 13,7 GB e não podem ficar residentes entre gravações num Mac de 18 GB.
        let motores = MotoresLocais(pastaDeModelos: pastaDeModelos, ciclo: ciclo)

        let pipeline = PipelineDeArquivo(
            armazenamento: armazenamento,
            repositorio: repositorio,
            idTranscricao: WhisperEngine.identificador,
            idResumo: QwenEngine.identificador,
            transcrever: { [motores, promptDeEntidades] url, speaker in
                try await motores.transcrever(
                    url,
                    speaker: speaker,
                    initialPrompt: promptDeEntidades
                )
            },
            resumir: { [motores] trechos in
                try await motores.resumir(trechos)
            }
        )

        do {
            let final = try await pipeline.processar(arquivo) { fase in
                Task { @MainActor [weak self] in
                    guard self?.identificadorDaExecucao == execucao else { return }
                    self?.fases[chave] = fase
                }
            }
            substituir(final)
            if final.trechos.isEmpty {
                erros[chave] = "Nenhuma fala reconhecida neste áudio."
            }
        } catch {
            erros[chave] = "\(error)"
        }

        // 13,7 GB não podem ficar residentes depois que o trabalho acabou.
        await motores.descarregarTudo()
    }

    private func finalizarProcessamento(_ chave: UUID, execucao: UUID) {
        guard identificadorDaExecucao == execucao else { return }

        fases[chave] = nil
        arquivoEmProcessamento = nil
        identificadorDaExecucao = nil
        tarefaDeProcessamento = nil
        iniciarProximoProcessamentoSeNecessario()
    }

    private func substituir(_ arquivo: Arquivo) {
        if let indice = arquivos.firstIndex(where: { $0.id == arquivo.id }) {
            arquivos[indice] = arquivo
        } else {
            arquivos.insert(arquivo, at: 0)
        }
    }

    // MARK: - Consulta pela view

    func arquivo(id: UUID) -> Arquivo? {
        arquivos.first { $0.id.rawValue == id }
    }

    func audio(de arquivo: Arquivo) -> URL {
        armazenamento
            .resolver(relativo: arquivo.pastaRelativa)
            .appendingPathComponent(Armazenamento.Nome.mixagem)
    }

    func estado(de arquivo: Arquivo) -> String {
        let chave = arquivo.id.rawValue
        if let fase = fases[chave] { return fase.descricao }
        if let posicao = filaDeProcessamento.firstIndex(of: arquivo.id) {
            return "na fila (posição \(posicao + 1))"
        }
        if let erro = erros[chave] { return erro }
        if arquivo.resumo != nil { return "transcrito e resumido" }
        if !arquivo.trechos.isEmpty { return "transcrito" }
        return "pronto para transcrever"
    }
}
