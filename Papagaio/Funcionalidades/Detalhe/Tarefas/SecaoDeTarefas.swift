import SwiftUI

struct SecaoDeTarefas: View {
    let titulo: String
    let cor: Color
    let tarefas: [TarefaDaConversa]
    let destino: DestinoDeTarefa
    let aoAlternarConclusao: (TarefaDaConversa) -> Void
    let aoEditar: (TarefaDaConversa) -> Void
    let aoMover: (UUID, DestinoDeTarefa) -> Void
    @State private var recebendoDrop = false

    var body: some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.medio) {
            HStack(spacing: PapagaioTema.Espaco.curto) {
                Circle()
                    .fill(cor)
                    .frame(width: 10, height: 10)

                Text(titulo)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(PapagaioTema.texto)

                Text("\(tarefas.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PapagaioTema.textoSecundario)
                    .frame(width: 26, height: 26)
                    .background(PapagaioTema.superficieSuave, in: Circle())

                Text("Arraste tarefas para cá")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PapagaioTema.textoSecundario)
            }
            .padding(.leading, PapagaioTema.Espaco.curto)

            VStack(spacing: PapagaioTema.Espaco.curto) {
                if tarefas.isEmpty {
                    Text("Solte uma tarefa aqui para mudar para \(titulo.lowercased()).")
                        .font(.callout)
                        .foregroundStyle(PapagaioTema.textoSecundario)
                        .frame(maxWidth: .infinity, minHeight: 62)
                        .background(PapagaioTema.superficie.opacity(0.45), in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))
                }

                ForEach(tarefas) { tarefa in
                    LinhaDeTarefaDaConversa(
                        tarefa: tarefa,
                        aoAlternarConclusao: { aoAlternarConclusao(tarefa) },
                        aoEditar: { aoEditar(tarefa) }
                    )
                    .draggable(tarefa.id.uuidString)
                }
            }
        }
        .padding(recebendoDrop ? 10 : 0)
        .background(
            recebendoDrop ? cor.opacity(0.08) : Color.clear,
            in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
        )
        .dropDestination(for: String.self) { ids, _ in
            guard let idTexto = ids.first,
                  let id = UUID(uuidString: idTexto)
            else { return false }
            aoMover(id, destino)
            return true
        } isTargeted: { ativo in
            recebendoDrop = ativo
        }
    }
}
