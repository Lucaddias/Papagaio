import Foundation

enum MembrosDasEquipes {
    private static func chave(_ equipeID: String) -> String {
        "membrosDaEquipe.\(equipeID)"
    }

    /// Equipe sem nada salvo não tem membro nenhum — quem acabou de criar uma
    /// equipe começa com a lista vazia e convida as pessoas de verdade.
    static func carregar(
        equipeID: String,
        em defaults: UserDefaults = .standard
    ) -> [MembroDaEquipe] {
        guard let dados = defaults.data(forKey: chave(equipeID)),
              let membros = try? JSONDecoder().decode([MembroDaEquipe].self, from: dados)
        else { return [] }
        return membros
    }

    static func salvar(
        _ membros: [MembroDaEquipe],
        equipeID: String,
        em defaults: UserDefaults = .standard
    ) {
        guard let dados = try? JSONEncoder().encode(membros) else { return }
        defaults.set(dados, forKey: chave(equipeID))
    }

    static func remover(equipeID: String, em defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: chave(equipeID))
    }
}

enum LimpezaDeVinculosDeEquipe {
    static func executar(
        equipes: [EquipeDisponivel],
        em defaults: UserDefaults = .standard
    ) {
        for equipe in equipes {
            MembrosDasEquipes.remover(equipeID: equipe.id, em: defaults)
        }
        EquipesDoUsuario.remover(em: defaults)
        defaults.removeObject(forKey: "equipeAtiva")
        defaults.removeObject(forKey: "contextoDaConta")
    }
}
