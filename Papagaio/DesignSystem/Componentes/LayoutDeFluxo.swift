import SwiftUI

/// Disposição de parágrafo corrido: coloca as subviews lado a lado, quebra a
/// linha quando a próxima não cabe mais na largura proposta, e justifica —
/// estica o espaço entre as palavras de cada linha completa até encostar na
/// borda direita, como um parágrafo de jornal.
///
/// É o que desenha as palavras de um trecho como um texto fluido. Não pode ser
/// um `Text` gigante: cada palavra precisa ser um `Button` (tap leva ao
/// timestamp dela) e o destaque precisa existir por palavra, não por trecho.
struct LayoutDeFluxo: Layout {
    /// Espaço mínimo entre palavras da mesma linha, em pontos — a
    /// justificação só aumenta esse valor, nunca diminui.
    var espacoHorizontal: CGFloat
    /// Espaço entre linhas quebradas, em pontos.
    var espacoVertical: CGFloat
    /// Só o corpo de um parágrafo (as falas/trechos da transcrição) deve
    /// justificar. Nos outros usos — chips de filtro, campos de nome de voz —
    /// os itens são controles curtos e discretos, não palavras de um texto
    /// corrido; esticar o espaço entre eles abriria buracos esquisitos numa
    /// linha de poucos elementos. Por isso o padrão é não justificar.
    var justificado: Bool = false

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
        guard !subviews.isEmpty else { return }
        let tamanhos = subviews.map { $0.sizeThatFits(.unspecified) }

        // Primeiro decide onde cada linha quebra — a mesma regra de
        // `sizeThatFits`, só que guardando os índices de cada linha em vez de
        // só medir a altura total — para só então distribuir o espaço
        // sobrando de cada uma entre as palavras dela.
        var linhas: [[Int]] = [[]]
        var larguraDaLinhaAtual = CGFloat.zero
        for (indice, tamanho) in tamanhos.enumerated() {
            if !linhas[linhas.count - 1].isEmpty,
               larguraDaLinhaAtual + tamanho.width > bounds.width {
                linhas.append([])
                larguraDaLinhaAtual = 0
            }
            linhas[linhas.count - 1].append(indice)
            larguraDaLinhaAtual += tamanho.width + espacoHorizontal
        }

        var y = bounds.minY
        for (indiceDaLinha, linha) in linhas.enumerated() {
            guard !linha.isEmpty else { continue }
            let alturaDaLinha = linha.map { tamanhos[$0].height }.max() ?? 0
            let espacos = linha.count - 1

            // A última linha do parágrafo não justifica — ninguém espera
            // isso dela, e esticar uma linha curta (a última quase sempre é)
            // abriria buracos enormes entre poucas palavras.
            let ultimaLinha = indiceDaLinha == linhas.count - 1
            let espacoExtra: CGFloat
            if justificado, !ultimaLinha, espacos > 0 {
                let larguraDasPalavras = linha.reduce(CGFloat.zero) { $0 + tamanhos[$1].width }
                let larguraMinimaDaLinha = larguraDasPalavras + CGFloat(espacos) * espacoHorizontal
                espacoExtra = max(0, bounds.width - larguraMinimaDaLinha) / CGFloat(espacos)
            } else {
                espacoExtra = 0
            }

            var x = bounds.minX
            for indice in linha {
                // `topLeading`: numa linha de `Text` com a mesma fonte as
                // baselines casam, e o fundo do destaque começa no topo da
                // palavra.
                subviews[indice].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: .unspecified
                )
                x += tamanhos[indice].width + espacoHorizontal + espacoExtra
            }
            y += alturaDaLinha + espacoVertical
        }
    }
}
