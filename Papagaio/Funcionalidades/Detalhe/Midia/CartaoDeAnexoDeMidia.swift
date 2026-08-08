import SwiftUI

struct CartaoDeAnexoDeMidia: View {
    let anexo: AnexoDeMidiaDaConversa
    let aoAbrir: () -> Void
    let aoRemover: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.largo) {
            Button(action: aoAbrir) {
                VStack(alignment: .leading, spacing: PapagaioTema.Espaco.medio) {
                    PreviaDoAnexoDeMidia(anexo: anexo)
                        .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: PapagaioTema.Espaco.minimo) {
                        Text(anexo.nome)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(PapagaioTema.texto)
                            .lineLimit(2)
                            .frame(minHeight: 44, alignment: .topLeading)

                        HStack(spacing: PapagaioTema.Espaco.minimo) {
                            SeloDeMidia(texto: anexo.tipoVisual, simbolo: anexo.simbolo)
                            SeloDeMidia(texto: anexo.extensaoVisual, simbolo: "doc.text")
                            SeloDeMidia(texto: formatoDeBytes(anexo.tamanho), simbolo: "externaldrive")
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    }
                    .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .buttonStyle(.plain)
            .help("Abrir \(anexo.nome)")

            Spacer(minLength: 0)

            HStack {
                Text(anexo.data.formatted(.dateTime.day().month(.abbreviated).year()))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(PapagaioTema.textoSecundario)

                Spacer()

                Button("Remover", systemImage: "trash", role: .destructive, action: aoRemover)
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(PapagaioTema.perigo)
            }
        }
        .padding(PapagaioTema.Espaco.largo)
        .frame(maxWidth: .infinity, minHeight: 318, maxHeight: 318, alignment: .topLeading)
        .cartaoPapagaio()
    }
}
