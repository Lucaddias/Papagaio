import Foundation

/// O que cada cartão da biblioteca mostra abaixo do título.
///
/// **Vale para a grade inteira, não para um cartão só.** Uma fileira de cartões
/// só se lê como fileira se todos tiverem os mesmos campos: com conteúdos
/// diferentes, cada cartão ganha uma altura, o rodapé de um cai na linha do
/// corpo do vizinho e a varredura de olho — que é como se usa uma grade — para
/// de funcionar. Além disso, a pessoa configuraria a mesma coisa dezenas de
/// vezes.
///
/// Título, capa e estado ficam de fora da lista de propósito: sem título o
/// cartão não identifica nada, e o estado só aparece quando há uma exceção
/// (fila, processando, falha), que é justamente quando ela precisa ser vista.
struct CamposDoCartao: OptionSet, Sendable {
    let rawValue: Int

    static let capa = CamposDoCartao(rawValue: 1 << 0)
    static let descricao = CamposDoCartao(rawValue: 1 << 1)
    static let pessoas = CamposDoCartao(rawValue: 1 << 2)
    static let data = CamposDoCartao(rawValue: 1 << 3)
    static let duracao = CamposDoCartao(rawValue: 1 << 4)
    static let origem = CamposDoCartao(rawValue: 1 << 5)
    static let participantes = CamposDoCartao(rawValue: 1 << 6)
    static let modalidade = CamposDoCartao(rawValue: 1 << 7)
    /// Os avisos de campo em branco — "Sem descrição", "Participantes não
    /// informados". São úteis para quem está preenchendo as fichas e puro ruído
    /// para quem já decidiu que não vai preencher.
    static let lacunas = CamposDoCartao(rawValue: 1 << 8)

    static let padrao: CamposDoCartao = [
        .capa, .descricao, .pessoas, .data, .duracao, .origem,
        .participantes, .modalidade, .lacunas,
    ]

    /// Chave única de `UserDefaults`, lida por `@AppStorage` em cada cartão.
    ///
    /// `@AppStorage` e não um objeto observável: a preferência é um inteiro
    /// só, e assim a grade toda se redesenha sozinha quando ela muda, sem
    /// precisar carregar um objeto por todo o caminho até o cartão.
    static let chave = "camposVisiveisDoCartao"

    /// Cada campo com seu rótulo e explicação, na ordem em que aparecem no
    /// cartão — a folha de personalização vira um espelho do que se vê ali.
    static let catalogo: [(campo: CamposDoCartao, titulo: String, detalhe: String)] = [
        (.capa, "Capa", "A faixa colorida ou a imagem escolhida, no topo."),
        (.descricao, "Descrição", "O resumo de uma ou duas linhas."),
        (.pessoas, "Entrevistador e entrevistado", "Os nomes preenchidos na ficha."),
        (.data, "Data e hora", "Quando a conversa aconteceu."),
        (.duracao, "Duração", "O tempo total do áudio."),
        (.origem, "Gravado ou importado", "De onde veio o áudio."),
        (.participantes, "Participantes", "Quantas pessoas, quando há mais de uma."),
        (.modalidade, "Modalidade", "Presencial ou online."),
        (.lacunas, "Avisos de campo em branco", "\"Sem descrição\" e \"Participantes não informados\"."),
    ]
}
