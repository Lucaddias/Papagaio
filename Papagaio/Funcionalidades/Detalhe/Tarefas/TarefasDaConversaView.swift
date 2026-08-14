import SwiftUI

struct TarefasDaConversaView: View {
    let tarefas: [TarefaDaConversa]
    @Binding var filtro: FiltroDeTarefas
    let aoAdicionar: () -> Void
    let aoAlternarConclusao: (TarefaDaConversa) -> Void
    let aoEditar: (TarefaDaConversa) -> Void
    let aoMover: (UUID, DestinoDeTarefa) -> Void

    private var tarefasFiltradas: [TarefaDaConversa] {
        switch filtro {
        case .tudo:
            tarefas
        case .prioridadeAlta:
            tarefas.filter { $0.prioridade == .alta && $0.status != .concluida }
        case .emAndamento:
            tarefas.filter { $0.status == .emAndamento }
        case .concluidas:
            tarefas.filter { $0.status == .concluida }
        }
    }

    private var altas: [TarefaDaConversa] {
        tarefasFiltradas.filter { $0.prioridade == .alta && $0.status != .concluida }
    }

    private var emAndamento: [TarefaDaConversa] {
        tarefasFiltradas.filter { $0.status == .emAndamento && $0.prioridade != .alta }
    }

    private var concluidas: [TarefaDaConversa] {
        tarefasFiltradas.filter { $0.status == .concluida }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.secao) {
            HStack(alignment: .center, spacing: PapagaioTema.Espaco.medio) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: PapagaioTema.Espaco.curto) {
                    ForEach(FiltroDeTarefas.allCases) { opcao in
                        Button {
                            withAnimation(.snappy(duration: 0.18)) {
                                filtro = opcao
                            }
                        } label: {
                            Text(opcao.rawValue)
                                .font(.callout.weight(.semibold))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .foregroundStyle(filtro == opcao ? PapagaioTema.textoSobrePrimario : PapagaioTema.textoSecundario)
                                .padding(.horizontal, PapagaioTema.Espaco.largo)
                                .frame(height: PapagaioTema.Altura.padrao)
                                .background(
                                    filtro == opcao ? PapagaioTema.preenchimentoPrimario : PapagaioTema.superficie,
                                    in: Capsule()
                                )
                                .overlay {
                                    Capsule()
                                        .stroke(filtro == opcao ? Color.clear : PapagaioTema.borda, lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                // O conteúdo das tags tem largura intrínseca. Sem limitar o
                // viewport, ele tomava o espaço do botão de criar e a última
                // tag acabava cortada, em vez de poder ser rolada.
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(0)

                Button(action: aoAdicionar) {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(PapagaioTema.textoSobrePrimario)
                        .frame(width: 48, height: 48)
                        .background(PapagaioTema.preenchimentoPrimario, in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Adicionar tarefa")
                .layoutPriority(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if tarefasFiltradas.isEmpty {
                CartaoDeEstadoVazio(
                    simbolo: "checklist",
                    titulo: "Nenhuma tarefa aqui",
                    mensagem: "Use o botão de adicionar para criar uma tarefa nesta conversa."
                )
                .frame(minHeight: 280)
                .cartaoPapagaio()
            } else {
                VStack(alignment: .leading, spacing: PapagaioTema.Espaco.pagina) {
                    secoesVisiveis
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var secoesVisiveis: some View {
        switch filtro {
        case .tudo:
            secaoAlta(tarefas: altas)
            secaoEmAndamento(tarefas: emAndamento)
            secaoConcluidas(tarefas: concluidas)
        case .prioridadeAlta:
            secaoAlta(tarefas: tarefasFiltradas)
        case .emAndamento:
            secaoEmAndamento(tarefas: tarefasFiltradas)
        case .concluidas:
            secaoConcluidas(tarefas: tarefasFiltradas)
        }
    }

    private func secaoAlta(tarefas: [TarefaDaConversa]) -> some View {
        SecaoDeTarefas(
            titulo: "Prioridade alta",
            cor: PapagaioTema.perigo,
            tarefas: tarefas,
            destino: .alta,
            aoAlternarConclusao: aoAlternarConclusao,
            aoEditar: aoEditar,
            aoMover: aoMover
        )
    }

    private func secaoEmAndamento(tarefas: [TarefaDaConversa]) -> some View {
        SecaoDeTarefas(
            titulo: "Em andamento",
            cor: PapagaioTema.destaque,
            tarefas: tarefas,
            destino: .emAndamento,
            aoAlternarConclusao: aoAlternarConclusao,
            aoEditar: aoEditar,
            aoMover: aoMover
        )
    }

    private func secaoConcluidas(tarefas: [TarefaDaConversa]) -> some View {
        SecaoDeTarefas(
            titulo: "Concluídas",
            cor: PapagaioTema.sucesso,
            tarefas: tarefas,
            destino: .concluida,
            aoAlternarConclusao: aoAlternarConclusao,
            aoEditar: aoEditar,
            aoMover: aoMover
        )
    }
}
