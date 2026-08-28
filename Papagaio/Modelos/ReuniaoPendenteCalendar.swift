import Foundation

struct ReuniaoPendenteCalendar: Identifiable, Equatable, Codable, Sendable {
    let id: String
    let titulo: String
    let dataHora: Date
    let participantes: [String]
    let descricao: String?
    let idExterno: String

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
