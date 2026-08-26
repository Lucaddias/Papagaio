import Foundation
import PapagaioCore
import Testing
@testable import Papagaio

// A regra de prazo e o ciclo de vida das tarefas viviam duplicados dentro da
// `ArquivoDetalheView` — e, por isso, sem teste nenhum. Com a migração para o
// `TarefasDaConversaViewModel` (que já existia e ninguém usava), as decisões
// de domínio ficam aqui, exercitáveis sem montar a tela.
//
// Os testes usam um `ArquivoID` aleatório e não tocam nas tarefas reais do
// usuário: cada um escreve só na própria chave de `UserDefaults`.

@MainActor
private func viewModelLimpo() -> TarefasDaConversaViewModel {
    TarefasDaConversaViewModel(arquivoID: ArquivoID())
}

@MainActor
@Test("Prazo a dois dias ou menos promove a tarefa a prioridade alta")
func prazoCurtoPromovePrioridade() {
    let vm = viewModelLimpo()
    vm.tituloDaTarefa = "Entregar proposta"
    vm.prazoDaTarefa = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()

    vm.adicionar(origem: "Reunião")

    #expect(vm.tarefas.count == 1)
    #expect(vm.tarefas.first?.prioridade == .alta)
}

@MainActor
@Test("Prazo folgado mantém a prioridade escolhida")
func prazoFolgadoMantemPrioridade() {
    let vm = viewModelLimpo()
    vm.tituloDaTarefa = "Revisar contrato"
    vm.prazoDaTarefa = Calendar.current.date(byAdding: .day, value: 10, to: Date()) ?? Date()

    vm.adicionar(origem: "Reunião")

    #expect(vm.tarefas.first?.prioridade == .media)
}

@MainActor
@Test("Concluída não sobe de prioridade mesmo com prazo estourado")
func concluidaNaoSobePorPrazo() {
    let vm = viewModelLimpo()
    vm.tituloDaTarefa = "Já feita"
    vm.statusDaTarefa = .concluida
    vm.prazoDaTarefa = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()

    vm.adicionar(origem: "Reunião")

    #expect(vm.tarefas.first?.prioridade == .media)
    #expect(vm.tarefas.first?.status == .concluida)
}

@MainActor
@Test("Primeira carga cria tarefas dos próximos passos do resumo")
func cargaCriaBaseDosProximosPassos() {
    let vm = viewModelLimpo()
    let passos = [
        ProximoPasso(descricao: "Fechar o contrato", responsavel: "Luca"),
        ProximoPasso(descricao: "Enviar minuta", responsavel: nil),
        ProximoPasso(descricao: "Agendar assinatura", responsavel: nil),
    ]

    vm.carregar(base: passos, tituloDaConversa: "Kickoff", dataDaConversa: Date())

    #expect(vm.tarefas.count == 3)
    // Os dois primeiros nascem alta; o resto, média.
    #expect(vm.tarefas[0].prioridade == .alta)
    #expect(vm.tarefas[1].prioridade == .alta)
    #expect(vm.tarefas[2].prioridade == .media)
    #expect(vm.tarefas.allSatisfy { $0.status == .naoIniciado })
    #expect(vm.tarefas.allSatisfy { $0.origem == "Kickoff" })
}

@MainActor
@Test("Recarga devolve o que foi salvo, sem duplicar a base")
func recargaNaoDuplica() {
    let arquivoID = ArquivoID()
    let vm = TarefasDaConversaViewModel(arquivoID: arquivoID)
    vm.tituloDaTarefa = "Criada à mão"
    vm.adicionar(origem: "Reunião")

    let outra = TarefasDaConversaViewModel(arquivoID: arquivoID)
    outra.carregar(
        base: [ProximoPasso(descricao: "Da base", responsavel: nil)],
        tituloDaConversa: "Reunião",
        dataDaConversa: Date()
    )

    // Já havia tarefas salvas: a base do resumo não entra de novo.
    #expect(outra.tarefas.map(\.titulo) == ["Criada à mão"])
}

@Test("Responsáveis vêm da ficha local com nomes e e-mails pareados")
func responsaveisVemDaFicha() {
    let metadados = MetadadosVisuaisDoArquivo(
        entrevistado: "Ana Silva",
        emailDoEntrevistado: "ana@empresa.com",
        entrevistadores: "João Lima\nMaria Souza",
        emailDosEntrevistadores: "joao@empresa.com\n",
        descricao: "",
        formato: "",
        participantes: 3
    )

    let pessoas = ResponsavelDaTarefa.disponiveis(em: metadados)

    #expect(pessoas.map(\.nome) == ["João Lima", "Maria Souza", "Ana Silva"])
    #expect(pessoas.map(\.email) == ["joao@empresa.com", "", "ana@empresa.com"])
    #expect(Set(pessoas.map(\.id)).count == 3)
}

@Test("Responsáveis repetidos na ficha aparecem uma única vez")
func responsaveisDaFichaNaoDuplicam() {
    let metadados = MetadadosVisuaisDoArquivo(
        entrevistado: "Ána Silva",
        emailDoEntrevistado: "",
        entrevistadores: "ana silva\nPessoa sem nome",
        emailDosEntrevistadores: "\ncontato@empresa.com",
        descricao: "",
        formato: "",
        participantes: nil
    )

    let pessoas = ResponsavelDaTarefa.disponiveis(em: metadados)

    #expect(pessoas.count == 2)
    #expect(pessoas[0].nome == "ana silva")
    #expect(pessoas[1].email == "contato@empresa.com")
}
