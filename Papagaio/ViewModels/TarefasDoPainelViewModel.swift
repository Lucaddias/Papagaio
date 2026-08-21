import Foundation
import Observation
import PapagaioCore

/// As tarefas do painel geral, observáveis.
///
/// Antes o estado vivia em `UserDefaults` atrás do `TarefasGeraisStore` e a
/// `TarefasView` forçava recomposição com um contador de versão
/// (`versaoDasTarefas`, lido com `_ =` nos computed properties). Aqui cada
/// mutação publica o estado novo e a tela recompõe sozinha — e a lógica de
/// criar/editar/mover/excluir sai da view.
@MainActor
@Observable
final class TarefasDoPainelViewModel {
    /// Tarefas por conversa, só com as conversas que têm alguma.
    private(set) var tarefasPorConversa: [ArquivoID: [TarefaDaConversa]] = [:]

    // MARK: - Carga

    /// Relê do disco. As mutações deste VM mantêm o estado atualizado; a
    /// recarga é para mudanças que vêm de fora (biblioteca nova, lixeira).
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

    // MARK: - Mutações

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
            if let prioridade = destino.prioridade {
                editada.prioridade = prioridade
            }
        }
    }

    /// Vai para a lixeira de tarefas em vez de sumir — de onde volta se a
    /// pessoa clicou sem querer.
    func excluir(_ tarefa: TarefaDaConversa, em arquivo: Arquivo, conversaTitulo: String) {
        let restantes = tarefas(de: arquivo).filter { $0.id != tarefa.id }
        persistir(restantes, em: arquivo)
        LixeiraDeTarefas.mover(tarefa, arquivoID: arquivo.id, conversaTitulo: conversaTitulo)
    }

    // MARK: - Apoio

    private func atualizar(_ id: UUID, em arquivo: Arquivo, alteracao: (inout TarefaDaConversa) -> Void) {
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
