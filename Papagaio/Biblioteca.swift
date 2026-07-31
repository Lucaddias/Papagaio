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

    /// Fase corrente por arquivo. Chaveado pelo `UUID` cru porque é o que a view
    /// tem em mãos na navegação.
    private(set) var fases: [UUID: PipelineDeArquivo.Fase] = [:]
    private(set) var erros: [UUID: String] = [:]

    let armazenamento: Armazenamento

    /// De onde os pesos são carregados. A `ContentView` mantém isto igual à
    /// pasta ativa do `ModelosViewModel` — pode ser a do container ou uma
    /// escolhida pelo usuário.
    var pastaDeModelos: URL

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
        } catch {
            erros[UUID()] = "Não foi possível abrir a biblioteca: \(error)"
        }
    }

    // MARK: - Entrada de áudio

    /// Registra um áudio recém-gravado ou importado e já dispara o processamento.
    func registrar(titulo: String, pastaRelativa: String, duracao: TimeInterval) async {
        let arquivo = Arquivo(
            titulo: titulo,
            duracao: duracao,
            pastaRelativa: pastaRelativa,
            espaco: espaco
        )
        do {
            try await repositorio.salvar(arquivo)
        } catch {
            erros[arquivo.id.rawValue] = "Não foi possível salvar: \(error)"
            return
        }
        arquivos.insert(arquivo, at: 0)
        await processar(arquivo)
    }

    func apagar(_ arquivo: Arquivo) async {
        do {
            try await repositorio.apagar(arquivo.id)
            arquivos.removeAll { $0.id == arquivo.id }
            fases[arquivo.id.rawValue] = nil
            erros[arquivo.id.rawValue] = nil
        } catch {
            erros[arquivo.id.rawValue] = "Não foi possível apagar: \(error)"
        }
    }

    // MARK: - Processamento

    var processando: Bool { !fases.isEmpty }

    func processar(_ arquivo: Arquivo) async {
        let chave = arquivo.id.rawValue
        guard fases[chave] == nil else { return }

        // Sem os pesos, o Whisper falharia lá dentro com um erro de carga. Dizer
        // o que falta é mais útil que repassar o erro do llama.cpp.
        let preflight = Preflight(pastaDeModelos: pastaDeModelos).avaliar()
        if preflight != .pronto, preflight != .termicoCritico {
            erros[chave] = preflight.mensagem
            return
        }

        erros[chave] = nil
        fases[chave] = .transcrevendo

        // Criado por execução, e descarregado no fim: os dois modelos somam
        // 13,7 GB e não podem ficar residentes entre gravações num Mac de 18 GB.
        let motores = MotoresLocais(pastaDeModelos: pastaDeModelos, ciclo: ciclo)

        let pipeline = PipelineDeArquivo(
            armazenamento: armazenamento,
            repositorio: repositorio,
            idTranscricao: WhisperEngine.identificador,
            idResumo: QwenEngine.identificador,
            transcrever: { [motores] url, speaker in
                try await motores.transcrever(url, speaker: speaker)
            },
            resumir: { [motores] trechos in
                try await motores.resumir(trechos)
            }
        )

        do {
            let final = try await pipeline.processar(arquivo) { fase in
                Task { @MainActor in self.fases[chave] = fase }
            }
            substituir(final)
            if final.trechos.isEmpty {
                erros[chave] = "Nenhuma fala reconhecida neste áudio."
            }
        } catch {
            erros[chave] = "\(error)"
        }

        fases[chave] = nil
        // 13,7 GB não podem ficar residentes depois que o trabalho acabou.
        await motores.descarregarTudo()
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
        if let erro = erros[chave] { return erro }
        if arquivo.resumo != nil { return "transcrito e resumido" }
        if !arquivo.trechos.isEmpty { return "transcrito" }
        return "aguardando processamento"
    }
}
