import Foundation
import PapagaioCore
import SwiftData
import Testing
@testable import Papagaio

// O ciclo de vida das pastas vivia privado na BibliotecaHomeView. No
// coordenador `PastasDaBiblioteca` ele ganha teste de ponta a ponta:
// apagar leva as conversas junto com um retrato na lixeira; restaurar
// devolve o conjunto.
//
// A biblioteca é injetada (container em memória + armazenamento temporário),
// e o nome da pasta é único por execução — a lista de pastas e a lixeira de
// pastas são chaves globais de UserDefaults, e o fim do teste limpa o rastro.

@MainActor
private func bibliotecaDeTeste() throws -> Biblioteca {
    let raiz = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: raiz, withIntermediateDirectories: true)

    let biblioteca = Biblioteca(
        armazenamento: Armazenamento(raiz: raiz),
        repositorio: SwiftDataRepository(
            modelContainer: try SwiftDataRepository.containerLocal(
                nome: UUID().uuidString, emMemoria: true
            )
        ),
        espaco: EspacoID()
    )
    biblioteca.processamentoAutomatico = false
    return biblioteca
}

@MainActor
@Test("Apagar a pasta leva as conversas para a lixeira com retrato; restaurar devolve tudo")
func pastaApagaERestauraCicloCompleto() async throws {
    let biblioteca = try bibliotecaDeTeste()
    let nome = "PastaTeste-\(UUID().uuidString.prefix(6))"

    let arquivo = try #require(
        await biblioteca.registrar(
            titulo: "Na pasta",
            pastaRelativa: Armazenamento.caminhoRelativo(id: UUID()),
            duracao: 30
        )
    )
    PreferenciasVisuaisDoArquivo.definirPasta(nome, para: arquivo.id)

    // Apagar: a conversa sai de cena junto, e o retrato fica na lixeira.
    await PastasDaBiblioteca.apagar(nome, biblioteca: biblioteca)

    #expect(biblioteca.arquivos.isEmpty)
    #expect(biblioteca.arquivosNaLixeira.map(\.id) == [arquivo.id])
    let retrato = try #require(LixeiraDePastas.itens().first { $0.nome == nome })
    #expect(retrato.conversas == [arquivo.id.rawValue])
    #expect(!PreferenciasVisuaisDoArquivo.pastas().contains(nome))

    // Restaurar: a pasta volta, e a conversa volta com o rótulo.
    await PastasDaBiblioteca.restaurar(retrato, biblioteca: biblioteca)

    #expect(biblioteca.arquivosNaLixeira.isEmpty)
    #expect(biblioteca.arquivos.map(\.id) == [arquivo.id])
    #expect(PreferenciasVisuaisDoArquivo.pasta(arquivo.id) == nome)
    #expect(!LixeiraDePastas.itens().contains { $0.nome == nome })

    // Limpeza: tira a pasta de teste das chaves globais do usuário.
    PreferenciasVisuaisDoArquivo.definirPasta(nil, para: arquivo.id)
    let restantes = PreferenciasVisuaisDoArquivo.pastas().filter { $0 != nome }
    UserDefaults.standard.set(restantes, forKey: "pastasDaBiblioteca")
}

@MainActor
@Test("Restaurar só a conversa devolve sem rótulo, e a pasta para de reclamá-la")
func restaurarConversaSoltaSemRotulo() async throws {
    let biblioteca = try bibliotecaDeTeste()
    let nome = "PastaTeste-\(UUID().uuidString.prefix(6))"

    let arquivo = try #require(
        await biblioteca.registrar(
            titulo: "Só ela",
            pastaRelativa: Armazenamento.caminhoRelativo(id: UUID()),
            duracao: 30
        )
    )
    PreferenciasVisuaisDoArquivo.definirPasta(nome, para: arquivo.id)
    await PastasDaBiblioteca.apagar(nome, biblioteca: biblioteca)

    await PastasDaBiblioteca.restaurarConversa(arquivo, biblioteca: biblioteca)

    // Voltou para "Todas" sem rótulo — a pasta não existe mais.
    #expect(biblioteca.arquivos.map(\.id) == [arquivo.id])
    #expect(PreferenciasVisuaisDoArquivo.pasta(arquivo.id) == nil)

    // E o retrato na lixeira deixou de apontar para ela.
    let retrato = try #require(LixeiraDePastas.itens().first { $0.nome == nome })
    #expect(!retrato.conversas.contains(arquivo.id.rawValue))

    // Limpeza do rastro nas chaves globais.
    LixeiraDePastas.remover(retrato)
    let restantes = PreferenciasVisuaisDoArquivo.pastas().filter { $0 != nome }
    UserDefaults.standard.set(restantes, forKey: "pastasDaBiblioteca")
}

@MainActor
@Test("Restaurar tudo devolve pasta, rótulos e conversas avulsas em ordem")
func restaurarTudoMantemOsVinculosDasPastas() async throws {
    let biblioteca = try bibliotecaDeTeste()
    let nome = "PastaTeste-\(UUID().uuidString.prefix(6))"

    let naPasta = try #require(
        await biblioteca.registrar(
            titulo: "Na pasta",
            pastaRelativa: Armazenamento.caminhoRelativo(id: UUID()),
            duracao: 30
        )
    )
    let avulsa = try #require(
        await biblioteca.registrar(
            titulo: "Avulsa",
            pastaRelativa: Armazenamento.caminhoRelativo(id: UUID()),
            duracao: 30
        )
    )
    PreferenciasVisuaisDoArquivo.definirPasta(nome, para: naPasta.id)
    await PastasDaBiblioteca.apagar(nome, biblioteca: biblioteca)
    await biblioteca.moverParaLixeira(avulsa)

    await PastasDaBiblioteca.restaurarTudo(biblioteca: biblioteca)

    #expect(biblioteca.arquivosNaLixeira.isEmpty)
    #expect(Set(biblioteca.arquivos.map(\.id)) == [naPasta.id, avulsa.id])
    #expect(PreferenciasVisuaisDoArquivo.pasta(naPasta.id) == nome)
    #expect(PreferenciasVisuaisDoArquivo.pasta(avulsa.id) == nil)
    #expect(PreferenciasVisuaisDoArquivo.pastas().contains(nome))
    #expect(!LixeiraDePastas.itens().contains { $0.nome == nome })

    PreferenciasVisuaisDoArquivo.definirPasta(nil, para: naPasta.id)
    let restantes = PreferenciasVisuaisDoArquivo.pastas().filter { $0 != nome }
    UserDefaults.standard.set(restantes, forKey: "pastasDaBiblioteca")
}
