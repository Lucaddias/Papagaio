import SwiftUI

struct MenuDeArquivoAberto: View {
    let bloqueioDeEdicao: Bool
    let bloqueioDeLixeira: Bool
    /// A conversa ainda está na fila ou sendo transcrita/resumida — mover
    /// para a lixeira agora também interrompe esse trabalho, e não só
    /// descarta um resultado pronto. O item de baixo muda de nome para dizer
    /// isso, em vez de deixar "Mover para Lixeira" fazer o dobro do que diz.
    var cancelavel: Bool = false
    let aoEditarAparencia: () -> Void
    let aoRenomear: () -> Void
    let aoBaixar: () -> Void
    let aoCompartilhar: () -> Void
    let aoDuplicar: () -> Void
    let aoMoverParaLixeira: () -> Void

    /// A ordem é por frequência, com a aparência no fim.
    ///
    /// "Cor e imagem" estava no topo por ser a mais nova, não por ser a mais
    /// usada — e ocupava o primeiro item, que é onde o olho cai e onde deveria
    /// estar o que se faz todo dia. Ela é decisão de arrumação: escolhe-se uma
    /// vez e não se volta. Vai para o fim da lista, encostada no separador que
    /// a distingue da lixeira.
    ///
    /// Mesmo desenho do menu da pasta, que já tinha Baixar antes de
    /// Compartilhar — "guardar comigo" antes de "mandar para alguém".
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ItemDoMenuDeArquivo(simbolo: "square.and.pencil", titulo: "Editar informações", acao: aoRenomear)
            ItemDoMenuDeArquivo(simbolo: "arrow.down.circle", titulo: "Baixar", acao: aoBaixar)
            ItemDoMenuDeArquivo(simbolo: "square.and.arrow.up", titulo: "Compartilhar", acao: aoCompartilhar)
            ItemDoMenuDeArquivo(simbolo: "rectangle.on.rectangle", titulo: "Duplicar", desabilitado: bloqueioDeEdicao, acao: aoDuplicar)
            ItemDoMenuDeArquivo(simbolo: "paintpalette", titulo: "Cor e imagem", acao: aoEditarAparencia)
            // Favoritar, mover para pasta e personalizar saem daqui: os dois
            // primeiros são botões no rodapé do cartão e o último mora nas
            // Configurações. Repetir a ação no menu só alonga a lista e faz a
            // pessoa procurar em dois lugares o mesmo comando.

            SeparadorPapagaio()
                .padding(.horizontal, PapagaioTema.Espaco.medio)
                .padding(.vertical, PapagaioTema.Espaco.minimo)

            ItemDoMenuDeArquivo(
                simbolo: cancelavel ? "xmark.circle" : "trash",
                titulo: cancelavel ? "Cancelar processamento" : "Mover para Lixeira",
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
