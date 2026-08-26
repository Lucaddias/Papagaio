import Foundation
import PapagaioCore

/// Remove todo estado auxiliar de uma conversa depois que SwiftData e a pasta
/// de gravação já foram excluídos com sucesso.
@MainActor
enum LimpezaDeArquivo {
    static func executar(_ id: ArquivoID, em defaults: UserDefaults = .standard) {
        TarefasDaConversa.remover(id, em: defaults)
        MidiasDaConversa.remover(id, em: defaults)
        PreferenciasVisuaisDoArquivo.remover(id, em: defaults)
        AparenciaDoCartao.remover(id, em: defaults)
        LixeiraDeMidia.removerRegistros(do: id, em: defaults)
        LixeiraDeTarefas.removerRegistros(do: id, em: defaults)
        LixeiraDePastas.removerReferencias(ao: id, em: defaults)
    }
}

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
    static func executar(em defaults: UserDefaults = .standard) {
        TarefasDaConversa.removerTodas(em: defaults)
        MidiasDaConversa.removerTodas(em: defaults)
        PreferenciasVisuaisDoArquivo.removerTodas(em: defaults)
        AparenciaDoCartao.removerTodas(em: defaults)
        AparenciaDasPastas.removerTodas(em: defaults)
        FotosDePessoas.removerTodas(em: defaults)
        LixeiraDeMidia.limparRegistros(em: defaults)
        LixeiraDeTarefas.esvaziar(em: defaults)
        LixeiraDePastas.esvaziar(em: defaults)

        // O espaço individual renasce na próxima abertura da biblioteca.
        defaults.removeObject(forKey: "espacoIndividual")
    }
}
