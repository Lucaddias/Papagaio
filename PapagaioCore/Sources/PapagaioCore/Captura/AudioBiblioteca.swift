import AVFoundation
import Foundation

/// Erros de manipulação de arquivo de áudio no container — portados do
/// `AudioLibraryError` do Eko.
public enum ErroAudioFile: LocalizedError {
    case armazenamentoIndisponivel
    case arquivoSemAudio
    case arquivoNaoBaixadoDoICloud

    public var errorDescription: String? {
        switch self {
        case .armazenamentoIndisponivel:
            "Não foi possível acessar o armazenamento local do Ōmu."
        case .arquivoSemAudio:
            "O arquivo selecionado não contém uma faixa de áudio válida."
        case .arquivoNaoBaixadoDoICloud:
            "Este arquivo ainda está só no iCloud e não foi baixado para este Mac. Abra-o uma vez no Finder (ou toque nele no app Arquivos) para baixar, e tente anexar de novo."
        }
    }
}

/// Helpers de áudio do lado do arquivo — portados do `AudioLibrary` do Eko.
///
/// As funções de caminho (pasta, gravações, resolução de relativo) ficam em
/// `Armazenamento`; aqui fica o que é transversal: pedir permissão de
/// microfone e esperar um arquivo do iCloud terminar de baixar antes de uma
/// cópia importada (copiar na hora baixa um arquivo incompleto, e a leitura
/// falha no meio com um erro genérico e confuso).
enum AudioBiblioteca {
    static func pedirPermissaoDeMicrofone() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            break
        @unknown default:
            return false
        }

        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { concedido in
                continuation.resume(returning: concedido)
            }
        }
    }

    /// Espera até ~20 s por um arquivo do iCloud Drive terminar de baixar
    /// para este Mac. Arquivos locais comuns (a grande maioria) não têm a
    /// chave `ubiquitousItemDownloadingStatus` e voltam imediatamente.
    static func garantirBaixadoLocalmente(_ url: URL) async throws {
        guard let valores = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]),
              let status = valores.ubiquitousItemDownloadingStatus else {
            return
        }
        guard status != .current else { return }

        try? FileManager.default.startDownloadingUbiquitousItem(at: url)

        let prazo = Date().addingTimeInterval(20)
        while Date() < prazo {
            try await Task.sleep(for: .milliseconds(500))
            let recente = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
            if recente?.ubiquitousItemDownloadingStatus == .current {
                return
            }
        }
        throw ErroAudioFile.arquivoNaoBaixadoDoICloud
    }
}