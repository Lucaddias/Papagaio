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

    /// Sem ler este `@Published`, o SwiftUI não tem motivo para recalcular
    /// este corpo quando a foto muda em outro lugar da árvore de views — a
    /// foto mora no `UserDefaults`, fora de qualquer estado que este avatar
    /// declare. Trocar a foto no formulário de edição não redesenhava o
    /// avatar do cartão na grade: era o mesmo nome, a mesma view por fora, e
    /// nada ali tinha mudado do ponto de vista do SwiftUI.
    @ObservedObject private var avisoDeFotos = FotosDePessoas.aviso

    /// Cor derivada do nome, e não aleatória: a mesma pessoa recebe sempre o
    /// mesmo tom, em todas as conversas, e isso é metade do reconhecimento.
    private var cor: Color {
        Self.corDoNome(nome)
    }

    static func corDoNome(_ nome: String) -> Color {
        let paleta = AparenciaDasPastas.Cor.allCases.filter { $0 != .padrao }
        let soma = nome.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return paleta[soma % paleta.count].cor
    }

    /// A cor que representa esta pessoa fora do círculo — hoje, o nome que
    /// aparece ao passar o mouse.
    ///
    /// Com foto, a cor sai da própria foto, exatamente como a faixa do cartão
    /// resolve a cor de uma conversa com capa: quem tem rosto não tem tom
    /// sorteado por nome, e um nome pintado de um verde que não aparece em
    /// lugar nenhum do avatar não liga uma coisa à outra.
    ///
    /// Sempre passando por `acentoSobreSuperficie`, porque este nome é lido
    /// sobre o cartão branco e não sobre o círculo.
    @MainActor
    static func corDeAcento(de nome: String) -> Color {
        if let foto = FotosDePessoas.imagem(de: nome),
           let dominante = CorDominanteDeImagem.cor(de: foto, chave: "pessoa." + FotosDePessoas.chave(de: nome)) {
            return dominante.acentoSobreSuperficie
        }
        return corDoNome(nome).acentoSobreSuperficie
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
