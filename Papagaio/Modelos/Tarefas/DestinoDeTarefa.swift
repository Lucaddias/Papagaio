import Foundation

enum DestinoDeTarefa {
    case alta
    case emAndamento
    case concluida

    var titulo: String {
        switch self {
        case .alta: "Prioridade alta"
        case .emAndamento: "Em andamento"
        case .concluida: "Concluída"
        }
    }

    var prioridade: PrioridadeDaTarefa? {
        switch self {
        case .alta: .alta
        case .emAndamento: .media
        case .concluida: nil
        }
    }

    var status: StatusDaTarefa {
        switch self {
        case .alta, .emAndamento: .emAndamento
        case .concluida: .concluida
        }
    }
}

extension DestinoDeTarefa: CaseIterable, Hashable {}
