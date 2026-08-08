import Foundation

struct ResponsavelDaTarefa: Identifiable, Hashable {
    var id: String { email.lowercased() }
    let nome: String
    let email: String

    var rotulo: String {
        email.isEmpty ? nome : "\(nome) - \(email)"
    }
}
