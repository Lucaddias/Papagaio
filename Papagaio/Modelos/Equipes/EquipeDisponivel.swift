import Foundation

/// Uma equipe do usuário.
///
/// Não existe equipe padrão: um app recém-instalado não tem equipe nenhuma até
/// que a pessoa crie a primeira. Por isso todo consumidor trata `EquipeDisponivel?`
/// em vez de assumir que sempre há uma ativa.
struct EquipeDisponivel: Identifiable, Hashable, Codable {
    let id: String
    let nome: String
    let papel: String
    var quantidadeDeMembros: Int
}
