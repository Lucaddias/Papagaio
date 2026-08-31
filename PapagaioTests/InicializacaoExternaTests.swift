import Testing
@testable import Papagaio

@MainActor
@Test("Inicialização em testes não executa serviços externos")
func inicializacaoDeTesteNaoConectaAutomaticamente() async {
    let politica = PoliticaDeInicializacaoExterna(
        ambiente: ["PAPAGAIO_TEST_MODE": "1"]
    )
    var tentativasDeConexao = 0

    await politica.executar {
        tentativasDeConexao += 1
    }

    #expect(!politica.permiteServicosExternos)
    #expect(tentativasDeConexao == 0)
}

@MainActor
@Test("Inicialização normal preserva os serviços externos")
func inicializacaoNormalPermiteConexao() async {
    let politica = PoliticaDeInicializacaoExterna(ambiente: [:])
    var tentativasDeConexao = 0

    await politica.executar {
        tentativasDeConexao += 1
    }

    #expect(politica.permiteServicosExternos)
    #expect(tentativasDeConexao == 1)
}
