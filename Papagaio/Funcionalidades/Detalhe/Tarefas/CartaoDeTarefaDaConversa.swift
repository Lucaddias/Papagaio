import SwiftUI

/// A tarefa de uma conversa, no mesmo desenho de cartão do Painel de Tarefas
/// geral — prioridade e ação em cima, título no meio, data embaixo à direita.
///
/// Existe para substituir `LinhaDeTarefaDaConversa`, que era uma linha de
/// planilha: título à esquerda e depois prioridade, responsável, status e data
/// em colunas esticando para a direita. Section por section já empilhava na
/// vertical; só a tarefa dentro de cada seção ainda pensava em linha. Aqui ela
/// também não pensa mais.
///
/// Sem o nome da conversa embaixo do título — que o cartão do painel geral
/// mostra porque reúne tarefas de várias conversas ao mesmo tempo. Aqui dentro
/// de uma conversa só, repetir o nome dela em cada cartão seria repetir o
/// título da própria página.
struct CartaoDeTarefaDaConversa: View {
    let tarefa: TarefaDaConversa
    let aoAlternarConclusao: () -> Void
    let aoEditar: () -> Void

    private var concluida: Bool { tarefa.status == .concluida }

    var body: some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.medio) {
            HStack {
                SeloDePrioridade(prioridade: tarefa.prioridade)
                Spacer()
                botaoEditar
            }

            HStack(alignment: .top, spacing: PapagaioTema.Espaco.curto) {
                botaoConclusao

                Text(tarefa.titulo)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(concluida ? PapagaioTema.textoSecundario : PapagaioTema.texto)
                    .strikethrough(concluida, color: PapagaioTema.textoSecundario)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Label(rotuloDoPrazo, systemImage: concluida ? "checkmark.circle" : "calendar")
                .font(.caption.weight(.bold))
                .foregroundStyle(corDoPrazo)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(PapagaioTema.Espaco.largo)
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
        .cartaoPapagaio()
        .shadow(color: PapagaioTema.destaque.opacity(0.08), radius: 10, y: 6)
    }

    private var botaoConclusao: some View {
        Button(action: aoAlternarConclusao) {
            Image(systemName: concluida ? "checkmark.square.fill" : "square")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(concluida ? PapagaioTema.sucesso : PapagaioTema.textoSecundario)
                .padding(.top, 1)
        }
        .buttonStyle(.plain)
        .help(concluida ? "Marcar como em andamento" : "Concluir")
    }

    private var botaoEditar: some View {
        Button(action: aoEditar) {
            Image(systemName: "pencil")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(PapagaioTema.textoSecundario)
                .frame(width: 28, height: 28)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Editar tarefa")
    }

    private var rotuloDoPrazo: String {
        guard let prazo = tarefa.prazo else { return "Sem deadline" }
        if Calendar.current.isDateInToday(prazo) { return "Hoje" }
        if Calendar.current.isDateInTomorrow(prazo) { return "Amanhã" }
        return prazo.formatted(.dateTime.day().month().year())
    }

    private var corDoPrazo: Color {
        guard let prazo = tarefa.prazo, !concluida else { return PapagaioTema.textoSecundario }
        if prazo <= Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date() {
            return PapagaioTema.perigo
        }
        return PapagaioTema.textoSecundario
    }
}
