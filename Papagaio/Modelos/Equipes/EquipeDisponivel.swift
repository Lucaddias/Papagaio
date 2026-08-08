import Foundation

struct EquipeDisponivel: Identifiable, Hashable, Codable {
    let id: String
    let nome: String
    let papel: String
    var quantidadeDeMembros: Int

    static let padrao = EquipeDisponivel(
        id: "creative-flow",
        nome: "Creative Flow Studio",
        papel: "Administrador",
        quantidadeDeMembros: 5
    )

    static let todas: [EquipeDisponivel] = [
        .padrao,
        EquipeDisponivel(
            id: "scribeflow",
            nome: "ScribeFlow Research",
            papel: "Transcritor",
            quantidadeDeMembros: 3
        ),
        EquipeDisponivel(
            id: "design-lab",
            nome: "Design Lab",
            papel: "Designer",
            quantidadeDeMembros: 2
        )
    ]
}
