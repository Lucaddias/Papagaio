import Foundation
import Synchronization
import Testing
@testable import PapagaioCore

// Testes do pipeline que liga gravação → transcrição → resumo → persistência.
// Motores falsos: o que está sob teste é a orquestração (qual insumo, em que
// ordem, o que é salvo quando), não a qualidade do Whisper ou do Qwen — isso já
// tem teste próprio nas suítes com modelo.

/// Repositório de mentira que registra cada `salvar`, para provar que a
/// transcrição é persistida **antes** do resumo começar.
private actor RepositorioEspiao: ArquivoRepository {
    private(set) var salvos: [Arquivo] = []

    func salvar(_ a: Arquivo) async throws { salvos.append(a) }
    func buscar(termo: String) async throws -> [Arquivo] { [] }
    func listar(espaco: EspacoID) async throws -> [Arquivo] { salvos }
    func apagar(_ id: ArquivoID) async throws {}
}

private func montarGravacao(
    microfone: Bool,
    sistema: Bool,
    mixagem: Bool
) throws -> (Armazenamento, Arquivo) {
    let raiz = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let armazenamento = Armazenamento(raiz: raiz)
    let id = UUID()
    let pasta = try armazenamento.criarPastaDaGravacao(id: id)

    // Conteúdo irrelevante: os motores são falsos. Só o *tamanho* importa —
    // é como o pipeline decide se o canal existe.
    let bytes = Data(repeating: 0, count: 64)
    if microfone {
        try bytes.write(to: pasta.appendingPathComponent(Armazenamento.Nome.pcmMicrofone))
    }
    if sistema {
        try bytes.write(to: pasta.appendingPathComponent(Armazenamento.Nome.pcmSistema))
    }
    if mixagem {
        try bytes.write(to: pasta.appendingPathComponent(Armazenamento.Nome.mixagem))
    }

    let arquivo = Arquivo(
        titulo: "Reunião",
        pastaRelativa: Armazenamento.caminhoRelativo(id: id),
        espaco: EspacoID()
    )
    return (armazenamento, arquivo)
}

private let resumoDeMentira = Resumo(
    titulo: "Resumo", visaoGeral: "visão", temas: [Tema(titulo: "t", detalhe: "d")]
)

@Test("Gravação com dois canais separa 'eu' de 'interlocutor'")
func pipelineMesclaOsCanais() async throws {
    let (armazenamento, arquivo) = try montarGravacao(
        microfone: true, sistema: true, mixagem: true
    )
    defer { try? FileManager.default.removeItem(at: armazenamento.raiz) }

    let repositorio = RepositorioEspiao()
    let pipeline = PipelineDeArquivo(
        armazenamento: armazenamento,
        repositorio: repositorio,
        idTranscricao: "whisper-falso",
        idResumo: "qwen-falso",
        transcrever: { url, speaker in
            // O speaker recebido é o do canal; o texto identifica a origem.
            let doMicrofone = url.lastPathComponent == Armazenamento.Nome.pcmMicrofone
            #expect(speaker == (doMicrofone ? Speaker.eu : Speaker.interlocutor))
            return doMicrofone
                ? [Trecho(start: 0, end: 3, texto: "oi")]
                : [Trecho(start: 4, end: 7, texto: "tudo bem")]
        },
        resumir: { _ in resumoDeMentira }
    )

    let final = try await pipeline.processar(arquivo)

    #expect(final.trechos.count == 2)
    #expect(final.trechos[0].speaker == Speaker.eu)
    #expect(final.trechos[1].speaker == Speaker.interlocutor)
    #expect(final.trechos[0].start < final.trechos[1].start)
    #expect(final.engineTranscricao == "whisper-falso")
    #expect(final.engineResumo == "qwen-falso")
    #expect(final.resumo?.titulo == "Resumo")
}

@Test("Arquivo importado (só mixagem) transcreve sem inventar falante")
func pipelineUsaMixagemQuandoNaoHaCanais() async throws {
    let (armazenamento, arquivo) = try montarGravacao(
        microfone: false, sistema: false, mixagem: true
    )
    defer { try? FileManager.default.removeItem(at: armazenamento.raiz) }

    let pipeline = PipelineDeArquivo(
        armazenamento: armazenamento,
        repositorio: RepositorioEspiao(),
        idTranscricao: "w", idResumo: "q",
        transcrever: { url, speaker in
            #expect(url.lastPathComponent == Armazenamento.Nome.mixagem)
            #expect(speaker == nil, "mixagem não permite atribuir falante")
            return [Trecho(start: 0, end: 2, texto: "conteúdo")]
        },
        resumir: { _ in resumoDeMentira }
    )

    let final = try await pipeline.processar(arquivo)
    #expect(final.trechos.count == 1)
    #expect(final.trechos[0].speaker == nil)
}

@Test("A transcrição é salva antes de o resumo começar")
func pipelineSalvaAntesDeResumir() async throws {
    let (armazenamento, arquivo) = try montarGravacao(
        microfone: true, sistema: false, mixagem: true
    )
    defer { try? FileManager.default.removeItem(at: armazenamento.raiz) }

    let repositorio = RepositorioEspiao()
    let fases = Mutex<[PipelineDeArquivo.Fase]>([])

    let pipeline = PipelineDeArquivo(
        armazenamento: armazenamento,
        repositorio: repositorio,
        idTranscricao: "w", idResumo: "q",
        transcrever: { _, _ in [Trecho(start: 0, end: 2, texto: "oi")] },
        resumir: { _ in
            // Neste ponto a transcrição já tem de estar no disco: se o resumo
            // falhar, o trabalho caro não pode ser perdido.
            let salvos = await repositorio.salvos
            #expect(salvos.count == 1)
            #expect(salvos[0].trechos.count == 1)
            #expect(salvos[0].resumo == nil)
            return resumoDeMentira
        }
    )

    try await pipeline.processar(arquivo) { fase in
        fases.withLock { $0.append(fase) }
    }

    let salvos = await repositorio.salvos
    #expect(salvos.count == 2)
    #expect(salvos[1].resumo != nil)
    #expect(fases.withLock { $0 } == [.transcrevendo, .salvando, .resumindo, .salvando])
}

@Test("Silêncio total não vira resumo inventado")
func pipelineNaoResumeTranscricaoVazia() async throws {
    let (armazenamento, arquivo) = try montarGravacao(
        microfone: true, sistema: false, mixagem: true
    )
    defer { try? FileManager.default.removeItem(at: armazenamento.raiz) }

    let chamouResumo = Mutex(false)
    let pipeline = PipelineDeArquivo(
        armazenamento: armazenamento,
        repositorio: RepositorioEspiao(),
        idTranscricao: "w", idResumo: "q",
        transcrever: { _, _ in [] },
        resumir: { _ in
            chamouResumo.withLock { $0 = true }
            return resumoDeMentira
        }
    )

    let final = try await pipeline.processar(arquivo)
    #expect(final.trechos.isEmpty)
    #expect(final.resumo == nil)
    #expect(chamouResumo.withLock { $0 } == false)
}

@Test("Áudio ausente falha com mensagem que diz qual gravação")
func pipelineFalhaSemAudio() async throws {
    let (armazenamento, arquivo) = try montarGravacao(
        microfone: false, sistema: false, mixagem: false
    )
    defer { try? FileManager.default.removeItem(at: armazenamento.raiz) }

    let pipeline = PipelineDeArquivo(
        armazenamento: armazenamento,
        repositorio: RepositorioEspiao(),
        idTranscricao: "w", idResumo: "q",
        transcrever: { _, _ in [] },
        resumir: { _ in resumoDeMentira }
    )

    await #expect(throws: ErroCaptura.self) {
        try await pipeline.processar(arquivo)
    }
}
