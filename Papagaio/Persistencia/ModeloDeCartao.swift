import Foundation

/// O layout do cartão de conversa na grade da Biblioteca.
///
/// Dois modelos, escolhidos em Configurações > Personalização dos Cartões —
/// a mesma lógica da aparência clara/escura: cada um é uma amostra clicável,
/// com o exemplo mudando na hora.
enum ModeloDeCartao: Int, CaseIterable {
    /// O cartão de sempre: faixa colorida (ou imagem de capa) no topo, no
    /// estilo Classroom.
    case comCapa
    /// Sem faixa: uma tarja de cor fina na lateral esquerda, título e dados
    /// direto no corpo — mais compacto, mais perto de uma lista densa.
    case compacto

    static let chave = "modeloDeCartao"
    static let padrao: ModeloDeCartao = .comCapa

    var titulo: String {
        switch self {
        case .comCapa: "Com capa"
        case .compacto: "Compacto"
        }
    }

    var descricao: String {
        switch self {
        case .comCapa: "Faixa colorida (ou foto) no topo de cada cartão."
        case .compacto: "Sem faixa: uma tarja de cor na lateral, cartões mais enxutos."
        }
    }

    var simbolo: String {
        switch self {
        case .comCapa: "rectangle.top.three.quarters.filled"
        case .compacto: "rectangle.lefthalf.filled"
        }
    }
}
