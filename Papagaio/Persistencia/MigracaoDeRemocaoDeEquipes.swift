import Foundation

/// Remove, uma única vez, o estado local da funcionalidade de equipes que não
/// faz mais parte do produto. A lista de membros usava uma chave por equipe;
/// apagar apenas `equipesDoUsuario` deixava nomes e e-mails órfãos no disco.
enum MigracaoDeRemocaoDeEquipes {
    private static let chaveDeControle = "migracaoDeRemocaoDeEquipes.v1"
    /// `v1` já pode ter apagado a lista de equipes antes de esta correção ser
    /// instalada. Por isso a migração do banco tem uma chave própria: ela
    /// precisa rodar também nessas instalações, e só termina depois de o
    /// SwiftData confirmar que todos os registros foram para o espaço pessoal.
    private static let chaveDaBiblioteca = "migracaoDeRemocaoDeEquipes.biblioteca.v2"
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

    static func bibliotecaPrecisaSerMigrada(_ defaults: UserDefaults = .standard) -> Bool {
        !defaults.bool(forKey: chaveDaBiblioteca)
    }

    static func concluirMigracaoDaBiblioteca(_ defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: chaveDaBiblioteca)
    }
}
