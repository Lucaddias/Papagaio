import SwiftUI

/// Quanto espaço o player de áudio ocupa na base da janela, informado de baixo
/// para cima.
///
/// O selo de gravação vive fora do `NavigationStack` — precisa disso para
/// sobreviver à abertura de uma conversa — e por isso não enxerga o que está
/// na tela empilhada. Usar "tem conversa aberta?" como pista fazia o selo subir
/// em toda aba do arquivo, inclusive nas que não mostram player.
///
/// `PreferenceKey` resolve sem criar dependência: quem desenha o player anuncia
/// a própria altura, e quem posiciona o selo escuta. Nenhum dos dois precisa
/// conhecer o outro.
struct AlturaDoPlayerKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        // O maior vence: se duas telas anunciarem ao mesmo tempo durante uma
        // transição, o selo deve respeitar a que ocupa mais espaço, senão ele
        // pousa em cima do player no meio da animação.
        value = max(value, nextValue())
    }
}

extension View {
    /// Anuncia a altura ocupada pelo player nesta tela.
    func alturaDoPlayerPapagaio(_ altura: CGFloat) -> some View {
        preference(key: AlturaDoPlayerKey.self, value: altura)
    }
}
