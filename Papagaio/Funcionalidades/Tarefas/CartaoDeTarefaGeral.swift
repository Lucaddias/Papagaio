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
                SeloDePrioridade(prioridade: tarefa.tarefa.prioridade)
                Spacer()
                SeloDeStatusDaTarefa(status: tarefa.tarefa.status)
                Menu {
                    Button("Editar", systemImage: "pencil", action: aoEditar)
                    Button(concluida ? "Marcar em andamento" : "Marcar concluída", systemImage: concluida ? "clock" : "checkmark", action: aoAlternarConclusao)
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

            HStack(spacing: PapagaioTema.Espaco.curto) {
                avatarResponsavel
                Spacer(minLength: 0)
                Label(rotuloDoPrazo, systemImage: concluida ? "checkmark.circle" : "calendar")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(corDoPrazo)
                    .lineLimit(1)
            }

        }
        .padding(PapagaioTema.Espaco.largo)
        // A grade fica muito mais fácil de varrer quando cada tarefa ocupa o
        // mesmo retângulo; título longo é truncado nas duas linhas acima.
        .frame(maxWidth: .infinity, minHeight: 156, maxHeight: 156, alignment: .topLeading)
        // Mesmo raio de todo cartão do app — o de "controle" (8pt, botão e
        // campo) fazia este cartão parecer um componente pequeno, não a
        // mesma superfície do cartão de conversa ao lado dele na Biblioteca.
        .cartaoPapagaio()
        .shadow(color: PapagaioTema.destaque.opacity(0.08), radius: 10, y: 6)
    }

    private var avatarResponsavel: some View {
        HStack(spacing: PapagaioTema.Espaco.curto) {
            if let nome = tarefa.tarefa.responsavelValido {
                // O mesmo avatar do cartão de conversa: se a pessoa já tem
                // foto cadastrada em algum lugar do app, ela aparece aqui
                // também, em vez de reinventar iniciais soltas.
                AvatarDePessoa(nome: nome, diametro: 28)

                Text(nome)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PapagaioTema.textoSecundario)
                    .lineLimit(1)
            } else {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 20))
                    .foregroundStyle(PapagaioTema.textoSecundario.opacity(0.6))
                    .frame(width: 28, height: 28)

                Text("Sem responsável")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PapagaioTema.textoSecundario)
                    .lineLimit(1)
            }
        }
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
