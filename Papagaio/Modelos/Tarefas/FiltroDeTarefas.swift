import Foundation

enum FiltroDeTarefas: String, CaseIterable, Identifiable {
    case tudo = "Tudo"
    case prioridadeAlta = "Prioridade alta"
    case emAndamento = "Em andamento"
    case concluidas = "Concluídas"

    var id: Self { self }
}
