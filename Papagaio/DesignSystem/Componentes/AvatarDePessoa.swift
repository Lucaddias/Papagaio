import AppKit
import SwiftUI

/// O rosto de um participante: a foto, quando existe, e as iniciais quando não.
///
/// Um componente só para os dois casos porque o lugar é o mesmo e o tamanho
/// também — trocar a foto não pode mexer no layout à volta. As iniciais não são
/// um estado de erro: são o padrão, e a foto é o extra.
struct AvatarDePessoa: View {
    let nome: String
    var diametro: CGFloat = 26
    /// A cor do anel que separa o avatar do fundo.
    var anel: Color = PapagaioTema.superficie

    /// Cor derivada do nome, e não aleatória: a mesma pessoa recebe sempre o
    /// mesmo tom, em todas as conversas, e isso é metade do reconhecimento.
    private var cor: Color {
        let paleta = AparenciaDasPastas.Cor.allCases.filter { $0 != .padrao }
        let soma = nome.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return paleta[soma % paleta.count].cor
    }

    private var foto: NSImage? { FotosDePessoas.imagem(de: nome) }

    var body: some View {
        ZStack {
            if let foto {
                Image(nsImage: foto)
                    .resizable()
                    .scaledToFill()
            } else {
                cor

                Text(iniciaisDe(nome))
                    .font(.system(size: diametro * 0.38, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: diametro, height: diametro)
        .clipShape(Circle())
        .overlay { Circle().stroke(anel, lineWidth: 2) }
        // O nome no hover: com vários participantes, iniciais iguais acontecem,
        // e a única saída era abrir a lista para descobrir de quem era o
        // círculo.
        .help(nome)
        .accessibilityLabel(nome)
    }
}
