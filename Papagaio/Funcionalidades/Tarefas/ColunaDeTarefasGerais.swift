import SwiftUI

struct ColunaDeTarefasGerais: View {
    let titulo: String
    let cor: Color
    let tarefas: [TarefaGeral]
    let aoEditar: (TarefaGeral) -> Void
    let aoAlternarConclusao: (TarefaGeral) -> Void
    let aoExcluir: (TarefaGeral) -> Void
    let aoMover: (String, DestinoDeTarefa) -> Void
    let compacto: Bool
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

            VStack(spacing: compacto ? PapagaioTema.Espaco.curto : PapagaioTema.Espaco.medio) {
                if tarefas.isEmpty {
                    Text("Solte uma tarefa aqui.")
                        .font(.callout)
                        .foregroundStyle(PapagaioTema.textoSecundario)
                        .frame(maxWidth: .infinity, minHeight: compacto ? 44 : 72)
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

                if compacto {
                    // Em modo vertical a coluna encolhe para a altura dos
                    // cards. Sem esta faixa, só alguns poucos pixels viravam
                    // destino de soltura e mover uma tarefa era impreciso.
                    Label("Arraste uma tarefa para cá", systemImage: "arrow.down.to.line")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(PapagaioTema.textoSecundario)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            recebendoDrop ? cor.opacity(0.12) : PapagaioTema.superficie.opacity(0.45),
                            in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
                        )
                } else {
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, minHeight: compacto ? 0 : 320, alignment: .top)
        }
        .frame(maxWidth: .infinity, minHeight: compacto ? 0 : 390, alignment: .top)
        // Padding fixo: alternar 0/10 no `isTargeted` remedia a coluna inteira a
        // cada entrada e saída do cursor, e era isso que travava o arrasto.
        .padding(compacto ? 4 : 10)
        .contentShape(RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))
        .background(
            recebendoDrop ? cor.opacity(0.10) : Color.clear,
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
