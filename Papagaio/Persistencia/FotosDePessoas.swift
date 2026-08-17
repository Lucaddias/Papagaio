import AppKit
import Foundation

/// A foto de cada pessoa, guardada pelo **nome**.
///
/// Pelo nome, e não por conversa: quem entrevista as mesmas pessoas em várias
/// sessões escolhe a foto uma vez e ela aparece em todas. É também o que faz a
/// grade ficar reconhecível — o mesmo rosto no mesmo lugar, conversa após
/// conversa.
///
/// A chave é o nome normalizado (sem acento, sem caixa, espaços colapsados)
/// para que "ana silva" e "Ana  Silva" não virem duas pessoas.
enum FotosDePessoas {
    private static let prefixo = "fotoDaPessoa."

    @MainActor private static let decodificadas = NSCache<NSString, NSImage>()

    /// Bookmarks já resolvidos, incluindo os ausentes — que é o caso da
    /// maioria das pessoas. Sem isto, cada avatar batia no `UserDefaults` a
    /// cada avaliação de `body`, e há um avatar por participante por cartão.
    @MainActor private static var urlsResolvidas: [String: URL?] = [:]

    static func chave(de nome: String) -> String {
        nome
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    @MainActor
    static func url(de nome: String) -> URL? {
        let chaveCompleta = prefixo + chave(de: nome)
        if let guardada = urlsResolvidas[chaveCompleta] { return guardada }

        guard let dados = UserDefaults.standard.data(forKey: chaveCompleta) else {
            urlsResolvidas[chaveCompleta] = URL?.none
            return nil
        }

        var obsoleto = false
        guard let url = try? URL(
            resolvingBookmarkData: dados,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &obsoleto
        ) else {
            UserDefaults.standard.removeObject(forKey: chaveCompleta)
            urlsResolvidas[chaveCompleta] = URL?.none
            return nil
        }
        if obsoleto { try? definir(url, para: nome) }
        urlsResolvidas[chaveCompleta] = url
        return url
    }

    @MainActor
    static func definir(_ url: URL, para nome: String) throws {
        let dados = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(dados, forKey: prefixo + chave(de: nome))
        urlsResolvidas[prefixo + chave(de: nome)] = nil
        decodificadas.removeObject(forKey: chave(de: nome) as NSString)
    }

    @MainActor
    static func remover(de nome: String) {
        UserDefaults.standard.removeObject(forKey: prefixo + chave(de: nome))
        urlsResolvidas[prefixo + chave(de: nome)] = nil
        decodificadas.removeObject(forKey: chave(de: nome) as NSString)
    }

    /// Imagem pronta para desenhar, decodificada no máximo uma vez.
    ///
    /// Sem o cache isto rodaria a cada avaliação de body de cada cartão da
    /// grade — leitura de disco por participante, por atualização.
    @MainActor
    static func imagem(de nome: String) -> NSImage? {
        let chaveDoCache = chave(de: nome) as NSString
        if let guardada = decodificadas.object(forKey: chaveDoCache) { return guardada }

        guard let url = url(de: nome) else { return nil }
        let acessou = url.startAccessingSecurityScopedResource()
        defer { if acessou { url.stopAccessingSecurityScopedResource() } }

        guard let original = NSImage(contentsOf: url) else { return nil }
        let imagem = MiniaturaDeImagem.reduzir(original)
        decodificadas.setObject(imagem, forKey: chaveDoCache)
        return imagem
    }

    /// Abre o seletor e guarda a escolha. Devolve `true` quando trocou.
    @MainActor
    @discardableResult
    static func escolherImagem(para nome: String) -> Bool {
        let painel = NSOpenPanel()
        painel.title = "Escolha uma foto para \(nome)"
        painel.prompt = "Usar foto"
        painel.canChooseFiles = true
        painel.canChooseDirectories = false
        painel.allowsMultipleSelection = false
        painel.allowedContentTypes = [.image]

        guard painel.runModal() == .OK,
              let url = painel.url,
              url.startAccessingSecurityScopedResource()
        else { return false }
        defer { url.stopAccessingSecurityScopedResource() }

        try? definir(url, para: nome)
        return true
    }
}
