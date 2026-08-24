import Foundation
import PapagaioCore
import Testing
@testable import Papagaio

// A fila serial da `Biblioteca` é a invariante que impede o Whisper (3 GB) e o
// Qwen (10,7 GB) de carregarem ao mesmo tempo num Mac cujo piso é 18 GB. Até
// agora ela não tinha teste nenhum: o `.xcodeproj` tinha um único target.
//
// Os testes não carregam modelo. A pasta de pesos aponta para um diretório
// temporário vazio, então o `Preflight` reprova logo no começo de
// `executarProcessamento` e o pipeline retorna cedo — o que exercita
// exatamente a mecânica da fila (entrar, virar ativo, terminar, chamar o
// próximo) sem tocar em 13,7 GB.

@MainActor
private func bibliotecaDeTeste() throws -> (Biblioteca, URL) {
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
    return (biblioteca, raiz)
}

/// Espera uma condição virar verdadeira, com teto. Evita `sleep` fixo, que ou
/// deixa o teste lento ou o deixa instável.
@MainActor
private func aguardar(
    ate limite: TimeInterval = 5,
    _ condicao: () -> Bool
) async -> Bool {
    let fim = Date().addingTimeInterval(limite)
    while Date() < fim {
        if condicao() { return true }
        try? await Task.sleep(for: .milliseconds(20))
    }
    return condicao()
}

@MainActor
@Test("Trocar de espaço isola as bibliotecas sem apagar o acervo anterior")
func trocaDeEspacoIsolaBibliotecas() async throws {
    let espacoPessoal = EspacoID()
    let espacoDaEquipe = EspacoID()
    let raiz = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: raiz, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: raiz) }

    let biblioteca = Biblioteca(
        armazenamento: Armazenamento(raiz: raiz),
        repositorio: SwiftDataRepository(
            modelContainer: try SwiftDataRepository.containerLocal(
                nome: UUID().uuidString,
                emMemoria: true
            )
        ),
        espaco: espacoPessoal
    )
    biblioteca.processamentoAutomatico = false

    _ = await biblioteca.registrar(
        titulo: "Pessoal",
        pastaRelativa: Armazenamento.caminhoRelativo(id: UUID()),
        duracao: 10
    )
    await biblioteca.usarEspaco(espacoDaEquipe)
    #expect(biblioteca.arquivos.isEmpty)

    _ = await biblioteca.registrar(
        titulo: "Equipe",
        pastaRelativa: Armazenamento.caminhoRelativo(id: UUID()),
        duracao: 10
    )
    await biblioteca.usarEspaco(espacoPessoal)

    #expect(biblioteca.arquivos.map(\.titulo) == ["Pessoal"])
}

// MARK: - Fila serial

@MainActor
@Test("Dois arquivos na fila nunca processam ao mesmo tempo")
func filaProcessaUmPorVez() async throws {
    let (biblioteca, raiz) = try bibliotecaDeTeste()
    defer { try? FileManager.default.removeItem(at: raiz) }

    biblioteca.processamentoAutomatico = false
    await biblioteca.registrar(titulo: "Primeira", pastaRelativa: Armazenamento.caminhoRelativo(id: UUID()), duracao: 60)
    await biblioteca.registrar(titulo: "Segunda", pastaRelativa: Armazenamento.caminhoRelativo(id: UUID()), duracao: 60)

    let primeira = try #require(biblioteca.arquivos.last)
    let segunda = try #require(biblioteca.arquivos.first)

    biblioteca.enfileirarProcessamento(primeira)
    biblioteca.enfileirarProcessamento(segunda)

    // Enquanto a fila roda, no máximo um arquivo pode estar ativo.
    var maiorSimultaneo = 0
    _ = await aguardar {
        let ativos = [primeira, segunda].filter { biblioteca.estaProcessando($0) }.count
        maiorSimultaneo = max(maiorSimultaneo, ativos)
        return !biblioteca.processando
    }

    #expect(maiorSimultaneo <= 1, "houve \(maiorSimultaneo) arquivos processando juntos")
    #expect(!biblioteca.processando)
}

@MainActor
@Test("O mesmo arquivo não entra duas vezes na fila")
func naoDuplicaNaFila() async throws {
    let (biblioteca, raiz) = try bibliotecaDeTeste()
    defer { try? FileManager.default.removeItem(at: raiz) }

    biblioteca.processamentoAutomatico = false
    await biblioteca.registrar(titulo: "Única", pastaRelativa: Armazenamento.caminhoRelativo(id: UUID()), duracao: 60)
    let arquivo = try #require(biblioteca.arquivos.first)

    biblioteca.enfileirarProcessamento(arquivo)
    biblioteca.enfileirarProcessamento(arquivo)
    biblioteca.enfileirarProcessamento(arquivo)

    _ = await aguardar { !biblioteca.processando }
    #expect(!biblioteca.estaNaFila(arquivo))
}

@MainActor
@Test("Processamento automático desligado não enfileira ao registrar")
func automaticoDesligadoNaoEnfileira() async throws {
    let (biblioteca, raiz) = try bibliotecaDeTeste()
    defer { try? FileManager.default.removeItem(at: raiz) }

    biblioteca.processamentoAutomatico = false
    await biblioteca.registrar(titulo: "Pausada", pastaRelativa: Armazenamento.caminhoRelativo(id: UUID()), duracao: 60)

    let arquivo = try #require(biblioteca.arquivos.first)
    #expect(!biblioteca.processando)
    #expect(biblioteca.estado(de: arquivo) == .prontoParaTranscrever)
}

// MARK: - Estado

@MainActor
@Test("Estado de um arquivo recém-registrado é pronto para transcrever")
func estadoInicial() async throws {
    let (biblioteca, raiz) = try bibliotecaDeTeste()
    defer { try? FileManager.default.removeItem(at: raiz) }

    biblioteca.processamentoAutomatico = false
    await biblioteca.registrar(titulo: "Nova", pastaRelativa: Armazenamento.caminhoRelativo(id: UUID()), duracao: 30)
    let arquivo = try #require(biblioteca.arquivos.first)

    #expect(biblioteca.estado(de: arquivo) == .prontoParaTranscrever)
    #expect(!biblioteca.estado(de: arquivo).ocupado)
}

@MainActor
@Test("Falta de pesos vira estado de falha, não silêncio")
func faltaDePesosViraFalha() async throws {
    // A pasta de modelos está vazia: o `Preflight` reprova e o motivo precisa
    // chegar ao usuário como estado, não sumir.
    let (biblioteca, raiz) = try bibliotecaDeTeste()
    defer { try? FileManager.default.removeItem(at: raiz) }

    biblioteca.processamentoAutomatico = false
    await biblioteca.registrar(titulo: "Sem pesos", pastaRelativa: Armazenamento.caminhoRelativo(id: UUID()), duracao: 60)
    let arquivo = try #require(biblioteca.arquivos.first)

    biblioteca.enfileirarProcessamento(arquivo)
    _ = await aguardar { !biblioteca.processando }

    guard case .falhou = biblioteca.estado(de: arquivo) else {
        Issue.record("esperava .falhou, veio \(biblioteca.estado(de: arquivo))")
        return
    }
}

// MARK: - Lixeira e fila

@MainActor
@Test("Mover para a lixeira tira o arquivo da fila")
func lixeiraRemoveDaFila() async throws {
    let (biblioteca, raiz) = try bibliotecaDeTeste()
    defer { try? FileManager.default.removeItem(at: raiz) }

    biblioteca.processamentoAutomatico = false
    await biblioteca.registrar(titulo: "A", pastaRelativa: Armazenamento.caminhoRelativo(id: UUID()), duracao: 60)
    await biblioteca.registrar(titulo: "B", pastaRelativa: Armazenamento.caminhoRelativo(id: UUID()), duracao: 60)

    let primeira = try #require(biblioteca.arquivos.last)
    let segunda = try #require(biblioteca.arquivos.first)
    biblioteca.enfileirarProcessamento(primeira)
    biblioteca.enfileirarProcessamento(segunda)

    await biblioteca.moverParaLixeira(segunda)

    #expect(!biblioteca.estaNaFila(segunda))
    #expect(biblioteca.arquivosNaLixeira.contains { $0.id == segunda.id })
    _ = await aguardar { !biblioteca.processando }
}

@MainActor
@Test("Apagar definitivamente esquece as preferências visuais do arquivo")
func exclusaoLimpaPreferencias() async throws {
    // Sem isto, cada arquivo apagado deixava três chaves órfãs em UserDefaults
    // para sempre.
    let (biblioteca, raiz) = try bibliotecaDeTeste()
    defer { try? FileManager.default.removeItem(at: raiz) }

    biblioteca.processamentoAutomatico = false
    await biblioteca.registrar(titulo: "Com favorito", pastaRelativa: Armazenamento.caminhoRelativo(id: UUID()), duracao: 30)
    let arquivo = try #require(biblioteca.arquivos.first)

    // O caminho precisa ser o canonico `Gravacoes/<UUID>`: `apagar` recusa
    // qualquer outra coisa antes de remover, e a limpeza nunca aconteceria.
    PreferenciasVisuaisDoArquivo.definirFavorito(true, para: arquivo.id)
    PreferenciasVisuaisDoArquivo.definirPasta("Clientes", para: arquivo.id)
    #expect(PreferenciasVisuaisDoArquivo.favorito(arquivo.id))

    await biblioteca.moverParaLixeira(arquivo)
    let naLixeira = try #require(biblioteca.arquivosNaLixeira.first)
    await biblioteca.apagarDefinitivamente(naLixeira)

    #expect(!PreferenciasVisuaisDoArquivo.favorito(arquivo.id))
    #expect(PreferenciasVisuaisDoArquivo.pasta(arquivo.id) == nil)
}

@MainActor
@Test("Erro de carregamento fica visível em vez de sumir num dicionário")
func erroDeCarregamentoEhObservavel() async throws {
    let (biblioteca, raiz) = try bibliotecaDeTeste()
    defer { try? FileManager.default.removeItem(at: raiz) }

    await biblioteca.carregar()
    // Container em memória e vazio: carrega sem erro, e o campo precisa ficar
    // limpo em vez de guardar lixo de execuções anteriores.
    #expect(biblioteca.erroDeCarregamento == nil)
}
