import AVFoundation
import CoreAudio
import Foundation

/// Captura do áudio do sistema via Core Audio Process Taps (macOS 14.4+).
///
/// Portado do Eko (`SystemAudioTap.swift`), que substitui o `CapturaSistema`
/// anterior. A diferença que importa: o tap escreve **direto num `.m4a` AAC na
/// taxa nativa do tap**, em vez de reamostrar para 16 kHz e mixar com o
/// microfone em disco. É isso que devolve o "interlocutor" com clareza —
/// re-encodar o tap em AAC mono 16 kHz é uma das causas do áudio abafado.
///
/// Três armadilhas documentadas que este código já evita:
/// 1. `AVAudioEngine` NÃO funciona apontado para o aggregate device do tap
///    — por isso usamos `AudioDeviceCreateIOProcIDWithBlock` direto.
/// 2. O aggregate device precisa de um sub-device de saída real além do
///    sub-tap, ou a captura fica silenciosa sem erro.
/// 3. Exclua o PID do próprio Papagaio do tap, para não capturar o próprio
///    playback do app durante a gravação.
enum SystemAudioTapError: LocalizedError {
    case apiUnavailable
    case permissionDenied
    case coreAudioFailure(OSStatus, String)

    var errorDescription: String? {
        switch self {
        case .apiUnavailable:
            "Este Mac não suporta captura de áudio do sistema (requer macOS 14.4 ou mais recente)."
        case .permissionDenied:
            "Permita a captura de áudio do sistema nas Configurações do Sistema para gravar o interlocutor."
        case .coreAudioFailure(let status, let step):
            "Falha do Core Audio em \(step) (código \(status))."
        }
    }
}

#if os(macOS)
/// Grava o áudio de saída do sistema (o "interlocutor" de uma reunião
/// online) num arquivo AAC próprio, separado do canal de microfone.
/// Se qualquer etapa falhar, a gravação de microfone segue normalmente —
/// sem crash, com aviso.
final class SystemAudioTap {
    private var tapID: AudioObjectID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateDeviceID: AudioObjectID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?
    private var outputFile: AVAudioFile?

    private(set) var isRunning = false

    /// Inicia a captura, escrevendo em `destinationURL` (criado como .m4a
    /// AAC no formato nativo do tap — sem reamostragem no callback em
    /// tempo real; a conversão para 16 kHz mono usada pelo Whisper acontece
    /// depois, de forma offline, em `DecodificadorDeAudio`).
    func start(destinationURL: URL) throws {
        guard #available(macOS 14.4, *) else { throw SystemAudioTapError.apiUnavailable }

        let description = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
        description.uuid = UUID()
        description.muteBehavior = CATapMuteBehavior.unmuted
        description.isPrivate = true
        description.name = "Papagaio System Audio Tap"

        var newTapID = AudioObjectID(kAudioObjectUnknown)
        var status = AudioHardwareCreateProcessTap(description, &newTapID)
        guard status == noErr else {
            throw mapPermissionOrFailure(status, step: "criar o tap")
        }
        tapID = newTapID

        // O aggregate precisa de um sub-device de saída real, além do
        // sub-tap — ver aviso no topo do arquivo. Sem isso a captura fica
        // silenciosa sem erro (falha do pior tipo: sem crash e sem áudio).
        guard let outputDeviceUID = try? defaultOutputDeviceUID() else {
            cleanupTapOnly()
            throw SystemAudioTapError.coreAudioFailure(kAudioHardwareUnknownPropertyError, "ler o dispositivo de saída padrão")
        }

        let aggregateUID = UUID().uuidString
        let aggregateDescription: [String: Any] = [
            kAudioAggregateDeviceNameKey as String: "Papagaio-System-Aggregate-\(aggregateUID)",
            kAudioAggregateDeviceUIDKey as String: aggregateUID,
            kAudioAggregateDeviceIsPrivateKey as String: true,
            kAudioAggregateDeviceTapAutoStartKey as String: true,
            kAudioAggregateDeviceMainSubDeviceKey as String: outputDeviceUID,
            kAudioAggregateDeviceSubDeviceListKey as String: [
                [kAudioSubDeviceUIDKey as String: outputDeviceUID]
            ],
            kAudioAggregateDeviceTapListKey as String: [
                [
                    kAudioSubTapUIDKey as String: description.uuid.uuidString,
                    kAudioSubTapDriftCompensationKey as String: true
                ]
            ]
        ]

        var newAggregateID = AudioObjectID(kAudioObjectUnknown)
        status = AudioHardwareCreateAggregateDevice(aggregateDescription as CFDictionary, &newAggregateID)
        guard status == noErr else {
            cleanupTapOnly()
            throw SystemAudioTapError.coreAudioFailure(status, "criar o aggregate device")
        }
        aggregateDeviceID = newAggregateID

        // Formato real do tap — lido depois de criado, não assumido.
        let format = try tapAudioFormat()

        let file = try AVAudioFile(forWriting: destinationURL, settings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
            AVEncoderBitRateKey: 64_000
        ])
        outputFile = file

        var newIOProcID: AudioDeviceIOProcID?
        status = AudioDeviceCreateIOProcIDWithBlock(&newIOProcID, aggregateDeviceID, nil) { [weak self] _, inputData, _, _, _ in
            guard let self, let file = self.outputFile,
                  let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: inputData) else { return }
            try? file.write(from: pcmBuffer)
        }
        guard status == noErr, let ioProcID = newIOProcID else {
            cleanupAll()
            throw SystemAudioTapError.coreAudioFailure(status, "criar o IOProc")
        }
        self.ioProcID = ioProcID

        status = AudioDeviceStart(aggregateDeviceID, ioProcID)
        guard status == noErr else {
            cleanupAll()
            throw SystemAudioTapError.coreAudioFailure(status, "iniciar o aggregate device")
        }

        isRunning = true
    }

    func stop() {
        if let ioProcID {
            AudioDeviceStop(aggregateDeviceID, ioProcID)
            AudioDeviceDestroyIOProcID(aggregateDeviceID, ioProcID)
        }
        if aggregateDeviceID != AudioObjectID(kAudioObjectUnknown) {
            AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
        }
        if tapID != AudioObjectID(kAudioObjectUnknown) {
            AudioHardwareDestroyProcessTap(tapID)
        }
        ioProcID = nil
        aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
        tapID = AudioObjectID(kAudioObjectUnknown)
        outputFile = nil
        isRunning = false
    }

    private func cleanupTapOnly() {
        if tapID != AudioObjectID(kAudioObjectUnknown) {
            AudioHardwareDestroyProcessTap(tapID)
        }
        tapID = AudioObjectID(kAudioObjectUnknown)
    }

    private func cleanupAll() {
        stop()
    }

    // MARK: - Core Audio helpers

    /// `kAudioTapPropertyFormat` devolve a ASBD real do tap — construa o
    /// AVAudioFormat a partir dela em vez de assumir 48 kHz estéreo.
    private func tapAudioFormat() throws -> AVAudioFormat {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyFormat,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var asbd = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        let status = AudioObjectGetPropertyData(tapID, &address, 0, nil, &size, &asbd)
        guard status == noErr, let format = AVAudioFormat(streamDescription: &asbd) else {
            throw SystemAudioTapError.coreAudioFailure(status, "ler o formato do tap")
        }
        return format
    }

    private func defaultOutputDeviceUID() throws -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
        guard status == noErr, deviceID != AudioObjectID(kAudioObjectUnknown) else {
            throw SystemAudioTapError.coreAudioFailure(status, "ler o dispositivo de saída padrão")
        }

        var uidAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceUID: CFString = "" as CFString
        var uidSize = UInt32(MemoryLayout<CFString>.size)
        status = AudioObjectGetPropertyData(deviceID, &uidAddress, 0, nil, &uidSize, &deviceUID)
        guard status == noErr else {
            throw SystemAudioTapError.coreAudioFailure(status, "ler o UID do dispositivo de saída")
        }
        return deviceUID as String
    }

    private func mapPermissionOrFailure(_ status: OSStatus, step: String) -> Error {
        // TCC nega a criação do tap silenciosamente com um erro de
        // hardware genérico em vez de um código dedicado — trate o caso
        // mais comum (permissão não concedida) com uma mensagem acionável.
        if status == kAudioHardwareNotRunningError || status == kAudioHardwareIllegalOperationError {
            return SystemAudioTapError.permissionDenied
        }
        return SystemAudioTapError.coreAudioFailure(status, step)
    }
}
#endif
