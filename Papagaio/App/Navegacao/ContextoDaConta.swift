import Foundation

enum ContextoDaConta: String {
    case perfil
    case equipe

    // Os rótulos de conta vêm de quem conhece a equipe ativa —
    // `BarraSuperiorPapagaioView.tituloDaContaAtiva` e `SeletorDeContextoDaConta`.
    // O `titulo` que existia aqui era morto e trazia um nome de equipe fixo.

    var simbolo: String {
        switch self {
        case .perfil: "person.crop.circle"
        case .equipe: "person.3"
        }
    }
}
