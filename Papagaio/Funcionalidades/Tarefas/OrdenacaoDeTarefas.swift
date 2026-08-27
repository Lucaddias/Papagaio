import Foundation

/// Regras puras de ordenacao das tarefas do painel.
enum OrdenacaoDeTarefas {
    /// Data limite ascendente; empate resolve por prioridade e titulo.
    /// Tarefas sem prazo ficam no fim, em ordem de titulo.
    static func porDeadline(_ primeira: TarefaDaConversa, _ segunda: TarefaDaConversa) -> Bool {
        switch (primeira.prazo, segunda.prazo) {
        case let (a?, b?):
            if a != b { return a < b }
            if primeira.prioridade != segunda.prioridade {
                return pesoDaPrioridade(primeira.prioridade) < pesoDaPrioridade(segunda.prioridade)
            }
            return primeira.titulo.localizedCaseInsensitiveCompare(segunda.titulo) == .orderedAscending
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            return primeira.titulo.localizedCaseInsensitiveCompare(segunda.titulo) == .orderedAscending
        }
    }

    /// Prioridade primeiro, data limite como desempate.
    static func porPrioridade(_ primeira: TarefaDaConversa, _ segunda: TarefaDaConversa) -> Bool {
        let pesoA = pesoDaPrioridade(primeira.prioridade)
        let pesoB = pesoDaPrioridade(segunda.prioridade)
        if pesoA != pesoB { return pesoA < pesoB }
        return porDeadline(primeira, segunda)
    }

    private static func pesoDaPrioridade(_ prioridade: PrioridadeDaTarefa) -> Int {
        switch prioridade {
        case .alta: 0
        case .media: 1
        case .baixa: 2
        }
    }
}
