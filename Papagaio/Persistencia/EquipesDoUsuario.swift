import Foundation

enum EquipesDoUsuario {
    private static let chave = "equipesDoUsuario"

    static func carregar() -> [EquipeDisponivel] {
        guard let dados = UserDefaults.standard.data(forKey: chave),
              let equipes = try? JSONDecoder().decode([EquipeDisponivel].self, from: dados),
              !equipes.isEmpty
        else { return EquipeDisponivel.todas }
        return equipes
    }

    static func salvar(_ equipes: [EquipeDisponivel]) {
        guard let dados = try? JSONEncoder().encode(equipes) else { return }
        UserDefaults.standard.set(dados, forKey: chave)
    }
}
