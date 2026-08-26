import Foundation

/// Tarefas que a pessoa escolheu tirar da própria vista no quadro geral —
/// não é status nem exclusão, é só uma preferência de exibição (tipo
/// "arquivar" sem mexer nos dados de verdade da tarefa). Por isso mora
/// separada da tarefa em si, guardada pelo `id` composto de `TarefaGeral`.
enum TarefasOcultasStore {
    private static let chave = "tarefasGeraisOcultas"

    static func carregar() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: chave) ?? [])
    }

    static func salvar(_ ids: Set<String>) {
        UserDefaults.standard.set(Array(ids), forKey: chave)
    }
}
