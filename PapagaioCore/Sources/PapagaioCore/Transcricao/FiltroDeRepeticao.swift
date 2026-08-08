import Foundation

/// Remove repetições consecutivas que são um artefato conhecido do Whisper em
/// silêncio, ruído constante ou trechos muito longos. É deliberadamente
/// conservador: não tenta reescrever texto, apenas remove cópias equivalentes
/// que se repetem sem fala diferente entre elas.
public enum FiltroDeRepeticao {
    /// Limpa primeiro uma frase repetida dentro do mesmo segmento e, depois,
    /// colapsa uma sequência de três ou mais segmentos iguais do mesmo falante.
    /// Duas frases iguais são preservadas porque podem ser uma repetição real da
    /// conversa (por exemplo, confirmação ou pedido de esclarecimento).
    public static func remover(_ trechos: [Trecho]) -> [Trecho] {
        let limpos = trechos.compactMap(limpar)
        guard !limpos.isEmpty else { return [] }

        var resultado: [Trecho] = []
        var inicioDaSequencia = 0
        while inicioDaSequencia < limpos.count {
            let primeiro = limpos[inicioDaSequencia]
            let referencia = normalizar(primeiro.texto)
            var fimDaSequencia = inicioDaSequencia + 1

            while fimDaSequencia < limpos.count,
                  limpos[fimDaSequencia].speaker == primeiro.speaker,
                  normalizar(limpos[fimDaSequencia].texto) == referencia,
                  limpos[fimDaSequencia].start - limpos[fimDaSequencia - 1].end <= 5
            {
                fimDaSequencia += 1
            }

            let quantidade = fimDaSequencia - inicioDaSequencia
            if quantidade >= 3 {
                resultado.append(primeiro)
            } else {
                resultado.append(contentsOf: limpos[inicioDaSequencia..<fimDaSequencia])
            }
            inicioDaSequencia = fimDaSequencia
        }
        return resultado
    }

    private static func limpar(_ trecho: Trecho) -> Trecho? {
        let frases = frasesEm(trecho.texto)
        let texto: String
        if frases.isEmpty {
            texto = trecho.texto.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            var anterior: String?
            var resultado: [String] = []
            for frase in frases {
                let chave = normalizar(frase)
                if chave == anterior { continue }
                resultado.append(frase)
                anterior = chave
            }
            texto = resultado.joined(separator: " ")
        }

        guard !texto.isEmpty else { return nil }
        return Trecho(id: trecho.id, start: trecho.start, end: trecho.end, texto: texto, speaker: trecho.speaker)
    }

    static func frasesEm(_ texto: String) -> [String] {
        let intervalo = texto.startIndex..<texto.endIndex
        guard !intervalo.isEmpty else { return [] }

        var frases: [String] = []
        texto.enumerateSubstrings(in: intervalo, options: .bySentences) { frase, _, _, _ in
            guard let frase else { return }
            let limpa = frase.trimmingCharacters(in: .whitespacesAndNewlines)
            if !limpa.isEmpty { frases.append(limpa) }
        }
        return frases
    }

    static func normalizar(_ texto: String) -> String {
        texto.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .split { !$0.isLetter && !$0.isNumber }
            .joined(separator: " ")
    }
}
