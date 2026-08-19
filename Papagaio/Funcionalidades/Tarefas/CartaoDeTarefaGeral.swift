import SwiftUI

struct CartaoDeTarefaGeral: View {
    let tarefa: TarefaGeral
    let aoEditar: () -> Void
    let aoAlternarConclusao: () -> Void
    let aoExcluir: () -> Void

    private var concluida: Bool { tarefa.tarefa.status == .concluida }

    var body: some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.medio) {
            HStack {
                // Só a prioridade — que é dado da tarefa, escolhido por
                // alguém. O status já está dito pela coluna em que o cartão
                // está; repeti-lo aqui em cima era a mesma informação duas
                // vezes na mesma tela.
                SeloDePrioridade(prioridade: tarefa.tarefa.prioridade)
                Spacer()
                Menu {
                    Button("Editar", systemImage: "pencil", action: aoEditar)
                    // "Marcar concluída" saiu daqui: com três colunas agora, o
                    // gesto que muda o status é arrastar o cartão até a que
                    // representa o novo estado — este atalho pulava direto
                    // para Concluída, sem passar por Em andamento.
                    Button("Excluir", systemImage: "trash", role: .destructive, action: aoExcluir)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(PapagaioTema.textoSecundario)
                        .frame(width: 30, height: 30)
                        .contentShape(Circle())
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .help("Ações da tarefa")
            }

            VStack(alignment: .leading, spacing: PapagaioTema.Espaco.minimo) {
                Text(tarefa.tarefa.titulo)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(concluida ? PapagaioTema.textoSecundario : PapagaioTema.texto)
                    .strikethrough(concluida, color: PapagaioTema.textoSecundario)
                    .lineLimit(2)

                Text(tarefa.conversa.titulo)
                    .font(.callout)
                    .foregroundStyle(PapagaioTema.textoSecundario)
                    .lineLimit(1)
            }

            Label(rotuloDoPrazo, systemImage: concluida ? "checkmark.circle" : "calendar")
                .font(.caption.weight(.bold))
                .foregroundStyle(corDoPrazo)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(PapagaioTema.Espaco.largo)
        // A grade fica muito mais fácil de varrer quando cada tarefa ocupa o
        // mesmo retângulo; título longo é truncado nas duas linhas acima.
        // Mais baixo que antes: sem o selo de status e sem a linha do
        // responsável, o retângulo antigo sobrava embaixo, vazio.
        .frame(maxWidth: .infinity, minHeight: 128, maxHeight: 128, alignment: .topLeading)
        // Mesmo raio de todo cartão do app — o de "controle" (8pt, botão e
        // campo) fazia este cartão parecer um componente pequeno, não a
        // mesma superfície do cartão de conversa ao lado dele na Biblioteca.
        .cartaoPapagaio()
        .shadow(color: PapagaioTema.destaque.opacity(0.08), radius: 10, y: 6)
    }

    private var rotuloDoPrazo: String {
        guard let prazo = tarefa.tarefa.prazo else { return "Sem deadline" }
        if Calendar.current.isDateInToday(prazo) { return "Hoje" }
        if Calendar.current.isDateInTomorrow(prazo) { return "Amanhã" }
        return prazo.formatted(.dateTime.day().month().year())
    }

    private var corDoPrazo: Color {
        guard let prazo = tarefa.tarefa.prazo, !concluida else { return PapagaioTema.textoSecundario }
        if prazo <= Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date() {
            return PapagaioTema.perigo
        }
        return PapagaioTema.textoSecundario
    }
}
