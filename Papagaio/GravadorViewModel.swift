import Foundation
import Observation
import PapagaioCore

/// Estado de gravação para a UI. Fica no app, não em `PapagaioCore` — a
/// biblioteca não conhece SwiftUI nem `@Observable` de tela.
@MainActor
@Observable
final class GravadorViewModel {
    enum Estado: Equatable {
        case ocioso
        case gravando
        case pausado
        case processando
        case falhou(String)
    }

    private(set) var estado: Estado = .ocioso
    private(set) var avisos: [String] = []

    /// Entrega o áudio pronto para quem persiste e processa (`Biblioteca`).
    /// A gravação em si não sabe o que é um `Arquivo` — só produz bytes.
    var aoProduzirAudio: (@MainActor (_ titulo: String, _ pastaRelativa: String,
                                      _ duracao: TimeInterval,
                                      _ notas: [NotaDaConversa]) async -> Void)?

    /// Amostras de nível para a waveform ao vivo, ~20 Hz, janela de ~6 s.
    private(set) var waveform: [Float] = []
    private let quadrosWaveform = 120

    /// O valor vem da quantidade de amostras que já entrou na mixagem, não do
    /// relógio do sistema. Assim o carimbo de uma nota aponta para o mesmo
    /// instante que será reproduzido depois.
    private(set) var tempoDeGravacao: TimeInterval = 0
    private(set) var notasDaGravacao: [NotaDaConversa] = []
    var rascunhoDaNota = ""
    var proximaNotaSeraCritica = false

    private var sessao: SessaoGravacao?
    private var tarefaNivel: Task<Void, Never>?
    private var identificadorDaGravacao: UUID?
    private let armazenamento: Armazenamento?

    init() {
        armazenamento = try? Armazenamento.padrao()
        if armazenamento == nil {
            estado = .falhou("não foi possível abrir a pasta de suporte do app")
        }
    }

    var gravando: Bool { estado == .gravando || estado == .pausado }
    var pausado: Bool { estado == .pausado }

    // MARK: - Gravação

    func alternarGravacao() async {
        if gravando {
            await parar()
        } else {
            await iniciar()
        }
    }

    func pausar() async {
        guard estado == .gravando, let sessao else { return }
        tempoDeGravacao = await sessao.tempoDecorrido()
        await sessao.pausar()
        tarefaNivel?.cancel()
        tarefaNivel = nil
        estado = .pausado
    }

    func continuar() async {
        guard estado == .pausado, let sessao else { return }
        await sessao.continuar()
        estado = .gravando
        iniciarMonitoramentoDeNivel(sessao: sessao, identificador: identificadorDaGravacao ?? UUID())
    }

    func cancelar() async {
        tarefaNivel?.cancel()
        tarefaNivel = nil
        guard let sessao else {
            limparDepoisDeGravar()
            estado = .ocioso
            return
        }
        await sessao.descartar()
        self.sessao = nil
        identificadorDaGravacao = nil
        avisos = ["Gravação cancelada — nenhum arquivo foi criado."]
        tempoDeGravacao = 0
        waveform = []
        limparDepoisDeGravar()
        estado = .ocioso
    }

    private func iniciar() async {
        guard let armazenamento else { return }
        avisos = []
        waveform = []
        tempoDeGravacao = 0
        notasDaGravacao = []
        rascunhoDaNota = ""
        proximaNotaSeraCritica = false

        let sessao = SessaoGravacao(armazenamento: armazenamento)
        do {
            try await sessao.iniciar()
        } catch {
            estado = .falhou("\(error)")
            return
        }

        self.sessao = sessao
        estado = .gravando
        let identificador = UUID()
        identificadorDaGravacao = identificador

        // Waveform: amostra o nível a ~20 Hz. O medidor é atômico, então
        // ler daqui não toca na thread de áudio. O tempo vem da própria
        // sessão, para manter notas e áudio sincronizados mesmo com buffers.
        iniciarMonitoramentoDeNivel(sessao: sessao, identificador: identificador)
    }

    private func parar() async {
        tarefaNivel?.cancel()
        tarefaNivel = nil
        guard let sessao else { return }

        // A última atualização visual acontece a cada 50 ms. Antes de anexar
        // um rascunho ao término, consultamos a sessão diretamente para que o
        // timestamp final não fique preso à última atualização da waveform.
        tempoDeGravacao = await sessao.tempoDecorrido()
        confirmarRascunhoDaNota()

        estado = .processando
        let resultado = await sessao.parar()
        self.sessao = nil
        identificadorDaGravacao = nil

        avisos = resultado.avisos
        estado = .ocioso
        tempoDeGravacao = resultado.duracao

        // Gravação descartada por ser curta demais volta com duração 0 e já foi
        // apagada do disco — não entra na biblioteca.
        if resultado.duracao > 0 {
            let notas = notasDaGravacao.map { nota in
                var notaAjustada = nota
                notaAjustada.start = min(max(0, nota.start), resultado.duracao)
                return notaAjustada
            }
            await aoProduzirAudio?(
                Self.tituloParaAgora(),
                resultado.pastaRelativa,
                resultado.duracao,
                Self.notasParaArquivo(notas)
            )
        } else if !notasDaGravacao.isEmpty {
            avisos.append(
                "As notas também foram descartadas porque a gravação era curta demais para criar um arquivo."
            )
        }

        // Uma gravação curta é descartada junto com o áudio, portanto não há
        // um arquivo ao qual as notas possam pertencer.
        limparDepoisDeGravar()
    }

    private func iniciarMonitoramentoDeNivel(sessao: SessaoGravacao, identificador: UUID) {
        identificadorDaGravacao = identificador
        let nivel = sessao.nivelMicrofone
        tarefaNivel = Task { [weak self] in
            while !Task.isCancelled {
                let valor = nivel.normalizado
                let tempo = await sessao.tempoDecorrido()
                await MainActor.run {
                    guard self?.identificadorDaGravacao == identificador,
                          self?.estado == .gravando
                    else { return }
                    self?.acrescentarAoWaveform(valor)
                    self?.tempoDeGravacao = tempo
                }
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    private func limparDepoisDeGravar() {
        notasDaGravacao = []
        rascunhoDaNota = ""
        proximaNotaSeraCritica = false
    }

    /// Título provisório de uma gravação. O resumo produz um título melhor
    /// (`Resumo.titulo`) — mas só depois de rodar, e a lista precisa mostrar
    /// alguma coisa enquanto isso.
    private static func tituloParaAgora() -> String {
        let formato = Date.FormatStyle(date: .abbreviated, time: .shortened)
        return "Gravação de \(Date().formatted(formato))"
    }

    private static func notasParaArquivo(_ notas: [NotaDaConversa]) -> [NotaDaConversa] {
        var resultado = notas.filter { $0.tipo == .marcador }
        let anotacoes = notas
            .filter { $0.tipo == .nota }
            .sorted { $0.start < $1.start }

        if !anotacoes.isEmpty {
            resultado.insert(
                NotaDaConversa(
                    texto: anotacoes.map { linhaDeNotaSalva($0) }.joined(separator: "\n"),
                    start: 0,
                    critica: anotacoes.contains { $0.critica },
                    tipo: .nota
                ),
                at: 0
            )
        }

        return resultado
    }

    private static func linhaDeNotaSalva(_ nota: NotaDaConversa) -> String {
        "[\(tempoCurto(nota.start))] \(nota.texto)"
    }

    private static func tempoCurto(_ segundos: TimeInterval) -> String {
        let total = max(0, Int(segundos))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private func acrescentarAoWaveform(_ valor: Float) {
        waveform.append(valor)
        if waveform.count > quadrosWaveform {
            waveform.removeFirst(waveform.count - quadrosWaveform)
        }
    }

    // MARK: - Notas da gravação

    /// Registra o texto atual com o carimbo de tempo do áudio. Rascunhos vazios
    /// não viram cartões silenciosos no detalhe.
    func adicionarNota() {
        let texto = rascunhoDaNota.trimmingCharacters(in: .whitespacesAndNewlines)
        guard estado == .gravando, !texto.isEmpty else { return }

        notasDaGravacao.append(
            NotaDaConversa(
                texto: texto,
                start: tempoDeGravacao,
                critica: proximaNotaSeraCritica,
                tipo: .nota
            )
        )
        rascunhoDaNota = ""
        proximaNotaSeraCritica = false
    }

    /// Um marcador é uma nota sem texto livre que conserva o instante exato da
    /// conversa. Pode ser usado depois para localizar um ponto relevante.
    func inserirMarcador() {
        guard estado == .gravando else { return }

        notasDaGravacao.append(
            NotaDaConversa(
                texto: "Marcador",
                start: tempoDeGravacao,
                critica: proximaNotaSeraCritica,
                tipo: .marcador
            )
        )
        proximaNotaSeraCritica = false
    }

    private func confirmarRascunhoDaNota() {
        adicionarNota()
    }

    // MARK: - Importação

    /// - Important: `url` precisa vir do `.fileImporter` **com o acesso
    ///   security-scoped já aberto** por quem chama.
    func importar(_ url: URL) async {
        guard let armazenamento else { return }
        estado = .processando
        do {
            let importado = try await ImportadorAudio(armazenamento: armazenamento).importar(de: url)
            avisos = ["Arquivo importado: um canal só, sem separação de falante."]
            estado = .ocioso
            await aoProduzirAudio?(
                importado.tituloSugerido, importado.pastaRelativa, importado.duracao, []
            )
        } catch {
            estado = .falhou(Self.mensagemAmigavelDeImportacao(error))
        }
    }

    private static func mensagemAmigavelDeImportacao(_ error: Error) -> String {
        let nsError = error as NSError
        let texto = "\(nsError.localizedDescription) \(nsError.localizedFailureReason ?? "")"
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

        if texto.contains("iphone") || texto.contains("locked") || texto.contains("bloqueado") {
            return "Você precisa desbloquear seu iPhone antes de importar esse áudio."
        }
        if nsError.domain == NSCocoaErrorDomain && [257, 260, 513].contains(nsError.code) {
            return "Não consegui acessar esse áudio. Se ele estiver no iPhone, desbloqueie o aparelho e tente importar de novo."
        }
        return "\(error)"
    }
}
