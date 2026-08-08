import SwiftUI

struct MidiaDaConversaView: View {
    let anexos: [AnexoDeMidiaDaConversa]
    let aoAdicionar: () -> Void
    let aoAbrir: (AnexoDeMidiaDaConversa) -> Void
    let aoRemover: (AnexoDeMidiaDaConversa) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.secao) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: PapagaioTema.Espaco.curto) {
                    Text("Arquivos e Mídia")
                        .font(PapagaioTema.Tipo.tituloDePagina)
                        .foregroundStyle(PapagaioTema.texto)

                    Text("Fotos, vídeos, áudios, documentos e anexos salvos nesta conversa.")
                        .font(.body)
                        .foregroundStyle(PapagaioTema.textoSecundario)
                }

                Spacer()

                HStack(spacing: PapagaioTema.Espaco.curto) {
                    Text(anexos.count == 1 ? "1 arquivo" : "\(anexos.count) arquivos")
                    Text(tamanhoTotal)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(PapagaioTema.textoSecundario)
                .padding(.horizontal, PapagaioTema.Espaco.medio)
                .frame(height: PapagaioTema.Altura.compacta)
                .background(PapagaioTema.superficieSuave, in: Capsule())
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 270, maximum: 380), spacing: PapagaioTema.Espaco.largo, alignment: .top)],
                spacing: PapagaioTema.Espaco.largo
            ) {
                Button(action: aoAdicionar) {
                    VStack(spacing: PapagaioTema.Espaco.medio) {
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(PapagaioTema.textoSecundario)
                            .frame(width: 54, height: 54)
                            .background(PapagaioTema.superficieSuave, in: Circle())

                        VStack(spacing: PapagaioTema.Espaco.minimo) {
                            Text("Adicionar mídia")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(PapagaioTema.texto)
                            Text("Foto, vídeo, áudio ou arquivo")
                                .font(.callout.weight(.medium))
                                .foregroundStyle(PapagaioTema.textoSecundario)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 318, maxHeight: 318)
                    .background(PapagaioTema.superficie.opacity(0.28), in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeCard, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: PapagaioTema.raioDeCard, style: .continuous)
                            .stroke(
                                PapagaioTema.borda,
                                style: StrokeStyle(lineWidth: 2, dash: [7, 6])
                            )
                    }
                }
                .buttonStyle(.plain)
                .help("Adicionar mídia")

                ForEach(anexos) { anexo in
                    CartaoDeAnexoDeMidia(
                        anexo: anexo,
                        aoAbrir: { aoAbrir(anexo) },
                        aoRemover: { aoRemover(anexo) }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tamanhoTotal: String {
        formatoDeBytes(anexos.reduce(0) { $0 + $1.tamanho })
    }
}
