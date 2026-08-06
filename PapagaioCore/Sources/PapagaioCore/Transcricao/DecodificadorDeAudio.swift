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

    public static func amostras(de url: URL) async throws -> [Float] {
        if url.pathExtension.lowercased() == extensaoCrua {
            return try amostrasCruas(de: url)
        }
        return try await amostrasDecodificadas(de: url)
    }

    private static func amostrasCruas(de url: URL) throws -> [Float] {
        let dados = try Data(contentsOf: url, options: .mappedIfSafe)
        guard !dados.isEmpty else { return [] }
        return dados.withUnsafeBytes { bruto in
            Array(bruto.bindMemory(to: Float.self))
        }
    }

    private static func amostrasDecodificadas(de url: URL) async throws -> [Float] {
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

        var amostras: [Float] = []
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
            amostras.append(contentsOf: pedaco)
        }

        if leitor.status == .failed {
            throw ErroCaptura.arquivoInvalido(
                leitor.error?.localizedDescription ?? "AVAssetReader terminou com falha"
            )
        }

        guard !amostras.isEmpty else {
            throw ErroCaptura.arquivoInvalido("\(url.lastPathComponent) está vazio")
        }
        return amostras
    }

    /// Duração em segundos de um vetor de amostras no formato canônico.
    public static func duracao(de amostras: [Float]) -> TimeInterval {
        TimeInterval(amostras.count) / FormatoAudio.taxaCanonica
    }
}
