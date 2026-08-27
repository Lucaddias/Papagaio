import Foundation
import PapagaioCore

struct ReuniaoPendenteCalendar: Identifiable, Equatable {
    let id: String
    let titulo: String
    let dataHora: Date
    let participantes: [ParticipanteDaReuniao]
    let descricao: String?
    let idExterno: String

    /// Compat: inicializa com strings legadas.
    init(id: String, titulo: String, dataHora: Date, participantes: [String], descricao: String?, idExterno: String) {
        self.id = id
        self.titulo = titulo
        self.dataHora = dataHora
        self.participantes = participantes.map { ParticipanteDaReuniao(legado: $0) }
        self.descricao = descricao
        self.idExterno = idExterno
    }

    init(id: String, titulo: String, dataHora: Date, participantes: [ParticipanteDaReuniao], descricao: String?, idExterno: String) {
        self.id = id
        self.titulo = titulo
        self.dataHora = dataHora
        self.participantes = participantes
        self.descricao = descricao
        self.idExterno = idExterno
    }

    enum Status: Equatable {
        case futura
        case emAndamento
        case pendenteExpirada
        case expirada
    }

    var status: Status {
        let agora = Date()
        let fimEstimado = dataHora.addingTimeInterval(3600)
        let expiracao = dataHora.addingTimeInterval(12 * 3600)

        if agora >= expiracao { return .expirada }
        if agora >= fimEstimado { return .pendenteExpirada }
        if agora >= dataHora { return .emAndamento }
        return .futura
    }

    var deveExibir: Bool { status != .expirada }
    var estaNoPassado: Bool { Date() >= dataHora }
    var tempoAteReuniao: TimeInterval { dataHora.timeIntervalSinceNow }
}