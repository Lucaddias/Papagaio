import Foundation

/// Resolve falas "Voz desconhecida" pelo **contexto da conversa**, com o
/// modelo de linguagem — o mesmo Qwen que resume.
///
/// O que o diarizador acústico não distingue, o texto às vezes distingue: um
/// trecho entre uma pergunta (Voz 1) e a resposta (Voz 2) quase sempre é a
/// resposta. O modelo decide entre as duas vozes confiáveis dos lados, ou
/// devolve "indeterminado" quando o contexto não dá evidência.
///
/// Não é uma segunda diarização: nada de estimar falante onde não há texto.
/// Só entra o que o `AlinhamentoDeFalantes` marcou como duvidoso (overlap
/// germinal, fronteira de turno, buraco cross-falante) — quem ficou sem
/// falante de propósito.
///
/// Regras:
/// - caso elegível = fala sem falante, curta (≤ `maxPalavrasPorCaso`), com os
///   dois vizinhos confiáveis de **falantes diferentes**;
/// - uma chamada só, com todos os casos — janela pequena e barata (≤
///   `maxCasosPorChamada`);
/// - o modelo responde JSON restrito por gramática: só `"voz-1"`,
///   `"voz-2"` ou `"indeterminado"` por caso;
/// - resposta ambígua ou ausente → a fala continua sem falante (estado
///   honesto, nunca chute).
public enum ResolvedorDeFalantes {
    /// Fala duvidosa maior que isto não é caso: sem confiança contextual
    /// suficiente e sem limite de custo.
    public static let maxPalavrasPorCaso = 8

    /// Teto de casos numa chamada — contexto curto, resposta determinística.
    public static let maxCasosPorChamada = 12

    /// Janela de evidência de cada lado do caso, em palavras.
    public static let palavrasDeContexto = 40

    /// Um trecho duvidoso com os vizinhos confiáveis que o delimitam.
    public struct Caso: Sendable, Equatable, Identifiable {
        public let id: UUID
        public let texto: String
        /// Rótulo acústico da fala confiável à esquerda (ex.: `"S1"`).
        public let falanteAnterior: String
        /// Rótulo acústico da fala confiável à direita.
        public let falanteSeguinte: String
        public let contextoAnterior: String
        public let contextoSeguinte: String

        public init(
            id: UUID,
            texto: String,
            falanteAnterior: String,
            falanteSeguinte: String,
            contextoAnterior: String,
            contextoSeguinte: String
        ) {
            self.id = id
            self.texto = texto
            self.falanteAnterior = falanteAnterior
            self.falanteSeguinte = falanteSeguinte
            self.contextoAnterior = contextoAnterior
            self.contextoSeguinte = contextoSeguinte
        }
    }

    // MARK: - Seleção

    /// Os casos resolvíveis da conversa, em ordem cronológica.
    ///
    /// - Precondition: `falas` na ordem de `FalasDaConversa.agrupar`.
    public static func casosElegiveis(falas: [FalaDeFalante]) -> [Caso] {
        var casos: [Caso] = []
        for (indice, fala) in falas.enumerated() {
            guard fala.falanteAcustico == nil,
                  !fala.palavras.isEmpty,
                  fala.palavras.count <= maxPalavrasPorCaso,
                  let anterior = vizinhoConfiante(falas, aPartirDe: indice, passo: -1),
                  let seguinte = vizinhoConfiante(falas, aPartirDe: indice, passo: 1),
                  let falanteAnterior = anterior.falanteAcustico,
                  let falanteSeguinte = seguinte.falanteAcustico,
                  falanteAnterior != falanteSeguinte
            else { continue }
            casos.append(Caso(
                id: fala.id,
                texto: fala.texto,
                falanteAnterior: falanteAnterior,
                falanteSeguinte: falanteSeguinte,
                contextoAnterior: contexto(de: anterior, ultimas: true),
                contextoSeguinte: contexto(de: seguinte, ultimas: false)
            ))
            if casos.count == maxCasosPorChamada { break }
        }
        return casos
    }

    /// A fala confiável (com falante atribuído e palavras) mais próxima, no
    /// sentido pedido, pulando as falas sem falante.
    private static func vizinhoConfiante(
        _ falas: [FalaDeFalante],
        aPartirDe indice: Int,
        passo: Int
    ) -> FalaDeFalante? {
        var cursor = indice + passo
        while falas.indices.contains(cursor) {
            let fala = falas[cursor]
            if fala.falanteAcustico != nil, !fala.palavras.isEmpty {
                return fala
            }
            cursor += passo
        }
        return nil
    }

    /// As últimas (`ultimas: true`) ou primeiras palavras da fala, como
    /// janela de evidência do caso.
    private static func contexto(de fala: FalaDeFalante, ultimas: Bool) -> String {
        let palavras = ultimas
            ? Array(fala.palavras.suffix(palavrasDeContexto))
            : Array(fala.palavras.prefix(palavrasDeContexto))
        return palavras.map { $0.palavra.texto }.joined(separator: " ")
    }

    // MARK: - Prompt e gramática

    /// "Voz 1" no prompt é sempre a fala à esquerda; a resposta é mapeada de
    /// volta pelo `Caso`.
    public static func prompt(para casos: [Caso]) -> String {
        """
        <|im_start|>system
        Você decide quem disse trechos duvidosos de uma conversa que já tem \
        vozes separadas. As vozes confiáveis são rotuladas "Voz 1" e "Voz 2"; \
        o trecho entre [????] foi reconhecido como fala, mas o áudio não \
        permitiu distinguir quem disse. Use SÓ o contexto: quem pergunta \
        geralmente responde, quem retoma um assunto é quem o deixou, \
        confirmações curtas seguem quem acabou de falar. Não invente fala que \
        não está nos trechos.
        Responda SOMENTE com um objeto JSON: uma chave por caso, com o id do \
        caso, e o valor "voz-1", "voz-2" ou "indeterminado" (quando o \
        contexto não permite decidir).<|im_end|>
        <|im_start|>user
        \(casos.map(\.corpo).joined(separator: "\n\n"))

        Responda somente o JSON.<|im_end|>
        <|im_start|>assistant
        """
    }

    /// GBNF que restringe a saída a chaves conhecidas e ao vocabulário de
    /// três valores — a sintaxe não pode sair do formato (mesma razão de
    /// `GramaticaDoResumo`).
    public static func gramatica(para casos: [Caso]) -> String {
        let pares = casos.map { caso in
            "\"\(caso.id.uuidString)\" ws \":\" ws valor"
        }.joined(separator: " ws \",\" ws ")
        return """
        root ::= "{" ws \(pares) ws "}"
        valor ::= "\"voz-1\"" | "\"voz-2\"" | "\"indeterminado\""
        ws ::= [ \\t\\n]*
        """
    }

    // MARK: - Aplicação

    /// Decodifica a resposta do modelo: caso → `"voz-1"`/`"voz-2"` (só os
    /// resolvidos; o resto fica de fora).
    public static func decodificar(_ bruto: String, casos: [Caso]) -> [UUID: String] {
        guard let inicio = bruto.firstIndex(of: "{"),
              let fim = bruto.lastIndex(of: "}"), inicio < fim
        else { return [:] }
        let json = String(bruto[inicio...fim])
        guard let mapa = try? JSONDecoder().decode([String: String].self, from: Data(json.utf8))
        else { return [:] }

        var resolucoes: [UUID: String] = [:]
        for caso in casos {
            let valor = mapa[caso.id.uuidString] ?? ""
            if valor == "voz-1" || valor == "voz-2" {
                resolucoes[caso.id] = valor
            }
        }
        return resolucoes
    }

    /// Aplica as resoluções às palavras do arquivo: cada fala resolvida ganha
    /// o rótulo acústico do vizinho indicado. Nunca sobrescreve falante
    /// já atribuído (a fala resolvível é toda duvidosa por construção).
    public static func aplicar(
        _ resolucoes: [UUID: String],
        casos: [Caso],
        em arquivo: Arquivo
    ) -> Arquivo {
        guard !resolucoes.isEmpty, !casos.isEmpty,
              let falas = FalasDaConversa.agrupar(arquivo.trechos)
        else { return arquivo }

        let rotuloPorFala: [UUID: String] = casos.reduce(into: [:]) { mapa, caso in
            guard let resposta = resolucoes[caso.id] else { return }
            mapa[caso.id] = resposta == "voz-1" ? caso.falanteAnterior : caso.falanteSeguinte
        }
        guard !rotuloPorFala.isEmpty else { return arquivo }

        var rotuloPorAncora: [UUID: [Int: String]] = [:]
        for fala in falas where rotuloPorFala[fala.id] != nil {
            for palavra in fala.palavras {
                rotuloPorAncora[palavra.trechoId, default: [:]][palavra.indiceNoTrecho] =
                    rotuloPorFala[fala.id]
            }
        }

        let trechos = arquivo.trechos.map { trecho -> Trecho in
            guard let rotulos = rotuloPorAncora[trecho.id], !rotulos.isEmpty else { return trecho }
            return Trecho(
                id: trecho.id,
                start: trecho.start,
                end: trecho.end,
                texto: trecho.texto,
                speaker: trecho.speaker,
                palavras: trecho.palavras.enumerated().map { indice, palavra -> Palavra in
                    guard let rotulo = rotulos[indice] else { return palavra }
                    return Palavra(
                        id: palavra.id,
                        start: palavra.start,
                        end: palavra.end,
                        texto: palavra.texto,
                        falanteAcustico: rotulo
                    )
                }
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
}

private extension ResolvedorDeFalantes.Caso {
    /// O caso em texto para o prompt: vizinhos delimitando o trecho.
    var corpo: String {
        """
        CASO \(id.uuidString)
        Voz 1: "\(contextoAnterior)"
        [????]: "\(texto)"
        Voz 2: "\(contextoSeguinte)"
        """
    }
}