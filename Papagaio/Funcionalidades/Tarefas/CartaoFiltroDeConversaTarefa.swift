import SwiftUI

struct CartaoFiltroDeConversaTarefa: View {
    let conversa: TarefasDaConversaGeral
    let selecionado: Bool
    let vencimento: Date?
    let acao: () -> Void

    var body: some View {
        Button(action: acao) {
            HStack(spacing: PapagaioTema.Espaco.medio) {
                Image(systemName: simbolo)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(selecionado ? PapagaioTema.destaqueEscuro : PapagaioTema.textoSecundario)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: PapagaioTema.Espaco.minimo) {
                    Text(conversa.titulo)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(selecionado ? PapagaioTema.destaqueEscuro : PapagaioTema.texto)
                        .lineLimit(1)

                    VStack(alignment: .leading, spacing: PapagaioTema.Espaco.minimo) {
                        Label("\(conversa.tarefas.count) \(conversa.tarefas.count == 1 ? "Tarefa" : "Tarefas")", systemImage: "checklist")

                        if let vencimento {
                            Label(rotuloDoVencimento(vencimento), systemImage: "calendar")
                        } else {
                            Label("Sem data", systemImage: "calendar.badge.clock")
                        }
                    }
                    .font(.callout.weight(.medium))
                    .foregroundStyle(PapagaioTema.textoSecundario)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, PapagaioTema.Espaco.largo)
            .frame(width: 254, height: 82)
            .background(selecionado ? PapagaioTema.destaqueSuave.opacity(0.82) : PapagaioTema.superficie, in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
                    .stroke(selecionado ? PapagaioTema.destaque : PapagaioTema.borda, lineWidth: selecionado ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(selecionado ? "Desmarcar \(conversa.titulo)" : "Marcar \(conversa.titulo)")
    }

    private var simbolo: String {
        selecionado ? "bubble.left.and.text.bubble.right.fill" : "bubble.left"
    }

    private func rotuloDoVencimento(_ data: Date) -> String {
        if Calendar.current.isDateInToday(data) { return "Hoje" }
        if Calendar.current.isDateInTomorrow(data) { return "Amanhã" }
        return data.formatted(.dateTime.day().month(.abbreviated))
    }
}
