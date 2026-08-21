import Foundation

enum FiltroDeTarefas: String, CaseIterable, Identifiable {
    case tudo = "Tudo"
    case naoIniciado = "Não iniciado"
    case emAndamento = "Em andamento"
    case concluidas = "Concluídas"

    var id: Self { self }
}
