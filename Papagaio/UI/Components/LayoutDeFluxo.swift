import SwiftUI

/// Disposição de parágrafo corrido: coloca as subviews lado a lado e quebra a
/// linha quando a próxima não cabe mais na largura proposta.
///
/// É o que desenha as palavras de um trecho como um texto fluido. Não pode ser
/// um `Text` gigante: cada palavra precisa ser um `Button` (tap leva ao
/// timestamp dela) e o destaque precisa existir por palavra, não por trecho.
struct LayoutDeFluxo: Layout {
    /// Espaço entre palavras da mesma linha, em pontos.
    var espacoHorizontal: CGFloat
    /// Espaço entre linhas quebradas, em pontos.
    var espacoVertical: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let larguraMaxima = proposal.width ?? .infinity
        var altura = CGFloat.zero
        var x = CGFloat.zero
        var alturaDaLinha = CGFloat.zero

        for subview in subviews {
            let tamanho = subview.sizeThatFits(.unspecified)
            if x > 0, x + tamanho.width > larguraMaxima {
                altura += alturaDaLinha + espacoVertical
                x = 0
                alturaDaLinha = 0
            }
            x += tamanho.width + espacoHorizontal
            alturaDaLinha = max(alturaDaLinha, tamanho.height)
        }
        return CGSize(width: proposal.width ?? x, height: altura + alturaDaLinha)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var alturaDaLinha = CGFloat.zero

        for subview in subviews {
            let tamanho = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + tamanho.width > bounds.maxX {
                x = bounds.minX
                y += alturaDaLinha + espacoVertical
                alturaDaLinha = 0
            }
            // `topLeading`: numa linha de `Text` com a mesma fonte as baselines
            // casam, e o fundo do destaque começa no topo da palavra.
            subview.place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: .unspecified
            )
            x += tamanho.width + espacoHorizontal
            alturaDaLinha = max(alturaDaLinha, tamanho.height)
        }
    }
}
