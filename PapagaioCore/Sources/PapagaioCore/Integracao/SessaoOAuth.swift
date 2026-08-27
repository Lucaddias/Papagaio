import Foundation

/// Orquestra o fluxo OAuth do MCP de ponta a ponta, com persistência no
/// Keychain e renovação silenciosa:
///
/// 1. metadados (RFC 8414) → DCR → URL de autorização;
/// 2. o `ApresentadorDeAutorizacaoOAuth` coleta o código no navegador;
/// 3. troca por credenciais e guarda (credenciais + registro do cliente);
/// 4. no próximo pedido: token válido → devolve; expirado → refresh;
///    sem nada → refaz o fluxo.
///
/// Divisão de responsabilidades: este ator não conhece MCP nem rede — recebe
/// o servidor MCP e `AutenticacaoOAuth` faz o HTTP.
public actor SessaoOAuth {
    private let servidorMCP: URL
    private let cofre: CofreDeTokens
    private let apresentador: any ApresentadorDeAutorizacaoOAuth

    private let contaCredenciais = "credenciais"
    private let contaCliente = "cliente-registrado"
    private let contaRedirecionamento = "redirecionamento"

    private var metadadosGuardados: MetadadosDeAutenticacao?
    private var clienteGuardado: ClienteRegistrado?
    private var credenciaisGuardadas: CredenciaisOAuth?
    private var carregou = false
    /// Evita dois fluxos de autorização simultâneos.
    private var autorizando = false

    private let redirecionamento: URL

    public init(
        servidorMCP: URL,
        redirecionamento: URL? = nil,
        cofre: CofreDeTokens,
        apresentador: any ApresentadorDeAutorizacaoOAuth
    ) {
        self.servidorMCP = servidorMCP
        self.redirecionamento = redirecionamento ?? URL(string: "papagaio://oauth")!
        self.cofre = cofre
        self.apresentador = apresentador
    }

    // MARK: - Consulta pública

    public func estaAutenticado() async -> Bool {
        await carregarSeNecessario()
        return (try? await tokenDeAcesso()) != nil
    }

    /// O token de acesso, válido para a chamada seguinte.
    ///
    /// Renova silenciosamente quando expirado; roda o fluxo completo quando
    /// não há nada salvo (ou o refresh também falhou). Com
    /// `forcandoRenovacao`, pula a checagem de validade local — uso do
    /// `ClienteMCP` quando o servidor devolveu 401/403 com um token que o
    /// cliente ainda julgava válido.
    public func tokenDeAcesso(forcandoRenovacao: Bool = false) async throws -> String {
        await carregarSeNecessario()
        if !forcandoRenovacao, let credenciais = credenciaisGuardadas, credenciais.aindaValido() {
            return credenciais.tokenDeAcesso
        }
        if let credenciais = credenciaisGuardadas {
            do {
                let renovadas = try await renovar(credenciais)
                try persistir(renovadas)
                credenciaisGuardadas = renovadas
                return renovadas.tokenDeAcesso
            } catch {
                // Refresh não é caminho livre de erro (token revogado, escopo
                // mudado): cai no fluxo completo em vez de mentir "autenticado".
                apagarCredenciais()
            }
        }
        return try await fluxoCompleto()
    }

    /// Desconecta: apaga credenciais e registro do Keychain.
    public func sair() async {
        carregou = true
        credenciaisGuardadas = nil
        clienteGuardado = nil
        metadadosGuardados = nil
        cofre.apagar(conta: contaCredenciais)
        cofre.apagar(conta: contaCliente)
        cofre.apagar(conta: contaRedirecionamento)
    }

    // MARK: - Fluxo

    private func fluxoCompleto() async throws -> String {
        guard !autorizando else {
            throw ErroOAuth.autorizacaoNegada
        }
        autorizando = true
        defer { autorizando = false }

        let credenciais = try await autenticarPedindoAoUsuario()
        try persistir(credenciais)
        credenciaisGuardadas = credenciais
        return credenciais.tokenDeAcesso
    }

    private func autenticarPedindoAoUsuario() async throws -> CredenciaisOAuth {
        let metadados = try await obterMetadados()
        let cliente = try await obterCliente(metadados)
        let pkce = AutenticacaoOAuth.novoDesafioPKCE()
        let estado = AutenticacaoOAuth.novoEstado()
        let url = try AutenticacaoOAuth.urlDeAutorizacao(
            metadados,
            cliente: cliente,
            desafioPKCE: pkce.desafio,
            estado: estado,
            escopos: metadados.escoposSuportados
        )
        let codigo = try await apresentador.autorizar(url: url)
        // `state` é nossa garantia contra CSRF no loopback real; por ora a
        // sessão de autorização é a que apresentou a URL — o código só volta
        // dela. O endpoint de troca valida `code_verifier` + `client_id`.
        return try await AutenticacaoOAuth.trocarCodigoPorToken(
            metadados,
            cliente: cliente,
            codigo: codigo,
            verificadorPKCE: pkce.verificador
        )
    }

    private func renovar(_ credenciais: CredenciaisOAuth) async throws -> CredenciaisOAuth {
        let metadados = try await obterMetadados()
        let cliente = try await obterCliente(metadados)
        return try await AutenticacaoOAuth.atualizarCredenciais(
            metadados,
            cliente: cliente,
            credenciais: credenciais
        )
    }

    // MARK: - Carga e persistência

    private func carregarSeNecessario() async {
        guard !carregou else { return }
        carregou = true
        let decodificador = JSONDecoder()
        if let dados = cofre.carregar(conta: contaCredenciais) {
            credenciaisGuardadas = try? decodificador.decode(CredenciaisOAuth.self, from: dados)
        }
        if let dados = cofre.carregar(conta: contaCliente),
           let registrado = (try? JSONSerialization.jsonObject(with: dados)) as? [String: Any],
           let id = registrado["client_id"] as? String {
            clienteGuardado = ClienteRegistrado(
                id: id,
                segredo: registrado["client_secret"] as? String,
                redirecionamento: cofre.carregar(conta: contaRedirecionamento)
                    .flatMap { String(data: $0, encoding: .utf8) }
                    .flatMap(URL.init(string:))
                    ?? URL(string: "papagaio://oauth")!
            )
        }
    }

    private func persistir(_ credenciais: CredenciaisOAuth) throws {
        try cofre.salvar(
            JSONEncoder().encode(credenciais),
            conta: contaCredenciais
        )
        if let clienteGuardado {
            let registro: [String: Any] = [
                "client_id": clienteGuardado.id,
                "client_secret": clienteGuardado.segredo as Any,
            ]
            try cofre.salvar(
                JSONSerialization.data(withJSONObject: registro),
                conta: contaCliente
            )
            try cofre.salvar(
                Data(clienteGuardado.redirecionamento.absoluteString.utf8),
                conta: contaRedirecionamento
            )
        }
    }

    private func apagarCredenciais() {
        credenciaisGuardadas = nil
        cofre.apagar(conta: contaCredenciais)
    }

    private func obterMetadados() async throws -> MetadadosDeAutenticacao {
        if let metadadosGuardados { return metadadosGuardados }
        let metadados = try await AutenticacaoOAuth.metadados(no: servidorMCP)
        metadadosGuardados = metadados
        return metadados
    }

    private func obterCliente(_ metadados: MetadadosDeAutenticacao) async throws -> ClienteRegistrado {
        if let clienteGuardado { return clienteGuardado }
        let cliente = try await AutenticacaoOAuth.registrarCliente(
            metadados,
            redirecionamento: redirecionamento,
            nomeDoApp: "Papagaio"
        )
        clienteGuardado = cliente
        return cliente
    }
}