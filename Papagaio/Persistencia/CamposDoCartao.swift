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
    static let pasta = CamposDoCartao(rawValue: 1 << 9)

    static let padrao: CamposDoCartao = [
        .capa, .descricao, .pessoas, .data, .duracao, .origem,
        .participantes, .modalidade, .lacunas, .pasta,
    ]

    /// Chave única de `UserDefaults`, lida por `@AppStorage` em cada cartão.
    ///
    /// `@AppStorage` e não um objeto observável: a preferência é um inteiro
    /// só, e assim a grade toda se redesenha sozinha quando ela muda, sem
    /// precisar carregar um objeto por todo o caminho até o cartão.
    static let chave = "camposVisiveisDoCartao"

    /// Quais campos já existiam da última vez que o app rodou.
    private static let chaveConhecidos = "camposConhecidosDoCartao"

    /// Liga os campos que passaram a existir desde a última execução.
    ///
    /// Sem isto, quem já tinha personalizado os cartões perdia silenciosamente
    /// toda funcionalidade nova: a preferência salva não conhece o bit do
    /// campo recém-criado, então ele nasce desligado e o dado some da tela sem
    /// que ninguém tenha pedido. Quem chega depois vê a versão completa; quem
    /// usava antes vê menos — exatamente ao contrário do que faz sentido.
    ///
    /// Campo desligado de propósito continua desligado: só entram aqui os bits
    /// que nunca foram oferecidos a esta pessoa.
    static func ligarCamposNovos() {
        let padroes = UserDefaults.standard
        let conhecidos = CamposDoCartao(rawValue: padroes.integer(forKey: chaveConhecidos))
        let novos = padrao.subtracting(conhecidos)
        guard !novos.isEmpty else { return }

        // `object(forKey:)` e não `integer`: quem nunca personalizou não tem
        // valor gravado, e ali `integer` devolveria zero — todos os campos
        // desligados — em vez do padrão.
        let atual = padroes.object(forKey: chave) as? Int ?? padrao.rawValue
        padroes.set(CamposDoCartao(rawValue: atual).union(novos).rawValue, forKey: chave)
        padroes.set(padrao.rawValue, forKey: chaveConhecidos)
    }

    /// Cada campo com seu rótulo e explicação, na ordem em que aparecem no
    /// cartão — a folha de personalização vira um espelho do que se vê ali.
    static let catalogo: [(campo: CamposDoCartao, titulo: String, detalhe: String)] = [
        // "Imagem" saiu: o círculo grande da conversa deu lugar aos círculos
        // dos participantes, que não são decoração e por isso não têm chave.
        (.descricao, "Descrição", "O resumo de uma ou duas linhas, no banner."),
        (.pasta, "Pasta", "Em qual pasta a conversa está, na cor dela."),
        (.pessoas, "Entrevistador e entrevistado", "Os nomes, dentro da ficha do cartão."),
        (.data, "Data e hora", "Quando a conversa aconteceu."),
        (.duracao, "Duração", "O tempo total do áudio."),
        // Origem e modalidade saíram do cartão: um interruptor que não muda
        // nada na tela é pior do que interruptor nenhum. Os bits continuam
        // definidos para o caso de os campos voltarem.
        (.participantes, "Participantes", "Quantas pessoas, e os nomes ao clicar."),
        (.lacunas, "Avisos de campo em branco", "\"Sem descrição\" e \"Participantes não informados\"."),
    ]
}
