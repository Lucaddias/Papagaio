import Foundation

enum EquipesDoUsuario {
    private static let chave = "equipesDoUsuario"

    /// Vazio é resposta legítima — quem nunca criou equipe não tem nenhuma.
    static func carregar() -> [EquipeDisponivel] {
        guard let dados = UserDefaults.standard.data(forKey: chave),
              let equipes = try? JSONDecoder().decode([EquipeDisponivel].self, from: dados)
        else { return [] }
        return equipes
    }

    static func salvar(_ equipes: [EquipeDisponivel]) {
        guard let dados = try? JSONEncoder().encode(equipes) else { return }
        UserDefaults.standard.set(dados, forKey: chave)
    }

    static func remover() {
        UserDefaults.standard.removeObject(forKey: chave)
    }
}
