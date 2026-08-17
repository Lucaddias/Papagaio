import AppKit

/// Reduz uma imagem antes de ela virar interface.
///
/// Uma foto de celular tem 4000 pixels de largura; o quadradinho da pasta tem
/// 38 pontos. Guardar o original e deixar o `scaledToFill` resolver significa o
/// macOS reamostrar milhões de pixels **a cada quadro**, por cartão visível —
/// com a grade cheia, a janela para de responder e o clique num botão parece
/// simplesmente não acontecer.
///
/// Reduzir uma vez, ao carregar, troca isso por uma conta feita uma única vez.
enum MiniaturaDeImagem {
    /// Maior lado, em pixels. 720 cobre a faixa do cartão numa tela Retina
    /// larga e ainda assim é 30 vezes menor que uma foto de celular.
    static let ladoMaximo: CGFloat = 720

    static func reduzir(_ imagem: NSImage, ladoMaximo: CGFloat = ladoMaximo) -> NSImage {
        let tamanho = imagem.size
        let maior = max(tamanho.width, tamanho.height)
        guard maior > ladoMaximo, maior > 0 else { return imagem }

        let escala = ladoMaximo / maior
        let novo = NSSize(width: tamanho.width * escala, height: tamanho.height * escala)

        let reduzida = NSImage(size: novo)
        reduzida.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        imagem.draw(
            in: NSRect(origin: .zero, size: novo),
            from: NSRect(origin: .zero, size: tamanho),
            operation: .copy,
            fraction: 1
        )
        reduzida.unlockFocus()
        return reduzida
    }
}
