import Foundation
import PapagaioCore
import Testing
@testable import Papagaio

@Test("Workspace CloudKit usa uma zona estável por equipe")
func zonaDaEquipeEhDeterministica() {
    #expect(
        ServicoDeEquipesCloudKit.nomeDaZona(para: "produto-a1b2c3")
            == "equipe.produto-a1b2c3"
    )
}

@Test("Equipe local legada continua decodificável")
func equipeLegadaNaoExigeMetadadosCloudKit() throws {
    let dados = """
    {"id":"equipe-legada","nome":"Produto","papel":"Administrador","quantidadeDeMembros":1}
    """.data(using: .utf8)!

    let equipe = try JSONDecoder().decode(EquipeDisponivel.self, from: dados)

    #expect(equipe.zonaCloudKit == nil)
    #expect(equipe.compartilhamentoCloudKit == nil)
}

@Test("Download CloudKit consome todos os cursores acima de 200 registros")
func downloadCloudKitEhPaginado() async throws {
    let espaco = EspacoID()
    let equipe = equipeCloudKitDeTeste(espaco: espaco)
    let arquivos = (0..<205).map { indice in
        Arquivo(
            titulo: "Conversa \(indice)",
            pastaRelativa: "",
            espaco: espaco
        )
    }
    let codificador = JSONEncoder()
    let transporte = TransporteDeConversasFake(
        paginas: [
            try arquivos.prefix(200).map(codificador.encode),
            try arquivos.suffix(5).map(codificador.encode),
        ]
    )
    let sincronizador = SincronizadorDaBibliotecaCloudKit(transporte: transporte)

    let baixados = try await sincronizador.baixar(da: equipe)

    #expect(baixados.count == 205)
    #expect(await transporte.quantidadeDePaginasLidas() == 2)
}

@Test("Mapeamento CloudKit preserva payload e ignora outro espaço")
func mapeamentoCloudKitRespeitaEspaco() async throws {
    let espaco = EspacoID()
    let equipe = equipeCloudKitDeTeste(espaco: espaco)
    let esperado = Arquivo(
        titulo: "Produto",
        duracao: 42,
        pastaRelativa: "Gravacoes/local",
        espaco: espaco,
        notas: [NotaDaConversa(texto: "Decisão", start: 7)]
    )
    let outro = Arquivo(
        titulo: "Outro espaço",
        pastaRelativa: "",
        espaco: EspacoID()
    )
    let transporte = TransporteDeConversasFake(
        paginas: [[try JSONEncoder().encode(esperado), try JSONEncoder().encode(outro)]]
    )
    let sincronizador = SincronizadorDaBibliotecaCloudKit(transporte: transporte)

    try await sincronizador.enviar(esperado, para: equipe)
    let enviado = try #require(await transporte.ultimoArquivoSalvo())
    let baixados = try await sincronizador.baixar(da: equipe)

    #expect(
        try JSONDecoder().decode(PayloadDeConversaCloudKit.self, from: enviado).arquivo
            == esperado
    )
    #expect(baixados == [esperado])
}

@MainActor
@Test("Falha de download CloudKit chega ao estado observável e à notificação")
func falhaCloudKitEhObservavel() async throws {
    let raiz = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: raiz, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: raiz) }
    let espaco = EspacoID()
    let transporte = TransporteDeConversasFake(paginas: [], falharAoPaginar: true)
    let sincronizador = SincronizadorDaBibliotecaCloudKit(transporte: transporte)
    let biblioteca = Biblioteca(
        armazenamento: Armazenamento(raiz: raiz),
        repositorio: SwiftDataRepository(
            modelContainer: try SwiftDataRepository.containerLocal(
                nome: UUID().uuidString,
                emMemoria: true
            )
        ),
        espaco: espaco,
        sincronizadorCloudKit: sincronizador
    )
    var notificacao: String?
    biblioteca.aoNotificar = { _, mensagem, _ in notificacao = mensagem }

    await biblioteca.usarEspaco(espaco, equipeCloudKit: equipeCloudKitDeTeste(espaco: espaco))

    guard case let .falhou(mensagem) = biblioteca.estadoDaSincronizacaoCloudKit else {
        Issue.record("A falha do transporte não chegou ao estado da biblioteca")
        return
    }
    #expect(mensagem.contains("Falha simulada"))
    #expect(notificacao?.contains("Falha simulada") == true)
}

@MainActor
@Test("Remoção só altera o espelho local depois da revogação remota")
func remocaoDeMembroEhRemotaPrimeiro() async throws {
    let suite = "membros-cloudkit-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let equipe = equipeCloudKitDeTeste(espaco: EspacoID())
    let membro = MembroDaEquipe(
        id: "usuario-remoto",
        nome: "Ana",
        email: "ana@icloud.com",
        cargo: "Membro",
        status: .ativo
    )
    let servico = ServicoDeMembrosFake(membros: [membro])
    let gestor = GestorDeMembrosDaEquipe(servico: servico, defaults: defaults)

    await gestor.carregar(equipe)
    await servico.definirFalhaNaRemocao(true)
    await gestor.remover(membro, da: equipe)

    #expect(gestor.membros == [membro])
    #expect(MembrosDasEquipes.carregar(equipeID: equipe.id, em: defaults) == [membro])
    #expect(gestor.erro?.contains("Falha simulada") == true)

    await servico.definirFalhaNaRemocao(false)
    await gestor.remover(membro, da: equipe)

    #expect(gestor.membros.isEmpty)
    #expect(MembrosDasEquipes.carregar(equipeID: equipe.id, em: defaults).isEmpty)
    #expect(await servico.quantidadeDeRemocoesTentadas() == 2)
}

@MainActor
@Test("Convite e edição persistem a permissão devolvida pelo serviço remoto")
func permissoesDeMembroSeguemRespostaRemota() async throws {
    let suite = "permissoes-cloudkit-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let equipe = equipeCloudKitDeTeste(espaco: EspacoID())
    let servico = ServicoDeMembrosFake(membros: [])
    let gestor = GestorDeMembrosDaEquipe(servico: servico, defaults: defaults)

    await gestor.carregar(equipe)
    await gestor.convidar(
        email: "bia@icloud.com",
        permissao: .leitura,
        para: equipe
    )
    let convidada = try #require(gestor.membros.first)
    #expect(convidada.permissao == .leitura)
    #expect(convidada.status == .aguardando)

    await gestor.atualizar(convidada, permissao: .escrita, na: equipe)

    #expect(gestor.membros.first?.permissao == .escrita)
    #expect(
        MembrosDasEquipes.carregar(equipeID: equipe.id, em: defaults).first?.permissao
            == .escrita
    )
}

@Test("Falha transitória sobrevive ao relançamento e respeita backoff limitado")
func filaCloudKitEhPersistente() async throws {
    let raiz = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: raiz) }
    let url = raiz.appendingPathComponent("fila.json")
    let agora = Date(timeIntervalSince1970: 1_000)
    let espaco = EspacoID()
    let equipe = equipeCloudKitDeTeste(espaco: espaco)
    let arquivo = Arquivo(titulo: "Local", pastaRelativa: "", espaco: espaco)
    let transporte = TransporteDeConversasFake(
        paginas: [],
        falharAoSalvar: true
    )
    let sincronizador = SincronizadorDaBibliotecaCloudKit(transporte: transporte)
    let primeiraExecucao = FilaPersistenteCloudKit(url: url)

    try await primeiraExecucao.agendarEnvio(
        arquivo,
        para: equipe,
        revisao: agora
    )
    let falha = try await primeiraExecucao.processar(
        com: sincronizador,
        agora: agora
    )

    #expect(falha.pendentes == 1)
    #expect(falha.proximaTentativa == agora.addingTimeInterval(5))

    let aposRelancamento = FilaPersistenteCloudKit(url: url)
    #expect(try await aposRelancamento.operacoesPendentes().first?.tentativas == 1)
    await transporte.definirFalhaAoSalvar(false)

    let cedo = try await aposRelancamento.processar(
        com: sincronizador,
        agora: agora.addingTimeInterval(4)
    )
    #expect(cedo.concluidas == 0)
    #expect(cedo.pendentes == 1)

    let retomada = try await aposRelancamento.processar(
        com: sincronizador,
        agora: agora.addingTimeInterval(5)
    )
    #expect(retomada.concluidas == 1)
    #expect(retomada.pendentes == 0)
    #expect(FilaPersistenteCloudKit.atraso(para: 20) == 15 * 60)
}

@Test("Download antigo não sobrescreve uma edição local pendente")
func conflitoCloudKitPreservaEdicaoLocal() {
    let revisaoRemota = Date(timeIntervalSince1970: 1_000)
    let revisaoLocal = Date(timeIntervalSince1970: 2_000)

    #expect(
        PoliticaDeConflitoCloudKit.decidir(
            revisaoRemota: revisaoRemota,
            revisaoLocalPendente: revisaoLocal
        ) == .preservarLocalPendente
    )
    #expect(
        PoliticaDeConflitoCloudKit.decidir(
            revisaoRemota: revisaoRemota,
            revisaoLocalPendente: nil
        ) == .aplicarRemoto
    )
    #expect(
        PoliticaDeConflitoCloudKit.decidir(
            revisaoRemota: revisaoRemota,
            revisaoLocalPendente: revisaoRemota
        ) == .aplicarRemoto
    )
}

private func equipeCloudKitDeTeste(espaco: EspacoID) -> EquipeDisponivel {
    EquipeDisponivel(
        id: "produto",
        nome: "Produto",
        papel: "Administrador",
        quantidadeDeMembros: 1,
        espacoID: espaco.rawValue.uuidString,
        zonaCloudKit: "equipe.produto",
        compartilhamentoCloudKit: "share",
        bancoCloudKit: BancoCloudKitDaEquipe.privado.rawValue
    )
}

private struct FalhaCloudKitFake: LocalizedError {
    var errorDescription: String? { "Falha simulada do CloudKit" }
}

private actor TransporteDeConversasFake: TransporteDeConversasCloudKit {
    private let paginas: [[Data]]
    private let falharAoPaginar: Bool
    private var falharAoSalvar: Bool
    private var indiceDaPagina = 0
    private var arquivoSalvo: Data?

    init(
        paginas: [[Data]],
        falharAoPaginar: Bool = false,
        falharAoSalvar: Bool = false
    ) {
        self.paginas = paginas
        self.falharAoPaginar = falharAoPaginar
        self.falharAoSalvar = falharAoSalvar
    }

    func salvar(_ dados: Data, id: String, equipe: EquipeDisponivel) throws {
        if falharAoSalvar { throw FalhaCloudKitFake() }
        arquivoSalvo = dados
    }

    func pagina(
        da equipe: EquipeDisponivel,
        continuando cursor: CursorDeConversasCloudKit?
    ) throws -> PaginaDeConversasCloudKit {
        if falharAoPaginar { throw FalhaCloudKitFake() }
        guard indiceDaPagina < paginas.count else {
            return PaginaDeConversasCloudKit(registros: [], proxima: nil)
        }
        let atual = indiceDaPagina
        indiceDaPagina += 1
        let proxima = indiceDaPagina < paginas.count
            ? CursorDeConversasCloudKit("pagina-\(indiceDaPagina)")
            : nil
        return PaginaDeConversasCloudKit(registros: paginas[atual], proxima: proxima)
    }

    func remover(id: String, equipe: EquipeDisponivel) {}

    func quantidadeDePaginasLidas() -> Int { indiceDaPagina }
    func ultimoArquivoSalvo() -> Data? { arquivoSalvo }
    func definirFalhaAoSalvar(_ falhar: Bool) { falharAoSalvar = falhar }
}

private actor ServicoDeMembrosFake: ServicoDeMembrosDaEquipe {
    private var membros: [MembroDaEquipe]
    private var falharNaRemocao = false
    private var remocoesTentadas = 0

    init(membros: [MembroDaEquipe]) {
        self.membros = membros
    }

    func carregarMembros(da equipe: EquipeDisponivel) -> [MembroDaEquipe] {
        membros
    }

    func adicionarMembro(
        email: String,
        permissao: PermissaoDoMembroDaEquipe,
        a equipe: EquipeDisponivel
    ) -> [MembroDaEquipe] {
        membros.append(
            MembroDaEquipe(
                id: "email:\(email)",
                nome: "Convidado",
                email: email,
                cargo: "Membro",
                status: .aguardando,
                permissao: permissao
            )
        )
        return membros
    }

    func atualizarPermissao(
        do membro: MembroDaEquipe,
        para permissao: PermissaoDoMembroDaEquipe,
        na equipe: EquipeDisponivel
    ) -> [MembroDaEquipe] {
        guard let indice = membros.firstIndex(where: { $0.id == membro.id }) else {
            return membros
        }
        membros[indice].permissao = permissao
        return membros
    }

    func removerMembro(
        _ membro: MembroDaEquipe,
        da equipe: EquipeDisponivel
    ) throws -> [MembroDaEquipe] {
        remocoesTentadas += 1
        if falharNaRemocao { throw FalhaCloudKitFake() }
        membros.removeAll { $0.id == membro.id }
        return membros
    }

    func definirFalhaNaRemocao(_ falhar: Bool) {
        falharNaRemocao = falhar
    }

    func quantidadeDeRemocoesTentadas() -> Int { remocoesTentadas }
}
