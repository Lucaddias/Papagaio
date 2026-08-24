import Foundation
import PapagaioCore
import Testing
@testable import Papagaio

// O painel geral de tarefas recompunha na base do contador de versão
// (`versaoDasTarefas`, lido com `_ =` nos computed properties). Com o
// `TarefasDoPainelViewModel` observável, a lógica de criar/editar/mover vira
// domínio testável — e o contador morre.
//
// Cada teste usa um `Arquivo` com id próprio: escreve só na própria chave de
// `UserDefaults`, sem tocar os dados reais do usuário.

@MainActor
private func conversaDeTeste() -> Arquivo {
    Arquivo(
        titulo: "Conversa de teste",
        pastaRelativa: Armazenamento.caminhoRelativo(id: UUID()),
        espaco: EspacoID()
    )
}

@MainActor
@Test("Salvar cria a tarefa e persiste no disco")
func painelSalvaCriaEPersiste() {
    let vm = TarefasDoPainelViewModel()
    let conversa = conversaDeTeste()
    let tarefa = TarefaDaConversa(titulo: "Nova", origem: conversa.titulo, prioridade: .media, status: .emAndamento, responsavel: nil, prazo: nil)

    vm.salvar(tarefa, em: conversa, substituindo: false)

    #expect(vm.tarefas(de: conversa).map(\.titulo) == ["Nova"])
    // E foi para o disco, não só para a memória do VM.
    #expect(TarefasGeraisStore.carregar(conversa).map(\.titulo) == ["Nova"])
}

@MainActor
@Test("Salvar substituindo atualiza, não duplica")
func painelSalvaSubstitui() {
    let vm = TarefasDoPainelViewModel()
    let conversa = conversaDeTeste()
    let original = TarefaDaConversa(titulo: "Antes", origem: conversa.titulo, prioridade: .media, status: .emAndamento, responsavel: nil, prazo: nil)
    vm.salvar(original, em: conversa, substituindo: false)

    var editada = original
    editada.titulo = "Depois"
    vm.salvar(editada, em: conversa, substituindo: true)

    #expect(vm.tarefas(de: conversa).map(\.titulo) == ["Depois"])
}

@MainActor
@Test("Alternar conclusão inverte o status")
func painelAlternaConclusao() {
    let vm = TarefasDoPainelViewModel()
    let conversa = conversaDeTeste()
    let tarefa = TarefaDaConversa(titulo: "Fazer", origem: conversa.titulo, prioridade: .media, status: .emAndamento, responsavel: nil, prazo: nil)
    vm.salvar(tarefa, em: conversa, substituindo: false)

    vm.alternarConclusao(tarefa.id, em: conversa)
    #expect(vm.tarefas(de: conversa).first?.status == .concluida)

    vm.alternarConclusao(tarefa.id, em: conversa)
    #expect(vm.tarefas(de: conversa).first?.status == .emAndamento)
}

@MainActor
@Test("Mover aplica o status e a prioridade do destino")
func painelMoveParaDestino() {
    let vm = TarefasDoPainelViewModel()
    let conversa = conversaDeTeste()
    let tarefa = TarefaDaConversa(titulo: "Mover", origem: conversa.titulo, prioridade: .media, status: .emAndamento, responsavel: nil, prazo: nil)
    vm.salvar(tarefa, em: conversa, substituindo: false)

    vm.mover(tarefa.id, para: .alta, em: conversa)

    let movida = try! #require(vm.tarefas(de: conversa).first)
    #expect(movida.prioridade == .alta)
    #expect(movida.status == .emAndamento)
}

@MainActor
@Test("Recarga esquece conversas que ficaram sem tarefas")
func painelRecargaLimpaVazias() {
    let vm = TarefasDoPainelViewModel()
    let comTarefa = conversaDeTeste()
    let semTarefa = conversaDeTeste()
    vm.salvar(TarefaDaConversa(titulo: "Fica", origem: comTarefa.titulo, prioridade: .media, status: .emAndamento, responsavel: nil, prazo: nil), em: comTarefa, substituindo: false)

    vm.recarregar(conversas: [comTarefa, semTarefa])

    #expect(vm.tarefasPorConversa.keys.contains(comTarefa.id))
    #expect(!vm.tarefasPorConversa.keys.contains(semTarefa.id))
}
