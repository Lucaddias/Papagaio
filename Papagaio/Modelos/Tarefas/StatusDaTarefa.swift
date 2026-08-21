import Foundation

enum StatusDaTarefa: String, Codable {
    case naoIniciado
    case emAndamento
    case concluida

    var titulo: String {
        switch self {
        case .naoIniciado: "Não iniciado"
        case .emAndamento: "Em andamento"
        case .concluida: "Concluída"
        }
    }
}

extension StatusDaTarefa: CaseIterable {}
