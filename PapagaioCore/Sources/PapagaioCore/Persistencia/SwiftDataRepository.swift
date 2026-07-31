import Foundation
import SwiftData

/// Espaço individual, local. Sem CloudKit: `cloudKitDatabase: .none`.
///
/// O espaço de equipe é outro store (`CloudKitRepository`, Passo 13) atrás do
/// mesmo protocolo — SwiftData com CloudKit suporta só a private database, sem
/// `CKShare`, então não dá para usar um só (D-0.3).
///
/// `@ModelActor` porque `ModelContext` não é `Sendable`: o ator garante que
/// todo acesso ao contexto acontece numa mesma fila.
@ModelActor
public actor SwiftDataRepository: ArquivoRepository {
    /// Container local, com o schema completo do app.
    public static func containerLocal(
        nome: String = "Papagaio",
        emMemoria: Bool = false
    ) throws -> ModelContainer {
        let schema = Schema([
            ArquivoPersistido.self,
            TrechoPersistido.self,
            InsightPersistido.self,
            EspacoPersistido.self,
        ])
        let configuracao = ModelConfiguration(
            nome,
            schema: schema,
            isStoredInMemoryOnly: emMemoria,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuracao])
    }

    // MARK: - ArquivoRepository

    public func salvar(_ a: Arquivo) async throws {
        let existente = try buscarPersistido(id: a.id)
        let persistido = existente ?? ArquivoPersistido(id: a.id.rawValue)

        persistido.titulo = a.titulo
        persistido.criadoEm = a.criadoEm
        persistido.duracao = a.duracao
        persistido.pastaRelativa = a.pastaRelativa
        persistido.engineTranscricao = a.engineTranscricao
        persistido.engineResumo = a.engineResumo
        persistido.temResumo = a.resumo != nil
        persistido.resumoTitulo = a.resumo?.titulo ?? ""
        persistido.resumoVisaoGeral = a.resumo?.visaoGeral ?? ""
        persistido.espaco = try espacoPersistido(a.espaco)

        if existente == nil { modelContext.insert(persistido) }

        // Trechos e insights são reescritos por inteiro: são derivados da
        // transcrição e do resumo, e reconciliar item a item custaria mais que
        // regravar.
        for antigo in persistido.trechos ?? [] { modelContext.delete(antigo) }
        for antigo in persistido.insights ?? [] { modelContext.delete(antigo) }
        persistido.trechos = []
        persistido.insights = []

        for trecho in a.trechos {
            let t = TrechoPersistido(id: trecho.id)
            t.start = trecho.start
            t.fim = trecho.end
            t.texto = trecho.texto
            t.speaker = trecho.speaker
            t.arquivo = persistido
            modelContext.insert(t)
        }

        if let resumo = a.resumo {
            inserirInsights(de: resumo, em: persistido)
        }

        try modelContext.save()
    }

    /// Busca com **prioridade de título**.
    ///
    /// Duas consultas, não uma com ordenação: quem procura "orçamento" e tem um
    /// arquivo chamado "Orçamento Q3" quer *aquele* primeiro, mesmo que outros
    /// dez mencionem a palavra no corpo. Ordenar por relevância calculada daria
    /// o mesmo resultado com muito mais código.
    ///
    /// `localizedStandardContains` é o que faz "orcamento" achar "Orçamento":
    /// ignora caixa **e** diacrítico. Um `contains` simples não acha.
    ///
    /// A assinatura precisa sobreviver a uma eventual migração para FTS5 sem
    /// mudar — por isso o retorno é `[Arquivo]` puro, sem tipo de score.
    public func buscar(termo: String) async throws -> [Arquivo] {
        let limpo = termo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpo.isEmpty else { return [] }

        let ordem = [SortDescriptor(\ArquivoPersistido.criadoEm, order: .reverse)]

        // Bucket A — o termo está no título.
        var porTitulo = FetchDescriptor<ArquivoPersistido>(
            predicate: #Predicate { $0.titulo.localizedStandardContains(limpo) },
            sortBy: ordem
        )
        porTitulo.relationshipKeyPathsForPrefetching = [\.trechos, \.insights]
        let bucketA = try modelContext.fetch(porTitulo)
        let idsDoTitulo = Set(bucketA.map(\.id))

        // Bucket B — o termo está no corpo: visão geral, trecho ou insight.
        //
        // Três consultas separadas, unidas depois. Um `#Predicate` único com as
        // três condições em `||` (duas delas sobre relação) **não compila**:
        // "the compiler is unable to type-check this expression in reasonable
        // time". Separar é mais rápido de compilar e mais fácil de ler.
        var porCorpo: [ArquivoPersistido] = []
        var jaVistos = idsDoTitulo

        func acrescentar(_ encontrados: [ArquivoPersistido]) {
            for arquivo in encontrados where !jaVistos.contains(arquivo.id) {
                jaVistos.insert(arquivo.id)
                porCorpo.append(arquivo)
            }
        }

        var porVisaoGeral = FetchDescriptor<ArquivoPersistido>(
            predicate: #Predicate { $0.resumoVisaoGeral.localizedStandardContains(limpo) },
            sortBy: ordem
        )
        porVisaoGeral.relationshipKeyPathsForPrefetching = [\.trechos, \.insights]
        acrescentar(try modelContext.fetch(porVisaoGeral))

        let porTrecho = FetchDescriptor<TrechoPersistido>(
            predicate: #Predicate { $0.texto.localizedStandardContains(limpo) }
        )
        acrescentar(try modelContext.fetch(porTrecho).compactMap(\.arquivo))

        let porInsight = FetchDescriptor<InsightPersistido>(
            predicate: #Predicate { $0.texto.localizedStandardContains(limpo) }
        )
        acrescentar(try modelContext.fetch(porInsight).compactMap(\.arquivo))

        porCorpo.sort { $0.criadoEm > $1.criadoEm }
        return (bucketA + porCorpo).map(Self.paraDominio)
    }

    public func listar(espaco: EspacoID) async throws -> [Arquivo] {
        let alvo = espaco.rawValue
        var descritor = FetchDescriptor<ArquivoPersistido>(
            predicate: #Predicate { $0.espaco?.id == alvo },
            sortBy: [SortDescriptor(\.criadoEm, order: .reverse)]
        )
        descritor.relationshipKeyPathsForPrefetching = [\.trechos, \.insights]
        return try modelContext.fetch(descritor).map(Self.paraDominio)
    }

    /// Apaga o registro **e os arquivos em disco**.
    ///
    /// Critério de aceite do Passo 8: apagar um arquivo apaga também o `.m4a`.
    /// Deixar o áudio órfão no container é vazamento de disco que o usuário não
    /// tem como limpar.
    public func apagar(_ id: ArquivoID) async throws {
        guard let persistido = try buscarPersistido(id: id) else { return }

        let relativo = persistido.pastaRelativa
        modelContext.delete(persistido)
        try modelContext.save()

        if !relativo.isEmpty, let armazenamento = try? Armazenamento.padrao() {
            try? FileManager.default.removeItem(at: armazenamento.resolver(relativo: relativo))
        }
    }

    // MARK: - Apoio

    private func buscarPersistido(id: ArquivoID) throws -> ArquivoPersistido? {
        let alvo = id.rawValue
        let descritor = FetchDescriptor<ArquivoPersistido>(
            predicate: #Predicate { $0.id == alvo }
        )
        return try modelContext.fetch(descritor).first
    }

    private func espacoPersistido(_ id: EspacoID) throws -> EspacoPersistido {
        let alvo = id.rawValue
        let descritor = FetchDescriptor<EspacoPersistido>(
            predicate: #Predicate { $0.id == alvo }
        )
        if let existente = try modelContext.fetch(descritor).first { return existente }

        let novo = EspacoPersistido(id: alvo, nome: "Meu espaço")
        modelContext.insert(novo)
        return novo
    }

    private func inserirInsights(de resumo: Resumo, em arquivo: ArquivoPersistido) {
        var ordem = 0
        func inserir(_ tipo: String, texto: String, detalhe: String? = nil,
                     start: TimeInterval? = nil, speaker: String? = nil) {
            let insight = InsightPersistido()
            insight.tipo = tipo
            insight.texto = texto
            insight.detalhe = detalhe
            insight.start = start
            insight.speaker = speaker
            insight.ordem = ordem
            insight.arquivo = arquivo
            modelContext.insert(insight)
            ordem += 1
        }

        for tema in resumo.temas {
            inserir(TipoDeInsight.tema, texto: tema.titulo, detalhe: tema.detalhe)
        }
        for citacao in resumo.citacoes {
            inserir(TipoDeInsight.citacao, texto: citacao.texto,
                    start: citacao.start, speaker: citacao.speaker)
        }
        for passo in resumo.proximosPassos {
            inserir(TipoDeInsight.proximoPasso, texto: passo.descricao,
                    detalhe: passo.responsavel)
        }
    }

    // MARK: - Mapeamento para o domínio

    static func paraDominio(_ p: ArquivoPersistido) -> Arquivo {
        let trechos = (p.trechos ?? [])
            .sorted { $0.start < $1.start }
            .map { Trecho(id: $0.id, start: $0.start, end: $0.fim,
                          texto: $0.texto, speaker: $0.speaker) }

        let insights = (p.insights ?? []).sorted { $0.ordem < $1.ordem }
        var resumo: Resumo?
        if p.temResumo {
            resumo = Resumo(
                titulo: p.resumoTitulo,
                visaoGeral: p.resumoVisaoGeral,
                temas: insights.filter { $0.tipo == TipoDeInsight.tema }
                    .map { Tema(titulo: $0.texto, detalhe: $0.detalhe ?? "") },
                citacoes: insights.filter { $0.tipo == TipoDeInsight.citacao }
                    .map { Citacao(texto: $0.texto, speaker: $0.speaker, start: $0.start) },
                proximosPassos: insights.filter { $0.tipo == TipoDeInsight.proximoPasso }
                    .map { ProximoPasso(descricao: $0.texto, responsavel: $0.detalhe) }
            )
        }

        return Arquivo(
            id: ArquivoID(rawValue: p.id),
            titulo: p.titulo,
            criadoEm: p.criadoEm,
            duracao: p.duracao,
            pastaRelativa: p.pastaRelativa,
            espaco: EspacoID(rawValue: p.espaco?.id ?? UUID()),
            trechos: trechos,
            resumo: resumo,
            engineTranscricao: p.engineTranscricao,
            engineResumo: p.engineResumo
        )
    }
}
