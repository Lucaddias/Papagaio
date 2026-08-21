import AppKit

/// Revela um anexo da aba Mídia no Finder, em vez de abri-lo.
///
/// Já tentou abrir com o player certo (QuickTime, para não cair no Música e
/// importar a gravação para a biblioteca de alguém). Mas o pedido de quem usa
/// a aba Mídia não é ouvir ali dentro — é achar o arquivo no Mac, para
/// arrastar, anexar num e-mail ou abrir com outra coisa. `activateFileViewer`
/// faz exatamente isso: abre o Finder já na pasta certa, com o arquivo
/// selecionado.
enum AberturaDeMidia {
    static func abrir(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
