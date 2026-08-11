import Foundation
import LlamaRuntime

/// A engine de sumarização do Papagaio. Não existe segunda (D-0.5).
///
/// Passe único é o padrão: a janela de 32k do Qwen cabe uma reunião inteira de
/// até ~3 h. Map-reduce só entra acima disso — e é o que permite o resumo
/// conectar um assunto do início com a retomada dele no fim, que é justamente o
/// que um modelo de 4k não faz.
public struct QwenEngine: SummarizationEngine {
    /// Ver a nota em `WhisperEngine.identificador` — mesmo motivo.
    public static let identificador = "qwen2.5-14b-instruct-q5_k_m"

    public let identifier = QwenEngine.identificador

    private let contexto: ContextoLlama

    /// Tamanho do chunk no modo map-reduce. ~8.000 tokens deixa espaço para o
    /// resumo parcial na mesma janela.
    public static let tokensPorChunk = 8_000

    public init(modelo: URL) {
        self.contexto = ContextoLlama(modelo: modelo)
    }

    public init(contexto: ContextoLlama) {
        self.contexto = contexto
    }

    public func summarize(_ trechos: [Trecho]) async throws -> Resumo {
        guard !trechos.isEmpty else {
            throw NotImplemented("resumo de transcrição vazia", passo: 7)
        }

        let transcricao = Self.formatar(trechos)
        let tokens = try await contexto.contarTokens(transcricao)

        let resumo: Resumo
        if tokens <= ContextoLlama.tetoDeEntrada {
            resumo = try await passeUnico(transcricao)
        } else {
            resumo = try await mapReduce(trechos)
        }
        return Self.validarCitacoes(resumo, em: trechos)
    }

    // MARK: - Passe único

    private func passeUnico(_ transcricao: String) async throws -> Resumo {
        let prompt = Self.prompt(paraTranscricao: transcricao)
        return try await gerarComReprompt(prompt: prompt)
    }

    /// Gera com a gramática e, se mesmo assim o JSON não decodificar, tenta uma
    /// vez com a instrução de formato reforçada.
    ///
    /// A gramática já garante a sintaxe; o reprompt cobre o caso de a saída
    /// estar sintaticamente válida mas semanticamente incompleta (campo
    /// faltando por truncamento, por exemplo).
    private func gerarComReprompt(prompt: String) async throws -> Resumo {
        let bruto = try await contexto.completar(
            prompt: prompt,
            gramatica: GramaticaDoResumo.gbnf,
            maxTokens: 2_048
        )

        if let resumo = Self.decodificar(bruto) { return resumo }

        let corrigido = try await contexto.completar(
            prompt: Self.promptDeCorrecao(saidaInvalida: bruto),
            gramatica: GramaticaDoResumo.gbnf,
            maxTokens: 2_048
        )
        guard let resumo = Self.decodificar(corrigido) else {
            throw ErroLlama.gramaticaInvalida
        }
        return resumo
    }

    // MARK: - Map-reduce

    private func mapReduce(_ trechos: [Trecho]) async throws -> Resumo {
        let chunks = try await particionar(trechos)

        var parciais: [String] = []
        for chunk in chunks {
            // Sessão nova por chunk — o `completar` limpa a memória do contexto
            // ao final de cada chamada.
            let parcial = try await contexto.completar(
                prompt: Self.promptParcial(Self.formatar(chunk)),
                gramatica: nil,
                maxTokens: 1_024
            )
            parciais.append(parcial)
        }

        let consolidado = parciais.enumerated()
            .map { "## Parte \($0.offset + 1)\n\($0.element)" }
            .joined(separator: "\n\n")

        return try await gerarComReprompt(
            prompt: Self.promptDeReducao(consolidado)
        )
    }

    private func particionar(_ trechos: [Trecho]) async throws -> [[Trecho]] {
        var chunks: [[Trecho]] = []
        var atual: [Trecho] = []
        var tokensAtuais = 0

        for trecho in trechos {
            let tokens = try await contexto.contarTokens(Self.formatar([trecho]))
            if tokensAtuais + tokens > Self.tokensPorChunk, !atual.isEmpty {
                chunks.append(atual)
                atual = []
                tokensAtuais = 0
            }
            atual.append(trecho)
            tokensAtuais += tokens
        }
        if !atual.isEmpty { chunks.append(atual) }
        return chunks
    }

    // MARK: - Citações verificáveis

    /// O modelo é bom em escolher ideias relevantes, mas não é uma fonte
    /// confiável para o segundo exato. Uma citação só sobrevive quando seu
    /// texto aparece de fato em um trecho da transcrição; a âncora e o falante
    /// sempre vêm desse trecho real, nunca do JSON produzido pelo modelo.
    static func validarCitacoes(_ resumo: Resumo, em trechos: [Trecho]) -> Resumo {
        var textosVistos = Set<String>()
        let citacoes = resumo.citacoes.compactMap { citacao -> Citacao? in
            let texto = limparCitacao(citacao.texto)
            let normalizado = normalizar(texto)
            let palavras = normalizado.split(separator: " ")

            // Frases muito curtas tendem a ser genéricas e não ajudam a
            // explicar por que uma conversa importa.
            guard palavras.count >= 6,
                  textosVistos.insert(normalizado).inserted,
                  let trecho = trechos.first(where: {
                      normalizar(limparCitacao($0.texto)).contains(normalizado)
                  })
            else { return nil }

            return Citacao(texto: texto, speaker: trecho.speaker, start: trecho.start)
        }

        return Resumo(
            titulo: resumo.titulo,
            visaoGeral: resumo.visaoGeral,
            temas: resumo.temas,
            citacoes: Array(citacoes.prefix(3)),
            proximosPassos: resumo.proximosPassos
        )
    }

    /// Limpeza editorial mínima. Ela só remove muletas de fala comuns;
    /// conteúdo, números e decisões permanecem literalmente os mesmos.
    private static func limparCitacao(_ texto: String) -> String {
        let semMuletas = texto.replacingOccurrences(
            of: #"(?i)\b(ah+|eh+|é+|hum+|hmm+|ahn+|uh+|putz|tipo|né)\b[\s,]*"#,
            with: "",
            options: .regularExpression
        )
        return semMuletas
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizar(_ texto: String) -> String {
        texto
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR"))
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Prompts

    /// Cada linha carrega o tempo e o falante — é o que permite ao modelo
    /// preencher `start` nas citações e `responsavel` nos próximos passos.
    public static func formatar(_ trechos: [Trecho]) -> String {
        trechos.map { trecho in
            let minutos = Int(trecho.start) / 60
            let segundos = Int(trecho.start) % 60
            let quem = trecho.speaker ?? "desconhecido"
            return String(format: "[%02d:%02d] (%@) %@", minutos, segundos, quem, trecho.texto)
        }.joined(separator: "\n")
    }

    static func prompt(paraTranscricao transcricao: String) -> String {
        """
        <|im_start|>system
        Você resume reuniões em português do Brasil. Seja fiel à transcrição: \
        não invente números, nomes nem decisões.<|im_end|>
        <|im_start|>user
        Resuma a reunião abaixo.

        \(GramaticaDoResumo.descricaoDoFormato)

        TRANSCRIÇÃO:
        \(transcricao)<|im_end|>
        <|im_start|>assistant
        """
    }

    static func promptParcial(_ transcricao: String) -> String {
        """
        <|im_start|>system
        Você resume trechos de reunião em português do Brasil, de forma fiel.<|im_end|>
        <|im_start|>user
        Resuma este trecho em até 8 linhas, preservando números, nomes e decisões.

        \(transcricao)<|im_end|>
        <|im_start|>assistant
        """
    }

    static func promptDeReducao(_ parciais: String) -> String {
        """
        <|im_start|>system
        Você consolida resumos parciais de uma mesma reunião em português do Brasil.<|im_end|>
        <|im_start|>user
        Os textos abaixo são resumos de partes consecutivas da MESMA reunião. \
        Consolide num resumo único, conectando assuntos que aparecem em partes diferentes.

        \(GramaticaDoResumo.descricaoDoFormato)

        \(parciais)<|im_end|>
        <|im_start|>assistant
        """
    }

    static func promptDeCorrecao(saidaInvalida: String) -> String {
        """
        <|im_start|>system
        Você corrige JSON malformado.<|im_end|>
        <|im_start|>user
        A saída abaixo deveria ser um JSON válido no formato pedido, mas não é. \
        Reescreva-a corretamente.

        \(GramaticaDoResumo.descricaoDoFormato)

        SAÍDA INVÁLIDA:
        \(saidaInvalida.prefix(4_000))<|im_end|>
        <|im_start|>assistant
        """
    }

    // MARK: - Decodificação

    static func decodificar(_ bruto: String) -> Resumo? {
        // O modelo pode emitir texto antes/depois do objeto mesmo com gramática
        // (por exemplo, se a gramática não foi aplicada). Recorta do primeiro
        // `{` ao último `}`.
        guard let inicio = bruto.firstIndex(of: "{"),
              let fim = bruto.lastIndex(of: "}"), inicio < fim
        else { return nil }
        let json = String(bruto[inicio...fim])
        return try? JSONDecoder().decode(Resumo.self, from: Data(json.utf8))
    }

    public func preaquecer() async throws {
        try await contexto.carregar()
    }

    public func descarregar() async {
        await contexto.descarregar()
    }
}

extension ContextoLlama: CicloDeVidaDeModelos.Residente {
    public nonisolated var identificador: String { QwenEngine.identificador }
}
