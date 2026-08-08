import SwiftUI

struct ColunaDeTarefasGerais: View {
    let titulo: String
    let cor: Color
    let tarefas: [TarefaGeral]
    let aoEditar: (TarefaGeral) -> Void
    let aoAlternarConclusao: (TarefaGeral) -> Void
    let aoExcluir: (TarefaGeral) -> Void
    let aoMover: (String, DestinoDeTarefa) -> Void
    @State private var recebendoDrop = false

    private var destino: DestinoDeTarefa {
        if titulo.localizedCaseInsensitiveContains("alta") { return .alta }
        if titulo.localizedCaseInsensitiveContains("conclu") { return .concluida }
        return .emAndamento
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.medio) {
            HStack(spacing: PapagaioTema.Espaco.curto) {
                Circle()
                    .fill(cor)
                    .frame(width: 9, height: 9)

                Text(titulo)
                    .font(.callout.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(PapagaioTema.textoSecundario)

                Text("\(tarefas.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PapagaioTema.textoSecundario)
                    .padding(.horizontal, PapagaioTema.Espaco.curto)
                    .padding(.vertical, PapagaioTema.Espaco.minimo)
                    .background(PapagaioTema.superficieSuave, in: Capsule())
            }
            .padding(.horizontal, PapagaioTema.Espaco.curto)
            .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
            .background(PapagaioTema.superficie.opacity(0.48), in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))

            VStack(spacing: PapagaioTema.Espaco.medio) {
                if tarefas.isEmpty {
                    Text("Solte uma tarefa aqui.")
                        .font(.callout)
                        .foregroundStyle(PapagaioTema.textoSecundario)
                        .frame(maxWidth: .infinity, minHeight: 72)
                        .background(PapagaioTema.superficie.opacity(0.45), in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))
                } else {
                    ForEach(tarefas) { tarefa in
                        CartaoDeTarefaGeral(
                            tarefa: tarefa,
                            aoEditar: { aoEditar(tarefa) },
                            aoAlternarConclusao: { aoAlternarConclusao(tarefa) },
                            aoExcluir: { aoExcluir(tarefa) }
                        )
                        .draggable(tarefa.id)
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 320, alignment: .top)
        }
        .frame(maxWidth: .infinity, minHeight: 390, alignment: .top)
        .padding(recebendoDrop ? 10 : 0)
        .contentShape(RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))
        .background(
            recebendoDrop ? cor.opacity(0.08) : Color.clear,
            in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
        )
        .dropDestination(for: String.self) { ids, _ in
            guard let id = ids.first else { return false }
            aoMover(id, destino)
            return true
        } isTargeted: { ativo in
            recebendoDrop = ativo
        }
    }
}
