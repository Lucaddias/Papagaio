import SwiftUI

/// Tokens visuais compartilhados pela biblioteca e pelo detalhe de conversa.
///
/// O design de referência usa superfícies claras e quentes. Centralizar os
/// valores evita que cada tela crie uma variação quase igual de borda, raio ou
/// cor de destaque.
enum PapagaioTema {
    static let fundo = Color(red: 0.980, green: 0.976, blue: 0.969)
    static let superficie = Color.white
    static let texto = Color(red: 0.125, green: 0.118, blue: 0.114)
    static let textoSecundario = Color(red: 0.385, green: 0.331, blue: 0.306)
    static let destaque = Color(red: 1.000, green: 0.537, blue: 0.392)
    static let destaqueEscuro = Color(red: 0.663, green: 0.278, blue: 0.161)
    static let destaqueSuave = Color(red: 0.992, green: 0.882, blue: 0.847)
    static let borda = Color(red: 0.910, green: 0.796, blue: 0.761)
    static let superficieSuave = Color(red: 0.949, green: 0.945, blue: 0.937)
    static let sucesso = Color(red: 0.207, green: 0.485, blue: 0.329)
    static let aviso = Color(red: 0.733, green: 0.435, blue: 0.078)
    static let perigo = Color(red: 0.730, green: 0.176, blue: 0.176)

    static let raioDeCard: CGFloat = 16
    static let raioDeControle: CGFloat = 12
    static let espacamentoDePagina: CGFloat = 22
    static let larguraMaximaDeConteudo: CGFloat = 1_420
}

extension View {
    /// Superfície branca com a borda discreta e quente da identidade visual.
    func cartaoPapagaio(raio: CGFloat = PapagaioTema.raioDeCard) -> some View {
        background(PapagaioTema.superficie, in: RoundedRectangle(cornerRadius: raio, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: raio, style: .continuous)
                    .stroke(PapagaioTema.borda, lineWidth: 1)
            }
    }

    /// Dá às páginas largura legível em janelas grandes, sem prejudicar
    /// redimensionamento ou Split View.
    func larguraDeConteudoPapagaio(alinhamento: Alignment = .leading) -> some View {
        frame(maxWidth: PapagaioTema.larguraMaximaDeConteudo, alignment: alinhamento)
            .frame(maxWidth: .infinity, alignment: alinhamento)
    }
}

struct BotaoPrincipalPapagaio: ButtonStyle {
    @Environment(\.isEnabled) private var habilitado

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .frame(minHeight: 44)
            .background(
                habilitado ? PapagaioTema.destaque : PapagaioTema.destaque.opacity(0.42),
                in: Capsule()
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct BotaoDeContornoPapagaio: ButtonStyle {
    @Environment(\.isEnabled) private var habilitado

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(habilitado ? PapagaioTema.destaqueEscuro : PapagaioTema.textoSecundario)
            .padding(.horizontal, 16)
            .frame(minHeight: 40)
            .background(PapagaioTema.superficie, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(PapagaioTema.borda.opacity(habilitado ? 1 : 0.5), lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

enum EstiloDoStatus {
    case destaque
    case sucesso
    case aviso
    case erro
    case neutro

    var cor: Color {
        switch self {
        case .destaque: PapagaioTema.destaqueEscuro
        case .sucesso: PapagaioTema.sucesso
        case .aviso: PapagaioTema.aviso
        case .erro: PapagaioTema.perigo
        case .neutro: PapagaioTema.textoSecundario
        }
    }

    var fundo: Color {
        switch self {
        case .destaque: PapagaioTema.destaqueSuave
        case .sucesso: PapagaioTema.sucesso.opacity(0.12)
        case .aviso: PapagaioTema.aviso.opacity(0.13)
        case .erro: PapagaioTema.perigo.opacity(0.1)
        case .neutro: PapagaioTema.superficieSuave
        }
    }
}

struct SeloDeStatus: View {
    let texto: String
    let simbolo: String
    let estilo: EstiloDoStatus

    var body: some View {
        Label(texto, systemImage: simbolo)
            .font(.caption.weight(.semibold))
            .foregroundStyle(estilo.cor)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(estilo.fundo, in: Capsule())
    }
}
