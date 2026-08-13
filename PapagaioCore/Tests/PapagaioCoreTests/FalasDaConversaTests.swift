import Foundation
import Testing
@testable import PapagaioCore

// Testes do agrupamento da transcrição em falas por falante acústico.
// Puro e sem IO: só as regras de encadeamento por falante e âncora no trecho.

private func palavra(
    _ texto: String, _ inicio: TimeInterval, _ fim: TimeInterval,
    falante: String? = nil
) -> Palavra {
    Palavra(start: inicio, end: fim, texto: texto, falanteAcustico: falante)
}

private func trecho(
    _ id: UUID, _ inicio: TimeInterval, _ fim: TimeInterval,
    palavras: [Palavra], speaker: String? = nil
) -> Trecho {
    Trecho(
        id: id,
        start: inicio,
        end: fim,
        texto: palavras.map(\.texto).joined(separator: " "),
        speaker: speaker,
        palavras: palavras
    )
}

@Test("Sem diarização nenhuma, devolve nil — a interface fica em blocos")
func falasSemDiarizacaoDevolveNil() {
    let trechos = [
        trecho(UUID(), 0, 2, palavras: [palavra("oi", 0, 1), palavra("bem", 1, 2)]),
        trecho(UUID(), 2, 4, palavras: [palavra("como", 2, 3), palavra("vai", 3, 4)]),
    ]

    #expect(FalasDaConversa.agrupar(trechos) == nil)
}

@Test("Palavras do mesmo falante viram uma fala só, atravessando trechos")
func falasAtravessamTrechos() {
    let trechos = [
        trecho(UUID(), 0, 3, palavras: [
            palavra("oi", 0, 1, falante: "S1"),
            palavra("tudo", 1, 2, falante: "S1"),
        ]),
        trecho(UUID(), 3, 6, palavras: [
            palavra("bem", 3, 4, falante: "S1"),
            palavra("e", 4, 5, falante: "S1"),
        ]),
    ]

    let falas = FalasDaConversa.agrupar(trechos)
    #expect(falas?.count == 1)
    #expect(falas?.first?.falanteAcustico == "S1")
    #expect(falas?.first?.inicio == 0)
    #expect(falas?.first?.fim == 5)
    #expect(falas?.first?.texto == "oi tudo bem e")
    #expect(falas?.first?.palavras.count == 4)
    #expect(falas?.first?.trechoIds.count == 2)
}

@Test("Troca de falante fecha a fala e abre outra")
func falasSeparadasPorFalante() {
    let trechos = [
        trecho(UUID(), 0, 4, palavras: [
            palavra("oi", 0, 1, falante: "S1"),
            palavra("tudo", 1, 2, falante: "S2"),
            palavra("bem", 2, 3, falante: "S1"),
        ]),
    ]

    let falas = FalasDaConversa.agrupar(trechos)
    #expect(falas?.count == 3)
    #expect(falas?.map(\.falanteAcustico) == ["S1", "S2", "S1"])
}

@Test("Palavra sem falante no meio de uma conversa diarizada vira fala própria")
func falasSemFalanteFormamFalaPropria() {
    let trechos = [
        trecho(UUID(), 0, 5, palavras: [
            palavra("oi", 0, 1, falante: "S1"),
            palavra("e", 1, 2),
            palavra("bem", 2, 3, falante: "S1"),
        ]),
    ]

    let falas = FalasDaConversa.agrupar(trechos)
    #expect(falas?.count == 3)
    #expect(falas?.first?.falanteAcustico == "S1")
    #expect(falas?[1].falanteAcustico == nil)
    #expect(falas?.last?.falanteAcustico == "S1")
}

@Test("Trecho sem palavras (editado ou legado) vira fala própria com o texto")
func falasAbrigamTrechoSemPalavras() {
    let legado = UUID()
    let trechos = [
        trecho(UUID(), 0, 3, palavras: [
            palavra("oi", 0, 1, falante: "S1"),
            palavra("tudo", 1, 2, falante: "S1"),
        ]),
        trecho(legado, 3, 4, palavras: [], speaker: Speaker.eu),
        trecho(UUID(), 4, 7, palavras: [
            palavra("bem", 4, 5, falante: "S1"),
        ]),
    ]

    let falas = FalasDaConversa.agrupar(trechos)
    #expect(falas?.count == 3)
    #expect(falas?[1].falanteAcustico == nil)
    #expect(falas?[1].id == legado)
    #expect(falas?[1].palavras.isEmpty == true)
    #expect(falas?[1].trechoIds == [legado])
    #expect(falas?.last?.falanteAcustico == "S1")
}

@Test("Palavras de uma fala guardam a âncora exata no trecho de origem")
func falasAncoramPalavraNoTrecho() {
    let primeiro = UUID()
    let segundo = UUID()
    let trechos = [
        trecho(primeiro, 0, 3, palavras: [
            palavra("oi", 0, 1, falante: "S1"),
            palavra("tudo", 1, 2, falante: "S1"),
        ]),
        trecho(segundo, 3, 6, palavras: [
            palavra("bem", 3, 4, falante: "S1"),
        ]),
    ]

    let falas = FalasDaConversa.agrupar(trechos)
    let ancoras = falas?.first?.palavras.map { Anchura(trechoId: $0.trechoId, indice: $0.indiceNoTrecho) }
    #expect(ancoras == [
        Anchura(trechoId: primeiro, indice: 0),
        Anchura(trechoId: primeiro, indice: 1),
        Anchura(trechoId: segundo, indice: 0),
    ])
}

private struct Anchura: Equatable {
    let trechoId: UUID
    let indice: Int
}

@Test("Fala inteira do mesmo canal carrega o canal; mista fica sem canal")
func falasCarregamCanalUniforme() {
    let mic = trecho(UUID(), 0, 3, palavras: [
        palavra("oi", 0, 1, falante: "S1"),
        palavra("tudo", 1, 2, falante: "S1"),
    ], speaker: Speaker.eu)
    let sis = trecho(UUID(), 3, 6, palavras: [
        palavra("bem", 3, 4, falante: "S2"),
    ], speaker: Speaker.interlocutor)

    let uniformes = FalasDaConversa.agrupar([mic])
    #expect(uniformes?.first?.speaker == Speaker.eu)

    let mistos = FalasDaConversa.agrupar([mic, sis])
    #expect(mistos?.first?.speaker == Speaker.eu)
    #expect(mistos?.last?.speaker == Speaker.interlocutor)
}

@Test("Fala mista entre microfone e sistema fica sem canal de origem")
func falasMistasPerdemCanal() {
    let mic = trecho(UUID(), 0, 3, palavras: [
        palavra("oi", 0, 1, falante: "S1"),
    ], speaker: Speaker.eu)
    let sis = trecho(UUID(), 3, 6, palavras: [
        palavra("bem", 3, 4, falante: "S1"),
    ], speaker: Speaker.interlocutor)

    let falas = FalasDaConversa.agrupar([mic, sis])
    #expect(falas?.count == 1)
    #expect(falas?.first?.falanteAcustico == "S1")
    #expect(falas?.first?.speaker == nil)
}

@Test("Trechos vazios devolvem nil, não falas vazias")
func falasSemTrechosDevolveNil() {
    #expect(FalasDaConversa.agrupar([]) == nil)
}
