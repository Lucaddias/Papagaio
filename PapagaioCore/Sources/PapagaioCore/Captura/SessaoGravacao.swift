import AVFoundation
import Foundation

/// Uma sessão de gravação: liga microfone e áudio do sistema, converte os dois
/// para o formato canônico, guarda cada canal separado (insumo do ASR e da
/// atribuição de falante) e mixa os dois num `.m4a` de arquivamento.
///
/// **A falha do tap do sistema não derruba a gravação.** Se o tap não subir
/// (permissão negada, API indisponível), a sessão continua só com microfone e
/// registra o motivo em `avisos` — critério explícito do Passo 2.
public actor SessaoGravacao {
    public struct Resultado: Sendable {
        public let id: UUID
        /// Caminho relativo ao container — é isto que vai para o modelo.
        public let pastaRelativa: String
        public let duracao: TimeInterval
        /// `true` só se o canal do sistema entregou **amostras não silenciosas**.
        /// Não basta o tap ter subido: com R-11 ele sobe e entrega zeros, e
        /// dizer "mic + sistema" nesse caso é o app mentindo para o usuário.
        public let capturouAudioDoSistema: Bool
        public let bytesMixagem: Int
        public let avisos: [String]

        public init(
            id: UUID,
            pastaRelativa: String,
            duracao: TimeInterval,
            capturouAudioDoSistema: Bool,
            bytesMixagem: Int,
            avisos: [String]
        ) {
            self.id = id
            self.pastaRelativa = pastaRelativa
            self.duracao = duracao
            self.capturouAudioDoSistema = capturouAudioDoSistema
            self.bytesMixagem = bytesMixagem
            self.avisos = avisos
        }
    }

    public let id: UUID
    private let armazenamento: Armazenamento
    private let microfone: CapturaMicrofone
    private let sistema: CapturaSistema

    private var pasta: URL?
    private var arquivoMixagem: AVAudioFile?
    private var pcmMicrofone: FileHandle?
    private var pcmSistema: FileHandle?

    private var conversorMicrofone: ConversorCanonico?
    private var conversorSistema: ConversorCanonico?

    private var tarefaConsumo: Task<Void, Never>?
    private var amostrasMixadas = 0
    private var capturouSistema = false
    private var sistemaTeveSinal = false
    private var avisos: [String] = []

    /// Cadência do consumidor. 100 ms é folgado para um ring buffer de 30 s e
    /// barato o suficiente para não pesar.
    private let intervaloConsumo = Duration.milliseconds(100)

    /// Abaixo disto a amostra é silêncio digital. −80 dBFS.
    static let limiarDeSilencio: Float = 0.0001

    /// Gravação mais curta que isto é clique acidental, não gravação.
    /// É descartada do disco em vez de virar arquivo de 26 KB na lista.
    public static let duracaoMinima: TimeInterval = 1.0

    public init(
        id: UUID = UUID(),
        armazenamento: Armazenamento,
        microfone: CapturaMicrofone = CapturaMicrofone(),
        sistema: CapturaSistema = CapturaSistema()
    ) {
        self.id = id
        self.armazenamento = armazenamento
        self.microfone = microfone
        self.sistema = sistema
    }

    /// Nível do microfone para a waveform ao vivo.
    public nonisolated var nivelMicrofone: NivelAudio { microfone.nivel }

    // MARK: - Ciclo de vida

    public func iniciar() throws {
        let pasta = try armazenamento.criarPastaDaGravacao(id: id)
        self.pasta = pasta

        // 1. Microfone — obrigatório. Se falhar, a sessão inteira falha.
        try microfone.iniciar()
        guard let formatoMic = microfone.formatoNativo,
              let conversorMic = ConversorCanonico(taxaNativa: formatoMic.sampleRate)
        else {
            microfone.parar()
            throw ErroCaptura.formatoIndisponivel
        }
        conversorMicrofone = conversorMic

        // 2. Áudio do sistema — desejável, não obrigatório.
        do {
            try sistema.iniciar()
            guard let formatoSis = sistema.formatoNativo,
                  let conversorSis = ConversorCanonico(taxaNativa: formatoSis.sampleRate)
            else {
                throw ErroCaptura.formatoIndisponivel
            }
            conversorSistema = conversorSis
            capturouSistema = true
        } catch {
            sistema.parar()
            capturouSistema = false
            avisos.append(
                "Áudio do sistema indisponível — gravando só o microfone. Motivo: \(error)"
            )
        }

        // 3. Destinos.
        arquivoMixagem = try AVAudioFile(
            forWriting: pasta.appendingPathComponent(Armazenamento.Nome.mixagem),
            settings: FormatoAudio.arquivamento
        )
        pcmMicrofone = try criarArquivo(pasta.appendingPathComponent(Armazenamento.Nome.pcmMicrofone))
        if capturouSistema {
            pcmSistema = try criarArquivo(pasta.appendingPathComponent(Armazenamento.Nome.pcmSistema))
        }

        // 4. Consumidor.
        let cadencia = intervaloConsumo
        tarefaConsumo = Task { [weak self] in
            while !Task.isCancelled {
                await self?.drenar()
                try? await Task.sleep(for: cadencia)
            }
        }
    }

    public func parar() async -> Resultado {
        tarefaConsumo?.cancel()
        tarefaConsumo = nil

        microfone.parar()
        sistema.parar()

        // Uma última passada: o que ficou nos ring buffers depois do stop.
        drenar()

        arquivoMixagem = nil
        try? pcmMicrofone?.close()
        try? pcmSistema?.close()
        pcmMicrofone = nil
        pcmSistema = nil

        let caminho = pasta.map { $0.appendingPathComponent(Armazenamento.Nome.mixagem) }
        let bytes = caminho.flatMap {
            try? FileManager.default.attributesOfItem(atPath: $0.path)[.size] as? Int
        } ?? 0

        var todosAvisos = avisos
        if capturouSistema, !sistemaTeveSinal {
            todosAvisos.append(
                "O áudio do sistema foi capturado mas veio em silêncio — a voz do "
                    + "interlocutor não foi gravada. Verifique a permissão de captura "
                    + "de áudio nos Ajustes do Sistema."
            )
        }
        let perdaMic = microfone.buffer.amostrasDescartadas
        let perdaSis = sistema.buffer.amostrasDescartadas
        if perdaMic > 0 {
            todosAvisos.append("Microfone: \(perdaMic) amostras descartadas por buffer cheio.")
        }
        if perdaSis > 0 {
            todosAvisos.append("Áudio do sistema: \(perdaSis) amostras descartadas por buffer cheio.")
        }

        let duracao = Double(amostrasMixadas) / FormatoAudio.taxaCanonica

        // Clique acidental: apaga em vez de deixar lixo na biblioteca.
        if duracao < Self.duracaoMinima, let pasta {
            try? FileManager.default.removeItem(at: pasta)
            self.pasta = nil
            return Resultado(
                id: id,
                pastaRelativa: Armazenamento.caminhoRelativo(id: id),
                duracao: 0,
                capturouAudioDoSistema: false,
                bytesMixagem: 0,
                avisos: ["Gravação curta demais (\(String(format: "%.1f", duracao)) s) — descartada."]
            )
        }

        return Resultado(
            id: id,
            pastaRelativa: Armazenamento.caminhoRelativo(id: id),
            duracao: duracao,
            capturouAudioDoSistema: sistemaTeveSinal,
            bytesMixagem: bytes,
            avisos: todosAvisos
        )
    }

    // MARK: - Consumo e mixagem

    private func drenar() {
        let doMicrofone = puxar(de: microfone.buffer, conversor: conversorMicrofone)
        let doSistema = puxar(de: sistema.buffer, conversor: conversorSistema)

        if !doMicrofone.isEmpty { escreverPCM(doMicrofone, em: pcmMicrofone) }
        if !doSistema.isEmpty {
            escreverPCM(doSistema, em: pcmSistema)
            if !sistemaTeveSinal, doSistema.contains(where: { abs($0) > Self.limiarDeSilencio }) {
                sistemaTeveSinal = true
            }
        }

        // Mixagem: soma os dois canais, preenchendo com silêncio o que faltar
        // no mais curto do lote. Sem tap do sistema, `doSistema` é sempre
        // vazio e a mixagem vira o microfone puro.
        let quadros = max(doMicrofone.count, doSistema.count)
        guard quadros > 0 else { return }

        var mistura = [Float](repeating: 0, count: quadros)
        for i in 0..<doMicrofone.count { mistura[i] += doMicrofone[i] }
        for i in 0..<doSistema.count { mistura[i] += doSistema[i] }
        // Somar dois canais pode estourar 1.0 — corta em vez de deixar
        // envolver e virar estalo.
        for i in 0..<quadros { mistura[i] = max(-1, min(1, mistura[i])) }

        escreverMixagem(mistura)
        amostrasMixadas += quadros
    }

    private func puxar(de buffer: RingBufferAudio, conversor: ConversorCanonico?) -> [Float] {
        guard let conversor else { return [] }
        let disponivel = buffer.pendentes
        guard disponivel > 0 else { return [] }

        var bruto = [Float](repeating: 0, count: disponivel)
        let lidas = bruto.withUnsafeMutableBufferPointer { destino in
            buffer.ler(para: destino.baseAddress!, quantidade: disponivel)
        }
        guard lidas > 0 else { return [] }
        if lidas < disponivel { bruto.removeLast(disponivel - lidas) }

        return conversor.converter(bruto)
    }

    private func escreverMixagem(_ amostras: [Float]) {
        guard let arquivo = arquivoMixagem,
              let buffer = AVAudioPCMBuffer(
                  pcmFormat: arquivo.processingFormat,
                  frameCapacity: AVAudioFrameCount(amostras.count)
              )
        else { return }

        buffer.frameLength = AVAudioFrameCount(amostras.count)
        amostras.withUnsafeBufferPointer { origem in
            buffer.floatChannelData![0].update(from: origem.baseAddress!, count: amostras.count)
        }
        try? arquivo.write(from: buffer)
    }

    private func escreverPCM(_ amostras: [Float], em arquivo: FileHandle?) {
        guard let arquivo else { return }
        amostras.withUnsafeBufferPointer { origem in
            try? arquivo.write(contentsOf: Data(buffer: origem))
        }
    }

    private func criarArquivo(_ url: URL) throws -> FileHandle {
        FileManager.default.createFile(atPath: url.path, contents: nil)
        return try FileHandle(forWritingTo: url)
    }
}
