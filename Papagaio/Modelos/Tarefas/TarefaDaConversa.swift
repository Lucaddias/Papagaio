import Foundation

struct TarefaDaConversa: Identifiable, Codable, Equatable {
    let id: UUID
    var titulo: String
    var origem: String
    var prioridade: PrioridadeDaTarefa
    var status: StatusDaTarefa
    var responsavel: String?
    var prazo: Date?

    init(
        id: UUID = UUID(),
        titulo: String,
        origem: String,
        prioridade: PrioridadeDaTarefa,
        status: StatusDaTarefa,
        responsavel: String?,
        prazo: Date?
    ) {
        self.id = id
        self.titulo = titulo
        self.origem = origem
        self.prioridade = prioridade
        self.status = status
        self.responsavel = responsavel
        self.prazo = prazo
    }
}
