import AVFoundation
import Foundation

/// Lê qualquer arquivo de áudio e devolve amostras no formato que o Whisper
/// consome: PCM Float32 **mono 16 kHz**.
///
/// A decodificação foi portada do `AudioSampleLoader` do Eko: usa
/// `AVAssetReader` em vez de `AVAudioFile` + `AVAudioConverter`. O
/// `AVAudioFile`/`ExtAudioFile` falha ao decodificar certos contêineres
/// AAC/.m4a "fora do padrão" (mesmo quando o `AVPlayer` toca o arquivo sem
/// problema); o `AVAssetReader` usa o MESMO pipeline de decodificação do
/// `AVPlayer`, pedindo direto PCM Float32 16 kHz mono como `outputSettings`
/// — ele mesmo resolve o resample/downmix internamente.
///
/// O Whisper não reamostra por conta própria — mandar 48 kHz produz uma
/// transcrição de lixo, não um erro. Por isso a conversão é obrigatória aqui.
public enum DecodificadorDeAudio {
    /// Arquivos `.pcm` legados do Papagaio são Float32 mono 16 kHz crus. Ler
    /// é só reinterpretar os bytes.
    public static let extensaoCrua = "pcm"

    /// Um trecho já normalizado para PCM Float32 mono a 16 kHz.
    ///
    /// A leitura em blocos é o caminho usado pela transcrição. Manter uma
    /// reunião inteira em `[Float]` fazia uma hora de áudio ocupar centenas de
    /// MiB antes mesmo de o Whisper começar a trabalhar.
    public struct Bloco: Sendable {
        public let inicio: TimeInterval
        public let amostras: [Float]

        public init(inicio: TimeInterval, amostras: [Float]) {
            self.inicio = inicio
            self.amostras = amostras
        }
    }

    public static func amostras(de url: URL) async throws -> [Float] {
        if url.pathExtension.lowercased() == extensaoCrua {
            return try amostrasCruas(de: url)
        }
        return try await amostrasDecodificadas(de: url)
    }

    /// Decodifica e entrega PCM canônico em blocos, sem acumular o arquivo
    /// inteiro. O callback é serial: quem consome um bloco pode concluir VAD e
    /// Whisper antes de o próximo ocupar memória.
    public static func processarEmBlocos(
        de url: URL,
        amostrasPorBloco: Int = Int(FormatoAudio.taxaCanonica * 60),
        acao: (Bloco) async throws -> Void
    ) async throws {
        precondition(amostrasPorBloco > 0)
        if url.pathExtension.lowercased() == extensaoCrua {
            try await processarPCMCru(
                de: url, amostrasPorBloco: amostrasPorBloco, acao: acao
            )
            return
        }
        try await processarAudioDecodificado(
            de: url, amostrasPorBloco: amostrasPorBloco, acao: acao
        )
    }

    private static func amostrasCruas(de url: URL) throws -> [Float] {
        let dados = try Data(contentsOf: url, options: .mappedIfSafe)
        guard !dados.isEmpty else { return [] }
        return dados.withUnsafeBytes { bruto in
            Array(bruto.bindMemory(to: Float.self))
        }
    }

    private static func amostrasDecodificadas(de url: URL) async throws -> [Float] {
        var resultado: [Float] = []
        try await processarAudioDecodificado(de: url, amostrasPorBloco: 16_000 * 60) { bloco in
            resultado.append(contentsOf: bloco.amostras)
        }
        guard !resultado.isEmpty else {
            throw ErroCaptura.arquivoInvalido("\(url.lastPathComponent) está vazio")
        }
        return resultado
    }

    private static func processarPCMCru(
        de url: URL,
        amostrasPorBloco: Int,
        acao: (Bloco) async throws -> Void
    ) async throws {
        let arquivo = try FileHandle(forReadingFrom: url)
        defer { try? arquivo.close() }

        var amostrasEntregues = 0
        let bytesPorBloco = amostrasPorBloco * MemoryLayout<Float>.size
        while let dados = try arquivo.read(upToCount: bytesPorBloco), !dados.isEmpty {
            guard dados.count.isMultiple(of: MemoryLayout<Float>.size) else {
                throw ErroCaptura.arquivoInvalido("\(url.lastPathComponent) tem PCM truncado")
            }
            let amostras = dados.withUnsafeBytes { bruto in
                Array(bruto.bindMemory(to: Float.self))
            }
            let inicio = TimeInterval(amostrasEntregues) / FormatoAudio.taxaCanonica
            try await acao(Bloco(inicio: inicio, amostras: amostras))
            amostrasEntregues += amostras.count
        }
    }

    private static func processarAudioDecodificado(
        de url: URL,
        amostrasPorBloco: Int,
        acao: (Bloco) async throws -> Void
    ) async throws {
        let asset = AVURLAsset(url: url)

        let trilhas: [AVAssetTrack]
        do {
            trilhas = try await asset.loadTracks(withMediaType: .audio)
        } catch {
            throw ErroCaptura.arquivoInvalido("loadTracks falhou: \(error.localizedDescription)")
        }
        guard let trilha = trilhas.first else {
            throw ErroCaptura.arquivoInvalido("\(url.lastPathComponent) não tem trilha de áudio")
        }

        let saidaTrilha = AVAssetReaderTrackOutput(
            track: trilha,
            outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: FormatoAudio.taxaCanonica,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsNonInterleaved: true,
                AVLinearPCMIsBigEndianKey: false,
            ]
        )
        saidaTrilha.alwaysCopiesSampleData = false

        let leitor: AVAssetReader
        do {
            leitor = try AVAssetReader(asset: asset)
        } catch {
            throw ErroCaptura.arquivoInvalido("AVAssetReader não inicializou: \(error.localizedDescription)")
        }
        guard leitor.canAdd(saidaTrilha) else {
            throw ErroCaptura.arquivoInvalido("AVAssetReader recusou a trilha de áudio")
        }
        leitor.add(saidaTrilha)

        guard leitor.startReading() else {
            throw ErroCaptura.arquivoInvalido(
                leitor.error?.localizedDescription ?? "startReading falhou sem detalhe"
            )
        }

        var pendentes: [Float] = []
        pendentes.reserveCapacity(amostrasPorBloco)
        var amostrasEntregues = 0
        while let buffer = saidaTrilha.copyNextSampleBuffer() {
            defer { CMSampleBufferInvalidate(buffer) }
            guard let bloco = CMSampleBufferGetDataBuffer(buffer) else { continue }
            let bytes = CMBlockBufferGetDataLength(bloco)
            guard bytes > 0 else { continue }

            let quantidade = bytes / MemoryLayout<Float>.size
            var pedaco = [Float](repeating: 0, count: quantidade)
            let status = pedaco.withUnsafeMutableBytes { bruto -> OSStatus in
                CMBlockBufferCopyDataBytes(
                    bloco, atOffset: 0, dataLength: bytes, destination: bruto.baseAddress!
                )
            }
            guard status == noErr else {
                throw ErroCaptura.arquivoInvalido("CMBlockBufferCopyDataBytes: OSStatus \(status)")
            }
            var inicioDoPedaco = 0
            while inicioDoPedaco < pedaco.count {
                let vagas = amostrasPorBloco - pendentes.count
                let quantidadeParaCopiar = min(vagas, pedaco.count - inicioDoPedaco)
                pendentes.append(contentsOf: pedaco[inicioDoPedaco..<(inicioDoPedaco + quantidadeParaCopiar)])
                inicioDoPedaco += quantidadeParaCopiar

                guard pendentes.count == amostrasPorBloco else { continue }
                let inicio = TimeInterval(amostrasEntregues) / FormatoAudio.taxaCanonica
                try await acao(Bloco(inicio: inicio, amostras: pendentes))
                amostrasEntregues += pendentes.count
                pendentes.removeAll(keepingCapacity: true)
            }
        }

        if leitor.status == .failed {
            throw ErroCaptura.arquivoInvalido(
                leitor.error?.localizedDescription ?? "AVAssetReader terminou com falha"
            )
        }

        if !pendentes.isEmpty {
            let inicio = TimeInterval(amostrasEntregues) / FormatoAudio.taxaCanonica
            try await acao(Bloco(inicio: inicio, amostras: pendentes))
        }
    }

    /// Duração em segundos de um vetor de amostras no formato canônico.
    public static func duracao(de amostras: [Float]) -> TimeInterval {
        TimeInterval(amostras.count) / FormatoAudio.taxaCanonica
    }
}
