import Foundation
import Testing
@testable import Papagaio

// A ordenação e o filtro de prazo do painel viviam privados na TarefasView.
// Extraídos para `OrdenacaoDeTarefas` e já presentes em
// `FiltroDeDeadlineTarefa`, ganham teste sem montar a tela.

private func tarefa(
    _ titulo: String,
    prazo: Date? = nil,
    prioridade: PrioridadeDaTarefa = .media
) -> TarefaDaConversa {
    TarefaDaConversa(
        titulo: titulo,
        origem: "Teste",
        prioridade: prioridade,
        status: .emAndamento,
        responsavel: nil,
        prazo: prazo
    )
}

private var amanha: Date {
    Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
}

private var depois: Date {
    Calendar.current.date(byAdding: .day, value: 5, to: Date()) ?? Date()
}

@Test("Prazo mais cedo vem primeiro")
func deadlineMaisCedoPrimeiro() {
    let cedo = tarefa("Cedo", prazo: amanha)
    let tarde = tarefa("Tarde", prazo: depois)

    #expect(OrdenacaoDeTarefas.porDeadline(cedo, tarde))
    #expect(!OrdenacaoDeTarefas.porDeadline(tarde, cedo))
}

@Test("Mesmo dia resolve por prioridade, depois por título")
func empateNoDia() {
    // Um instante só para os dois: o empate precisa ser de verdade, senão o
    // desempate por prazo decide antes da prioridade.
    let dia = amanha
    let alta = tarefa("Zebra", prazo: dia, prioridade: .alta)
    let media = tarefa("Abelha", prazo: dia, prioridade: .media)

    // Alta vence mesmo com título "maior".
    #expect(OrdenacaoDeTarefas.porDeadline(alta, media))

    let uma = tarefa("Uma", prazo: dia, prioridade: .media)
    let duas = tarefa("Duas", prazo: dia, prioridade: .media)

    // Mesma prioridade: título decide.
    #expect(OrdenacaoDeTarefas.porDeadline(duas, uma))
}

@Test("Tarefa sem prazo vai para o fim")
func semPrazoPorUltimo() {
    let comPrazo = tarefa("Com", prazo: depois)
    let semPrazo = tarefa("Sem")

    #expect(OrdenacaoDeTarefas.porDeadline(comPrazo, semPrazo))
    #expect(!OrdenacaoDeTarefas.porDeadline(semPrazo, comPrazo))
}

@Test("Ordenação por prioridade agrupa alta antes de média e baixa")
func prioridadeAgrupa() {
    let baixa = tarefa("Baixa", prazo: amanha, prioridade: .baixa)
    let alta = tarefa("Alta", prazo: depois, prioridade: .alta)

    // O prazo da alta é pior, mas a prioridade manda.
    #expect(OrdenacaoDeTarefas.porPrioridade(alta, baixa))
}

@Test("Filtro de prazo separa atrasadas, hoje, próximos sete dias e sem data")
func filtroDeDeadlineClassifica() {
    let ontem = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()

    #expect(FiltroDeDeadlineTarefa.atrasadas.inclui(ontem))
    #expect(!FiltroDeDeadlineTarefa.atrasadas.inclui(amanha))
    #expect(!FiltroDeDeadlineTarefa.atrasadas.inclui(nil))

    #expect(FiltroDeDeadlineTarefa.hoje.inclui(Date()))
    #expect(!FiltroDeDeadlineTarefa.hoje.inclui(amanha))

    #expect(FiltroDeDeadlineTarefa.proximosSeteDias.inclui(amanha))
    #expect(!FiltroDeDeadlineTarefa.proximosSeteDias.inclui(ontem))

    #expect(FiltroDeDeadlineTarefa.semData.inclui(nil))
    #expect(!FiltroDeDeadlineTarefa.semData.inclui(amanha))

    #expect(FiltroDeDeadlineTarefa.todas.inclui(nil))
    #expect(FiltroDeDeadlineTarefa.todas.inclui(ontem))
}
