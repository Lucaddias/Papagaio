import CryptoKit
import Foundation

/// Metadados de autenticação do servidor OAuth (RFC 8414).
///
/// Descobertos em `/.well-known/oauth-authorization-server` acima da raiz do
/// servidor MCP — o Granola registra os endpoints lá, no mesmo padrão do
/// MCP spec. Todos os campos que usamos podem faltar; o fluxo autoriza e
/// falha com mensagem clara quando um endpoint vital não existe.
public struct MetadadosDeAutenticacao: Sendable, Decodable {
    public let emissor: String?
    public let autorizacaoEndpoint: URL?
    public let tokenEndpoint: URL?
    public let registroEndpoint: URL?
    /// `nil` quando o servidor não publica a lista — o pedido de autorização
    /// então sai sem `scope` e vale o padrão do servidor.
    public let escoposSuportados: [String]?

    enum CodingKeys: String, CodingKey {
        case emissor = "issuer"
        case autorizacaoEndpoint = "authorization_endpoint"
        case tokenEndpoint = "token_endpoint"
        case registroEndpoint = "registration_endpoint"
        case escoposSuportados = "scopes_supported"
    }
}

/// Registro do cliente feito por Dynamic Client Registration (DCR).
///
/// O MCP exige DCR: não existem client ID/secret pré-gerados — o próprio
/// app se registra na primeira autenticação e guarda o resultado.
public struct ClienteRegistrado: Sendable, Equatable {
    public let id: String
    /// Conforme o método de auth do servidor; o Granola usa `none`
    /// (public client com PKCE), então em geral é `nil`.
    public let segredo: String?
    public let redirecionamento: URL

    public init(id: String, segredo: String?, redirecionamento: URL) {
        self.id = id
        self.segredo = segredo
        self.redirecionamento = redirecionamento
    }
}

/// Credenciais de acesso com refresh — o que flui entre o fluxo de código e
/// as chamadas seguintes. `Codable` para o cofre do Keychain.
public struct CredenciaisOAuth: Sendable, Equatable, Codable {
    public var tokenDeAcesso: String
    public var tokenDeAtualizacao: String?
    /// Momento de expiração, quando o servidor informou `expires_in`.
    public var expiraEm: Date?
    public var escopo: String?

    public init(
        tokenDeAcesso: String,
        tokenDeAtualizacao: String? = nil,
        expiraEm: Date? = nil,
        escopo: String? = nil
    ) {
        self.tokenDeAcesso = tokenDeAcesso
        self.tokenDeAtualizacao = tokenDeAtualizacao
        self.expiraEm = expiraEm
        self.escopo = escopo
    }

    public func aindaValido(por segundos: TimeInterval = 30) -> Bool {
        guard let expiraEm else { return false }
        return expiraEm.timeIntervalSinceNow > segundos
    }
}

public enum ErroOAuth: LocalizedError, Equatable {
    case semEndpointAutorizacao
    case semEndpointToken
    case semEndpointRegistro
    case falhaDeRede(String)
    case respostaInvalida(String)
    case autorizacaoNegada
    case recusadoPeloServidor(descricao: String)

    public var errorDescription: String? {
        switch self {
        case .semEndpointAutorizacao:
            "O servidor de autenticação não publica o endpoint de autorização."
        case .semEndpointToken:
            "O servidor de autenticação não publica o endpoint de token."
        case .semEndpointRegistro:
            "O servidor de autenticação não publica o endpoint de registro de cliente."
        case let .falhaDeRede(detalhe):
            "Falha de rede na autenticação: \(detalhe)"
        case let .respostaInvalida(detalhe):
            "Resposta inválida do servidor de autenticação: \(detalhe)"
        case .autorizacaoNegada:
            "Autorização cancelada."
        case let .recusadoPeloServidor(descricao):
            "O servidor recusou a autenticação: \(descricao)"
        }
    }
}

/// Passos HTTP puros do fluxo OAuth 2.0 (Authorization Code + PKCE + DCR).
///
/// Sem estado: cada função recebe o que precisa e devolve o resultado. A
/// orquestração (cache, refresh, persistência) vive em `SessaoOAuth`.
public enum AutenticacaoOAuth {
    /// Onde o MCP publica os metadados de auth — RFC 8414 pede
    /// `/.well-known/oauth-authorization-server` acima do caminho do servidor.
    public static func urlDosMetadados(servidorMCP: URL) -> URL {
        let base = servidorMCP.deletingLastPathComponent()
        var componentes = URLComponents(url: base, resolvingAgainstBaseURL: false)
            ?? URLComponents()
        let caminho = componentes.path.hasSuffix("/")
            ? String(componentes.path.dropLast())
            : componentes.path
        componentes.path = caminho + "/.well-known/oauth-authorization-server"
        return componentes.url ?? base
    }

    public static func metadados(no servidor: URL) async throws -> MetadadosDeAutenticacao {
        let url = urlDosMetadados(servidorMCP: servidor)
        let (dados, resposta) = try await URLSession.shared.data(from: url)
        guard let http = resposta as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ErroOAuth.respostaInvalida("metadados com status não-2xx")
        }
        do {
            return try JSONDecoder().decode(MetadadosDeAutenticacao.self, from: dados)
        } catch {
            throw ErroOAuth.respostaInvalida("JSON dos metadados: \(error.localizedDescription)")
        }
    }

    /// DCR: registra este app como cliente OAuth do servidor.
    public static func registrarCliente(
        _ metadados: MetadadosDeAutenticacao,
        redirecionamento: URL,
        nomeDoApp: String
    ) async throws -> ClienteRegistrado {
        guard let registro = metadados.registroEndpoint else {
            throw ErroOAuth.semEndpointRegistro
        }
        let corpo: [String: Any] = [
            "client_name": nomeDoApp,
            "redirect_uris": [redirecionamento.absoluteString],
            "grant_types": ["authorization_code", "refresh_token"],
            "response_types": ["code"],
            "token_endpoint_auth_method": "none",
        ]
        let dados = try JSONSerialization.data(withJSONObject: corpo)
        var pedido = URLRequest(url: registro)
        pedido.httpMethod = "POST"
        pedido.setValue("application/json", forHTTPHeaderField: "Content-Type")
        pedido.httpBody = dados

        let (respostaDados, resposta) = try await tratamentoDeRede { try await URLSession.shared.data(for: pedido) }
        let mapa = try respostaComoMapa(respostaDados, resposta: resposta, contexto: "registro")
        guard let id = mapa["client_id"] as? String else {
            throw ErroOAuth.respostaInvalida("registro sem client_id")
        }
        return ClienteRegistrado(
            id: id,
            segredo: mapa["client_secret"] as? String,
            redirecionamento: redirecionamento
        )
    }

    /// A URL do navegador para o usuário autorizar o app (PKCE S256).
    public static func urlDeAutorizacao(
        _ metadados: MetadadosDeAutenticacao,
        cliente: ClienteRegistrado,
        desafioPKCE: String,
        estado: String,
        escopos: [String]?
    ) throws -> URL {
        guard let autorizacao = metadados.autorizacaoEndpoint else {
            throw ErroOAuth.semEndpointAutorizacao
        }
        var itens: [URLQueryItem] = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: cliente.id),
            URLQueryItem(name: "redirect_uri", value: cliente.redirecionamento.absoluteString),
            URLQueryItem(name: "code_challenge", value: desafioPKCE),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: estado),
        ]
        let pedido = escopos ?? metadados.escoposSuportados
        if let pedido, !pedido.isEmpty {
            itens.append(URLQueryItem(name: "scope", value: pedido.joined(separator: " ")))
        }
        var componentes = URLComponents(url: autorizacao, resolvingAgainstBaseURL: false)
        componentes?.queryItems = itens
        guard let url = componentes?.url else {
            throw ErroOAuth.respostaInvalida("URL de autorização mal formada")
        }
        return url
    }

    /// Troca o código de autorização por credenciais.
    public static func trocarCodigoPorToken(
        _ metadados: MetadadosDeAutenticacao,
        cliente: ClienteRegistrado,
        codigo: String,
        verificadorPKCE: String
    ) async throws -> CredenciaisOAuth {
        guard let token = metadados.tokenEndpoint else {
            throw ErroOAuth.semEndpointToken
        }
        let corpo = [
            "grant_type": "authorization_code",
            "code": codigo,
            "redirect_uri": cliente.redirecionamento.absoluteString,
            "client_id": cliente.id,
            "code_verifier": verificadorPKCE,
        ]
        return try await pedirCredenciais(token, corpo: corpo)
    }

    /// Renova com o refresh token.
    public static func atualizarCredenciais(
        _ metadados: MetadadosDeAutenticacao,
        cliente: ClienteRegistrado,
        credenciais: CredenciaisOAuth
    ) async throws -> CredenciaisOAuth {
        guard let token = metadados.tokenEndpoint else {
            throw ErroOAuth.semEndpointToken
        }
        guard let atualizacao = credenciais.tokenDeAtualizacao else {
            throw ErroOAuth.respostaInvalida("sem refresh token para renovar")
        }
        let corpo = [
            "grant_type": "refresh_token",
            "refresh_token": atualizacao,
            "client_id": cliente.id,
        ]
        return try await pedirCredenciais(token, corpo: corpo)
    }

    // MARK: - PKCE

    /// Par `verificador`/`desafio` S256 com base64url sem padding (RFC 7636).
    public static func novoDesafioPKCE() -> (verificador: String, desafio: String) {
        var bytes = [UInt8](repeating: 0, count: 32)
        for indice in bytes.indices {
            bytes[indice] = UInt8.random(in: 0...255)
        }
        let verificador = Data(bytes).base64URLSemPadding
        let hash = SHA256.hash(data: Data(verificador.utf8))
        return (verificador, Data(hash).base64URLSemPadding)
    }

    public static func novoEstado() -> String {
        UUID().uuidString
    }

    // MARK: - Apoio

    private static func tratamentoDeRede(
        _ trabalho: () async throws -> (Data, URLResponse)
    ) async throws -> (Data, URLResponse) {
        do {
            return try await trabalho()
        } catch {
            throw ErroOAuth.falhaDeRede(error.localizedDescription)
        }
    }

    private static func pedirCredenciais(
        _ endpoint: URL,
        corpo: [String: String]
    ) async throws -> CredenciaisOAuth {
        var pedido = URLRequest(url: endpoint)
        pedido.httpMethod = "POST"
        pedido.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        pedido.httpBody = corpo
            .map { "\($0.key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? $0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (dados, resposta) = try await tratamentoDeRede { try await URLSession.shared.data(for: pedido) }
        let mapa = try respostaComoMapa(dados, resposta: resposta, contexto: "token")
        guard let acesso = mapa["access_token"] as? String else {
            let descricao = (mapa["error_description"] as? String)
                ?? (mapa["error"] as? String)
                ?? "sem access_token"
            throw ErroOAuth.recusadoPeloServidor(descricao: descricao)
        }
        var expiraEm: Date?
        if let em = mapa["expires_in"] as? NSNumber {
            expiraEm = Date().addingTimeInterval(em.doubleValue)
        }
        return CredenciaisOAuth(
            tokenDeAcesso: acesso,
            tokenDeAtualizacao: mapa["refresh_token"] as? String,
            expiraEm: expiraEm,
            escopo: mapa["scope"] as? String
        )
    }

    private static func respostaComoMapa(
        _ dados: Data,
        resposta: URLResponse,
        contexto: String
    ) throws -> [String: Any] {
        guard let http = resposta as? HTTPURLResponse else {
            throw ErroOAuth.respostaInvalida("\(contexto) sem resposta HTTP")
        }
        guard (200..<300).contains(http.statusCode) else {
            let texto = String(data: dados, encoding: .utf8) ?? ""
            throw ErroOAuth.recusadoPeloServidor(
                descricao: "\(contexto) com status \(http.statusCode): \(String(texto.prefix(150)))"
            )
        }
        guard let mapa = (try? JSONSerialization.jsonObject(with: dados)) as? [String: Any] else {
            throw ErroOAuth.respostaInvalida("\(contexto) fora de JSON")
        }
        return mapa
    }
}

extension Data {
    /// Base64url sem padding — o formato do PKCE (RFC 7636) e do JWT.
    var base64URLSemPadding: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}