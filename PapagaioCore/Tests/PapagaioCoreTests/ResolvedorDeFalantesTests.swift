import Foundation
import Testing
@testable import PapagaioCore

// Testes da resolução contextual de falas duvidosas pelo modelo de linguagem.
// Puro e sem IO: seleção de casos, prompt, gramática, decodificação e aplicação.
// O que NÃO se testa aqui é o modelo em si — fica para a avaliação manual.

private func palavra(
    _ texto: String, _ inicio: TimeInterval, _ fim: TimeInterval,
    falante: String? = nil
) -> Palavra {
    Palavra(start: inicio, end: fim, texto: texto, falanteAcustico: falante)
}

private func trecho(
    _ inicio: TimeInterval, _ fim: TimeInterval, palavras: [Palavra]
) -> Trecho {
    Trecho(
        start: inicio,
        end: fim,
        texto: palavras.map(\.texto).joined(separator: " "),
        palavras: palavras
    )
}

/// Conversa de teste: pergunta (S1), resposta curta sem falante, complemento
/// (S2) — o formato exato do relato do bug original.
private func conversaComCaso() -> Arquivo {
    Arquivo(
        titulo: "Teste",
        pastaRelativa: "x",
        espaco: EspacoID(),
        trechos: [
            trecho(0, 10, palavras: [
                palavra("tem", 0, 1, falante: "S1"),
                palavra("dúvida", 1, 2, falante: "S1"),
                palavra("ai", 2, 3, falante: "S1"),
                palavra("meu", 3, 4, falante: "S1"),
                palavra("bem", 4, 5, falante: "S1"),
            ]),
            trecho(10, 12, palavras: [
                palavra("sim", 10, 10.5),
                palavra("tenho", 10.5, 11),
            ]),
            trecho(12, 20, palavras: [
                palavra("qual", 12, 13, falante: "S2"),
                palavra("é", 13, 14, falante: "S2"),
                palavra("a", 14, 15, falante: "S2"),
            ]),
        ]
    )
}

@Test("Fala duvidosa entre vozes diferentes vira caso elegível com os vizinhos")
func casosSelecionaComVizinhosConfiante() {
    let falas = FalasDaConversa.agrupar(conversaComCaso().trechos)!

    let casos = ResolvedorDeFalantes.casosElegiveis(falas: falas)

    #expect(casos.count == 1)
    #expect(casos[0].texto == "sim tenho")
    #expect(casos[0].falanteAnterior == "S1")
    #expect(casos[0].falanteSeguinte == "S2")
    #expect(casos[0].contextoAnterior.contains("tem dúvida ai meu bem"))
    #expect(casos[0].contextoSeguinte.contains("qual é a"))
}

@Test("Vizinhos do mesmo falante não são caso — não há ambiguidade de voz")
func casosComMesmosVizinhosNaoSaoElegiveis() {
    let arquivo = Arquivo(
        titulo: "T",
        pastaRelativa: "x",
        espaco: EspacoID(),
        trechos: [
            trecho(0, 10, palavras: [
                palavra("oi", 0, 1, falante: "S1"),
                palavra("bom", 1, 2, falante: "S1"),
            ]),
            trecho(10, 12, palavras: [palavra("e", 10, 10.5)]),
            trecho(12, 20, palavras: [
                palavra("dia", 12, 13, falante: "S1"),
                palavra("como", 13, 14, falante: "S1"),
            ]),
        ]
    )

    let casos = ResolvedorDeFalantes.casosElegiveis(
        falas: FalasDaConversa.agrupar(arquivo.trechos)!
    )
    #expect(casos.isEmpty)
}

@Test("Duvidosa sem vizinho confiável de um lado não é caso")
func casosSemVizinhoConfiavelNaoSaoElegiveis() {
    // A conversa começa com a duvidosa: não há quem decida o lado esquerdo.
    let arquivo = Arquivo(
        titulo: "T",
        pastaRelativa: "x",
        espaco: EspacoID(),
        trechos: [
            trecho(0, 10, palavras: [palavra("alô", 0, 1)]),
            trecho(10, 20, palavras: [
                palavra("tudo", 10, 11, falante: "S2"),
                palavra("bem", 11, 12, falante: "S2"),
            ]),
        ]
    )

    let casos = ResolvedorDeFalantes.casosElegiveis(
        falas: FalasDaConversa.agrupar(arquivo.trechos)!
    )
    #expect(casos.isEmpty)
}

@Test("Fala duvidosa longa demais não é caso — contexto curto não resolve")
func casosLongosNaoSaoElegiveis() {
    let duvidosa = (0..<10).map { i in
        palavra("palavra", Double(i), Double(i + 1))
    }
    let arquivo = Arquivo(
        titulo: "T",
        pastaRelativa: "x",
        espaco: EspacoID(),
        trechos: [
            trecho(0, 10, palavras: [
                palavra("oi", 0, 1, falante: "S1"),
                palavra("bem", 1, 2, falante: "S1"),
            ]),
            trecho(10, 20, palavras: duvidosa),
            trecho(20, 30, palavras: [
                palavra("qual", 20, 21, falante: "S2"),
                palavra("era", 21, 22, falante: "S2"),
            ]),
        ]
    )

    let casos = ResolvedorDeFalantes.casosElegiveis(
        falas: FalasDaConversa.agrupar(arquivo.trechos)!
    )
    #expect(casos.isEmpty)
}

@Test("Prompt pede a resposta no formato restrito e mostra os vizinhos")
func promptContemCasosEEscolhas() {
    let casos = ResolvedorDeFalantes.casosElegiveis(
        falas: FalasDaConversa.agrupar(conversaComCaso().trechos)!
    )

    let prompt = ResolvedorDeFalantes.prompt(para: casos)

    #expect(prompt.contains(casos[0].id.uuidString))
    #expect(prompt.contains("sim tenho"))
    #expect(prompt.contains("Voz 1"))
    #expect(prompt.contains("Voz 2"))
    #expect(prompt.contains("[????]"))
    #expect(prompt.contains("indeterminado"))
    #expect(prompt.contains("voz-1"))
    #expect(prompt.contains("voz-2"))
}

@Test("Gramática restringe às chaves dos casos e ao vocabulário das três respostas")
func gramaticaRestringeFormato() {
    let casos = ResolvedorDeFalantes.casosElegiveis(
        falas: FalasDaConversa.agrupar(conversaComCaso().trechos)!
    )

    let gramatica = ResolvedorDeFalantes.gramatica(para: casos)

    #expect(gramatica.contains(casos[0].id.uuidString))
    #expect(gramatica.contains("\"voz-1\""))
    #expect(gramatica.contains("\"voz-2\""))
    #expect(gramatica.contains("\"indeterminado\""))
    #expect(!gramatica.contains("qualquer"))
}

@Test("Decodifica só as respostas inequívocas; o resto fica de fora")
func decodificarIgnoraAusentesEIndeterminado() {
    let casos = ResolvedorDeFalantes.casosElegiveis(
        falas: FalasDaConversa.agrupar(conversaComCaso().trechos)!
    )
    let id = casos[0].id.uuidString

    let resolucoes = ResolvedorDeFalantes.decodificar(
        "{\"\(id)\": \"voz-2\", \"fora\": \"voz-1\"}", casos: casos
    )
    #expect(resolucoes[casos[0].id] == "voz-2")
    #expect(resolucoes.count == 1)

    let comIndeterminado = ResolvedorDeFalantes.decodificar(
        "{\"\(id)\": \"indeterminado\"}", casos: casos
    )
    #expect(comIndeterminado.isEmpty)

    #expect(ResolvedorDeFalantes.decodificar("lixo sem json", casos: casos).isEmpty)
}

@Test("Aplicar rotula as palavras duvidosas pelo vizinho indicado, sem tocar no resto")
func aplicarRotulaPalavrasDaFalaResolvida() {
    let arquivo = conversaComCaso()
    let falas = FalasDaConversa.agrupar(arquivo.trechos)!
    let casos = ResolvedorDeFalantes.casosElegiveis(falas: falas)
    let resolucoes = [casos[0].id: "voz-2"]

    let aplicado = ResolvedorDeFalantes.aplicar(resolucoes, casos: casos, em: arquivo)

    let palavrasDoMeio = aplicado.trechos[1].palavras
    #expect(palavrasDoMeio.allSatisfy { $0.falanteAcustico == "S2" })
    #expect(aplicado.trechos[0].palavras.allSatisfy { $0.falanteAcustico == "S1" })
    #expect(aplicado.trechos[2].palavras.allSatisfy { $0.falanteAcustico == "S2" })
    #expect(aplicado.trechos[0].texto == arquivo.trechos[0].texto)
}

@Test("Sem resoluções, o arquivo volta igual")
func aplicarSemResolucoesNaoMudaNada() {
    let arquivo = conversaComCaso()
    let falas = FalasDaConversa.agrupar(arquivo.trechos)!
    let casos = ResolvedorDeFalantes.casosElegiveis(falas: falas)

    let aplicado = ResolvedorDeFalantes.aplicar([:], casos: casos, em: arquivo)

    #expect(aplicado == arquivo)
}