import SwiftUI

struct CartaoNovaConversa: View {
    let gravando: Bool
    let bloqueado: Bool
    let prontoParaEntrada: Bool
    let aoAlternarGravacao: () async -> Void
    let aoImportar: () -> Void

    var body: some View {
        VStack(spacing: PapagaioTema.Espaco.largo) {
            Image(systemName: "plus")
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(PapagaioTema.destaqueEscuro)
                .frame(width: 64, height: 64)
                .background(PapagaioTema.destaqueSuave, in: Circle())

            VStack(spacing: PapagaioTema.Espaco.minimo) {
                Text("Gerar nova conversa")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(PapagaioTema.texto)
                Text("Grave áudio ou importe um arquivo para transcrever.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(PapagaioTema.textoSecundario)
            }

            if !prontoParaEntrada {
                SeloDeStatus(
                    texto: "Preparando biblioteca",
                    simbolo: "arrow.triangle.2.circlepath",
                    estilo: .neutro
                )
                .accessibilityLabel("Preparando a biblioteca. Gravar e importar estarão disponíveis em instantes.")
            }

            if bloqueado {
                SeloDeStatus(
                    texto: "Preparando áudio",
                    simbolo: "waveform",
                    estilo: .destaque
                )
            }

            // Em coluna estreita os dois botões lado a lado eram espremidos até
            // o rótulo hifenizar ("Impor-tar"). Empilhar é melhor que quebrar
            // a palavra.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: PapagaioTema.Espaco.curto) {
                    botoes
                }

                VStack(spacing: PapagaioTema.Espaco.curto) {
                    botoes
                }
            }
        }
        .padding(PapagaioTema.Espaco.secao)
        .frame(maxWidth: .infinity, minHeight: 260, maxHeight: 260)
        .background(PapagaioTema.superficie.opacity(0.55), in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeCard, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PapagaioTema.raioDeCard, style: .continuous)
                .stroke(
                    PapagaioTema.borda,
                    style: StrokeStyle(lineWidth: 2, dash: [7, 6])
                )
        }
        .accessibilityElement(children: .contain)
    }

    private var botoes: some View {
        Group {
            Button("Gravar", systemImage: "mic.fill") {
                Task { await aoAlternarGravacao() }
            }
            .buttonStyle(BotaoPrincipalPapagaio())
            .disabled(bloqueado || !prontoParaEntrada)

            Button("Importar", systemImage: "arrow.down.doc") {
                aoImportar()
            }
            .buttonStyle(BotaoDeContornoPapagaio())
            .disabled(bloqueado || !prontoParaEntrada)
        }
    }
}
