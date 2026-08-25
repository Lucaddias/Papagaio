import Foundation

/// Caminho único da exclusão de dados da conta local.
///
/// Antes a cascata vivia espalhada na `ContentView`: cada store novo era um
/// convite para esquecer uma limpeza. Aqui todo store que guarda dados da
/// conta se registra — um lugar só para auditar o que sai quando a pessoa
/// exclui a conta.
///
/// Preferências do app e modelos baixados ficam de fora de propósito: uma
/// conta nova não precisa reconfigurar a aparência nem baixar pesos de novo.
@MainActor
enum LimpezaDeConta {
    static func executar() {
        TarefasDaConversa.removerTodas()
        MidiasDaConversa.removerTodas()
        PreferenciasVisuaisDoArquivo.removerTodas()
        LixeiraDeMidia.limparRegistros()
        LixeiraDeTarefas.esvaziar()

        // O espaço individual renasce na próxima abertura da biblioteca.
        UserDefaults.standard.removeObject(forKey: "espacoIndividual")
    }
}
