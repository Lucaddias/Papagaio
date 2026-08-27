import CryptoKit
import Foundation
import os
import PapagaioCore
import AppKit

enum ErroOAuthGoogle: LocalizedError, Equatable {
    case credenciaisNaoConfiguradas
    case autorizacaoNegada
    case semCodigoDeAutorizacao
    case respostaInvalida
    case servidor(mensagem: String)
    case semRefreshToken
    case navegadorNaoAbriu
    case tempoEsgotado
    case servidorLocalFalhou(String)

    var errorDescription: String? {
        switch self {
        case .credenciaisNaoConfiguradas:
            return "Client ID e Client Secret do Google não configurados. Configure em SessaoOAuthGoogle.Credenciais ou no Info.plist."
        case .autorizacaoNegada:
            return "Autorização cancelada ou recusada no navegador."
        case .semCodigoDeAutorizacao:
            return "O navegador voltou sem o código de autorização. Tente de novo."
        case .respostaInvalida:
            return "O servidor do Google respondeu de forma inesperada."
        case let .servidor(mensagem):
            return "O servidor respondeu: \(mensagem)."
        case .semRefreshToken:
            return "A sessão expirou e não há refresh token. Conecte de novo."
        case .navegadorNaoAbriu:
            return "O navegador não abriu — confira se o Papagaio pode abrir janelas e tente de novo."
        case .tempoEsgotado:
            return "Tempo esgotado esperando sua autorização — volte ao navegador e tente de novo."
        case let .servidorLocalFalhou(msg):
            return "Falha ao iniciar servidor local para OAuth: \(msg)"
        }
    }
}

enum CredenciaisGoogle {
    static var clienteID: String {
        if let valor = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CLIENT_ID") as? String,
           !valor.isEmpty {
            return valor
        }
        return ""
    }

    static var segredoDoCliente: String {
        if let valor = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CLIENT_SECRET") as? String,
           !valor.isEmpty {
            return valor
        }
        return ""
    }

    static var estaConfigurado: Bool {
        !clienteID.isEmpty && !segredoDoCliente.isEmpty
    }
}

final class SessaoOAuthGoogle: Sendable {
    private let cofre: CofreDeTokens
    private let apresentador: ApresentadorDeAutorizacaoOAuth
    private let sessao = URLSession(configuration: .ephemeral)
    private let registro = Logger(subsystem: "Papagaio", category: "GoogleCalendar")

    private let autorizacaoEndpoint = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!
    private let tokenEndpoint = URL(string: "https://oauth2.googleapis.com/token")!
    private let revogacaoEndpoint = URL(string: "https://oauth2.googleapis.com/revoke")!
    private let userinfoEndpoint = URL(string: "https://www.googleapis.com/oauth2/v3/userinfo")!

    private let escopos = "https://www.googleapis.com/auth/calendar.readonly https://www.googleapis.com/auth/userinfo.email"

    init(
        cofre: CofreDeTokens,
        apresentador: ApresentadorDeAutorizacaoOAuth
    ) {
        self.cofre = cofre
        self.apresentador = apresentador
    }

    func tokenDeAcesso(forcandoRenovacao forcar: Bool) async throws -> String {
        guard CredenciaisGoogle.estaConfigurado else {
            throw ErroOAuthGoogle.credenciaisNaoConfiguradas
        }

        let guardado = carregarToken()
        if !forcar,
           let guardado,
           guardado.expiraEm > Date().addingTimeInterval(60) {
            return guardado.valor
        }

        if let refresh = cofre.carregar(conta: "refresh_token")
            .map({ String(data: $0, encoding: .utf8) ?? "" }),
           !refresh.isEmpty {
            return try await trocarRefreshToken(refresh).accessToken
        }

        if let guardado, guardado.expiraEm > Date() {
            return guardado.valor
        }

        return try await fluxoDeAutorizacao()
    }

    func sair() async {
        if let refresh = cofre.carregar(conta: "refresh_token")
            .map({ String(data: $0, encoding: .utf8) ?? "" }),
           !refresh.isEmpty {
            try? await revogar(refresh)
        }
        registro.info("Sessão Google encerrada — credenciais apagadas do Keychain")
        cofre.apagar(conta: "access_token")
        cofre.apagar(conta: "access_token_expenses")
        cofre.apagar(conta: "refresh_token")
        cofre.apagar(conta: "pkce")
    }

    private func fluxoDeAutorizacao() async throws -> String {
        let (servidor, redirectURI) = try await iniciarServidorLocal()

        let url = urlDeAutorizacao(redirectURI: redirectURI)
        if !NSWorkspace.shared.open(url) {
            await servidor.parar()
            throw ErroOAuthGoogle.navegadorNaoAbriu
        }
        
        registro.info("[DIAG] fluxoDeAutorizacao: chamando aguardarCodigo() com timeout...")
        let codigo = try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                try await servidor.aguardarCodigo()
            }
            group.addTask {
                try await Task.sleep(for: .seconds(180))
                await servidor.parar()
                throw ErroOAuthGoogle.tempoEsgotado
            }
            guard let result = try await group.next() else {
                throw ErroOAuthGoogle.tempoEsgotado
            }
            group.cancelAll()
            return result
        }
        registro.info("[DIAG] fluxoDeAutorizacao: aguardarCodigo() retornou: \(codigo.prefix(20))...")
        registro.info("[DIAG] fluxoDeAutorizacao: parando servidor...")
        await servidor.parar()
        registro.info("[DIAG] fluxoDeAutorizacao: servidor parado")
        guard !codigo.isEmpty else { throw ErroOAuthGoogle.semCodigoDeAutorizacao }
        
        registro.info("[DIAG] fluxoDeAutorizacao: trocando código por token...")
        let credenciais = try await trocarCodigo(codigo, redirectURI: redirectURI)
        registro.info("[DIAG] fluxoDeAutorizacao: token obtido com sucesso")
        return credenciais.accessToken
    }

    private func iniciarServidorLocal() async throws -> (ServidorOAuthLocal, redirectURI: String) {
        let servidor = ServidorOAuthLocal()
        let porta = try await servidor.iniciar()
        let redirectURI = "http://127.0.0.1:\(porta)/oauth/callback"
        return (servidor, redirectURI)
    }

    private func urlDeAutorizacao(redirectURI: String) -> URL {
        let par = gerarAtributoPKCE()
        try? cofre.salvar(Data(par.verificador.utf8), conta: "pkce")

        var componentes = URLComponents(url: autorizacaoEndpoint, resolvingAgainstBaseURL: false)!
        var itens = [
            URLQueryItem(name: "client_id", value: CredenciaisGoogle.clienteID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "code_challenge", value: par.desafio),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: UUID().uuidString),
            URLQueryItem(name: "scope", value: escopos),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
        ]
        componentes.queryItems = itens
        registro.info("URL de autorização Google pronta: \(componentes.url!.absoluteString, privacy: .public)")
        return componentes.url!
    }

    private func trocarCodigo(_ codigo: String, redirectURI: String) async throws -> CredenciaisDeToken {
        let verificador = cofre.carregar(conta: "pkce")
            .map { String(data: $0, encoding: .utf8) ?? "" } ?? ""
        cofre.apagar(conta: "pkce")

        var corpo: [String: Any] = [
            "grant_type": "authorization_code",
            "code": codigo,
            "redirect_uri": redirectURI,
            "code_verifier": verificador,
            "client_id": CredenciaisGoogle.clienteID,
            "client_secret": CredenciaisGoogle.segredoDoCliente,
        ]

        var pedido = URLRequest(url: tokenEndpoint)
        pedido.timeoutInterval = 15
        pedido.httpMethod = "POST"
        pedido.setValue("application/json", forHTTPHeaderField: "Content-Type")
        pedido.httpBody = try JSONSerialization.data(withJSONObject: corpo)

        registro.info("Trocando código de autorização por token (Google)")
        return try await responderComToken(pedido)
    }

    private func trocarRefreshToken(_ refresh: String) async throws -> CredenciaisDeToken {
        var corpo: [String: Any] = [
            "grant_type": "refresh_token",
            "refresh_token": refresh,
            "client_id": CredenciaisGoogle.clienteID,
            "client_secret": CredenciaisGoogle.segredoDoCliente,
        ]

        var pedido = URLRequest(url: tokenEndpoint)
        pedido.timeoutInterval = 15
        pedido.httpMethod = "POST"
        pedido.setValue("application/json", forHTTPHeaderField: "Content-Type")
        pedido.httpBody = try JSONSerialization.data(withJSONObject: corpo)

        registro.info("Renovando token com refresh token (Google)")
        return try await responderComToken(pedido)
    }

    private func revogar(_ token: String) async throws {
        var pedido = URLRequest(url: revogacaoEndpoint)
        pedido.timeoutInterval = 15
        pedido.httpMethod = "POST"
        pedido.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var corpo = URLComponents()
        corpo.queryItems = [URLQueryItem(name: "token", value: token)]
        pedido.httpBody = corpo.query?.data(using: .utf8)
        _ = try? await sessao.data(for: pedido)
    }

    private func responderComToken(_ pedido: URLRequest) async throws -> CredenciaisDeToken {
        let (dados, resposta) = try await sessao.data(for: pedido)
        guard let http = resposta as? HTTPURLResponse else {
            throw ErroOAuthGoogle.respostaInvalida
        }
        let json = try corpoJSON(dados)
        if let erro = json["error"] as? String {
            let descricao = json["error_description"] as? String ?? erro
            if http.statusCode == 400 && erro == "invalid_grant" {
                registro.info("Refresh token inválido/expirado — fluxo completo na próxima")
                cofre.apagar(conta: "refresh_token")
            }
            throw ErroOAuthGoogle.servidor(mensagem: descricao)
        }
        guard let acesso = json["access_token"] as? String else {
            throw ErroOAuthGoogle.respostaInvalida
        }
        let expiraEm = json["expires_in"] as? TimeInterval ?? 3600
        let credenciais = CredenciaisDeToken(
            accessToken: acesso,
            refreshToken: json["refresh_token"] as? String,
            expiraEm: Date().addingTimeInterval(expiraEm)
        )
        registro.info("Token Google obtido (expira em \(Int(expiraEm))s)")
        guardar(credenciais)
        return credenciais
    }

    private func guardar(_ credenciais: CredenciaisDeToken) {
        try? cofre.salvar(Data(credenciais.accessToken.utf8), conta: "access_token")
        if let refresh = credenciais.refreshToken {
            try? cofre.salvar(Data(refresh.utf8), conta: "refresh_token")
        }
        try? cofre.salvar(String(credenciais.expiraEm.timeIntervalSince1970).data(using: .utf8)!, conta: "access_token_expires")
    }

    private func carregarToken() -> TokenGuardado? {
        guard let valor = cofre.carregar(conta: "access_token")
            .map({ String(data: $0, encoding: .utf8) ?? "" }),
              !valor.isEmpty
        else { return nil }
        let expiraEm = cofre.carregar(conta: "access_token_expires")
            .flatMap { dados in TimeInterval(String(data: dados, encoding: .utf8) ?? "") }
            .map(Date.init(timeIntervalSince1970:)) ?? Date.distantFuture
        return TokenGuardado(valor: valor, expiraEm: expiraEm)
    }

    private func corpoJSON(_ dados: Data) throws -> [String: Any] {
        guard let json = try JSONSerialization.jsonObject(with: dados) as? [String: Any] else {
            throw ErroOAuthGoogle.respostaInvalida
        }
        return json
    }

    private func gerarAtributoPKCE() -> (verificador: String, desafio: String) {
        let alfabeto = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
        let verificador = String((0..<96).map { _ in alfabeto.randomElement()! })
        let hash = Data(SHA256.hash(data: Data(verificador.utf8)))
        let desafio = hash.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return (verificador, desafio)
    }

    func obterInfoConta(accessToken: String) async throws -> (email: String, nome: String?) {
        var pedido = URLRequest(url: userinfoEndpoint)
        pedido.timeoutInterval = 15
        pedido.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (dados, _) = try await sessao.data(for: pedido)
        let json = try corpoJSON(dados)
        let email = (json["email"] as? String) ?? ""
        let nome = json["name"] as? String
        return (email, nome)
    }
}

actor ServidorOAuthLocal {
    private var listener: FileHandle?
    private let registro = Logger(subsystem: "Papagaio", category: "GoogleCalendar")

    init() {}

    func iniciar() async throws -> Int {
        let socket = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard socket >= 0 else {
            throw ErroOAuthGoogle.servidorLocalFalhou("socket falhou")
        }

        var opt = 1
        setsockopt(socket, SOL_SOCKET, SO_REUSEADDR, &opt, socklen_t(MemoryLayout<Int>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        addr.sin_port = 0

        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(socket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            close(socket)
            throw ErroOAuthGoogle.servidorLocalFalhou("bind falhou")
        }

        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        let getsockResult = withUnsafeMutablePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(socket, $0, &len)
            }
        }
        guard getsockResult == 0 else {
            close(socket)
            throw ErroOAuthGoogle.servidorLocalFalhou("getsockname falhou")
        }

        let porta = Int(UInt16(addr.sin_port).byteSwapped)

        guard listen(socket, 1) == 0 else {
            close(socket)
            throw ErroOAuthGoogle.servidorLocalFalhou("listen falhou")
        }

        self.listener = FileHandle(fileDescriptor: socket, closeOnDealloc: true)

        return porta
    }

    func aguardarCodigo() async throws -> String {
        guard let listener = listener else {
            throw ErroOAuthGoogle.servidorLocalFalhou("servidor não iniciado")
        }
        let socket = listener.fileDescriptor

        registro.info("[DIAG] aguardarCodigo: iniciando loop accept...")

        // Loop síncrono até receber o código
        while true {
            var clientAddr = sockaddr_in()
            var clientLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            let clientSocket = withUnsafeMutablePointer(to: &clientAddr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.accept(socket, $0, &clientLen)
                }
            }
            guard clientSocket >= 0 else { continue }

            registro.info("[DIAG] aguardarCodigo: conexão aceita")
            let clientHandle = FileHandle(fileDescriptor: clientSocket, closeOnDealloc: true)
            let dados = clientHandle.readData(ofLength: 4096)
            if !dados.isEmpty, let requisicao = String(data: dados, encoding: .utf8) {
                registro.info("Request recebido: \(requisicao, privacy: .public)")
                if let codigo = extrairCodigo(da: requisicao) {
                    registro.info("Código extraído: \(codigo, privacy: .public)")
                    let body = """
                        <html><body>
                        <h1>Autorização concluída</h1>
                        <p>Pode fechar esta janela e voltar ao Papagaio.</p>
                        <script>window.close();</script>
                        </body></html>
                        """
                    let bodyData = Data(body.utf8)
                    var resposta = Data()
                    resposta.append("HTTP/1.1 200 OK\r\n".data(using: .ascii)!)
                    resposta.append("Content-Type: text/html; charset=utf-8\r\n".data(using: .ascii)!)
                    resposta.append("Connection: close\r\n".data(using: .ascii)!)
                    resposta.append("Content-Length: \(bodyData.count)\r\n".data(using: .ascii)!)
                    resposta.append("\r\n".data(using: .ascii)!)
                    resposta.append(bodyData)

                    let escrito = resposta.withUnsafeBytes { ptr in
                        var total = 0
                        let ponteiro = ptr.bindMemory(to: UInt8.self).baseAddress!
                        while total < resposta.count {
                            let n = Darwin.write(clientSocket, ponteiro.advanced(by: total), resposta.count - total)
                            if n <= 0 { break }
                            total += n
                        }
                        return total
                    }
                    registro.info("Bytes escritos: \(escrito)/\(resposta.count)")

                    Darwin.shutdown(clientSocket, SHUT_WR)
                    clientHandle.closeFile()
                    registro.info("Resposta HTTP enviada e socket fechado")

                    registro.info("[DIAG] aguardarCodigo: RETORNANDO código")
                    return codigo
                }
            }
            clientHandle.closeFile()
        }
    }

    func parar() {
        listener?.closeFile()
        listener = nil
    }

    private func extrairCodigo(da requisicao: String) -> String? {
        guard let primeiraLinha = requisicao.split(separator: "\n").first,
              primeiraLinha.hasPrefix("GET ") || primeiraLinha.hasPrefix("POST ")
        else { return nil }
        let partes = primeiraLinha.split(separator: " ")
        guard partes.count >= 2 else { return nil }
        let caminho = String(partes[1])
        guard let urlComponents = URLComponents(string: caminho),
              let code = urlComponents.queryItems?.first(where: { $0.name == "code" })?.value
        else { return nil }
        return code
    }
}

private struct CredenciaisDeToken {
    let accessToken: String
    let refreshToken: String?
    let expiraEm: Date
}

private struct TokenGuardado {
    let valor: String
    let expiraEm: Date
}