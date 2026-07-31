import Darwin
import Synchronization

/// Nível RMS do último bloco capturado, para a waveform ao vivo.
///
/// Escrito na thread de áudio, lido na UI. Um `Atomic<UInt32>` com o bit
/// pattern do `Float` evita lock nos dois lados — a UI pode ler um valor de
/// um bloco atrás, o que é irrelevante para um medidor a ~20 Hz.
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
