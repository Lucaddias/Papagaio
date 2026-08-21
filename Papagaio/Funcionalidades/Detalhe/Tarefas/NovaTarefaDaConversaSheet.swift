import SwiftUI

struct NovaTarefaDaConversaSheet: View {
    enum Modo {
        case criacao
        case edicao

        var titulo: String {
            switch self {
            case .criacao: "Nova tarefa"
            case .edicao: "Editar tarefa"
            }
        }

        var botao: String {
            switch self {
            case .criacao: "Adicionar tarefa"
            case .edicao: "Salvar alterações"
            }
        }

        var simbolo: String {
            switch self {
            case .criacao: "list.clipboard"
            case .edicao: "pencil"
            }
        }
    }

    let modo: Modo
    @Binding var titulo: String
    @Binding var responsavel: String
    @Binding var prioridade: PrioridadeDaTarefa
    @Binding var status: StatusDaTarefa
    @Binding var prazo: Date
    let responsaveisDisponiveis: [ResponsavelDaTarefa]
    let aoCancelar: () -> Void
    let aoAdicionar: () -> Void

    private var podeAdicionar: Bool {
        !titulo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var prazoEstaPerto: Bool {
        let calendario = Calendar.current
        let hoje = calendario.startOfDay(for: Date())
        let diaDoPrazo = calendario.startOfDay(for: prazo)
        let dias = calendario.dateComponents([.day], from: hoje, to: diaDoPrazo).day ?? Int.max
        return dias <= 2
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.secao) {
            HStack(alignment: .top, spacing: PapagaioTema.Espaco.medio) {
                Image(systemName: modo.simbolo)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(PapagaioTema.destaqueEscuro)
                    .frame(width: 44, height: 44)
                    .background(PapagaioTema.destaqueSuave, in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))

                VStack(alignment: .leading, spacing: PapagaioTema.Espaco.minimo) {
                    Text(modo.titulo)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(PapagaioTema.texto)

                    Text("Defina título, responsável, prioridade e deadline antes de salvar.")
                        .font(.callout)
                        .foregroundStyle(PapagaioTema.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            VStack(alignment: .leading, spacing: PapagaioTema.Espaco.curto) {
                Text("Título")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PapagaioTema.textoSecundario)

                TextField("Ex.: Revisar pontos da entrevista", text: $titulo)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .padding(.horizontal, PapagaioTema.Espaco.medio)
                    .frame(height: PapagaioTema.Altura.padrao)
                    .background(PapagaioTema.superficie, in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
                            .stroke(PapagaioTema.borda, lineWidth: 1)
                    }
            }

            VStack(alignment: .leading, spacing: PapagaioTema.Espaco.curto) {
                Text("Responsável")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PapagaioTema.textoSecundario)

                VStack(spacing: PapagaioTema.Espaco.curto) {
                    Menu {
                        Button("Sem responsável") {
                            responsavel = ""
                        }

                        ForEach(responsaveisDisponiveis) { pessoa in
                            Button {
                                responsavel = pessoa.rotulo
                            } label: {
                                Text(pessoa.rotulo)
                            }
                        }
                    } label: {
                        HStack(spacing: PapagaioTema.Espaco.curto) {
                            Image(systemName: "person.crop.circle")
                            Text(responsavel.isEmpty ? "Escolher da equipe" : responsavel)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.bold))
                        }
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(PapagaioTema.texto)
                        .padding(.horizontal, PapagaioTema.Espaco.medio)
                        .frame(height: PapagaioTema.Altura.padrao)
                        .background(PapagaioTema.superficie, in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
                                .stroke(PapagaioTema.borda, lineWidth: 1)
                        }
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)

                    TextField("Ou digite nome, e-mail ou login", text: $responsavel)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .padding(.horizontal, PapagaioTema.Espaco.medio)
                        .frame(height: PapagaioTema.Altura.padrao)
                        .background(PapagaioTema.superficie, in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
                                .stroke(PapagaioTema.borda, lineWidth: 1)
                        }
                }
            }

            VStack(alignment: .leading, spacing: PapagaioTema.Espaco.curto) {
                Text("Prioridade")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PapagaioTema.textoSecundario)

                ControleSegmentadoPapagaio(
                    opcoes: PrioridadeDaTarefa.allCases,
                    selecionado: $prioridade,
                    titulo: { $0.rawValue },
                    simbolo: { _ in nil }
                )
            }

            VStack(alignment: .leading, spacing: PapagaioTema.Espaco.curto) {
                Text("Deadline")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PapagaioTema.textoSecundario)

                CampoDeDataPapagaio(data: $prazo, rotuloAcessivel: "Data de entrega")

                if prazoEstaPerto && status != .concluida {
                    Label("Deadline perto: a tarefa será marcada como prioridade alta.", systemImage: "bell.badge")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PapagaioTema.perigo)
                }
            }

            HStack(spacing: PapagaioTema.Espaco.medio) {
                Button("Cancelar", action: aoCancelar)
                    .buttonStyle(BotaoDeContornoPapagaio())

                Spacer()

                Button(modo.botao, systemImage: modo == .criacao ? "plus" : "checkmark") {
                    aoAdicionar()
                }
                .buttonStyle(BotaoPrincipalPapagaio())
                .disabled(!podeAdicionar)
                .keyboardShortcut(.return, modifiers: [.command])
            }
        }
        .padding(PapagaioTema.Espaco.secao)
        .frame(minWidth: 340, idealWidth: 500, maxWidth: 520, alignment: .leading)
        .background(PapagaioTema.fundo)
    }
}
