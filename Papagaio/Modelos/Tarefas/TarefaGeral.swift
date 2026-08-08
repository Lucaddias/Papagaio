import Foundation
import PapagaioCore

struct TarefasDaConversaGeral: Identifiable {
    let arquivo: Arquivo
    let titulo: String
    let tarefas: [TarefaDaConversa]

    var id: ArquivoID { arquivo.id }
}

struct TarefaGeral: Identifiable {
    let conversa: TarefasDaConversaGeral
    let tarefa: TarefaDaConversa

    var id: String { "\(conversa.id.rawValue.uuidString)-\(tarefa.id.uuidString)" }
}
