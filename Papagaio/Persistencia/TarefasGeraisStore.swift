import Foundation
import PapagaioCore

enum TarefasGeraisStore {
    static func carregar(_ arquivo: Arquivo) -> [TarefaDaConversa] {
        if let dados = UserDefaults.standard.data(forKey: chave(arquivo.id)),
           let tarefas = try? JSONDecoder().decode([TarefaDaConversa].self, from: dados) {
            // Reaplicada a cada carga, e não só na criação: sem isto, uma
            // tarefa cujo prazo foi ficando perto só subia de prioridade se
            // alguém reabrisse a tela da conversa — a aba geral de Tarefas,
            // que lê direto daqui, nunca via a promoção.
            let ajustadas = tarefas.map(RegraDePrazoDaTarefa.ajustada)
            if ajustadas != tarefas {
                salvar(ajustadas, para: arquivo.id)
            }
            return ajustadas
        }

        let titulo = arquivo.resumo?.titulo ?? arquivo.titulo
        let tarefas = (arquivo.resumo?.proximosPassos ?? []).enumerated().map { indice, passo in
            TarefaDaConversa(
                titulo: passo.descricao,
                origem: titulo,
                prioridade: indice < 2 ? .alta : .media,
                status: .naoIniciado,
                responsavel: TarefaDaConversa.responsavelSaneado(passo.responsavel),
                prazo: Calendar.current.date(byAdding: .day, value: 7 + indice, to: arquivo.criadoEm)
            )
        }

        if !tarefas.isEmpty {
            salvar(tarefas, para: arquivo.id)
        }

        return tarefas
    }

    static func salvar(_ tarefas: [TarefaDaConversa], para arquivoID: ArquivoID) {
        guard let dados = try? JSONEncoder().encode(tarefas) else { return }
        UserDefaults.standard.set(dados, forKey: chave(arquivoID))
    }

    /// Duplica o estado atual das tarefas para uma conversa distinta. IDs e a
    /// origem precisam ser recriados: a cópia é uma nova conversa e não pode
    /// compartilhar a identidade nem continuar mostrando o título antigo.
    static func duplicar(_ arquivo: Arquivo, para copia: Arquivo) {
        let origemDaCopia = copia.resumo?.titulo ?? copia.titulo
        let tarefasCopiadas = carregar(arquivo).map { tarefa in
            TarefaDaConversa(
                titulo: tarefa.titulo,
                origem: origemDaCopia,
                prioridade: tarefa.prioridade,
                status: tarefa.status,
                responsavel: tarefa.responsavel,
                prazo: tarefa.prazo,
                descricao: tarefa.descricao
            )
        }

        guard !tarefasCopiadas.isEmpty else { return }
        salvar(tarefasCopiadas, para: copia.id)
    }

    static func remover(_ arquivoID: ArquivoID, em defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: chave(arquivoID))
    }

    private static func chave(_ arquivoID: ArquivoID) -> String {
        "tarefasDaConversa.\(arquivoID.rawValue.uuidString)"
    }
}
