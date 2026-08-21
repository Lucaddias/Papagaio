import SwiftUI

struct CartaoFiltroDeConversaTarefa: View {
    let conversa: TarefasDaConversaGeral
    let selecionado: Bool
    let vencimento: Date?
    let acao: () -> Void

    /// A mesma cor do cartão desta conversa na Biblioteca — não o status das
    /// tarefas. Este cartão é um atalho para "a conversa X", e a pessoa já
    /// reconhece essa conversa pela cor dela lá; uma cor diferente aqui era
    /// a mesma conversa parecendo duas coisas em duas telas.
    ///
    /// Mesma prioridade de `CartaoDeConversa.corDaTarjaLateral`: pasta vence
    /// tudo, depois a cor escolhida à mão, e só na ausência das duas cai no
    /// acento padrão da marca.
    private var corDeIdentidade: Color {
        let id = conversa.arquivo.id
        if let pasta = PreferenciasVisuaisDoArquivo.pasta(id) {
            return AparenciaDasPastas.corResolvida(de: pasta).acentoSobreSuperficie
        }
        if AparenciaDoCartao.semCor(id) {
            return PapagaioTema.destaqueEscuro
        }
        if let escolhida = AparenciaDoCartao.cor(id) {
            return escolhida.acentoSobreSuperficie
        }
        return PapagaioTema.destaqueEscuro
    }

    var body: some View {
        Button(action: acao) {
            HStack(spacing: PapagaioTema.Espaco.medio) {
                // O ícone leva a mesma cor da tarja — os dois dizem a mesma
                // coisa, o status geral das tarefas desta conversa, e não
                // fazia sentido um estar colorido e o outro cinza.
                Image(systemName: simbolo)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(selecionado ? PapagaioTema.destaqueEscuro : corDeIdentidade)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: PapagaioTema.Espaco.minimo) {
                    Text(conversa.titulo)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(selecionado ? PapagaioTema.destaqueEscuro : PapagaioTema.texto)
                        .lineLimit(1)

                    VStack(alignment: .leading, spacing: PapagaioTema.Espaco.minimo) {
                        Label("\(conversa.tarefas.count) \(conversa.tarefas.count == 1 ? "Tarefa" : "Tarefas")", systemImage: "list.clipboard")

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
            // Recuo extra à esquerda para o conteúdo não encostar na tarja.
            .padding(.leading, PapagaioTema.Espaco.curto)
            .frame(width: 254, height: 82)
            .background(selecionado ? PapagaioTema.destaqueSuave.opacity(0.82) : PapagaioTema.superficie, in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))
            .overlay(alignment: .leading) {
                // A tarja resume o status das tarefas desta conversa — a
                // mesma identidade que o quadro usa, só que numa pastilha.
                Rectangle().fill(corDeIdentidade).frame(width: 4)
            }
            .overlay {
                RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
                    .stroke(selecionado ? PapagaioTema.destaque : PapagaioTema.borda, lineWidth: selecionado ? 2 : 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))
            // Sem isto, só o texto e o ícone respondiam ao clique — o vazio
            // à direita do `Spacer` (boa parte do cartão) não abria nada.
            // O cartão inteiro precisa ser o alvo, não só onde há pixel
            // desenhado.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(selecionado ? "Desmarcar \(conversa.titulo)" : "Marcar \(conversa.titulo)")
    }

    // Balão de chat: este cartão representa a conversa (quem gerou as
    // tarefas), não as tarefas em si — esse ícone é o do quadro logo abaixo.
    private var simbolo: String {
        selecionado ? "bubble.left.and.text.bubble.right.fill" : "bubble.left"
    }

    private func rotuloDoVencimento(_ data: Date) -> String {
        if Calendar.current.isDateInToday(data) { return "Hoje" }
        if Calendar.current.isDateInTomorrow(data) { return "Amanhã" }
        return data.formatted(.dateTime.day().month(.abbreviated))
    }
}
