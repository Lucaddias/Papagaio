import Foundation

/// Formatação de posições e durações de áudio.
///
/// Existia copiada **catorze vezes** em seis arquivos, e não igual: metade
/// usava `%d:%02d`, metade `%02d:%02d`, e só uma tratava valores não finitos —
/// o que aparecia como inconsistência real na tela, não só como duplicação.
extension TimeInterval {
    /// `3:07` — posições e durações no meio do texto.
    var comoRelogio: String {
        let total = Self.segundosValidos(self)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// `03:07` — cronômetro da gravação, onde a largura fixa evita o número
    /// "pular" a cada dígito que entra.
    var comoCronometro: String {
        let total = Self.segundosValidos(self)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    /// `3 min 7 s` — para VoiceOver, que não lê "3:07" como tempo.
    var faladoPorExtenso: String {
        let total = Self.segundosValidos(self)
        let minutos = total / 60
        let segundos = total % 60
        return minutos > 0 ? "\(minutos) min \(segundos) s" : "\(segundos) s"
    }

    /// `1 h 5 min`, `45 min 30 s`, `12 segundos` — duração de um arquivo, onde
    /// o formato de relógio não ajuda a estimar tamanho.
    ///
    /// Também existia em duas versões que discordavam: uma devolvia `"30 s"`
    /// para meio minuto, a outra `"30 segundos"`, e uma nunca mostrava os
    /// segundos junto dos minutos.
    var comoDuracaoPorExtenso: String {
        let total = Self.segundosValidos(self)
        let horas = total / 3600
        let minutos = (total % 3600) / 60
        let segundos = total % 60

        if horas > 0 {
            return minutos > 0 ? "\(horas) h \(minutos) min" : "\(horas) h"
        }
        if minutos > 0 {
            return segundos > 0 ? "\(minutos) min \(segundos) s" : "\(minutos) min"
        }
        return "\(segundos) segundos"
    }

    /// Lê o que a pessoa digitou no campo de duração: `1h 15min`, `45 min`,
    /// `90` (interpretado como minutos). Devolve `nil` para texto vazio.
    static func lendo(_ texto: String) -> TimeInterval? {
        let limpo = texto
            .lowercased()
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpo.isEmpty else { return nil }

        let padroes: [(String, Double)] = [
            (#"([0-9]+(?:\.[0-9]+)?)\s*h"#, 3600),
            (#"([0-9]+(?:\.[0-9]+)?)\s*(?:min|m)"#, 60),
            (#"([0-9]+(?:\.[0-9]+)?)\s*(?:seg|s)"#, 1)
        ]

        var total: Double = 0
        for (padrao, multiplicador) in padroes {
            guard let regex = try? NSRegularExpression(pattern: padrao) else { continue }
            let intervalo = NSRange(limpo.startIndex..<limpo.endIndex, in: limpo)
            regex.enumerateMatches(in: limpo, range: intervalo) { match, _, _ in
                guard let match,
                      let range = Range(match.range(at: 1), in: limpo),
                      let valor = Double(limpo[range])
                else { return }
                total += valor * multiplicador
            }
        }

        if total > 0 { return total }
        // Número solto: a intenção quase sempre é minutos.
        return Double(limpo).map { $0 * 60 }
    }

    /// `AVPlayer` devolve `NaN` antes de carregar a duração, e `Int(NaN)`
    /// derruba o processo — por isso a validação fica num lugar só.
    private static func segundosValidos(_ valor: TimeInterval) -> Int {
        guard valor.isFinite, valor > 0 else { return 0 }
        return Int(valor)
    }
}
