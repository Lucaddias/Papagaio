import SwiftUI

struct LinhaDeTarefaDaConversa: View {
    let tarefa: TarefaDaConversa
    let aoAlternarConclusao: () -> Void
    let aoEditar: () -> Void

    private var concluida: Bool { tarefa.status == .concluida }
    private var dataDoPrazo: String {
        tarefa.prazo?.formatted(.dateTime.day().month().year()) ?? "Sem deadline"
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            conteudoHorizontal
            conteudoCompacto
        }
        .padding(.horizontal, PapagaioTema.Espaco.largo)
        .padding(.vertical, PapagaioTema.Espaco.medio)
        .frame(minHeight: 86)
        .background(PapagaioTema.superficie, in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
                .stroke(PapagaioTema.borda, lineWidth: 1)
        }
    }

    private var conteudoHorizontal: some View {
        HStack(spacing: PapagaioTema.Espaco.medio) {
            botaoConclusao

            tituloDaTarefa
                .frame(minWidth: 160, maxWidth: .infinity, alignment: .leading)

            SeparadorDaLinhaDeTarefa()
            ColunaDaTarefa(rotulo: "Prioridade") {
                SeloDePrioridade(prioridade: tarefa.prioridade)
            }
            .frame(minWidth: 96, idealWidth: 128, maxWidth: 150, alignment: .leading)

            SeparadorDaLinhaDeTarefa()
            ColunaDaTarefa(rotulo: "Responsável") {
                responsavelDaTarefa
            }
            .frame(minWidth: 130, idealWidth: 190, maxWidth: 220, alignment: .leading)

            SeparadorDaLinhaDeTarefa()
            ColunaDaTarefa(rotulo: "Status") {
                SeloDeStatusDaTarefa(status: tarefa.status)
            }
            .frame(minWidth: 96, idealWidth: 124, maxWidth: 150, alignment: .leading)

            SeparadorDaLinhaDeTarefa()
            ColunaDaTarefa(rotulo: "Data") {
                Label(dataDoPrazo, systemImage: concluida ? "checkmark.circle" : "calendar")
                    .font(.callout.weight(.bold))
                    .foregroundStyle(concluida ? PapagaioTema.sucesso : PapagaioTema.perigo)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .frame(minWidth: 104, idealWidth: 136, maxWidth: 160, alignment: .leading)

            botaoEditar
        }
    }

    private var conteudoCompacto: some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.medio) {
            HStack(alignment: .top, spacing: PapagaioTema.Espaco.medio) {
                botaoConclusao
                tituloDaTarefa
                Spacer()
                botaoEditar
            }

            Divider()
                .background(PapagaioTema.borda)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 135), spacing: PapagaioTema.Espaco.medio, alignment: .leading)],
                alignment: .leading,
                spacing: PapagaioTema.Espaco.medio
            ) {
                ColunaDaTarefa(rotulo: "Prioridade") {
                    SeloDePrioridade(prioridade: tarefa.prioridade)
                }
                ColunaDaTarefa(rotulo: "Responsável") {
                    responsavelDaTarefa
                }
                ColunaDaTarefa(rotulo: "Status") {
                    SeloDeStatusDaTarefa(status: tarefa.status)
                }
                ColunaDaTarefa(rotulo: "Data") {
                    Label(dataDoPrazo, systemImage: concluida ? "checkmark.circle" : "calendar")
                        .font(.callout.weight(.bold))
                        .foregroundStyle(concluida ? PapagaioTema.sucesso : PapagaioTema.perigo)
                        .monospacedDigit()
                        .lineLimit(1)
                }
            }
        }
    }

    private var botaoConclusao: some View {
        Button(action: aoAlternarConclusao) {
            Image(systemName: concluida ? "checkmark.square.fill" : "square")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(concluida ? PapagaioTema.sucesso : PapagaioTema.textoSecundario)
        }
        .buttonStyle(.plain)
        .help(concluida ? "Marcar como em andamento" : "Concluir")
    }

    private var botaoEditar: some View {
        Button(action: aoEditar) {
            Image(systemName: "pencil")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(PapagaioTema.textoSecundario)
                .frame(width: 34, height: 34)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Editar tarefa")
    }

    private var tituloDaTarefa: some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.minimo) {
            Text(tarefa.titulo)
                .font(.headline.weight(.semibold))
                .foregroundStyle(concluida ? PapagaioTema.textoSecundario : PapagaioTema.texto)
                .strikethrough(concluida, color: PapagaioTema.textoSecundario)
                .lineLimit(2)

            Text(tarefa.origem)
                .font(.callout)
                .foregroundStyle(PapagaioTema.textoSecundario)
                .lineLimit(1)
        }
    }

    private var responsavelDaTarefa: some View {
        HStack(spacing: PapagaioTema.Espaco.curto) {
            if let responsavel = tarefa.responsavelValido {
                AvatarDePessoa(nome: responsavel, diametro: 30)

                Text(responsavel)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(PapagaioTema.textoSecundario)
                    .lineLimit(1)
            } else {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(PapagaioTema.textoSecundario)
                    .frame(width: 30, height: 30)

                Text("Sem responsável")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(PapagaioTema.textoSecundario)
                    .lineLimit(1)
            }
        }
    }
}

struct ColunaDaTarefa<Conteudo: View>: View {
    let rotulo: String
    let conteudo: Conteudo

    init(rotulo: String, @ViewBuilder conteudo: () -> Conteudo) {
        self.rotulo = rotulo
        self.conteudo = conteudo()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.minimo) {
            Text(rotulo)
                .font(.caption2.weight(.bold))
                .foregroundStyle(PapagaioTema.textoSecundario)
                .textCase(.uppercase)
            conteudo
        }
    }
}

struct SeparadorDaLinhaDeTarefa: View {
    var body: some View {
        Rectangle()
            .fill(PapagaioTema.borda.opacity(0.85))
            .frame(width: 1, height: 44)
    }
}
