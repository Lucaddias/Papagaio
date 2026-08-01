import AVFoundation

/// Formatos de trabalho do Papagaio. Dois, com propósitos diferentes — ver
/// skill `papagaio-audio-capture`.
public enum FormatoAudio {
    /// O que o `whisper.cpp` consome e o que circula entre captura e mixagem:
    /// PCM Float32, mono, 16 kHz, não intercalado.
    public static let taxaCanonica: Double = 16_000

    public static var canonico: AVAudioFormat {
        // Falha só se os parâmetros forem inválidos — não são, são constantes.
        AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: taxaCanonica,
            channels: 1,
            interleaved: false
        )!
    }

    /// Teto real do encoder AAC a 16 kHz mono.
    ///
    /// A skill `papagaio-audio-capture` prescreve 64 kbps, mas o encoder da
    /// Apple **rejeita** esse valor nesta taxa: `AVAudioFile(forWriting:)`
    /// falha em `AudioConverterSetProperty(kAudioConverterEncodeBitRate)`.
    /// Medido nesta máquina (ver D-2.3):
    ///
    /// | Taxa | Bitrates aceitos (kbps) |
    /// |---|---|
    /// | 16 kHz | 24, 32, **48** |
    /// | 22,05 kHz | 24, 32, 48, 64 |
    /// | 44,1 kHz | 32, 48, 64, 96 |
    ///
    /// 48 kbps é o maior disponível a 16 kHz → ~21,6 MB/h, ~3,6 MB em 10 min.
    public static let bitrateArquivamento = 48_000

    /// Formato de arquivamento: AAC mono 16 kHz.
    /// WAV daria ~350 MB/h e ocuparia espaço demais na biblioteca local.
    ///
    /// Computada, não `let`: um `[String: Any]` estático não é `Sendable` e o
    /// Swift 6 em modo `complete` recusa como estado global mutável.
    public static var arquivamento: [String: Any] {
        [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: taxaCanonica,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: bitrateArquivamento,
        ]
    }
}
