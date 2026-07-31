import AVFoundation
import Foundation

/// Importa um arquivo de áudio externo para dentro do container.
///
/// Um arquivo importado tem **um canal só de origem** — não há microfone nem
/// tap para separar. Os trechos que saírem dele ficam com `speaker: nil`,
/// sem atribuição de falante (ver skill `papagaio-speaker-attribution`).
public struct ImportadorAudio: Sendable {
    public struct Resultado: Sendable {
        public let id: UUID
        public let pastaRelativa: String
        public let duracao: TimeInterval
        public let bytes: Int
        public let tituloSugerido: String
    }

    private let armazenamento: Armazenamento

    public init(armazenamento: Armazenamento) {
        self.armazenamento = armazenamento
    }

    /// Valida, converte para o formato de arquivamento e **copia para o
    /// container**. Nenhuma referência ao arquivo original sobrevive.
    ///
    /// - Important: sob App Sandbox, quem chama precisa ter aberto o acesso com
    ///   `startAccessingSecurityScopedResource()` antes — é o erro nº 1 de
    ///   importação. Ver `ContentView` no app.
    public func importar(de origem: URL, id: UUID = UUID()) async throws -> Resultado {
        let asset = AVURLAsset(url: origem)

        let trilhas = try await asset.loadTracks(withMediaType: .audio)
        guard !trilhas.isEmpty else {
            throw ErroCaptura.arquivoInvalido("nenhuma trilha de áudio em \(origem.lastPathComponent)")
        }

        let duracao = try await asset.load(.duration)
        let segundos = CMTimeGetSeconds(duracao)
        guard segundos.isFinite, segundos > 0 else {
            throw ErroCaptura.arquivoInvalido("duração inválida")
        }

        let pasta = try armazenamento.criarPastaDaGravacao(id: id)
        let destino = pasta.appendingPathComponent(Armazenamento.Nome.mixagem)

        try await converter(asset: asset, para: destino)

        let bytes = (try? FileManager.default.attributesOfItem(atPath: destino.path)[.size] as? Int) ?? 0

        return Resultado(
            id: id,
            pastaRelativa: Armazenamento.caminhoRelativo(id: id),
            duracao: segundos,
            bytes: bytes,
            tituloSugerido: origem.deletingPathExtension().lastPathComponent
        )
    }

    /// Lê o asset e reescreve no formato canônico de arquivamento
    /// (AAC mono 16 kHz), usando o encoder por hardware via `AVAudioConverter`.
    private func converter(asset: AVURLAsset, para destino: URL) async throws {
        let leitor = try AVAssetReader(asset: asset)
        let trilhas = try await asset.loadTracks(withMediaType: .audio)
        guard let trilha = trilhas.first else {
            throw ErroCaptura.arquivoInvalido("sem trilha de áudio")
        }

        // Pede ao leitor PCM Float32 mono já em 16 kHz — o próprio pipeline do
        // AVFoundation faz a reamostragem.
        let saidaTrilha = AVAssetReaderTrackOutput(
            track: trilha,
            outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsNonInterleaved: false,
                AVLinearPCMIsBigEndianKey: false,
                AVSampleRateKey: FormatoAudio.taxaCanonica,
                AVNumberOfChannelsKey: 1,
            ]
        )
        guard leitor.canAdd(saidaTrilha) else {
            throw ErroCaptura.arquivoInvalido("formato não legível pelo AVAssetReader")
        }
        leitor.add(saidaTrilha)

        let arquivo = try AVAudioFile(forWriting: destino, settings: FormatoAudio.arquivamento)

        guard leitor.startReading() else {
            throw ErroCaptura.arquivoInvalido(leitor.error?.localizedDescription ?? "startReading falhou")
        }

        while let amostra = saidaTrilha.copyNextSampleBuffer() {
            defer { CMSampleBufferInvalidate(amostra) }
            guard let blocos = CMSampleBufferGetDataBuffer(amostra) else { continue }

            var tamanho = 0
            var ponteiro: UnsafeMutablePointer<CChar>?
            guard CMBlockBufferGetDataPointer(
                blocos, atOffset: 0, lengthAtOffsetOut: nil,
                totalLengthOut: &tamanho, dataPointerOut: &ponteiro
            ) == noErr, let ponteiro, tamanho > 0 else { continue }

            let quadros = tamanho / MemoryLayout<Float>.size
            guard quadros > 0,
                  let buffer = AVAudioPCMBuffer(
                      pcmFormat: arquivo.processingFormat,
                      frameCapacity: AVAudioFrameCount(quadros)
                  )
            else { continue }

            buffer.frameLength = AVAudioFrameCount(quadros)
            ponteiro.withMemoryRebound(to: Float.self, capacity: quadros) { origem in
                buffer.floatChannelData![0].update(from: origem, count: quadros)
            }
            try arquivo.write(from: buffer)
        }

        if leitor.status == .failed {
            throw ErroCaptura.arquivoInvalido(leitor.error?.localizedDescription ?? "leitura falhou")
        }
    }
}
