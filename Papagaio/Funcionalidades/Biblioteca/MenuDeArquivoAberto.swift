import SwiftUI

struct MenuDeArquivoAberto: View {
    let bloqueioDeEdicao: Bool
    let bloqueioDeLixeira: Bool
    let aoEditarAparencia: () -> Void
    let aoRenomear: () -> Void
    let aoCompartilhar: () -> Void
    let aoDuplicar: () -> Void
    let aoMoverParaLixeira: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ItemDoMenuDeArquivo(simbolo: "paintpalette", titulo: "Cor e imagem", acao: aoEditarAparencia)
            ItemDoMenuDeArquivo(simbolo: "square.and.pencil", titulo: "Editar informações", acao: aoRenomear)
            ItemDoMenuDeArquivo(simbolo: "square.and.arrow.up", titulo: "Compartilhar", acao: aoCompartilhar)
            ItemDoMenuDeArquivo(simbolo: "rectangle.on.rectangle", titulo: "Duplicar", desabilitado: bloqueioDeEdicao, acao: aoDuplicar)
            // Favoritar, mover para pasta e personalizar saem daqui: os dois
            // primeiros são botões no rodapé do cartão e o último mora nas
            // Configurações. Repetir a ação no menu só alonga a lista e faz a
            // pessoa procurar em dois lugares o mesmo comando.

            SeparadorPapagaio()
                .padding(.horizontal, PapagaioTema.Espaco.medio)
                .padding(.vertical, PapagaioTema.Espaco.minimo)

            ItemDoMenuDeArquivo(
                simbolo: "trash",
                titulo: "Mover para Lixeira",
                destrutivo: true,
                desabilitado: bloqueioDeLixeira,
                acao: aoMoverParaLixeira
            )
        }
        .frame(width: 214)
        .padding(.vertical, PapagaioTema.Espaco.minimo)
        // Sem fundo, moldura e sombra próprios: agora isto vive dentro de um
        // popover, que já traz os três do sistema. Somados, davam duas bordas
        // e duas sombras — a aparência de um cartão colado em cima de outro.
    }
}

struct ItemDoMenuDeArquivo: View {
    let simbolo: String
    let titulo: String
    var destrutivo = false
    var desabilitado = false
    let acao: () -> Void

    var body: some View {
        Button(action: acao) {
            HStack(spacing: PapagaioTema.Espaco.medio) {
                Image(systemName: simbolo)
                    .font(.system(size: 15, weight: .regular))
                    .symbolRenderingMode(.monochrome)
                    .frame(width: 18)

                Text(titulo)
                    .font(.system(size: 14, weight: .regular))
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .foregroundStyle(cor.opacity(desabilitado ? 0.42 : 1))
            .padding(.horizontal, PapagaioTema.Espaco.medio)
            .frame(height: PapagaioTema.Altura.padrao)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(desabilitado)
    }

    private var cor: Color {
        destrutivo ? PapagaioTema.perigo : PapagaioTema.textoSecundario
    }
}
