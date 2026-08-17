import AppKit
import SwiftUI

/// A textura fixa da faixa do cartão: um degradê diagonal e um grão fino.
///
/// A faixa era um retângulo chapado. Chapado ela lê como área preenchida —
/// espaço que sobrou e foi pintado — e não como superfície. O degradê dá a ela
/// uma direção de luz, e o grão dá matéria; juntos fazem a diferença entre um
/// bloco de cor e uma capa.
///
/// É a mesma textura em todo cartão, e de propósito: ela não é decoração de
/// cada conversa, é o acabamento do componente. Cada cartão continua se
/// distinguindo pela cor, que é o dado; a textura é o que eles têm em comum.
///
/// Some sobre imagem? Não: fica por cima dela também. Uma foto com o mesmo
/// tratamento de luz das faixas coloridas pertence à mesma grade — sem isso, o
/// cartão com capa parecia recortado de outro app e colado ali.
struct TexturaDaFaixa: View {
    var body: some View {
        ZStack {
            // Claro no alto à esquerda, escuro embaixo à direita: é a direção
            // que o olho lê como luz vinda de cima, a mesma de qualquer
            // superfície iluminada. Invertida, a faixa parece um buraco.
            LinearGradient(
                colors: [
                    .white.opacity(0.14),
                    .clear,
                    .black.opacity(0.10),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(nsImage: Self.grao)
                .resizable(resizingMode: .tile)
                // `overlay` clareia o que é claro e escurece o que é escuro,
                // mantendo a matiz: o grão vira textura da cor em vez de uma
                // sujeira cinza por cima dela.
                .blendMode(.overlay)
                .opacity(0.22)
        }
        // A textura é acabamento: não pode roubar clique de nada que esteja
        // atrás dela.
        .allowsHitTesting(false)
    }

    /// Um ladrilho de ruído, gerado uma única vez.
    ///
    /// 64x64 é pequeno o bastante para o desenho ser barato e grande o bastante
    /// para a repetição não formar padrão visível — em 16x16 a grade do
    /// ladrilho aparece como xadrez.
    private static let grao: NSImage = {
        let lado = 64
        let imagem = NSImage(size: NSSize(width: lado, height: lado))

        guard let contexto = CGContext(
            data: nil,
            width: lado,
            height: lado,
            bitsPerComponent: 8,
            bytesPerRow: lado * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let dados = contexto.data else { return imagem }

        let pixels = dados.bindMemory(to: UInt8.self, capacity: lado * lado * 4)
        var gerador = SystemRandomNumberGenerator()

        for indice in 0..<(lado * lado) {
            // Cinzas em volta de 128: no modo `overlay`, 128 é o neutro, então
            // o desvio em torno dele é exatamente o quanto o grão aparece.
            let valor = UInt8(Int.random(in: 108...148, using: &gerador))
            let base = indice * 4
            pixels[base] = valor
            pixels[base + 1] = valor
            pixels[base + 2] = valor
            pixels[base + 3] = 255
        }

        guard let cg = contexto.makeImage() else { return imagem }
        return NSImage(cgImage: cg, size: NSSize(width: lado, height: lado))
    }()
}
