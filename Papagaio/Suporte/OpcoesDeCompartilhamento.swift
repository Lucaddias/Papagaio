import AppKit
import Foundation

/// Acrescenta "Salvar em…" ao painel de compartilhamento do macOS.
///
/// O painel do sistema lista apps e serviços — Mail, Mensagens, AirDrop — mas
/// não oferece gravar num diretório. Como o `NSSharingServicePicker` aceita
/// serviços próprios, entra aqui um que abre o painel de salvar. Assim
/// "compartilhar" e "salvar no disco" ficam no mesmo lugar, que é onde a
/// pessoa procura.
final class OpcoesDeCompartilhamento: NSObject, NSSharingServicePickerDelegate {
    private let arquivos: [URL]

    init(arquivos: [URL]) {
        self.arquivos = arquivos
    }

    func sharingServicePicker(
        _ picker: NSSharingServicePicker,
        sharingServicesForItems items: [Any],
        proposedSharingServices propostos: [NSSharingService]
    ) -> [NSSharingService] {
        guard let primeiro = arquivos.first else { return propostos }

        let icone = NSImage(systemSymbolName: "folder", accessibilityDescription: nil) ?? NSImage()
        let salvar = NSSharingService(title: "Salvar em…", image: icone, alternateImage: nil) {
            let painel = NSSavePanel()
            painel.nameFieldStringValue = primeiro.lastPathComponent
            painel.canCreateDirectories = true
            guard painel.runModal() == .OK, let destino = painel.url else { return }
            try? FileManager.default.removeItem(at: destino)
            try? FileManager.default.copyItem(at: primeiro, to: destino)
        }

        return [salvar] + propostos
    }
}
