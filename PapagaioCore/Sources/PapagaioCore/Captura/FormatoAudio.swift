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

    /// Formato do microfone gravado pelo `AVAudioRecorder` — PCM de 16 bits
    /// a 16 kHz mono (o mesmo do Eko). WAV é o que preserva o áudio sem as
    /// perdas da codificação AAC mono de 16 kHz, e é a reprodução que deixava
    /// o Papagaio "abafado". Só o canal do sistema (que sai do tap em taxa
    /// nativa) é AAC — e em altas taxas, não rebaixado para 16 kHz.
    public static var microfoneWAV: [String: Any] {
        [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: taxaCanonica,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
        ]
    }

    /// Formato de arquivamento: AAC mono 16 kHz.
    ///
    /// Mantido como legado — gravações antigas e o teste de reprodução ainda
    /// escrevem `.m4a`. As gravações novas não passam mais por aqui: o
    /// microfone é WAV e o canal de sistema sai do tap em taxa nativa.
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

    /// Formato dos canais usados pela transcrição. Diferente da mixagem AAC,
    /// WAV preserva o PCM canônico sem cabeçalhos ambíguos ou dados crus sem
    /// metadados de taxa/canais.
    public static var transcricaoWAV: [String: Any] {
        [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: taxaCanonica,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: true,
            AVLinearPCMIsBigEndianKey: false,
        ]
    }
}
