import Foundation

enum FiltroDeTarefas: String, CaseIterable, Identifiable {
    case tudo = "Tudo"
    case naoIniciado = "Não iniciado"
    case emAndamento = "Em andamento"
    case concluidas = "Concluídas"
    // Recorte, não status — mesmo conceito da coluna "Atrasada" do Painel
    // de Tarefas geral (ver `TarefasView.tarefasAtrasadas`). Por último,
    // depois de "Concluídas".
    case atrasadas = "Atrasadas"

    var id: Self { self }
}
