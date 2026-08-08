import SwiftUI

struct AcoesDaLixeira: View {
    let temArquivos: Bool
    let aoRestaurarTudo: () -> Void
    let aoEsvaziar: () -> Void

    var body: some View {
        HStack(spacing: PapagaioTema.Espaco.largo) {
            Button("Restaurar Tudo", systemImage: "arrow.counterclockwise", action: aoRestaurarTudo)
                .buttonStyle(BotaoDeContornoPapagaio())
                .disabled(!temArquivos)
                .help("Restaurar todos os arquivos da lixeira")

            Button("Esvaziar Lixeira", systemImage: "trash.square", role: .destructive, action: aoEsvaziar)
                .font(.body.weight(.semibold))
                .foregroundStyle(PapagaioTema.textoSobrePrimario)
                .padding(.horizontal, PapagaioTema.Espaco.largo)
                .frame(minHeight: PapagaioTema.Altura.destaque)
                .background(PapagaioTema.preenchimentoPrimario, in: Capsule())
                .buttonStyle(.plain)
                .disabled(!temArquivos)
                .opacity(temArquivos ? 1 : 0.45)
                .help("Apagar definitivamente todos os arquivos da lixeira")
        }
    }
}
