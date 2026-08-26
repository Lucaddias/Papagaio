import Foundation
import Observation
import PapagaioCore

/// Estado observavel e mutacoes do painel geral de tarefas.
@MainActor
@Observable
final class TarefasDoPainelViewModel {
    private(set) var tarefasPorConversa: [ArquivoID: [TarefaDaConversa]] = [:]

    /// Rele do armazenamento para incorporar mudancas feitas fora do painel.
    func recarregar(conversas: [Arquivo]) {
        var novo: [ArquivoID: [TarefaDaConversa]] = [:]
        for arquivo in conversas {
            let tarefas = TarefasGeraisStore.carregar(arquivo)
            if !tarefas.isEmpty {
                novo[arquivo.id] = tarefas
            }
        }
        tarefasPorConversa = novo
    }

    func tarefas(de arquivo: Arquivo) -> [TarefaDaConversa] {
        tarefasPorConversa[arquivo.id] ?? []
    }

    func salvar(_ tarefa: TarefaDaConversa, em arquivo: Arquivo, substituindo existente: Bool) {
        var tarefas = tarefas(de: arquivo)
        if existente, let indice = tarefas.firstIndex(where: { $0.id == tarefa.id }) {
            tarefas[indice] = tarefa
        } else {
            tarefas.append(tarefa)
        }
        persistir(tarefas, em: arquivo)
    }

    func alternarConclusao(_ id: UUID, em arquivo: Arquivo) {
        atualizar(id, em: arquivo) { editada in
            editada.status = editada.status == .concluida ? .emAndamento : .concluida
        }
    }

    func mover(_ id: UUID, para destino: DestinoDeTarefa, em arquivo: Arquivo) {
        atualizar(id, em: arquivo) { editada in
            editada.status = destino.status
        }
    }

    func excluir(_ tarefa: TarefaDaConversa, em arquivo: Arquivo, conversaTitulo: String) {
        let restantes = tarefas(de: arquivo).filter { $0.id != tarefa.id }
        persistir(restantes, em: arquivo)
        LixeiraDeTarefas.mover(tarefa, arquivoID: arquivo.id, conversaTitulo: conversaTitulo)
    }

    private func atualizar(
        _ id: UUID,
        em arquivo: Arquivo,
        alteracao: (inout TarefaDaConversa) -> Void
    ) {
        var tarefas = tarefas(de: arquivo)
        guard let indice = tarefas.firstIndex(where: { $0.id == id }) else { return }
        alteracao(&tarefas[indice])
        persistir(tarefas, em: arquivo)
    }

    private func persistir(_ tarefas: [TarefaDaConversa], em arquivo: Arquivo) {
        TarefasGeraisStore.salvar(tarefas, para: arquivo.id)
        tarefasPorConversa[arquivo.id] = tarefas.isEmpty ? nil : tarefas
    }
}
