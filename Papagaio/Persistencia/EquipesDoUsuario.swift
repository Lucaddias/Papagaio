import Foundation

enum EquipesDoUsuario {
    private static let chave = "equipesDoUsuario"

    /// Vazio é resposta legítima — quem nunca criou equipe não tem nenhuma.
    static func carregar(em defaults: UserDefaults = .standard) -> [EquipeDisponivel] {
        guard let dados = defaults.data(forKey: chave),
              let equipes = try? JSONDecoder().decode([EquipeDisponivel].self, from: dados)
        else { return [] }
        return equipes
    }

    static func salvar(_ equipes: [EquipeDisponivel], em defaults: UserDefaults = .standard) {
        guard let dados = try? JSONEncoder().encode(equipes) else { return }
        defaults.set(dados, forKey: chave)
    }

    static func incluirOuAtualizar(
        _ equipe: EquipeDisponivel,
        em defaults: UserDefaults = .standard
    ) {
        var equipes = carregar(em: defaults)
        if let indice = equipes.firstIndex(where: { $0.id == equipe.id }) {
            equipes[indice] = equipe
        } else {
            equipes.append(equipe)
        }
        salvar(equipes, em: defaults)
    }

    static func remover(em defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: chave)
    }
}
