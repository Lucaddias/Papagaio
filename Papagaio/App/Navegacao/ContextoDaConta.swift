import Foundation

enum ContextoDaConta: String {
    case perfil
    case equipe

    var titulo: String {
        switch self {
        case .perfil: "Perfil pessoal"
        case .equipe: "Creative Flow Studio"
        }
    }

    var subtitulo: String {
        switch self {
        case .perfil: "Conta pessoal"
        case .equipe: "Equipe selecionada"
        }
    }

    var simbolo: String {
        switch self {
        case .perfil: "person.crop.circle"
        case .equipe: "person.3"
        }
    }
}
