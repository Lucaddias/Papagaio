import Foundation

enum MembrosDasEquipes {
    private static func chave(_ equipeID: String) -> String {
        "membrosDaEquipe.\(equipeID)"
    }

    /// Equipe sem nada salvo não tem membro nenhum — quem acabou de criar uma
    /// equipe começa com a lista vazia e convida as pessoas de verdade.
    static func carregar(equipeID: String) -> [MembroDaEquipe] {
        guard let dados = UserDefaults.standard.data(forKey: chave(equipeID)),
              let membros = try? JSONDecoder().decode([MembroDaEquipe].self, from: dados)
        else { return [] }
        return membros
    }

    static func salvar(_ membros: [MembroDaEquipe], equipeID: String) {
        guard let dados = try? JSONEncoder().encode(membros) else { return }
        UserDefaults.standard.set(dados, forKey: chave(equipeID))
    }
}
