import Foundation

/// Erros do protocolo MCP e do transporte.
public enum ErroMCP: LocalizedError, Equatable {
    /// Resposta fora do formato JSON-RPC esperado.
    case respostaInvalida(String)
    /// O servidor respondeu com o bloco `error` do JSON-RPC.
    case erroDoServidor(codigo: Int, mensagem: String)
    /// 401/403: o token não vale mais (ou o fluxo OAuth foi cancelado).
    case naoAutenticado
    /// Falha de transporte (`initialize`, sessão, rede).
    case transporte(String)

    public var errorDescription: String? {
        switch self {
        case let .respostaInvalida(detalhe):
            "Resposta do MCP em formato inesperado: \(detalhe)"
        case let .erroDoServidor(codigo, mensagem):
            "MCP respondeu com erro \(codigo): \(mensagem)"
        case .naoAutenticado:
            "Não autenticado no MCP. Autentique novamente."
        case let .transporte(mensagem):
            "Falha de conexão com o MCP: \(mensagem)"
        }
    }
}

/// Árvore de valor JSON tipada e `Sendable` — a resposta crua de um tool MCP.
///
/// `JSONSerialization` devolve `Any`, que não atravessa fronteiras de actor
/// em Swift 6. Tudo que atravessa (respostas do servidor, argumentos de
/// tools) usa esta árvore; o `MapeadorGranola` a converte para o domínio.
public enum ValorJSON: Sendable, Equatable {
    case objeto([String: ValorJSON])
    case lista([ValorJSON])
    case texto(String)
    case numero(Double)
    case booleano(Bool)
    case nulo

    /// Converte o resultado do `JSONSerialization` em árvore; `nil` quando
    /// o valor não é JSON (ex.: `Data` solta, número fora do JSON).
    public init?(de qualquer: Any) {
        switch qualquer {
        case let s as String:
            self = .texto(s)
        case let b as Bool:
            self = .booleano(b)
        case let n as NSNumber:
            if CFGetTypeID(n) == CFBooleanGetTypeID() {
                self = .booleano(n.boolValue)
            } else {
                self = .numero(n.doubleValue)
            }
        case let d as [String: Any]:
            var mapa: [String: ValorJSON] = [:]
            for (chave, valor) in d {
                guard let convertido = ValorJSON(de: valor) else { return nil }
                mapa[chave] = convertido
            }
            self = .objeto(mapa)
        case let a as [Any]:
            var lista: [ValorJSON] = []
            for valor in a {
                guard let convertido = ValorJSON(de: valor) else { return nil }
                lista.append(convertido)
            }
            self = .lista(lista)
        default:
            return nil
        }
    }

    /// O mesmo valor de volta para o `JSONSerialization` (argumentos de tools).
    public var comoAny: Any {
        switch self {
        case .objeto(let mapa):
            mapa.mapValues(\.comoAny)
        case .lista(let lista):
            lista.map(\.comoAny)
        case .texto(let s):
            s
        case .numero(let n):
            n
        case .booleano(let b):
            b
        case .nulo:
            NSNull()
        }
    }
}

extension [String: ValorJSON] {
    /// Texto da chave, quando existe.
    public func texto(_ chave: String) -> String? {
        guard case .texto(let valor)? = self[chave] else { return nil }
        return valor
    }
}

/// Cliente mínimo do Model Context Protocol sobre **Streamable HTTP**
/// (spec 2025-03-26): `initialize` + `tools/call`, JSON-RPC 2.0.
///
/// Tudo que o Granola (e qualquer servidor MCP futuro) precisa aqui é chamar
/// um tool e receber o `result` decodificado. Feito à mão de propósito: o
/// projeto não tem dependências externas, e o subset é pequeno o bastante
/// para caber em um arquivo.
///
/// Fluxo por debaixo dos panos:
/// 1. `GET /` — entrega o `Mcp-Session-Id` (quando o servidor usa);
/// 2. `POST initialize` — negocia a versão do protocolo;
/// 3. `POST tools/call` — o trabalho real, reenviado uma vez após 401.
///
/// O token de autorização vem da closure `fornecerToken` (a `SessaoOAuth`),
/// chamada a cada requisição. Em 401/403 a requisição é repetida **uma**
/// vez com `forcarRenovacao: true` — o fornecedor renova (ou re-executa o
/// fluxo OAuth) e a chamada sobrevive sozinha. Se o renovado também falhar,
/// o erro `naoAutenticado` sobe para o chamador.
public actor ClienteMCP {
    /// Versão do protocolo negociada no `initialize`.
    nonisolated public static let versaoDoProtocolo = "2025-03-26"

    public let url: URL
    private let sessao: URLSession
    private let fornecerToken: @Sendable (_ forcarRenovacao: Bool) async throws -> String

    private var sessaoMCP: String?
    private var inicializado = false

    public init(
        url: URL,
        sessao: URLSession? = nil,
        fornecerToken: @escaping @Sendable (_ forcarRenovacao: Bool) async throws -> String
    ) {
        self.url = url
        self.sessao = sessao ?? URLSession.shared
        self.fornecerToken = fornecerToken
    }

    /// Chama um tool MCP (`tools/call`) e devolve o `result` decodificado.
    public func chamar(metodo: String, parametros: [String: ValorJSON] = [:]) async throws -> ValorJSON {
        _ = try await inicializarSeNecessario()
        return try await chamarUmaVez(metodo: metodo, parametros: parametros, tentativa: 0)
    }

    // MARK: - Transporte

    private func inicializarSeNecessario() async throws {
        guard !inicializado else { return }

        let token = try await fornecerToken(false)
        var pedido = URLRequest(url: url)
        pedido.httpMethod = "GET"
        pedido.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        pedido.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (dados, resposta) = try await sessao.data(for: pedido)
        if let http = resposta as? HTTPURLResponse,
           let sessao = http.value(forHTTPHeaderField: "Mcp-Session-Id") {
            sessaoMCP = sessao
        }
        _ = dados

        let resultado = try await enviar(
            metodo: "initialize",
            parametros: [
                "protocolVersion": Self.versaoDoProtocolo,
                "capabilities": [:],
                "clientInfo": [
                    "name": "papagaio",
                    "version": "1.0",
                ],
            ]
        )
        guard let raiz = resultado as? [String: Any],
              let versao = raiz["protocolVersion"] as? String
        else {
            throw ErroMCP.respostaInvalida("initialize sem protocolVersion")
        }
        if versao != Self.versaoDoProtocolo {
            throw ErroMCP.respostaInvalida("versão \(versao) não suportada")
        }
        inicializado = true
    }

    private func chamarUmaVez(metodo: String, parametros: [String: ValorJSON], tentativa: Int) async throws -> ValorJSON {
        let resultado: Any
        do {
            resultado = try await enviar(
                metodo: "tools/call",
                parametros: ["name": metodo, "arguments": parametros]
            )
        } catch ErroMCP.naoAutenticado where tentativa == 0 {
            // Token revogado no servidor (401/403): renova forçando e repete
            // uma vez. Se a renovação desencadear o fluxo OAuth completo,
            // esta chamada sobrevive ao período de autorização.
            _ = try await fornecerToken(true)
            return try await chamarUmaVez(metodo: metodo, parametros: parametros, tentativa: 1)
        }
        guard let raiz = resultado as? [String: Any] else {
            throw ErroMCP.respostaInvalida("tools/call sem objeto de resultado")
        }
        if let erro = raiz["isError"] as? Bool, erro {
            let texto = (raiz["content"] as? [[String: Any]])?
                .compactMap { $0["text"] as? String }
                .joined(separator: " ") ?? "sem detalhes"
            throw ErroMCP.erroDoServidor(codigo: -1, mensagem: texto)
        }
        if let saida = raiz["content"] as? [[String: Any]],
           saida.contains(where: { $0["type"] as? String == "text" }) {
            // Servidores que entregam o resultado como conteúdo textual puro
            // (typeless) — o Granola devolve JSON estruturado, mas aceitar o
            // texto mantém o cliente utilizável com qualquer servidor.
            let texto = saida.compactMap { $0["text"] as? String }.joined(separator: "\n")
            if let bruto = texto.data(using: .utf8),
               let decodificado = try? JSONSerialization.jsonObject(with: bruto),
               let arvore = ValorJSON(de: decodificado) {
                return arvore
            }
            return .texto(texto)
        }
        guard let resultadoFinal = raiz["structuredContent"] ?? raiz as Any?,
              let arvore = ValorJSON(de: resultadoFinal)
        else {
            throw ErroMCP.respostaInvalida("resultado do tools/call sem JSON válido")
        }
        return arvore
    }

    /// Envia um pedido JSON-RPC e devolve o `result` cru (sem envelope).
    ///
    /// Aceita respostas JSON puras e `text/event-stream` (linhas `data:`);
    /// o streamable HTTP do MCP entrega as duas formas conforme o servidor.
    private func enviar(metodo: String, parametros: [String: Any]) async throws -> Any {
        let token = try await fornecerToken(false)
        let id = UUID().uuidString
        let corpo: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id,
            "method": metodo,
            "params": parametros,
        ]
        let dadosDoCorpo = try JSONSerialization.data(withJSONObject: corpo)

        var pedido = URLRequest(url: url)
        pedido.httpMethod = "POST"
        pedido.setValue("application/json", forHTTPHeaderField: "Content-Type")
        pedido.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        pedido.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let sessaoMCP {
            pedido.setValue(sessaoMCP, forHTTPHeaderField: "Mcp-Session-Id")
        }
        pedido.httpBody = dadosDoCorpo

        let (dados, resposta): (Data, URLResponse)
        do {
            (dados, resposta) = try await sessao.data(for: pedido)
        } catch {
            throw ErroMCP.transporte(error.localizedDescription)
        }
        guard let http = resposta as? HTTPURLResponse else {
            throw ErroMCP.transporte("resposta sem HTTP")
        }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw ErroMCP.naoAutenticado
        }
        guard (200..<300).contains(http.statusCode) else {
            let texto = String(data: dados, encoding: .utf8) ?? ""
            throw ErroMCP.erroDoServidor(
                codigo: http.statusCode,
                mensagem: String(texto.prefix(200))
            )
        }

        let mensagem = try decodificarEnvelope(dados, contentType: http.mimeType)
        guard let envelope = mensagem as? [String: Any],
              (envelope["id"] as? String) == id
        else {
            throw ErroMCP.respostaInvalida("envelope sem id correspondente")
        }
        if let erro = envelope["error"] as? [String: Any] {
            throw ErroMCP.erroDoServidor(
                codigo: erro["code"] as? Int ?? -1,
                mensagem: erro["message"] as? String ?? "sem mensagem"
            )
        }
        guard let resultado = envelope["result"] else {
            throw ErroMCP.respostaInvalida("sem result no envelope")
        }
        return resultado
    }

    private func decodificarEnvelope(_ dados: Data, contentType: String?) throws -> Any {
        let eTexto = contentType?.contains("text/event-stream") ?? false
        let bruto: Data
        if eTexto {
            let linhas = String(data: dados, encoding: .utf8) ?? ""
            let dadosDeEventos = linhas
                .split(separator: "\n")
                .filter { $0.hasPrefix("data:") }
                .filter { $0 != "data: [DONE]" }
                .map { $0.dropFirst("data:".count).trimmingCharacters(in: .whitespaces) }
                .joined(separator: "\n")
            guard !dadosDeEventos.isEmpty else {
                throw ErroMCP.respostaInvalida("stream sem eventos data:")
            }
            bruto = Data(dadosDeEventos.utf8)
        } else {
            bruto = dados
        }
        do {
            return try JSONSerialization.jsonObject(with: bruto)
        } catch {
            throw ErroMCP.respostaInvalida("JSON inválido na resposta")
        }
    }
}