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

    /// Referência do workspace compartilhado.
    var espacoID: String?

    init(
        id: String,
        nome: String,
        papel: String,
        quantidadeDeMembros: Int,
        espacoID: String? = nil
    ) {
        self.id = id
        self.nome = nome
        self.papel = papel
        self.quantidadeDeMembros = quantidadeDeMembros
        self.espacoID = espacoID
    }
}
