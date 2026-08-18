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
    let duvidosa = (0..<16).map { i in
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

@Test("Mais de doze casos são todos elegíveis — o lote é responsabilidade do chamador")
func casosAcimaDoTetoDeChamadaSaoTodosElegiveis() {
    // Conversa em zigue-zague S1/S2 com uma duvidosa entre cada par — cada
    // par vira caso, e tem que virar TODOS, mesmo além do teto de uma chamada.
    var trechos: [Trecho] = []
    for i in 0..<13 {
        trechos.append(trecho(Double(i * 6), Double(i * 6 + 2), palavras: [
            palavra("oi", Double(i * 6), Double(i * 6 + 1), falante: "S1"),
            palavra("bom", Double(i * 6 + 1), Double(i * 6 + 2), falante: "S1"),
        ]))
        trechos.append(trecho(Double(i * 6 + 2), Double(i * 6 + 3), palavras: [
            palavra("e", Double(i * 6) + 2, Double(i * 6) + 2.5),
        ]))
        trechos.append(trecho(Double(i * 6 + 3), Double(i * 6 + 6), palavras: [
            palavra("dia", Double(i * 6 + 3), Double(i * 6 + 4), falante: "S2"),
            palavra("qual", Double(i * 6 + 4), Double(i * 6 + 5), falante: "S2"),
        ]))
    }

    let casos = ResolvedorDeFalantes.casosElegiveis(
        falas: FalasDaConversa.agrupar(trechos)!
    )

    #expect(casos.count > ResolvedorDeFalantes.maxCasosPorChamada)
    #expect(casos.count == 13)
    #expect(Set(casos.map(\.id)).count == 13)
}

// MARK: - Costura de vozes iguais

@Test("Fala duvidosa entre dois pedaços da mesma voz é costurada sem modelo")
func costuraEntreVozesIguais() {
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

    let costurado = ResolvedorDeFalantes.costurarVozesIguais(arquivo)

    let palavrasDoMeio = costurado.trechos[1].palavras
    #expect(palavrasDoMeio.allSatisfy { $0.falanteAcustico == "S1" })
    #expect(costurado.trechos[0].palavras.allSatisfy { $0.falanteAcustico == "S1" })
    #expect(costurado.trechos[2].palavras.allSatisfy { $0.falanteAcustico == "S1" })
}

@Test("Costura não mexe em fala entre vozes diferentes — fica para o modelo")
func costuraEntreVozesDiferentesPassaDireto() {
    let arquivo = conversaComCaso()

    let costurado = ResolvedorDeFalantes.costurarVozesIguais(arquivo)

    #expect(costurado.trechos[1].palavras.allSatisfy { $0.falanteAcustico == nil })
    #expect(costurado.trechos[0].palavras.allSatisfy { $0.falanteAcustico == "S1" })
    #expect(costurado.trechos[2].palavras.allSatisfy { $0.falanteAcustico == "S2" })
}

@Test("Costura deixa de fora fala longa, mesmo entre dois pedaços da mesma voz")
func costuraNaoEsticaFalaLonga() {
    let duvidosa = (0..<16).map { i in
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
                palavra("qual", 20, 21, falante: "S1"),
                palavra("era", 21, 22, falante: "S1"),
            ]),
        ]
    )

    let costurado = ResolvedorDeFalantes.costurarVozesIguais(arquivo)

    #expect(costurado.trechos[1].palavras.allSatisfy { $0.falanteAcustico == nil })
}

@Test("Várias duvidosas encadeadas entre dois pedaços da mesma voz são costuradas")
func costuraCadeiaDeDuvidosasEntreMesmaVoz() {
    let arquivo = Arquivo(
        titulo: "T",
        pastaRelativa: "x",
        espaco: EspacoID(),
        trechos: [
            trecho(0, 10, palavras: [
                palavra("oi", 0, 1, falante: "S1"),
                palavra("bom", 1, 2, falante: "S1"),
            ]),
            trecho(10, 12, palavras: [palavra("bem", 10, 10.5)]),
            trecho(12, 14, palavras: [palavra("e", 12, 12.5)]),
            trecho(14, 20, palavras: [
                palavra("dia", 14, 15, falante: "S1"),
                palavra("como", 15, 16, falante: "S1"),
            ]),
        ]
    )

    let costurado = ResolvedorDeFalantes.costurarVozesIguais(arquivo)

    #expect(costurado.trechos[1].palavras.allSatisfy { $0.falanteAcustico == "S1" })
    #expect(costurado.trechos[2].palavras.allSatisfy { $0.falanteAcustico == "S1" })
}

@Test("Duvidosa sem vizinho confiável de um dos lados não é costurada")
func costuraSemVizinhoConfiavelNaoAge() {
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

    let costurado = ResolvedorDeFalantes.costurarVozesIguais(arquivo)

    #expect(costurado == arquivo)
}

@Test("Arquivo sem diarização volta igual — costura exige falas")
func costuraSemDiarizacaoNaoAge() {
    let arquivo = conversaComCaso()
    let semDiarizacao = Arquivo(
        titulo: arquivo.titulo,
        pastaRelativa: arquivo.pastaRelativa,
        espaco: arquivo.espaco,
        trechos: arquivo.trechos.map { trecho in
            trecho.comPalavras(trecho.palavras.map { palavra in
                Palavra(
                    id: palavra.id,
                    start: palavra.start,
                    end: palavra.end,
                    texto: palavra.texto,
                    falanteAcustico: nil
                )
            })
        }
    )

    let costurado = ResolvedorDeFalantes.costurarVozesIguais(semDiarizacao)

    #expect(costurado == semDiarizacao)
}

@Test("Prompt pede a resposta no formato restrito e mostra os vizinhos")
func promptContemCasosEEscolhas() {
    let casos = ResolvedorDeFalantes.casosElegiveis(
        falas: FalasDaConversa.agrupar(conversaComCaso().trechos)!
    )

    let prompt = ResolvedorDeFalantes.prompt(para: casos)

    // Chave posicional no lugar do id: `CASO 1` no prompt, `"1"` na resposta.
    #expect(prompt.contains("CASO 1"))
    #expect(!prompt.contains(casos[0].id.uuidString))
    #expect(prompt.contains("sim tenho"))
    #expect(prompt.contains("Voz 1"))
    #expect(prompt.contains("Voz 2"))
    #expect(prompt.contains("[????]"))
    #expect(prompt.contains("indeterminado"))
    #expect(prompt.contains("voz-1"))
    #expect(prompt.contains("voz-2"))
}

@Test("Gramática restringe às chaves posicionais e ao vocabulário das três respostas")
func gramaticaRestringeFormato() {
    let casos = ResolvedorDeFalantes.casosElegiveis(
        falas: FalasDaConversa.agrupar(conversaComCaso().trechos)!
    )

    let gramatica = ResolvedorDeFalantes.gramatica(para: casos)

    // Chave posicional do caso (`"1"`), não o id: chave de uuid aceita
    // qualquer hexadecimal e o modelo emitia um que não casava — a fala
    // ficava sem dono mesmo com a resposta certa no JSON.
    #expect(gramatica.contains("\"1\""))
    #expect(!gramatica.contains("uuid ::= hex8"))
    #expect(!gramatica.contains(casos[0].id.uuidString))
    // Aspas em literais separados: `"\""` — não pode haver literal com aspas
    // embutidas (`""voz`) nem valor desprotegido (`"voz-1"` numa ponta só).
    #expect(gramatica.contains("\"\\\"\""))
    #expect(gramatica.contains("\"voz-1\""))
    #expect(gramatica.contains("\"voz-2\""))
    #expect(gramatica.contains("\"indeterminado\""))
    #expect(!gramatica.contains("\"\"voz"))
    #expect(!gramatica.contains("qualquer"))
    #expect(gramatica.contains("{0,4}"))
    #expect(gramatica.contains("\"\\\"\" \"1\" \"\\\"\" ws \":\" ws valor"))
}

@Test("Decodifica pelas chaves posicionais; o resto fica de fora")
func decodificarIgnoraAusentesEIndeterminado() {
    let casos = ResolvedorDeFalantes.casosElegiveis(
        falas: FalasDaConversa.agrupar(conversaComCaso().trechos)!
    )

    let resolucoes = ResolvedorDeFalantes.decodificar(
        "{\"1\": \"voz-2\", \"fora\": \"voz-1\"}", casos: casos
    )
    #expect(resolucoes[casos[0].id] == "voz-2")
    #expect(resolucoes.count == 1)

    let comIndeterminado = ResolvedorDeFalantes.decodificar(
        "{\"1\": \"indeterminado\"}", casos: casos
    )
    #expect(comIndeterminado.isEmpty)

    // Chave posicional errada não vira resolução para caso nenhum — é o bug
    // do uuid que não casava, agora impossível pela construção da chave.
    let chaveInvalida = ResolvedorDeFalantes.decodificar(
        "{\"7\": \"voz-2\"}", casos: casos
    )
    #expect(chaveInvalida.isEmpty)

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