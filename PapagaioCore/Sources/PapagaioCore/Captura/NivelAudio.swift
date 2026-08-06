import Darwin
import Synchronization

/// Nível RMS do último bloco capturado, para a waveform ao vivo.
///
/// No backend novo (Eko) o microfone é gravado por `AVAudioRecorder`, cujo
/// medidor entrega decibéis em vez de amostras — a UI escreve por
/// `definirNormalizado`. A API por amostras (`registrar`) continua para os
/// testes e para quem ainda tiver a leitura direta de PCM.
public final class NivelAudio: @unchecked Sendable {
    private let bits = Atomic<UInt32>(0)

    public init() {}

    /// Chamado **na thread de áudio**. Só aritmética.
    public func registrar(_ amostras: UnsafePointer<Float>, quantidade: Int) {
        guard quantidade > 0 else { return }
        var soma: Float = 0
        for i in 0..<quantidade {
            let amostra = amostras[i]
            soma += amostra * amostra
        }
        let rms = (soma / Float(quantidade)).squareRoot()
        bits.store(rms.bitPattern, ordering: .relaxed)
    }

    /// Recebe um valor normalizado (0…1) — a saída direta do medidor do
    /// `AVAudioRecorder`, já escalada. Armazena o RMS equivalente para que
    /// `rms` e `normalizado` continuem consistentes entre si.
    public func definirNormalizado(_ valor: Float) {
        let normalizado = max(0, min(1, valor))
        let db = normalizado * 60 - 60
        let rms = pow(10, db / 20)
        bits.store(Float(rms).bitPattern, ordering: .relaxed)
    }

    /// RMS linear, 0…1.
    public var rms: Float {
        Float(bitPattern: bits.load(ordering: .relaxed))
    }

    /// Nível normalizado para desenho, comprimido em escala de decibéis.
    /// -60 dBFS vira 0, 0 dBFS vira 1.
    public var normalizado: Float {
        let valor = rms
        guard valor > 0.000_001 else { return 0 }
        let db = 20 * log10(valor)
        return max(0, min(1, (db + 60) / 60))
    }
}
