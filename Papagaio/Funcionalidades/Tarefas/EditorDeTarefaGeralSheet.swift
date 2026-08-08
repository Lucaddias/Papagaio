import PapagaioCore
import SwiftUI

struct EditorDeTarefaGeralSheet: View {
    enum Modo {
        case criacao
        case edicao
    }

    let modo: Modo
    let conversas: [Arquivo]
    @Binding var conversaSelecionada: ArquivoID?
    @Binding var titulo: String
    @Binding var responsavel: String
    @Binding var prioridade: PrioridadeDaTarefa
    @Binding var status: StatusDaTarefa
    @Binding var prazo: Date
    let aoCancelar: () -> Void
    let aoSalvar: () -> Void

    private var conversaAtual: Arquivo? {
        guard let conversaSelecionada else { return nil }
        return conversas.first { $0.id == conversaSelecionada }
    }

    private var podeSalvar: Bool {
        conversaSelecionada != nil && !titulo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.secao) {
            HStack(alignment: .top, spacing: PapagaioTema.Espaco.medio) {
                Image(systemName: modo == .criacao ? "plus.circle" : "pencil")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(PapagaioTema.destaqueEscuro)
                    .frame(width: 46, height: 46)
                    .background(PapagaioTema.destaqueSuave, in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))

                VStack(alignment: .leading, spacing: PapagaioTema.Espaco.minimo) {
                    Text(modo == .criacao ? "Nova tarefa" : "Editar tarefa")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(PapagaioTema.texto)
                    Text("Escolha a conversa, prioridade, responsável e data limite.")
                        .font(.callout)
                        .foregroundStyle(PapagaioTema.textoSecundario)
                }

                Spacer()
            }

            campo("Conversa") {
                Menu {
                    ForEach(conversas) { conversa in
                        Button(conversa.resumo?.titulo ?? conversa.titulo) {
                            conversaSelecionada = conversa.id
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "bubble.left")
                        Text(conversaAtual.map { $0.resumo?.titulo ?? $0.titulo } ?? "Escolher conversa")
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
            }

            campo("Título") {
                TextField("Ex.: Revisar documentação", text: $titulo)
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

            campo("Responsável") {
                TextField("Nome, e-mail ou login", text: $responsavel)
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

            campo("Prioridade") {
                ControleSegmentadoPapagaio(
                    opcoes: PrioridadeDaTarefa.allCases,
                    selecionado: $prioridade,
                    titulo: { $0.rawValue },
                    simbolo: { _ in nil }
                )
            }

            campo("Data limite") {
                CampoDeDataPapagaio(data: $prazo, rotuloAcessivel: "Data limite")
            }

            HStack(spacing: PapagaioTema.Espaco.medio) {
                Button("Cancelar", action: aoCancelar)
                    .buttonStyle(BotaoDeContornoPapagaio())

                Spacer()

                Button(modo == .criacao ? "Adicionar tarefa" : "Salvar alterações", systemImage: modo == .criacao ? "plus" : "checkmark") {
                    aoSalvar()
                }
                .buttonStyle(BotaoPrincipalPapagaio())
                .disabled(!podeSalvar)
            }
        }
        .padding(PapagaioTema.Espaco.secao)
        .frame(width: 540, alignment: .leading)
        .background(PapagaioTema.fundo)
    }

    private func campo<Conteudo: View>(_ titulo: String, @ViewBuilder conteudo: () -> Conteudo) -> some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.curto) {
            Text(titulo)
                .font(.caption.weight(.bold))
                .foregroundStyle(PapagaioTema.textoSecundario)
            conteudo()
        }
    }
}
