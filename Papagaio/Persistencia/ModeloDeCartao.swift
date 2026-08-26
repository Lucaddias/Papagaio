import Foundation

/// O layout do cartão de conversa na grade da Biblioteca.
///
/// Dois modelos, escolhidos em Configurações > Personalização dos Cartões —
/// a mesma lógica da aparência clara/escura: cada um é uma amostra clicável,
/// com o exemplo mudando na hora.
enum ModeloDeCartao: Int, CaseIterable {
    /// Sem faixa: uma tarja de cor fina na lateral esquerda, título e dados
    /// direto no corpo — mais compacto, mais perto de uma lista densa.
    ///
    /// Declarado primeiro (mas com `rawValue` 1, não 0): é o que `allCases`
    /// usa para ordenar as duas amostras em Configurações, e o pedido foi
    /// "Compacto" à esquerda. O `rawValue` explícito mantém compatível quem
    /// já tinha `comCapa` (0) salvo em `@AppStorage` antes desta troca — só
    /// a ordem de exibição muda, o valor persistido de cada caso não.
    case compacto = 1
    /// O cartão de sempre: faixa colorida (ou imagem de capa) no topo, no
    /// estilo Classroom.
    case comCapa = 0

    static let chave = "modeloDeCartao"
    /// Compacto é o padrão agora: quem abre o app pela primeira vez começa
    /// com ele selecionado, não mais "Com capa".
    static let padrao: ModeloDeCartao = .compacto

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
