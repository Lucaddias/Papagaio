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

@Test("Conversa preserva conteúdo ao preparar o payload CloudKit")
func conversaCodificaParaSincronizacao() throws {
    let espaco = EspacoID()
    let arquivo = Arquivo(
        titulo: "Planejamento",
        pastaRelativa: "gravacoes/teste",
        espaco: espaco,
        trechos: [Trecho(start: 0, end: 2, texto: "Vamos começar")],
        notas: [NotaDaConversa(texto: "Decisão", start: 1)]
    )

    let decodificado = try JSONDecoder().decode(Arquivo.self, from: JSONEncoder().encode(arquivo))

    #expect(decodificado == arquivo)
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
