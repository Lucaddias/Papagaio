import AVFoundation
import Foundation

/// Captura do microfone via `AVAudioEngine`.
///
/// O bloco do tap faz só aritmética e `memcpy` para o ring buffer. **Não**
/// escreve arquivo ali dentro: codificar AAC aloca, e alocação em thread de
/// áudio produz glitch intermitente que só aparece na máquina do usuário sob
/// carga. A conversão e a escrita ficam no consumidor — ver D-2.2.
public final class CapturaMicrofone: @unchecked Sendable {
    private let engine = AVAudioEngine()
    public let buffer: RingBufferAudio

    /// Formato nativo do dispositivo de entrada. Só é válido depois de `iniciar`.
    public private(set) var formatoNativo: AVAudioFormat?

    /// Nível RMS do último bloco, para a waveform ao vivo. Escrito na thread de
    /// áudio e lido na UI — ver `NivelAudio`.
    public let nivel = NivelAudio()

    private var rodando = false

    public init(capacidadeBuffer: Int = 48_000 * 30) {
        self.buffer = RingBufferAudio(capacidade: capacidadeBuffer)
    }

    public func iniciar() throws {
        guard !rodando else { return }

        let entrada = engine.inputNode
        let formato = entrada.outputFormat(forBus: 0)
        guard formato.sampleRate > 0, formato.channelCount > 0 else {
            throw ErroCaptura.formatoIndisponivel
        }
        formatoNativo = formato

        let buffer = self.buffer
        let nivel = self.nivel
        let canais = Int(formato.channelCount)

        entrada.installTap(onBus: 0, bufferSize: 4096, format: formato) { blocoPCM, _ in
            // ===== THREAD DE ÁUDIO =====
            // Permitido: aritmética e memcpy. Proibido: alocar, lock, Task,
            // await, print, ARC não trivial.
            guard let canaisFloat = blocoPCM.floatChannelData else { return }
            let quadros = Int(blocoPCM.frameLength)
            guard quadros > 0 else { return }

            if canais == 1 {
                buffer.escrever(canaisFloat[0], quantidade: quadros)
                nivel.registrar(canaisFloat[0], quantidade: quadros)
            } else {
                // Downmix para mono somando os canais no próprio buffer do
                // canal 0 é destrutivo; em vez disso escrevemos o canal 0 e
                // somamos os demais amostra a amostra num acumulador local do
                // ring buffer. Como não podemos alocar aqui, fazemos a média
                // in-place no canal 0 — o buffer é descartável depois do tap.
                let destino = canaisFloat[0]
                for quadro in 0..<quadros {
                    var soma = destino[quadro]
                    for canal in 1..<canais {
                        soma += canaisFloat[canal][quadro]
                    }
                    destino[quadro] = soma / Float(canais)
                }
                buffer.escrever(destino, quantidade: quadros)
                nivel.registrar(destino, quantidade: quadros)
            }
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            entrada.removeTap(onBus: 0)
            throw error
        }
        rodando = true
    }

    public func parar() {
        guard rodando else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        rodando = false
    }
}
