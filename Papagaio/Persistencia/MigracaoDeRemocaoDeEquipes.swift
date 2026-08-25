import Foundation

/// Remove, uma única vez, o estado local da funcionalidade de equipes que não
/// faz mais parte do produto. A lista de membros usava uma chave por equipe;
/// apagar apenas `equipesDoUsuario` deixava nomes e e-mails órfãos no disco.
enum MigracaoDeRemocaoDeEquipes {
    private static let chaveDeControle = "migracaoDeRemocaoDeEquipes.v1"
    private static let prefixoDeMembros = "membrosDaEquipe."

    static func executarUmaVez(_ defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: chaveDeControle) else { return }

        for chave in defaults.dictionaryRepresentation().keys
        where chave.hasPrefix(prefixoDeMembros) {
            defaults.removeObject(forKey: chave)
        }

        defaults.removeObject(forKey: "equipesDoUsuario")
        defaults.removeObject(forKey: "equipeAtiva")
        defaults.removeObject(forKey: "contextoDaConta")
        defaults.removeObject(forKey: "limpezaDeDadosFabricados.v1")
        defaults.set(true, forKey: chaveDeControle)
    }
}
