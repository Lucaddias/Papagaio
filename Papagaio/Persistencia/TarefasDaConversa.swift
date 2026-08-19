import Foundation
import PapagaioCore

enum TarefasDaConversa {
    static func carregar(
        _ arquivoID: ArquivoID,
        base proximosPassos: [ProximoPasso],
        tituloDaConversa: String,
        dataDaConversa: Date
    ) -> [TarefaDaConversa] {
        if let dados = UserDefaults.standard.data(forKey: chave(arquivoID)),
           let tarefas = try? JSONDecoder().decode([TarefaDaConversa].self, from: dados) {
            return tarefas
        }

        let tarefas = proximosPassos.enumerated().map { indice, passo in
            TarefaDaConversa(
                titulo: passo.descricao,
                origem: tituloDaConversa,
                prioridade: indice < 2 ? .alta : .media,
                status: .naoIniciado,
                responsavel: TarefaDaConversa.responsavelSaneado(passo.responsavel),
                prazo: Calendar.current.date(byAdding: .day, value: 7 + indice, to: dataDaConversa)
            )
        }
        salvar(tarefas, para: arquivoID)
        return tarefas
    }

    static func salvar(_ tarefas: [TarefaDaConversa], para arquivoID: ArquivoID) {
        guard let dados = try? JSONEncoder().encode(tarefas) else { return }
        UserDefaults.standard.set(dados, forKey: chave(arquivoID))
    }

    static func removerTodas() {
        let defaults = UserDefaults.standard
        for chave in defaults.dictionaryRepresentation().keys where chave.hasPrefix("tarefasDaConversa.") {
            defaults.removeObject(forKey: chave)
        }
    }

    private static func chave(_ arquivoID: ArquivoID) -> String {
        "tarefasDaConversa.\(arquivoID.rawValue.uuidString)"
    }
}
