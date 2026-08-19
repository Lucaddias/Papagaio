import AppKit
import SwiftUI

/// A cor que resume uma imagem.
///
/// Existe para o cartão com capa: os acentos do rodapé — a linha, o hover dos
/// ícones, a estrela acesa — seguem a cor escolhida para a conversa, e quem
/// escolheu uma foto no lugar da cor não tem cor nenhuma para eles seguirem.
/// Sem isto, o cartão azul tinha rodapé azul e o cartão com foto caía no
/// laranja da marca, como se pertencesse a outra grade.
///
/// Não é a média dos pixels. Média puxa tudo para um cinza-barro: uma foto de
/// céu com um telhado vermelho vira bege. O que se procura aqui é a cor que uma
/// pessoa apontaria como sendo "a cor daquela imagem", e essa é sempre a mais
/// viva, não a mais frequente.
enum CorDominanteDeImagem {
    @MainActor private static var memoria: [String: Color] = [:]

    /// `chave` é o identificador de quem pediu — a conversa ou a pasta.
    ///
    /// A extração percorre pixels, e o `body` de um cartão roda muitas vezes
    /// por segundo enquanto a grade rola. Sem memória, isto seria varredura de
    /// imagem por quadro, por cartão.
    @MainActor
    static func cor(de imagem: NSImage, chave: String) -> Color? {
        if let guardada = memoria[chave] { return guardada }
        guard let extraida = extrair(de: imagem) else { return nil }
        memoria[chave] = extraida
        return extraida
    }

    @MainActor
    static func esquecer(_ chave: String) {
        memoria.removeValue(forKey: chave)
    }

    /// Reduz a imagem a uma grade pequena e escolhe o pixel mais vivo dela.
    ///
    /// A redução é o filtro: em 16x16 cada pixel já é a média de uma região
    /// inteira, então ruído e detalhe somem e sobra a estrutura de cor da
    /// imagem — que é o que se quer resumir.
    private static func extrair(de imagem: NSImage) -> Color? {
        let lado = 16
        guard let contexto = CGContext(
            data: nil,
            width: lado,
            height: lado,
            bitsPerComponent: 8,
            bytesPerRow: lado * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        var area = CGRect(x: 0, y: 0, width: imagem.size.width, height: imagem.size.height)
        guard let cg = imagem.cgImage(forProposedRect: &area, context: nil, hints: nil) else {
            return nil
        }
        contexto.draw(cg, in: CGRect(x: 0, y: 0, width: lado, height: lado))

        guard let dados = contexto.data else { return nil }
        let pixels = dados.bindMemory(to: UInt8.self, capacity: lado * lado * 4)

        var melhor: (nota: Double, cor: NSColor)?
        var somaR = 0.0, somaG = 0.0, somaB = 0.0

        for indice in 0..<(lado * lado) {
            let base = indice * 4
            let r = Double(pixels[base]) / 255
            let g = Double(pixels[base + 1]) / 255
            let b = Double(pixels[base + 2]) / 255
            somaR += r; somaG += g; somaB += b

            let cor = NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
            let saturacao = cor.saturationComponent
            let brilho = cor.brightnessComponent

            // Quase branco e quase preto ficam de fora: são fundo, papel e
            // sombra — não são a cor de imagem nenhuma.
            guard saturacao > 0.18, brilho > 0.18, brilho < 0.96 else { continue }

            // Saturação pesa mais que brilho: entre um vermelho médio e um
            // rosa-claro lavado, é o vermelho que a pessoa chamaria de "a cor".
            let nota = Double(saturacao) * 1.6 + Double(brilho) * 0.4
            if nota > (melhor?.nota ?? 0) {
                melhor = (nota, cor)
            }
        }

        if let melhor { return Color(nsColor: melhor.cor) }

        // Imagem inteiramente cinza (uma digitalização, uma foto em preto e
        // branco): aí a média é honesta, porque não há cor a destacar.
        let total = Double(lado * lado)
        return Color(nsColor: NSColor(
            srgbRed: somaR / total,
            green: somaG / total,
            blue: somaB / total,
            alpha: 1
        ))
    }
}

extension Color {
    /// Esta cor, escurecida o quanto for preciso para se ler sobre o cartão.
    ///
    /// A cor da faixa é lida sobre a própria faixa, onde qualquer tom funciona.
    /// Os acentos do rodapé são lidos sobre o branco do cartão, onde um amarelo
    /// ou um verde-limão desaparecem. Em vez de proibir cores claras — que é
    /// tirar da pessoa a escolha que a paleta livre existe para dar —, o tom
    /// escurece só o necessário para passar do limiar.
    var acentoSobreSuperficie: Color {
        guard let hsb = NSColor(self).usingColorSpace(.sRGB) else { return self }

        var brilho = hsb.brightnessComponent
        var candidata = hsb

        // No máximo doze passos: é o suficiente para trazer qualquer cor de
        // brilho 1,0 até a faixa legível, e evita laço infinito com cores que
        // não escurecem (o branco puro, que tem saturação zero).
        for _ in 0..<12 where luminancia(de: candidata) > 0.42 {
            brilho *= 0.86
            candidata = NSColor(
                hue: hsb.hueComponent,
                saturation: min(1, hsb.saturationComponent * 1.06),
                brightness: brilho,
                alpha: 1
            ).usingColorSpace(.sRGB) ?? candidata
        }

        return Color(nsColor: candidata)
    }

    private func luminancia(de cor: NSColor) -> Double {
        func linear(_ canal: CGFloat) -> Double {
            let valor = Double(canal)
            return valor <= 0.03928 ? valor / 12.92 : pow((valor + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(cor.redComponent)
            + 0.7152 * linear(cor.greenComponent)
            + 0.0722 * linear(cor.blueComponent)
    }
}
