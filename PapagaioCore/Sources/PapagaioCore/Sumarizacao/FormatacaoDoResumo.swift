import Foundation

/// Formata somente a apresentação da visão geral; não altera temas, citações
/// nem próximos passos que já têm estrutura própria no `Resumo`.
public enum FormatacaoDoResumo {
    /// Reparte a visão geral em parágrafos de no máximo duas frases completas.
    /// `String.enumerateSubstrings(.bySentences)` lida melhor com abreviações
    /// e números decimais do que dividir manualmente em pontos.
    public static func visaoGeralEmBlocosDeDuasFrases(_ texto: String) -> String {
        let frases = FiltroDeRepeticao.frasesEm(texto)
        guard !frases.isEmpty else {
            return texto.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return stride(from: 0, to: frases.count, by: 2)
            .map { frases[$0..<min($0 + 2, frases.count)].joined(separator: " ") }
            .joined(separator: "\n\n")
    }
}
