import Foundation

enum StatusDaTarefa: String, Codable {
    case emAndamento
    case concluida

    var titulo: String {
        switch self {
        case .emAndamento: "Em andamento"
        case .concluida: "Concluída"
        }
    }
}

extension StatusDaTarefa: CaseIterable {}
