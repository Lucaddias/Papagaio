import Foundation

/// Uma pasta de modelos escolhida pelo usuário, lembrada entre execuções.
///
/// Existe por um motivo prático: quem já usa `llama.cpp` ou `whisper.cpp` tem
/// esses mesmos GGUF no disco. Obrigar um segundo download de modelos grandes para
/// colocar cópias idênticas dentro do container é desperdício de banda e de
/// disco.
///
/// Sob App Sandbox o app não alcança `~/Documents`. O que dá acesso é o usuário
/// escolher a pasta num `NSOpenPanel`, e o que faz esse acesso **sobreviver ao
/// relançamento** é o bookmark com escopo de segurança — daí o entitlement
/// `com.apple.security.files.bookmarks.app-scope`.
public enum PastaDeModelosDoUsuario {
    private static let chave = "pastaDeModelosEscolhida"

    public static func guardar(_ url: URL) throws {
        let dados = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(dados, forKey: chave)
    }

    /// Resolve o bookmark e **abre** o acesso com escopo.
    ///
    /// O acesso fica aberto de propósito: o par `stop` viria no encerramento do
    /// app, e fechar antes tornaria a URL inútil no meio de uma transcrição.
    public static func resolver() -> URL? {
        guard let dados = UserDefaults.standard.data(forKey: chave) else { return nil }

        var obsoleto = false
        guard let url = try? URL(
            resolvingBookmarkData: dados,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &obsoleto
        ) else {
            esquecer()
            return nil
        }

        guard url.startAccessingSecurityScopedResource() else {
            // A pasta foi movida, apagada, ou está num volume desmontado.
            esquecer()
            return nil
        }
        if obsoleto { try? guardar(url) }
        return url
    }

    public static func esquecer() {
        UserDefaults.standard.removeObject(forKey: chave)
    }
}
