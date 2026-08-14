import Foundation

/// Leva uma gravação de áudio bruto até `Arquivo` salvo: transcreve, agrupa em
/// trechos, resume e persiste.
///
/// Isto existia só dentro do `main.swift` da CLI — era por isso que gravar pelo
/// app não produzia transcrição nem resumo. Aqui vira código de biblioteca,
/// testável com motores falsos, e a interface só chama.
///
/// Recebe closures em vez dos protocolos `TranscriptionEngine`/
/// `SummarizationEngine` por dois motivos: a transcrição precisa do parâmetro
/// `speaker`, que não está no contrato do Passo 1, e a alternância de carga
/// entre os dois modelos é responsabilidade de `MotoresLocais`.
public struct PipelineDeArquivo: Sendable {
    public enum Fase: Sendable, Equatable {
        case transcrevendo
        case diarizando
        case resumindo
        case salvando

        public var descricao: String {
            switch self {
            case .transcrevendo: "transcrevendo…"
            case .diarizando: "distinguindo falantes…"
            case .resumindo: "resumindo…"
            case .salvando: "salvando…"
            }
        }
    }

    public typealias Transcrever = @Sendable (URL, String?) async throws -> [Trecho]
    public typealias Resumir = @Sendable ([Trecho]) async throws -> Resumo
    /// Diariza **um canal** de áudio e devolve quem falou quando.
    public typealias Diarizar = @Sendable (URL) async throws -> [SegmentoDeFalante]

    private let armazenamento: Armazenamento
    private let transcrever: Transcrever
    private let resumir: Resumir
    private let diarizar: Diarizar?
    private let repositorio: any ArquivoRepository
    private let idTranscricao: String
    private let idResumo: String

    public init(
        armazenamento: Armazenamento,
        repositorio: any ArquivoRepository,
        idTranscricao: String,
        idResumo: String,
        transcrever: @escaping Transcrever,
        resumir: @escaping Resumir,
        diarizar: Diarizar? = nil
    ) {
        self.armazenamento = armazenamento
        self.repositorio = repositorio
        self.idTranscricao = idTranscricao
        self.idResumo = idResumo
        self.transcrever = transcrever
        self.resumir = resumir
        self.diarizar = diarizar
    }

    /// Processa e salva. Devolve o `Arquivo` atualizado.
    ///
    /// Salva **duas vezes**: uma com a transcrição pronta e outra com o resumo.
    /// O resumo é a parte lenta (dezenas de segundos), e perder a transcrição
    /// porque o Qwen falhou seria jogar fora a parte cara que já deu certo.
    @discardableResult
    public func processar(
        _ arquivo: Arquivo,
        aoProgredir: @Sendable (Fase) -> Void = { _ in }
    ) async throws -> Arquivo {
        var atualizado = arquivo

        // Pontos de desistência entre as fases.
        //
        // O whisper e o Qwen são blocos síncronos e longos: uma vez dentro
        // deles, nada os interrompe. Verificar aqui é o que permite ao app
        // largar o trabalho assim que a fase corrente termina, em vez de
        // seguir resumindo uma conversa que a pessoa acabou de apagar.
        try Task.checkCancellation()

        aoProgredir(.transcrevendo)
        atualizado.trechos = try await transcrever(arquivo)
        atualizado.engineTranscricao = idTranscricao

        try Task.checkCancellation()

        // A diarização é decorativa e **nunca** decide o destino da gravação:
        // falha de modelo, de áudio ou de alinhamento não sobe — o `try?` por
        // canal vira "sem falante acústico", que é o estado de sempre antes
        // desta feature. Transcrição e resumo não podem ser jogados fora por
        // causa da diarização.
        aoProgredir(.diarizando)
        atualizado = await aplicarDiarizacao(atualizado)

        aoProgredir(.salvando)
        try await repositorio.salvar(atualizado)

        // Sem fala reconhecida não há o que resumir — e mandar transcrição
        // vazia para o Qwen produz um resumo inventado.
        guard !atualizado.trechos.isEmpty else { return atualizado }

        try Task.checkCancellation()

        aoProgredir(.resumindo)
        atualizado.resumo = try await resumir(atualizado.trechos)
        atualizado.engineResumo = idResumo

        aoProgredir(.salvando)
        try await repositorio.salvar(atualizado)
        return atualizado
    }

    // MARK: - Escolha do insumo

    /// Transcreve pelo caminho que preserva o falante.
    ///
    /// Os WAVs por canal são o único insumo que separa "eu" de "interlocutor":
    /// a atribuição vem do canal de origem, não de diarização (skill
    /// `papagaio-speaker-attribution`). O `.m4a` já é a mixagem dos dois, então
    /// só serve quando os `.pcm` não existem — arquivo importado, ou gravação
    /// de uma versão anterior.
    private func transcrever(_ arquivo: Arquivo) async throws -> [Trecho] {
        let canais = canaisSeparados(do: arquivo)
        let temMicrofone = canais.microfone != nil
        let temSistema = canais.sistema != nil

        if temMicrofone {
            let doMicrofone = try await transcrever(canais.microfone!, Speaker.eu)
            // O canal do sistema é acessório: se ele estiver corrompido — tap
            // que morreu no meio, arquivo só com cabeçalho — a conversa ainda
            // tem o microfone, que é o principal. Deixar o erro subir aqui
            // jogava fora uma gravação inteira por causa do canal secundário.
            var doSistema: [Trecho] = []
            if temSistema {
                doSistema = (try? await transcrever(canais.sistema!, Speaker.interlocutor)) ?? []
            }
            return Segmentacao.mesclarCanais(microfone: doMicrofone, sistema: doSistema)
        }

        let mixagem = Self.arquivoDeCanalUnico(em: armazenamento.resolver(relativo: arquivo.pastaRelativa))
        guard FileManager.default.fileExists(atPath: mixagem.path) else {
            throw ErroCaptura.arquivoInvalido("não há áudio em \(arquivo.pastaRelativa)")
        }
        // Canal único (mixagem legada ou importado): não dá para saber quem
        // falou. `nil` é honesto; inventar "eu" atribuiria as falas do
        // interlocutor ao usuário.
        return Segmentacao.agrupar(try await transcrever(mixagem, nil))
    }

    /// Diariza os canais separados e casa os falantes acústicos com as palavras.
    ///
    /// Nunca lança. Com canais separados, cada canal é diarizado no seu próprio
    /// áudio (a mixagem misturaria as vozes e o rótulo enganaria). **Sem canais
    /// separados** — importado ou gravação legada, que só têm a mixagem — a
    /// mixagem é o único insumo: diarizá-la perde o canal de origem (que já
    /// não existe no arquivo), mas separa as vozes acústicas, que é o que a
    /// interface de falas mostra. Canais sem conteúdo ou sem fala passam
    /// direto — palavras sem `falanteAcustico` são o estado normal.
    private func aplicarDiarizacao(_ arquivo: Arquivo) async -> Arquivo {
        guard let diarizar else { return arquivo }
        let canais = canaisSeparados(do: arquivo)

        let microfone: [SegmentoDeFalante]
        if let url = canais.microfone {
            microfone = (try? await diarizar(url)) ?? []
        } else {
            microfone = []
        }
        let sistema: [SegmentoDeFalante]
        if let url = canais.sistema {
            sistema = (try? await diarizar(url)) ?? []
        } else {
            sistema = []
        }
        let mixagem: [SegmentoDeFalante]
        if canais.microfone == nil, canais.sistema == nil {
            let url = Self.arquivoDeCanalUnico(em: armazenamento.resolver(relativo: arquivo.pastaRelativa))
            mixagem = (try? await diarizar(url)) ?? []
        } else {
            mixagem = []
        }

        guard !microfone.isEmpty || !sistema.isEmpty || !mixagem.isEmpty else { return arquivo }

        let trechos = arquivo.trechos.map { trecho -> Trecho in
            guard !trecho.palavras.isEmpty else { return trecho }
            let segmentos: [SegmentoDeFalante]
            if let speaker = trecho.speaker {
                segmentos = speaker == Speaker.eu ? microfone : sistema
            } else {
                // Sem canal de origem não há de onde escolher: as vozes da
                // mixagem são a única atribuição possível.
                segmentos = mixagem
            }
            guard !segmentos.isEmpty else { return trecho }
            return trecho.comPalavras(
                AlinhamentoDeFalantes.atribuir(palavras: trecho.palavras, a: segmentos)
            )
        }
        return Arquivo(
            id: arquivo.id,
            titulo: arquivo.titulo,
            criadoEm: arquivo.criadoEm,
            duracao: arquivo.duracao,
            pastaRelativa: arquivo.pastaRelativa,
            espaco: arquivo.espaco,
            trechos: trechos,
            notas: arquivo.notas,
            resumo: arquivo.resumo,
            engineTranscricao: arquivo.engineTranscricao,
            engineResumo: arquivo.engineResumo,
            apagadoEm: arquivo.apagadoEm
        )
    }

    /// Os caminhos dos canais separados com conteúdo, na convenção nova
    /// (`microfone.wav` + `sistema.m4a`) com fallback nos nomes legados.
    private func canaisSeparados(do arquivo: Arquivo) -> (microfone: URL?, sistema: URL?) {
        let pasta = armazenamento.resolver(relativo: arquivo.pastaRelativa)
        // Canais separados (nova convenção): `microfone.wav` + `sistema.m4a`.
        // Os nomes legados ficam na cadeia — wav do sistema, pcm, mixagem —
        // para a biblioteca existente continuar transcrevendo até sair.
        let microfone = Self.primeiroComConteudo(pasta, [
            Armazenamento.Nome.microfone,
            Armazenamento.Nome.wavMicrofone,
            Armazenamento.Nome.pcmMicrofone,
        ])
        let sistema = Self.primeiroComConteudo(pasta, [
            Armazenamento.Nome.sistema,
            Armazenamento.Nome.sistemaM4ALegado,
            Armazenamento.Nome.wavSistema,
            Armazenamento.Nome.pcmSistema,
        ])
        return (
            Self.temConteudo(microfone) ? microfone : nil,
            Self.temConteudo(sistema) ? sistema : nil
        )
    }

    private static func temConteudo(_ url: URL) -> Bool {
        guard let atributos = try? FileManager.default.attributesOfItem(atPath: url.path),
              let tamanho = atributos[.size] as? Int64
        else { return false }
        return tamanho > 0
    }

    /// Primeiro candidato que existe com conteúdo — a nova convenção primeiro,
    /// os legados como fallback natural.
    private static func primeiroComConteudo(_ pasta: URL, _ candidatos: [String]) -> URL {
        for nome in candidatos {
            let url = pasta.appendingPathComponent(nome)
            if temConteudo(url) { return url }
        }
        return pasta.appendingPathComponent(candidatos.last ?? "")
    }

    /// O arquivo único quando não há canais separados: a mixagem legada
    /// (`gravacao.m4a`) ou o importado copiado como veio (`gravacao.<ext>`).
    private static func arquivoDeCanalUnico(em pasta: URL) -> URL {
        let mixagem = pasta.appendingPathComponent(Armazenamento.Nome.mixagem)
        if temConteudo(mixagem) { return mixagem }
        let conteudo = (try? FileManager.default.contentsOfDirectory(
            at: pasta, includingPropertiesForKeys: nil
        )) ?? []
        if let importado = conteudo.first(where: {
            $0.lastPathComponent.hasPrefix(Armazenamento.Nome.prefixoImportado + ".")
        }) {
            return importado
        }
        return mixagem
    }
}
