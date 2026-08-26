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

@Test("Migração de remoção de equipes apaga o estado legado uma única vez")
func migracaoDeRemocaoDeEquipesLimpaSomenteEstadoLegado() throws {
    let suite = "MigracaoDeRemocaoDeEquipesTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }

    defaults.set(Data([1]), forKey: "membrosDaEquipe.primeira")
    defaults.set(Data([2]), forKey: "membrosDaEquipe.segunda")
    defaults.set(Data([3]), forKey: "equipesDoUsuario")
    defaults.set("primeira", forKey: "equipeAtiva")
    defaults.set("equipe", forKey: "contextoDaConta")
    defaults.set(true, forKey: "limpezaDeDadosFabricados.v1")
    defaults.set("permanece", forKey: "preferenciaSemRelacao")

    MigracaoDeRemocaoDeEquipes.executarUmaVez(defaults)

    #expect(defaults.object(forKey: "membrosDaEquipe.primeira") == nil)
    #expect(defaults.object(forKey: "membrosDaEquipe.segunda") == nil)
    #expect(defaults.object(forKey: "equipesDoUsuario") == nil)
    #expect(defaults.object(forKey: "equipeAtiva") == nil)
    #expect(defaults.object(forKey: "contextoDaConta") == nil)
    #expect(defaults.object(forKey: "limpezaDeDadosFabricados.v1") == nil)
    #expect(defaults.string(forKey: "preferenciaSemRelacao") == "permanece")

    // Depois de concluída, a migração não deve apagar preferências que uma
    // versão futura venha a gravar com o antigo prefixo por coincidência.
    defaults.set(Data([4]), forKey: "membrosDaEquipe.posterior")
    MigracaoDeRemocaoDeEquipes.executarUmaVez(defaults)
    #expect(defaults.data(forKey: "membrosDaEquipe.posterior") == Data([4]))
}

@Test("Migração de equipes reúne ativos e lixeira no espaço pessoal")
func migracaoDeEquipesPreservaBibliotecaCompleta() async throws {
    let repositorio = SwiftDataRepository(
        modelContainer: try SwiftDataRepository.containerLocal(
            nome: UUID().uuidString, emMemoria: true
        )
    )
    let pessoal = EspacoID()
    let equipe = EspacoID()
    let outroEspacoLegado = EspacoID()
    let ativoDaEquipe = Arquivo(
        titulo: "Reunião da equipe",
        pastaRelativa: Armazenamento.caminhoRelativo(id: UUID()),
        espaco: equipe
    )
    let naLixeira = Arquivo(
        titulo: "Conversa arquivada",
        pastaRelativa: Armazenamento.caminhoRelativo(id: UUID()),
        espaco: outroEspacoLegado
    )

    try await repositorio.salvar(ativoDaEquipe)
    try await repositorio.salvar(naLixeira)
    try await repositorio.moverParaLixeira(naLixeira.id)

    try await repositorio.migrarTodosOsEspacos(para: pessoal)

    #expect(try await repositorio.listar(espaco: pessoal).map(\.id) == [ativoDaEquipe.id])
    #expect(try await repositorio.listarNaLixeira(espaco: pessoal).map(\.id) == [naLixeira.id])
    #expect(try await repositorio.listar(espaco: equipe).isEmpty)
    #expect(try await repositorio.listarNaLixeira(espaco: outroEspacoLegado).isEmpty)
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
@Test("Duplicar recria os bookmarks dos anexos na pasta copiada")
func duplicacaoMantemAnexosVisiveisNaCopia() async throws {
    let (biblioteca, raiz) = try bibliotecaDeTeste()
    defer { try? FileManager.default.removeItem(at: raiz) }

    biblioteca.processamentoAutomatico = false
    let pastaOriginal = Armazenamento.caminhoRelativo(id: UUID())
    let original = try #require(
        await biblioteca.registrar(titulo: "Com anexo", pastaRelativa: pastaOriginal, duracao: 30)
    )
    defer { MidiasDaConversa.remover(original.id) }

    let raizOriginal = raiz.appendingPathComponent(pastaOriginal, isDirectory: true)
    let pastaDeAnexos = raizOriginal.appendingPathComponent("documentos", isDirectory: true)
    try FileManager.default.createDirectory(at: pastaDeAnexos, withIntermediateDirectories: true)
    let anexoOriginal = pastaDeAnexos.appendingPathComponent("roteiro.pdf")
    try Data("conteúdo".utf8).write(to: anexoOriginal)
    try MidiasDaConversa.salvar(
        [try MidiasDaConversa.anexo(para: anexoOriginal)],
        para: original.id
    )

    let copia = try #require(await biblioteca.duplicar(original))
    defer { MidiasDaConversa.remover(copia.id) }

    let anexosDaCopia = MidiasDaConversa.carregar(copia.id)
    let esperado = raiz
        .appendingPathComponent(copia.pastaRelativa, isDirectory: true)
        .appendingPathComponent("documentos/roteiro.pdf")
        .standardizedFileURL
    #expect(anexosDaCopia.map(\.url.standardizedFileURL) == [esperado])
    #expect(FileManager.default.fileExists(atPath: esperado.path))
}

@MainActor
@Test("Duplicar preserva o estado das tarefas com novos ids")
func duplicacaoMantemTarefasIndependentes() async throws {
    let (biblioteca, raiz) = try bibliotecaDeTeste()
    defer { try? FileManager.default.removeItem(at: raiz) }

    biblioteca.processamentoAutomatico = false
    let original = try #require(
        await biblioteca.registrar(
            titulo: "Com tarefas",
            pastaRelativa: Armazenamento.caminhoRelativo(id: UUID()),
            duracao: 30
        )
    )
    defer { TarefasGeraisStore.remover(original.id) }

    let prazo = Date(timeIntervalSinceReferenceDate: 12_345)
    let tarefaOriginal = TarefaDaConversa(
        titulo: "Enviar ata",
        origem: original.titulo,
        prioridade: .alta,
        status: .emAndamento,
        responsavel: "Ana",
        prazo: prazo,
        descricao: "Incluir os encaminhamentos."
    )
    TarefasGeraisStore.salvar([tarefaOriginal], para: original.id)

    let copia = try #require(await biblioteca.duplicar(original))
    defer { TarefasGeraisStore.remover(copia.id) }

    let tarefasDaCopia = TarefasGeraisStore.carregar(copia)
    #expect(tarefasDaCopia.count == 1)
    let tarefaDaCopia = try #require(tarefasDaCopia.first)
    #expect(tarefaDaCopia.id != tarefaOriginal.id)
    #expect(tarefaDaCopia.titulo == tarefaOriginal.titulo)
    #expect(tarefaDaCopia.origem == copia.titulo)
    #expect(tarefaDaCopia.prioridade == tarefaOriginal.prioridade)
    #expect(tarefaDaCopia.status == tarefaOriginal.status)
    #expect(tarefaDaCopia.responsavel == tarefaOriginal.responsavel)
    #expect(tarefaDaCopia.prazo == prazo)
    #expect(tarefaDaCopia.descricao == tarefaOriginal.descricao)
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

@MainActor
@Test("Excluir a conta limpa todos os stores locais sem apagar preferências globais")
func exclusaoDaContaLimpaStoresLocais() throws {
    let suite = "LimpezaDeContaTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }

    let chavesDaConta = [
        "tarefasDaConversa.arquivo", "midiasDaConversa.arquivo",
        "arquivoFavorito.id", "arquivoPasta.id", "arquivoCapa.id",
        "arquivoMetadados.id", "arquivoNomesDeVoz.id", "pastasDaBiblioteca",
        "corDaFaixaDoCartao.id", "bannerDoCartao.id", "ajusteDoBannerDoCartao.id",
        "faixaSemCorDoCartao.id", "corDaPasta.Cliente", "capaDaPasta.Cliente",
        "ajusteDaCapaDaPasta.Cliente", "pastaFavorita.Cliente",
        "pastaCriadaEm.Cliente", "corLivreDaPasta.Cliente", "pastaSemCor.Cliente",
        "fotoDaPessoa.ana", "midiaNaLixeira", "tarefasNaLixeira",
        "pastasNaLixeira", "espacoIndividual",
    ]
    for chave in chavesDaConta { defaults.set(Data([1]), forKey: chave) }

    defaults.set("escuro", forKey: "aparenciaDoApp")
    defaults.set(false, forKey: "processamentoAutomatico")

    LimpezaDeConta.executar(em: defaults)

    for chave in chavesDaConta {
        #expect(defaults.object(forKey: chave) == nil, "sobrou \(chave)")
    }
    #expect(defaults.string(forKey: "aparenciaDoApp") == "escuro")
    #expect(defaults.object(forKey: "processamentoAutomatico") != nil)
}

@MainActor
@Test("Excluir a conta não apaga a mídia de outro espaço")
func exclusaoDaContaPreservaMidiaDeOutroEspaco() async throws {
    let raiz = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: raiz, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: raiz) }

    let armazenamento = Armazenamento(raiz: raiz)
    let repositorio = SwiftDataRepository(
        modelContainer: try SwiftDataRepository.containerLocal(
            nome: UUID().uuidString, emMemoria: true
        )
    )
    let espacoAtual = EspacoID()
    let outroEspaco = EspacoID()
    let bibliotecaAtual = Biblioteca(
        armazenamento: armazenamento, repositorio: repositorio, espaco: espacoAtual
    )
    let bibliotecaDoOutroEspaco = Biblioteca(
        armazenamento: armazenamento, repositorio: repositorio, espaco: outroEspaco
    )
    bibliotecaAtual.processamentoAutomatico = false
    bibliotecaDoOutroEspaco.processamentoAutomatico = false

    let pastaAtual = Armazenamento.caminhoRelativo(id: UUID())
    let pastaDoOutroEspaco = Armazenamento.caminhoRelativo(id: UUID())
    let arquivoAtual = try #require(
        await bibliotecaAtual.registrar(titulo: "Minha conversa", pastaRelativa: pastaAtual, duracao: 30)
    )
    let arquivoDoOutroEspaco = try #require(
        await bibliotecaDoOutroEspaco.registrar(
            titulo: "Conversa da outra conta", pastaRelativa: pastaDoOutroEspaco, duracao: 30
        )
    )
    try FileManager.default.createDirectory(
        at: armazenamento.resolver(relativo: arquivoAtual.pastaRelativa),
        withIntermediateDirectories: true
    )
    let audioDoOutroEspaco = armazenamento
        .resolver(relativo: arquivoDoOutroEspaco.pastaRelativa)
        .appendingPathComponent(Armazenamento.Nome.microfone)
    try FileManager.default.createDirectory(
        at: audioDoOutroEspaco.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try Data("preservar".utf8).write(to: audioDoOutroEspaco)

    try await bibliotecaAtual.excluirDadosDaConta()

    #expect(bibliotecaAtual.arquivos.isEmpty)
    #expect(FileManager.default.fileExists(atPath: audioDoOutroEspaco.path))
    #expect(try await repositorio.listar(espaco: outroEspaco).map(\.id) == [arquivoDoOutroEspaco.id])
}

@MainActor
@Test("Excluir uma conversa limpa só os dados auxiliares daquele arquivo")
func exclusaoDeArquivoLimpaSomenteSeuEstado() throws {
    let suite = "LimpezaDeArquivoTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }

    let alvo = ArquivoID()
    let outro = ArquivoID()
    let sufixo = alvo.rawValue.uuidString
    let sufixoDoOutro = outro.rawValue.uuidString
    let chavesDoAlvo = [
        "tarefasDaConversa.\(sufixo)", "midiasDaConversa.\(sufixo)",
        "arquivoFavorito.\(sufixo)", "arquivoPasta.\(sufixo)",
        "arquivoCapa.\(sufixo)", "arquivoMetadados.\(sufixo)",
        "arquivoNomesDeVoz.\(sufixo)", "corDaFaixaDoCartao.\(sufixo)",
        "bannerDoCartao.\(sufixo)", "ajusteDoBannerDoCartao.\(sufixo)",
        "faixaSemCorDoCartao.\(sufixo)",
    ]
    for chave in chavesDoAlvo { defaults.set(Data([1]), forKey: chave) }
    defaults.set(Data([2]), forKey: "tarefasDaConversa.\(sufixoDoOutro)")

    let tarefa = TarefaDaConversa(
        titulo: "Revisar", origem: "Conversa", prioridade: .media,
        status: .naoIniciado, responsavel: nil, prazo: nil
    )
    let tarefasNaLixeira = [
        TarefaNaLixeira(arquivoID: alvo, conversaTitulo: "Alvo", tarefa: tarefa),
        TarefaNaLixeira(arquivoID: outro, conversaTitulo: "Outra", tarefa: tarefa),
    ]
    defaults.set(try JSONEncoder().encode(tarefasNaLixeira), forKey: "tarefasNaLixeira")

    let midiasNaLixeira = [
        MidiaNaLixeira(
            arquivoID: alvo, conversaTitulo: "Alvo", nome: "a.wav", tamanho: 1,
            tipo: "Áudio", daGravacao: false, caminhoOriginal: "/a", caminhoNaLixeira: "/b"
        ),
        MidiaNaLixeira(
            arquivoID: outro, conversaTitulo: "Outra", nome: "b.wav", tamanho: 1,
            tipo: "Áudio", daGravacao: false, caminhoOriginal: "/c", caminhoNaLixeira: "/d"
        ),
    ]
    defaults.set(try JSONEncoder().encode(midiasNaLixeira), forKey: "midiaNaLixeira")

    let estado = AparenciaDasPastas.Estado(
        preset: nil, corLivre: nil, favorita: false, semCor: nil,
        criadaEm: nil, capa: nil
    )
    let pastasNaLixeira = [
        PastaNaLixeira(nome: "Cliente", conversas: [alvo.rawValue, outro.rawValue], aparencia: estado),
    ]
    defaults.set(try JSONEncoder().encode(pastasNaLixeira), forKey: "pastasNaLixeira")

    LimpezaDeArquivo.executar(alvo, em: defaults)

    for chave in chavesDoAlvo {
        #expect(defaults.object(forKey: chave) == nil, "sobrou \(chave)")
    }
    #expect(defaults.data(forKey: "tarefasDaConversa.\(sufixoDoOutro)") == Data([2]))
    #expect(try JSONDecoder().decode([TarefaNaLixeira].self, from: #require(defaults.data(forKey: "tarefasNaLixeira"))).map(\.arquivoID) == [outro])
    #expect(try JSONDecoder().decode([MidiaNaLixeira].self, from: #require(defaults.data(forKey: "midiaNaLixeira"))).map(\.arquivoID) == [outro])
    #expect(try JSONDecoder().decode([PastaNaLixeira].self, from: #require(defaults.data(forKey: "pastasNaLixeira"))).first?.conversas == [outro.rawValue])
}

@Test("Apagar anexo não aceita pasta irmã com o mesmo prefixo")
func apagarAnexoRecusaPastaIrma() throws {
    let raiz = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let conversa = raiz.appendingPathComponent("Conversa", isDirectory: true)
    let irma = raiz.appendingPathComponent("Conversa-antiga", isDirectory: true)
    try FileManager.default.createDirectory(at: conversa, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: irma, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: raiz) }

    let externo = irma.appendingPathComponent("nao-apagar.txt")
    try Data("preservar".utf8).write(to: externo)
    let anexo = AnexoDeMidiaDaConversa(
        id: UUID(), nome: externo.lastPathComponent, tamanho: 9,
        data: Date(), url: externo
    )

    #expect(throws: MidiasDaConversa.Erro.arquivoForaDaConversa) {
        try MidiasDaConversa.apagarArquivoSalvo(anexo, pastaDaConversa: conversa)
    }
    #expect(FileManager.default.fileExists(atPath: externo.path))
}

@Test("Apagar anexo remove arquivo realmente contido na conversa")
func apagarAnexoInterno() throws {
    let raiz = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let conversa = raiz.appendingPathComponent("Conversa", isDirectory: true)
    let midia = conversa.appendingPathComponent("Mídia", isDirectory: true)
    try FileManager.default.createDirectory(at: midia, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: raiz) }

    let interno = midia.appendingPathComponent("apagar.txt")
    try Data("apagar".utf8).write(to: interno)
    let anexo = AnexoDeMidiaDaConversa(
        id: UUID(), nome: interno.lastPathComponent, tamanho: 6,
        data: Date(), url: interno
    )

    try MidiasDaConversa.apagarArquivoSalvo(anexo, pastaDaConversa: conversa)

    #expect(!FileManager.default.fileExists(atPath: interno.path))
}

@Test("Exportar conversas com o mesmo título cria pastas distintas e completas")
func exportacaoNaoMisturaTitulosIguais() throws {
    let origem = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: origem, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: origem) }

    var conversas: [(arquivo: Arquivo, audio: URL)] = []
    for indice in 1...2 {
        let pasta = origem.appendingPathComponent("origem-\(indice)", isDirectory: true)
        try FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)
        let audio = pasta.appendingPathComponent(Armazenamento.Nome.microfone)
        try Data("audio-\(indice)".utf8).write(to: audio)
        conversas.append((
            Arquivo(
                titulo: "Entrevista repetida",
                pastaRelativa: Armazenamento.caminhoRelativo(id: UUID()),
                espaco: EspacoID()
            ),
            audio
        ))
    }

    let exportada = try DossieDaConversa.pastaComTudo(
        nome: "Cliente/Projeto", conversas: conversas
    )

    #expect(exportada.lastPathComponent == "Cliente-Projeto")
    let pastas = try FileManager.default.contentsOfDirectory(
        at: exportada, includingPropertiesForKeys: [.isDirectoryKey]
    ).filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
    #expect(pastas.count == 2)
    #expect(Set(pastas.map(\.lastPathComponent)).count == 2)
    for pasta in pastas {
        let itens = try FileManager.default.contentsOfDirectory(atPath: pasta.path)
        #expect(itens.contains(Armazenamento.Nome.microfone))
        #expect(itens.contains("entrevista-repetida.md"))
    }

    let raizTemporaria = exportada.deletingLastPathComponent()
    DossieDaConversa.descartarPastaTemporaria(exportada)
    #expect(!FileManager.default.fileExists(atPath: raizTemporaria.path))
}

@Test("Exportar uma conversa descarta a pasta intermediária após criar o zip")
func pacoteDaConversaNaoAcumulaPastaIntermediaria() throws {
    let fm = FileManager.default
    let origem = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: origem, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: origem) }

    let audio = origem.appendingPathComponent(Armazenamento.Nome.microfone)
    try Data("audio".utf8).write(to: audio)
    let arquivo = Arquivo(
        titulo: "Pacote temporário \(UUID().uuidString)",
        pastaRelativa: Armazenamento.caminhoRelativo(id: UUID()),
        espaco: EspacoID()
    )
    let base = DossieDaConversa.nomeDeArquivo(para: arquivo).replacingOccurrences(of: ".md", with: "")

    let pacote = try DossieDaConversa.pacoteComAudio(arquivo: arquivo, audioPrincipal: audio)

    let intermediarias = try fm.contentsOfDirectory(
        at: fm.temporaryDirectory,
        includingPropertiesForKeys: [.isDirectoryKey]
    ).filter { url in
        url.lastPathComponent.hasPrefix("\(base)-")
            && (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }
    #expect(intermediarias.isEmpty)
    #expect(fm.fileExists(atPath: pacote.path))

    let raizDoPacote = pacote.deletingLastPathComponent()
    DossieDaConversa.descartarArquivoTemporario(pacote)
    #expect(!fm.fileExists(atPath: raizDoPacote.path))
}

@Test("Compactar pasta mantém o nome do pacote e permite limpar o temporário")
func zipDaPastaMantemNomeELimpeza() throws {
    let fm = FileManager.default
    let pasta = fm.temporaryDirectory
        .appendingPathComponent("Projeto-\(UUID().uuidString)", isDirectory: true)
    try fm.createDirectory(at: pasta, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: pasta) }
    try Data("conteúdo".utf8).write(to: pasta.appendingPathComponent("nota.txt"))

    let zip = try DossieDaConversa.zipar(pasta)

    #expect(zip.lastPathComponent == "\(pasta.lastPathComponent).zip")
    #expect(fm.fileExists(atPath: zip.path))

    let raizDoZip = zip.deletingLastPathComponent()
    DossieDaConversa.descartarArquivoTemporario(zip)
    #expect(!fm.fileExists(atPath: raizDoZip.path))
}

@Test("Fallback Markdown usa raiz temporária exclusiva e removível")
func markdownTemporarioTemCicloDeVidaSeguro() throws {
    let fm = FileManager.default
    let arquivo = Arquivo(
        titulo: "Fallback \(UUID().uuidString)",
        pastaRelativa: Armazenamento.caminhoRelativo(id: UUID()),
        espaco: EspacoID()
    )

    let markdown = try DossieDaConversa.markdownTemporario(arquivo: arquivo)

    #expect(markdown.lastPathComponent == DossieDaConversa.nomeDeArquivo(para: arquivo))
    #expect(fm.fileExists(atPath: markdown.path))

    let raiz = markdown.deletingLastPathComponent()
    DossieDaConversa.descartarArquivoTemporario(markdown)
    #expect(!fm.fileExists(atPath: raiz.path))
}
