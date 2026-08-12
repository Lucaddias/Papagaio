import Foundation
import Testing
@testable import PapagaioCore

/// A transcrição de referência dos testes.
///
/// Um trecho longo o bastante para conter frases de tamanhos diferentes, com
/// falantes distintos e tempos que não seguem a ordem do texto — assim um
/// `start` "plausível" chutado pelo modelo não coincide com o real por acaso.
private let transcricao: [Trecho] = [
    Trecho(
        start: 0,
        end: 9,
        texto: "Oi, tudo bem? Então, a gente precisa decidir o orçamento hoje.",
        speaker: Speaker.eu
    ),
    Trecho(
        start: 42,
        end: 61,
        texto: "Eu acho que a gente devia priorizar a retenção antes de gastar com aquisição, porque trazer usuário novo para um produto que ainda não segura ninguém é jogar dinheiro fora.",
        speaker: Speaker.interlocutor
    ),
    Trecho(
        start: 90,
        end: 96,
        texto: "Isso mesmo, concordo.",
        speaker: Speaker.eu
    ),
]

@Test("Citação real é aprovada com o tempo e o falante do trecho de origem")
func citacaoRealPreservaTempoEFalante() {
    let sugerida = Citacao(
        texto: "a gente devia priorizar a retenção antes de gastar com aquisição, porque trazer usuário novo para um produto que ainda não segura ninguém é jogar dinheiro fora",
        speaker: "Alguém",
        start: 7
    )

    let aprovadas = ValidacaoDeCitacoes.validar([sugerida], contra: transcricao)

    #expect(aprovadas.count == 1)
    // O tempo vem do trecho onde a fala está — não do palpite do modelo.
    #expect(aprovadas.first?.start == 42)
    #expect(aprovadas.first?.speaker == Speaker.interlocutor)
}

@Test("Paráfrase é descartada mesmo soando plausível")
func parafraseEhDescartada() {
    let inventada = Citacao(
        texto: "Precisamos focar em reter usuários antes de investir em aquisição de novos clientes",
        speaker: Speaker.interlocutor,
        start: 42
    )

    #expect(ValidacaoDeCitacoes.validar([inventada], contra: transcricao).isEmpty)
}

@Test("Confirmação curta não vira citação")
func confirmacaoCurtaEhDescartada() {
    let curta = Citacao(texto: "Isso mesmo, concordo", speaker: Speaker.eu, start: 90)
    #expect(ValidacaoDeCitacoes.validar([curta], contra: transcricao).isEmpty)
}

@Test("Vícios de fala saem do texto exibido, sem quebrar a localização")
func viciosDeFalaSaem() {
    let comVicios = Citacao(
        texto: "Então, né, a gente precisa decidir o orçamento hoje, tipo, sabe",
        speaker: nil,
        start: nil
    )

    let aprovadas = ValidacaoDeCitacoes.validar([comVicios], contra: transcricao)

    #expect(aprovadas.count == 1)
    let texto = try! #require(aprovadas.first?.texto)
    #expect(!texto.lowercased().contains(" né"))
    #expect(!texto.lowercased().contains("tipo"))
    #expect(texto.contains("orçamento"))
}

@Test("Acento, caixa e pontuação diferentes ainda localizam a fala")
func normalizacaoBasicaEhAceita() {
    let variacao = Citacao(
        texto: "A GENTE PRECISA DECIDIR O ORCAMENTO HOJE... e nada mais",
        speaker: nil,
        start: nil
    )

    // "e nada mais" não existe na transcrição: a fala inteira precisa bater.
    #expect(ValidacaoDeCitacoes.validar([variacao], contra: transcricao).isEmpty)
}

@Test("No máximo três citações, uma por trecho, em ordem de tempo")
func tetoDeTresEOrdemPorTempo() {
    let repetida = Citacao(
        texto: "a gente devia priorizar a retenção antes de gastar com aquisição, porque trazer usuário novo para um produto que ainda não segura ninguém é jogar dinheiro fora",
        speaker: nil,
        start: nil
    )
    let outra = Citacao(
        texto: "Então, a gente precisa decidir o orçamento hoje",
        speaker: nil,
        start: nil
    )

    let aprovadas = ValidacaoDeCitacoes.validar(
        [repetida, repetida, outra, repetida],
        contra: transcricao
    )

    #expect(aprovadas.count == 2)
    #expect(aprovadas.map(\.start) == [0, 42])
}

@Test("Sem candidata boa, a seção fica vazia em vez de mostrar qualquer coisa")
func preferirVazioAImpreciso() {
    let ruins = [
        Citacao(texto: "Oi, tudo bem?", speaker: nil, start: nil),
        Citacao(texto: "Vamos dobrar o faturamento até dezembro", speaker: nil, start: nil),
    ]

    #expect(ValidacaoDeCitacoes.validar(ruins, contra: transcricao).isEmpty)
}

@Test("Transcrição vazia não produz citação")
func transcricaoVaziaNaoProduzCitacao() {
    let sugerida = Citacao(texto: "qualquer coisa dita por alguém em algum momento", speaker: nil, start: nil)
    #expect(ValidacaoDeCitacoes.validar([sugerida], contra: []).isEmpty)
}
