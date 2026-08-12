import AVFoundation
import Foundation
import Speech
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
    private(set) var avisos: [String] = [] {
        didSet { agendarSumicoDosAvisos() }
    }

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
    private var tarefaDeSumicoDosAvisos: Task<Void, Never>?
    /// Quanto tempo um aviso de "cancelada", "importada" ou "concluída" fica na
    /// tela. Eles descrevem algo que já terminou; passado esse tempo viram
    /// ruído fixo num lugar onde a pessoa já está fazendo outra coisa.
    private let duracaoDosAvisos: Duration = .seconds(30)
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
        tempoDeGravacao = sessao.tempoDecorrido
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

    /// Erros não somem sozinhos: um `.falhou` pede ação da pessoa e sumir
    /// sozinho esconderia o motivo de a gravação não ter acontecido.
    private func agendarSumicoDosAvisos() {
        tarefaDeSumicoDosAvisos?.cancel()
        tarefaDeSumicoDosAvisos = nil
        guard !avisos.isEmpty else { return }

        tarefaDeSumicoDosAvisos = Task { [duracaoDosAvisos] in
            try? await Task.sleep(for: duracaoDosAvisos)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.avisos = []
            }
        }
    }

    private func iniciar() async {
        guard let armazenamento else { return }

        // Descarta qualquer sessão que tenha sobrado.
        //
        // O `Timer` de medição é criado com `target:`, e alvo de timer é
        // retido: uma sessão que não foi encerrada continua viva, com o
        // `AVAudioRecorder` dela segurando o microfone. A tentativa seguinte
        // então falhava com "recusou começar a gravar" sem motivo aparente.
        if let anterior = sessao {
            await anterior.descartar()
            sessao = nil
        }
        tarefaNivel?.cancel()
        tarefaNivel = nil

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
            // Sem isto a sessão que falhou continuava sendo a `self.sessao` de
            // uma tentativa anterior, e nada a soltava.
            self.sessao = nil
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
        tempoDeGravacao = sessao.tempoDecorrido
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
                let tempo = sessao.tempoDecorrido
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
        "[\(nota.start.comoRelogio)] \(nota.texto)"
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

/// Captura do ditado — **fora do `MainActor` de propósito**.
///
/// O `installTap` entrega buffers na thread de áudio em tempo real. Tocar em
/// estado isolado no `MainActor` a partir dali derruba o processo com
/// `_dispatch_assert_queue_fail` ("Block was not expected to execute on
/// queue") — não é exceção, é o libdispatch abortando. Foi exatamente o que
/// acontecia na primeira versão deste ditado.
///
/// Por isso tudo que o bloco toca vive aqui, sem isolação: o arquivo de saída e
/// o pedido do Speech. O texto reconhecido sai por um callback que quem recebe
/// leva para a main.
final class CapturaDeDitado: @unchecked Sendable {
    let arquivoDeAudio: URL

    private let motor = AVAudioEngine()
    private let pedido = SFSpeechAudioBufferRecognitionRequest()
    private var tarefa: SFSpeechRecognitionTask?
    private var saida: AVAudioFile?

    init(arquivoDeAudio: URL) {
        self.arquivoDeAudio = arquivoDeAudio
    }

    func iniciar(
        reconhecedor: SFSpeechRecognizer,
        aoReconhecer: @escaping @Sendable (String) -> Void
    ) throws {
        let entrada = motor.inputNode
        let formato = entrada.outputFormat(forBus: 0)

        // Sem microfone o formato vem com 0 Hz, e o `installTap` com formato
        // inválido aborta o processo em vez de lançar erro.
        guard formato.sampleRate > 0, formato.channelCount > 0 else {
            throw ErroDeDitado.semEntradaDeAudio
        }

        let arquivo = try AVAudioFile(forWriting: arquivoDeAudio, settings: formato.settings)
        saida = arquivo

        pedido.shouldReportPartialResults = true
        // No dispositivo quando dá: o ditado não sai da máquina.
        pedido.requiresOnDeviceRecognition = reconhecedor.supportsOnDeviceRecognition

        tarefa = reconhecedor.recognitionTask(with: pedido) { resultado, _ in
            guard let texto = resultado?.bestTranscription.formattedString else { return }
            aoReconhecer(texto)
        }

        let pedidoDoTap = pedido
        entrada.installTap(onBus: 0, bufferSize: 2_048, format: formato) { buffer, _ in
            pedidoDoTap.append(buffer)
            try? arquivo.write(from: buffer)
        }

        motor.prepare()
        try motor.start()
    }

    func encerrar() {
        if motor.isRunning { motor.stop() }
        motor.inputNode.removeTap(onBus: 0)
        pedido.endAudio()
        tarefa?.cancel()
        tarefa = nil
        saida = nil
    }

    enum ErroDeDitado: LocalizedError {
        case semEntradaDeAudio
        case reconhecimentoIndisponivel

        var errorDescription: String? {
            switch self {
            case .semEntradaDeAudio: "Nenhum microfone disponível."
            case .reconhecimentoIndisponivel: "O reconhecimento de fala não está disponível agora."
            }
        }
    }
}

/// Ditado de uma nota: texto ao vivo enquanto a pessoa fala, refinado pelo
/// Whisper ao terminar.
///
/// Os dois reconhecedores fazem o que cada um faz melhor. O `Speech` da Apple
/// devolve parciais em tempo real; o Whisper do app acerta mais mas precisa do
/// arquivo inteiro. Se o Whisper falhar, o que a Apple entendeu continua
/// valendo — nunca se perde o ditado.
@MainActor
@Observable
final class DitadoDeNota {
    enum Estado: Equatable {
        case ocioso
        case gravando
        case transcrevendo
        case falhou(String)
    }

    private(set) var estado: Estado = .ocioso
    private(set) var textoParcial = ""

    var gravando: Bool { estado == .gravando }
    var ocupado: Bool { estado == .gravando || estado == .transcrevendo }

    @ObservationIgnored private var captura: CapturaDeDitado?

    func iniciar() async {
        guard !ocupado else { return }
        estado = .ocioso
        textoParcial = ""

        // Microfone primeiro: tocar no `inputNode` antes da permissão devolve
        // formato inválido, e formato inválido no tap aborta o processo.
        guard await autorizarMicrofone() else {
            estado = .falhou("Autorize o microfone em Ajustes do Sistema › Privacidade › Microfone.")
            return
        }
        guard await autorizarFala() else {
            estado = .falhou("Autorize o reconhecimento de fala em Ajustes do Sistema › Privacidade.")
            return
        }

        guard let reconhecedor = SFSpeechRecognizer(locale: Locale(identifier: "pt_BR")) ?? SFSpeechRecognizer(),
              reconhecedor.isAvailable
        else {
            estado = .falhou(CapturaDeDitado.ErroDeDitado.reconhecimentoIndisponivel.localizedDescription)
            return
        }

        let destino = FileManager.default.temporaryDirectory
            .appendingPathComponent("ditado-\(UUID().uuidString).caf")
        let nova = CapturaDeDitado(arquivoDeAudio: destino)

        do {
            try nova.iniciar(reconhecedor: reconhecedor) { texto in
                Task { @MainActor [weak self] in
                    self?.textoParcial = texto
                }
            }
            captura = nova
            estado = .gravando
        } catch {
            nova.encerrar()
            try? FileManager.default.removeItem(at: destino)
            estado = .falhou(error.localizedDescription)
        }
    }

    func concluir(transcrever: (URL) async throws -> String) async -> String? {
        guard estado == .gravando, let captura else { return nil }

        captura.encerrar()
        self.captura = nil
        let gravado = captura.arquivoDeAudio
        let parcial = textoParcial.trimmingCharacters(in: .whitespacesAndNewlines)
        defer { try? FileManager.default.removeItem(at: gravado) }

        estado = .transcrevendo
        do {
            let refinado = try await transcrever(gravado).trimmingCharacters(in: .whitespacesAndNewlines)
            estado = .ocioso
            return refinado.isEmpty ? (parcial.isEmpty ? nil : parcial) : refinado
        } catch {
            estado = .ocioso
            return parcial.isEmpty ? nil : parcial
        }
    }

    func cancelar() {
        if let captura {
            captura.encerrar()
            try? FileManager.default.removeItem(at: captura.arquivoDeAudio)
        }
        captura = nil
        textoParcial = ""
        estado = .ocioso
    }

    func limparFalha() {
        if case .falhou = estado { estado = .ocioso }
    }

    private func autorizarMicrofone() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .audio)
        default: return false
        }
    }

    private func autorizarFala() async -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: return true
        case .notDetermined:
            return await withCheckedContinuation { continuacao in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuacao.resume(returning: status == .authorized)
                }
            }
        default: return false
        }
    }
}
