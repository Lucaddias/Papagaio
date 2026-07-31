import AVFoundation
import CoreAudio
import Foundation

/// Captura do áudio do sistema via Core Audio Process Taps.
///
/// Usa a API Swift de `CoreAudio` (macOS 15+): `AudioHardwareSystem.shared`,
/// `makeProcessTap`, `makeAggregateDevice`. Isso substitui a sequência C de
/// `AudioHardwareCreateProcessTap`/`AudioHardwareCreateAggregateDevice` com
/// erro tipado e sem ponteiro cru — ver D-2.1.
///
/// A entrega dos quadros continua sendo `AudioDeviceCreateIOProcIDWithBlock`:
/// não existe equivalente Swift, e **não** dá para apontar um `AVAudioEngine`
/// para o aggregate device (setar `kAudioOutputUnitProperty_CurrentDevice`
/// retorna `noErr` e o engine segue lendo o input default em silêncio).
public final class CapturaSistema: @unchecked Sendable {
    public let buffer: RingBufferAudio

    private let sistema = AudioHardwareSystem.shared
    private var tap: AudioHardwareTap?
    private var aggregate: AudioHardwareAggregateDevice?
    private var ioProcID: AudioDeviceIOProcID?

    /// Formato que o tap entrega. Só é válido depois de `iniciar`.
    public private(set) var formatoNativo: AVAudioFormat?

    private var rodando = false

    public init(capacidadeBuffer: Int = 48_000 * 30) {
        self.buffer = RingBufferAudio(capacidade: capacidadeBuffer)
    }

    public func iniciar() throws {
        guard !rodando else { return }
        do {
            let tap = try criarTap()
            self.tap = tap
            let aggregate = try criarAggregate(paraTap: tap)
            self.aggregate = aggregate
            self.formatoNativo = try lerFormato(de: tap)
            try instalarIOProc(no: aggregate)
        } catch {
            desmontar()
            throw error
        }
        rodando = true
    }

    public func parar() {
        guard rodando else { return }
        desmontar()
        rodando = false
    }

    // MARK: - Montagem

    private func criarTap() throws -> AudioHardwareTap {
        // Tap global **excluindo o próprio Papagaio**. Sem isso, o playback do
        // app (tocar um trecho durante a gravação) volta para dentro da captura.
        //
        // As listas do CATapDescription são de AudioObjectID de processo, não
        // de PID — passar o PID cru não excluiria ninguém, silenciosamente.
        let meuPID = ProcessInfo.processInfo.processIdentifier
        guard let meuProcesso = try sistema.process(for: meuPID) else {
            throw ErroCaptura.tapIndisponivel("não foi possível resolver o processo do próprio app")
        }

        let descricao = CATapDescription(monoGlobalTapButExcludeProcesses: [meuProcesso.id])
        descricao.name = "Papagaio — áudio do sistema"
        descricao.isPrivate = true                    // invisível para outros apps
        descricao.isExclusive = false                 // não rouba o áudio de ninguém
        descricao.muteBehavior = .unmuted             // o usuário continua ouvindo a reunião

        guard let tap = try sistema.makeProcessTap(description: descricao) else {
            throw ErroCaptura.tapIndisponivel("makeProcessTap devolveu nil")
        }
        return tap
    }

    private func criarAggregate(paraTap tap: AudioHardwareTap) throws -> AudioHardwareAggregateDevice {
        let tapUID = try tap.uid

        var descricao: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Papagaio Aggregate",
            kAudioAggregateDeviceUIDKey: "com.papagaio.aggregate.\(UUID().uuidString)",
            // Privado: só este processo enxerga o device, e ele some com o app.
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceTapListKey: [
                [
                    kAudioSubTapUIDKey: tapUID,
                    kAudioSubTapDriftCompensationKey: true,
                ] as [String: Any]
            ],
        ]

        // NOTA (R-11): uma hipótese para o tap entregar silêncio é o aggregate
        // não ter fonte de clock. Adicionar o device de saída padrão como
        // subdevice + `kAudioAggregateDeviceMainSubDeviceKey` é a receita
        // usual — mas muda a composição da lista de buffers do IOProc, e
        // `lista.first` deixaria de ser necessariamente o stream do tap.
        // Não aplicado sem poder testar: a hipótese mais provável hoje é TCC,
        // não clock. Ver D-2.6.
        descricao[kAudioAggregateDeviceSubDeviceListKey] = [] as [[String: Any]]

        guard let aggregate = try sistema.makeAggregateDevice(description: descricao) else {
            throw ErroCaptura.tapIndisponivel("makeAggregateDevice devolveu nil")
        }
        return aggregate
    }

    private func lerFormato(de tap: AudioHardwareTap) throws -> AVAudioFormat {
        var asbd = try tap.format
        guard asbd.mSampleRate > 0, asbd.mChannelsPerFrame > 0,
              let formato = AVAudioFormat(streamDescription: &asbd)
        else {
            throw ErroCaptura.formatoIndisponivel
        }
        return formato
    }

    private func instalarIOProc(no aggregate: AudioHardwareAggregateDevice) throws {
        guard let formato = formatoNativo else { throw ErroCaptura.formatoIndisponivel }

        let buffer = self.buffer
        let canais = Int(formato.channelCount)
        let intercalado = formato.isInterleaved

        let status = AudioDeviceCreateIOProcIDWithBlock(&ioProcID, aggregate.id, nil) {
            _, entrada, _, _, _ in
            // ===== THREAD DE ÁUDIO =====
            // Só aritmética e memcpy. Nada de alocar, travar, logar.
            let lista = UnsafeMutableAudioBufferListPointer(
                UnsafeMutablePointer(mutating: entrada)
            )
            guard let primeiro = lista.first, let dados = primeiro.mData else { return }
            let amostras = dados.assumingMemoryBound(to: Float.self)

            if canais == 1 {
                let quadros = Int(primeiro.mDataByteSize) / MemoryLayout<Float>.size
                buffer.escrever(amostras, quantidade: quadros)
            } else if intercalado {
                // Downmix in-place sobre o buffer do driver, que é descartado
                // logo depois deste callback.
                let quadros = Int(primeiro.mDataByteSize) / (MemoryLayout<Float>.size * canais)
                for quadro in 0..<quadros {
                    var soma: Float = 0
                    for canal in 0..<canais {
                        soma += amostras[quadro * canais + canal]
                    }
                    amostras[quadro] = soma / Float(canais)
                }
                buffer.escrever(amostras, quantidade: quadros)
            } else {
                // Não intercalado: um mBuffer por canal. Acumula no canal 0.
                let quadros = Int(primeiro.mDataByteSize) / MemoryLayout<Float>.size
                for indice in 1..<lista.count {
                    guard let outro = lista[indice].mData?.assumingMemoryBound(to: Float.self)
                    else { continue }
                    for quadro in 0..<quadros {
                        amostras[quadro] += outro[quadro]
                    }
                }
                let divisor = Float(lista.count)
                for quadro in 0..<quadros {
                    amostras[quadro] /= divisor
                }
                buffer.escrever(amostras, quantidade: quadros)
            }
        }

        guard status == noErr else {
            throw ErroCaptura.coreAudio("AudioDeviceCreateIOProcIDWithBlock", status)
        }

        let inicio = AudioDeviceStart(aggregate.id, ioProcID)
        guard inicio == noErr else {
            throw ErroCaptura.coreAudio("AudioDeviceStart", inicio)
        }
    }

    // MARK: - Desmontagem

    private func desmontar() {
        if let aggregate, let ioProcID {
            AudioDeviceStop(aggregate.id, ioProcID)
            AudioDeviceDestroyIOProcID(aggregate.id, ioProcID)
        }
        ioProcID = nil

        if let aggregate {
            try? sistema.destroyAggregateDevice(aggregate)
            self.aggregate = nil
        }
        if let tap {
            try? sistema.destroyProcessTap(tap)
            self.tap = nil
        }
    }

    deinit {
        desmontar()
    }
}
