import Foundation

/// Ordenação pura das tarefas do painel.
///
/// Vivia como função privada da `TarefasView` — decisão de domínio sem teste
/// nenhum. Aqui ela é exercitável sem montar a tela.
enum OrdenacaoDeTarefas {
    /// Data limite ascendente; empate no dia resolve por prioridade, depois
    /// por título. Tarefas **sem** prazo vão para o fim, em ordem de título.
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

    static func pesoDaPrioridade(_ prioridade: PrioridadeDaTarefa) -> Int {
        switch prioridade {
        case .alta: 0
        case .media: 1
        case .baixa: 2
        }
    }
}
