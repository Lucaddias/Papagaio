//import AppKit
//import PapagaioCore
//import SwiftUI
//
///// Preferências puramente visuais de um arquivo: favorito, pasta e capa.
/////
///// Ficam em `UserDefaults` porque não são dado da conversa — não viajam na
///// exportação nem entram na busca. O que **não** pode acontecer é elas
///// sobreviverem ao arquivo: `esquecer(_:)` é chamado na exclusão definitiva,
///// senão cada arquivo apagado deixaria três chaves órfãs para sempre.
/////
///// `@MainActor` porque tudo aqui é lido de dentro de views e o cache de capas
///// (`NSCache`) não é `Sendable` — confinar ao ator principal é honesto e não
///// custa nada, já que não há chamador fora dele.
//@MainActor
//enum PreferenciasVisuaisDoArquivo {
//    private static let prefixoFavorito = "arquivoFavorito."
//    private static let prefixoPasta = "arquivoPasta."
//    private static let prefixoCapa = "arquivoCapa."
//
//    /// Capas já resolvidas e decodificadas.
//    ///
//    /// Sem isto, `NSImage(contentsOf:)` rodava **a cada avaliação de body** do
//    /// cartão, e a resolução do bookmark (que toca o filesystem) rodava a cada
//    /// `init`. Com a fila ativa a biblioteca recompõe a cada mudança de fase,
//    /// então isso era leitura de disco por cartão por atualização.
//    private static let capasDecodificadas = NSCache<NSString, NSImage>()
//
//    // MARK: - Favorito
//
//    static func favorito(_ id: ArquivoID) -> Bool {
//        UserDefaults.standard.bool(forKey: prefixoFavorito + id.rawValue.uuidString)
//    }
//
//    static func definirFavorito(_ favorito: Bool, para id: ArquivoID) {
//        UserDefaults.standard.set(favorito, forKey: prefixoFavorito + id.rawValue.uuidString)
//    }
//
//    // MARK: - Pasta
//
//    static func pasta(_ id: ArquivoID) -> String? {
//        UserDefaults.standard.string(forKey: prefixoPasta + id.rawValue.uuidString)
//    }
//
//    static func definirPasta(_ pasta: String?, para id: ArquivoID) {
//        let chave = prefixoPasta + id.rawValue.uuidString
//        if let pasta {
//            UserDefaults.standard.set(pasta, forKey: chave)
//        } else {
//            UserDefaults.standard.removeObject(forKey: chave)
//        }
//    }
//
//    /// Todas as pastas em uso, para a biblioteca poder filtrar por elas.
//    static func pastasEmUso(de arquivos: [Arquivo]) -> [String] {
//        Set(arquivos.compactMap { pasta($0.id) }).sorted()
//    }
//
//    // MARK: - Capa
//
//    static func capa(_ id: ArquivoID) -> URL? {
//        let chave = prefixoCapa + id.rawValue.uuidString
//        guard let dados = UserDefaults.standard.data(forKey: chave) else { return nil }
//        var obsoleto = false
//        guard let url = try? URL(
//            resolvingBookmarkData: dados,
//            options: .withSecurityScope,
//            relativeTo: nil,
//            bookmarkDataIsStale: &obsoleto
//        ) else {
//            UserDefaults.standard.removeObject(forKey: chave)
//            return nil
//        }
//        if obsoleto { try? definirCapa(url, para: id) }
//        return url
//    }
//
//    static func definirCapa(_ url: URL, para id: ArquivoID) throws {
//        let dados = try url.bookmarkData(
//            options: .withSecurityScope,
//            includingResourceValuesForKeys: nil,
//            relativeTo: nil
//        )
//        UserDefaults.standard.set(dados, forKey: prefixoCapa + id.rawValue.uuidString)
//        capasDecodificadas.removeObject(forKey: id.rawValue.uuidString as NSString)
//    }
//
//    /// Imagem de capa pronta para desenhar, decodificada no máximo uma vez.
//    static func imagemDaCapa(_ id: ArquivoID) -> NSImage? {
//        let chave = id.rawValue.uuidString as NSString
//        if let guardada = capasDecodificadas.object(forKey: chave) { return guardada }
//
//        guard let url = capa(id) else { return nil }
//        let acessou = url.startAccessingSecurityScopedResource()
//        defer { if acessou { url.stopAccessingSecurityScopedResource() } }
//
//        guard let imagem = NSImage(contentsOf: url) else { return nil }
//        capasDecodificadas.setObject(imagem, forKey: chave)
//        return imagem
//    }
//
//    // MARK: - Limpeza
//
//    /// Remove tudo que pertence a um arquivo apagado definitivamente.
//    static func esquecer(_ id: ArquivoID) {
//        let sufixo = id.rawValue.uuidString
//        for prefixo in [prefixoFavorito, prefixoPasta, prefixoCapa] {
//            UserDefaults.standard.removeObject(forKey: prefixo + sufixo)
//        }
//        capasDecodificadas.removeObject(forKey: sufixo as NSString)
//    }
//}
