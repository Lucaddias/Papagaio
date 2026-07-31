import AVFoundation

/// Converte um fluxo mono na taxa nativa do dispositivo para o formato
/// canônico (Float32 mono 16 kHz).
///
/// Roda **fora** da thread de áudio — aloca à vontade. O downmix para mono já
/// aconteceu no bloco do tap; aqui só sobra a reamostragem.
///
/// Usa `AVAudioConverter`, que aciona o codec por hardware. Nunca ffmpeg: além
/// da licença e do tamanho, sob App Sandbox não se invoca processo externo —
/// o mesmo motivo que descarta `whisper-cli` via subprocess.
final class ConversorCanonico {
    private let conversor: AVAudioConverter
    private let formatoEntrada: AVAudioFormat
    private let formatoSaida = FormatoAudio.canonico
    private let razao: Double

    init?(taxaNativa: Double) {
        guard taxaNativa > 0,
              let entrada = AVAudioFormat(
                  commonFormat: .pcmFormatFloat32,
                  sampleRate: taxaNativa,
                  channels: 1,
                  interleaved: false
              ),
              let conversor = AVAudioConverter(from: entrada, to: formatoSaida)
        else { return nil }

        self.formatoEntrada = entrada
        self.conversor = conversor
        self.razao = formatoSaida.sampleRate / taxaNativa
    }

    /// Converte um lote. Devolve as amostras já em 16 kHz.
    func converter(_ amostras: [Float]) -> [Float] {
        guard !amostras.isEmpty else { return [] }

        guard let entrada = AVAudioPCMBuffer(
            pcmFormat: formatoEntrada,
            frameCapacity: AVAudioFrameCount(amostras.count)
        ) else { return [] }

        entrada.frameLength = AVAudioFrameCount(amostras.count)
        amostras.withUnsafeBufferPointer { origem in
            entrada.floatChannelData![0].update(from: origem.baseAddress!, count: amostras.count)
        }

        // Folga generosa: o conversor pode emitir um pouco mais que o cálculo
        // exato por causa do estado interno do reamostrador.
        let capacidadeSaida = AVAudioFrameCount(Double(amostras.count) * razao) + 64
        guard let saida = AVAudioPCMBuffer(
            pcmFormat: formatoSaida,
            frameCapacity: capacidadeSaida
        ) else { return [] }

        var jaEntregue = false
        var erro: NSError?
        let status = conversor.convert(to: saida, error: &erro) { _, statusEntrada in
            if jaEntregue {
                statusEntrada.pointee = .noDataNow
                return nil
            }
            jaEntregue = true
            statusEntrada.pointee = .haveData
            return entrada
        }

        guard status != .error, saida.frameLength > 0, let canal = saida.floatChannelData else {
            return []
        }
        return Array(UnsafeBufferPointer(start: canal[0], count: Int(saida.frameLength)))
    }
}
