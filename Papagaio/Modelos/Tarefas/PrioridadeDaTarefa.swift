import SwiftUI

enum PrioridadeDaTarefa: String, Codable, CaseIterable {
    case alta = "Alta"
    case media = "Média"
    case baixa = "Baixa"

    var cor: Color {
        switch self {
        case .alta: PapagaioTema.perigo
        case .media: PapagaioTema.textoSecundario
        case .baixa: PapagaioTema.sucesso
        }
    }

}
