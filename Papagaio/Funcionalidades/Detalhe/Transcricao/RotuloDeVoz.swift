import Foundation

/// Traduz o rótulo bruto do diarizador ("S1", "S2"...) para o que aparece na
/// tela: o nome que a pessoa escolheu (ver
/// `PreferenciasVisuaisDoArquivo.nomesDeVoz`), ou, sem nome ainda, o rótulo
/// padrão "Voz N".
///
/// Antes esta tradução vivia duplicada em `LinhaDeFala` e
/// `LinhaDeTranscricao` — cada uma com sua própria cópia da mesma função.
/// Unificada aqui para as duas (e o editor "Quem é quem", acima da
/// transcrição) nunca discordarem sobre como uma voz deveria se chamar.
enum RotuloDeVoz {
    /// "S1" → "Voz 1". Nunca um nome de pessoa — é só o que aparece antes de
    /// alguém dar um nome de verdade à voz.
    static func padrao(_ falanteAcustico: String) -> String {
        if falanteAcustico.hasPrefix("S"), let numero = Int(falanteAcustico.dropFirst()) {
            return "Voz \(numero)"
        }
        return "Voz \(falanteAcustico)"
    }

    /// O nome escolhido para esta voz, ou o rótulo padrão quando ainda não
    /// foi renomeada (mapa vazio, ausente, ou só espaços em branco).
    static func exibicao(_ falanteAcustico: String, nomes: [String: String]) -> String {
        if let nome = nomes[falanteAcustico]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !nome.isEmpty {
            return nome
        }
        return padrao(falanteAcustico)
    }
}
