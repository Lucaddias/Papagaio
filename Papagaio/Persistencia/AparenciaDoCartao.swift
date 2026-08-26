import AppKit
import PapagaioCore
import SwiftUI

/// A aparência da faixa do cartão: cor própria ou imagem.
///
/// Guardado por conversa, e à parte da capa redonda — são dois enquadramentos
/// diferentes, e a foto que preenche a faixa deitada fica decapitada no
/// círculo.
///
/// Sem nada escolhido, a faixa cai na cor da pasta. Essa é a boa regra
/// padrão: conversas do mesmo projeto se agrupam sozinhas na grade. A escolha
/// manual existe para quando a pessoa quer que **uma** conversa se destaque, e
/// por isso vence a cor da pasta quando existe.
enum AparenciaDoCartao {
    private static let prefixoCor = "corDaFaixaDoCartao."
    private static let prefixoBanner = "bannerDoCartao."
    private static let prefixoAjuste = "ajusteDoBannerDoCartao."

    static func ajuste(_ id: ArquivoID) -> AjusteDeImagem {
        let bruto = UserDefaults.standard.string(forKey: prefixoAjuste + id.rawValue.uuidString)
        return bruto.flatMap(AjusteDeImagem.init(rawValue:)) ?? .preencher
    }

    static func definirAjuste(_ ajuste: AjusteDeImagem, para id: ArquivoID) {
        UserDefaults.standard.set(ajuste.rawValue, forKey: prefixoAjuste + id.rawValue.uuidString)
    }

    // MARK: - Cor

    private static let prefixoSemCor = "faixaSemCorDoCartao."

    /// "Sem cor" é uma escolha, e não a ausência de escolha.
    ///
    /// `cor == nil` já significava "herdar a cor da pasta", então não dava para
    /// usar o mesmo `nil` para "não quero cor nenhuma" — são intenções opostas
    /// e precisavam de estados diferentes.
    static func semCor(_ id: ArquivoID) -> Bool {
        UserDefaults.standard.bool(forKey: prefixoSemCor + id.rawValue.uuidString)
    }

    static func definirSemCor(_ ativo: Bool, para id: ArquivoID) {
        let chave = prefixoSemCor + id.rawValue.uuidString
        if ativo {
            UserDefaults.standard.set(true, forKey: chave)
        } else {
            UserDefaults.standard.removeObject(forKey: chave)
        }
    }

    static func cor(_ id: ArquivoID) -> Color? {
        guard let hex = UserDefaults.standard.string(forKey: prefixoCor + id.rawValue.uuidString) else {
            return nil
        }
        return Color(hexadecimal: hex)
    }

    static func definirCor(_ cor: Color?, para id: ArquivoID) {
        let chave = prefixoCor + id.rawValue.uuidString
        guard let cor, let hex = cor.hexadecimal else {
            UserDefaults.standard.removeObject(forKey: chave)
            return
        }
        UserDefaults.standard.set(hex, forKey: chave)
    }

    // MARK: - Imagem

    /// Bookmark com escopo de segurança, e não o caminho: sob sandbox um
    /// caminho solto deixa de abrir assim que o app reinicia.
    @MainActor private static let decodificados = NSCache<NSString, NSImage>()

    /// Bookmarks já resolvidos, **inclusive os ausentes**.
    ///
    /// Resolver um bookmark com escopo de segurança toca o sistema de arquivos
    /// e custa milissegundos. Isto roda no `init` de cada cartão, e trocar de
    /// filtro reconstrói a grade inteira de uma vez: com quinze cartões, a
    /// soma travava a janela por segundos. Guardar o resultado — o `nil`
    /// também, que é o caso mais comum — transforma o segundo acesso em
    /// consulta a um dicionário.
    @MainActor private static var urlsResolvidas: [String: URL?] = [:]

    @MainActor
    static func banner(_ id: ArquivoID) -> URL? {
        let chave = prefixoBanner + id.rawValue.uuidString
        if let guardada = urlsResolvidas[chave] { return guardada }

        guard let dados = UserDefaults.standard.data(forKey: chave) else {
            urlsResolvidas[chave] = URL?.none
            return nil
        }

        var obsoleto = false
        guard let url = try? URL(
            resolvingBookmarkData: dados,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &obsoleto
        ) else {
            UserDefaults.standard.removeObject(forKey: chave)
            urlsResolvidas[chave] = URL?.none
            return nil
        }
        if obsoleto { try? definirBanner(url, para: id) }
        urlsResolvidas[chave] = url
        return url
    }

    @MainActor
    static func definirBanner(_ url: URL, para id: ArquivoID) throws {
        let dados = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(dados, forKey: prefixoBanner + id.rawValue.uuidString)
        urlsResolvidas[prefixoBanner + id.rawValue.uuidString] = nil
        decodificados.removeObject(forKey: id.rawValue.uuidString as NSString)
    }

    @MainActor
    static func removerBanner(_ id: ArquivoID) {
        UserDefaults.standard.removeObject(forKey: prefixoBanner + id.rawValue.uuidString)
        urlsResolvidas[prefixoBanner + id.rawValue.uuidString] = nil
        decodificados.removeObject(forKey: id.rawValue.uuidString as NSString)
    }

    @MainActor
    static func remover(_ id: ArquivoID, em defaults: UserDefaults = .standard) {
        let sufixo = id.rawValue.uuidString
        for prefixo in [prefixoCor, prefixoBanner, prefixoAjuste, prefixoSemCor] {
            let chave = prefixo + sufixo
            defaults.removeObject(forKey: chave)
            urlsResolvidas[chave] = nil
        }
        decodificados.removeObject(forKey: sufixo as NSString)
        CorDominanteDeImagem.esquecer(sufixo)
    }

    /// Imagem pronta para desenhar, decodificada no máximo uma vez.
    @MainActor
    static func imagem(_ id: ArquivoID) -> NSImage? {
        let chave = id.rawValue.uuidString as NSString
        if let guardada = decodificados.object(forKey: chave) { return guardada }

        guard let url = banner(id) else { return nil }
        let acessou = url.startAccessingSecurityScopedResource()
        defer { if acessou { url.stopAccessingSecurityScopedResource() } }

        guard let original = NSImage(contentsOf: url) else { return nil }
        let imagem = MiniaturaDeImagem.reduzir(original)
        decodificados.setObject(imagem, forKey: chave)
        return imagem
    }

    /// Remove personalizações vinculadas às conversas da conta atual.
    @MainActor
    static func removerTodas(em defaults: UserDefaults = .standard) {
        let prefixos = [prefixoCor, prefixoBanner, prefixoAjuste, prefixoSemCor]
        for chave in defaults.dictionaryRepresentation().keys
        where prefixos.contains(where: chave.hasPrefix) {
            defaults.removeObject(forKey: chave)
        }
        urlsResolvidas.removeAll()
        decodificados.removeAllObjects()
    }
}

extension Color {
    /// Aceita `#RRGGBB` e `RRGGBB`, com ou sem `#`, em qualquer caixa.
    ///
    /// Digitar cor em hexadecimal é como designer troca cor — é o que o Figma,
    /// o Sketch e o próprio painel do macOS aceitam. Sem isto, casar a faixa
    /// com a paleta de uma marca viraria caça ao pixel na roda de cores.
    init?(hexadecimal: String) {
        var texto = hexadecimal.trimmingCharacters(in: .whitespacesAndNewlines)
        if texto.hasPrefix("#") { texto.removeFirst() }
        guard texto.count == 6, let valor = UInt32(texto, radix: 16) else { return nil }

        self.init(
            red: Double((valor >> 16) & 0xFF) / 255,
            green: Double((valor >> 8) & 0xFF) / 255,
            blue: Double(valor & 0xFF) / 255
        )
    }

    /// Preto ou branco, o que for legível sobre esta cor.
    ///
    /// A cor da faixa é escolhida pelo usuário — inclusive amarelo, bege ou
    /// quase branco. Texto branco fixo sumiria nesses casos, e não há como
    /// impedir a escolha sem tirar a liberdade que a paleta livre existe para
    /// dar. A saída é medir: acima de ~60% de luminância, o texto vira escuro.
    ///
    /// A fórmula é a de luminância relativa do WCAG, com correção de gama —
    /// média simples dos canais erraria em verde e azul, que o olho percebe
    /// com pesos muito diferentes.
    var textoLegivel: Color {
        guard let sRGB = NSColor(self).usingColorSpace(.sRGB) else { return .white }

        func linear(_ canal: CGFloat) -> Double {
            let valor = Double(canal)
            return valor <= 0.03928 ? valor / 12.92 : pow((valor + 0.055) / 1.055, 2.4)
        }

        let luminancia = 0.2126 * linear(sRGB.redComponent)
            + 0.7152 * linear(sRGB.greenComponent)
            + 0.0722 * linear(sRGB.blueComponent)

        return luminancia > 0.45 ? Color(red: 0.12, green: 0.11, blue: 0.10) : .white
    }

    /// `#RRGGBB` no espaço sRGB.
    ///
    /// A conversão passa por `NSColor` porque uma `Color` do SwiftUI pode ser
    /// dinâmica (clara/escura) ou vir de outro espaço de cor; sem converter
    /// para sRGB, os componentes vêm errados ou nem existem.
    var hexadecimal: String? {
        guard let sRGB = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        let r = Int((sRGB.redComponent * 255).rounded())
        let g = Int((sRGB.greenComponent * 255).rounded())
        let b = Int((sRGB.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
