import Foundation
import Testing
@testable import PapagaioCore

// Testes do alinhamento palavra × segmento de diarização. Puro e sem IO:
// só as regras de overlap e empate delas.

private func palavra(
    _ texto: String, _ inicio: TimeInterval, _ fim: TimeInterval
) -> Palavra {
    Palavra(start: inicio, end: fim, texto: texto)
}

@Test("Palavra dentro de um único segmento herda o falante dele")
func alinhamentoAtribuiFalanteUnico() {
    let palavras = [
        palavra("oi", 0, 1),
        palavra("tudo", 1, 2),
        palavra("bem", 2, 3),
    ]
    let segmentos = [
        SegmentoDeFalante(falanteId: "S1", inicio: 0, fim: 3)
    ]

    let atribuidas = AlinhamentoDeFalantes.atribuir(palavras: palavras, a: segmentos)
    #expect(atribuidas.map(\.falanteAcustico) == ["S1", "S1", "S1"])
}

@Test("Palavra cortada pela fronteira dos segmentos fica desconhecida")
func alinhamentoEmpateTecnicoEUnknown() {
    // A palavra 0,95–1,05 é cortada ao meio por S1 (0–1) e S2 (1–2): overlaps
    // de 0,05 cada. Empate claro — atribuir um falante seria chutar.
    let palavraCortada = palavra("e", 0.95, 1.05)
    let palavras = [palavraCortada]
    let segmentos = [
        SegmentoDeFalante(falanteId: "S1", inicio: 0, fim: 1),
        SegmentoDeFalante(falanteId: "S2", inicio: 1, fim: 2),
    ]

    let atribuidas = AlinhamentoDeFalantes.atribuir(palavras: palavras, a: segmentos)
    #expect(atribuidas[0].falanteAcustico == nil)
}

@Test("Palavra cortada na fronteira de segmentos do mesmo falante costura")
func alinhamentoEmpateTecnicoDoMesmoFalanteCostura() {
    // Mesma fronteira, mas os dois segmentos são S1: o turno foi só dividido em
    // dois pedaços — a costura é segura, sem ambiguidade de falante.
    let palavras = [palavra("e", 0.95, 1.05)]
    let segmentos = [
        SegmentoDeFalante(falanteId: "S1", inicio: 0, fim: 1),
        SegmentoDeFalante(falanteId: "S1", inicio: 1, fim: 2),
    ]

    let atribuidas = AlinhamentoDeFalantes.atribuir(palavras: palavras, a: segmentos)
    #expect(atribuidas[0].falanteAcustico == "S1")
}

@Test("Palavra num buraco grande demais fica desconhecida")
func alinhamentoSemOverlapEUnknown() {
    // Buraco de 3s (palavra a partir de 5, segmento termina em 2): acima da
    // ponte máxima de 2s — é pausa real, sem costura.
    let palavras = [palavra("oi", 5, 5.5)]
    let segmentos = [
        SegmentoDeFalante(falanteId: "S1", inicio: 0, fim: 2)
    ]

    let atribuidas = AlinhamentoDeFalantes.atribuir(palavras: palavras, a: segmentos)
    #expect(atribuidas[0].falanteAcustico == nil)
}

@Test("Palavra de duração zero dentro de um segmento ganha o falante dele")
func alinhamentoDuracaoZeroPontoDentroDeSegmento() {
    // O Whisper emite palavras pontuais (start == end). O overlap é sempre 0 —
    // quem decide é o instante da palavra.
    let palavras = [palavra("e", 1.5, 1.5)]
    let segmentos = [
        SegmentoDeFalante(falanteId: "S1", inicio: 0, fim: 2)
    ]

    let atribuidas = AlinhamentoDeFalantes.atribuir(palavras: palavras, a: segmentos)
    #expect(atribuidas[0].falanteAcustico == "S1")
}

@Test("Palavra de duração zero exatamente na fronteira fica desconhecida")
func alinhamentoDuracaoZeroNaFronteiraEAmbiguo() {
    let palavras = [palavra("e", 1, 1)]
    let segmentos = [
        SegmentoDeFalante(falanteId: "S1", inicio: 0, fim: 1),
        SegmentoDeFalante(falanteId: "S2", inicio: 1, fim: 2),
    ]

    let atribuidas = AlinhamentoDeFalantes.atribuir(palavras: palavras, a: segmentos)
    #expect(atribuidas[0].falanteAcustico == nil)
}

@Test("Palavra num buraco pequeno costura até o segmento contíguo mais próximo")
func alinhamentoPonteDeBuracoPequeno() {
    // O diarizador dividiu o turno de S1 em [0–1] e [1.5–2]; a palavra 1.1–1.3
    // cai no buraco de 0.5s — é continuação da mesma fala.
    let palavras = [palavra("isso", 1.1, 1.3)]
    let segmentos = [
        SegmentoDeFalante(falanteId: "S1", inicio: 0, fim: 1),
        SegmentoDeFalante(falanteId: "S1", inicio: 1.5, fim: 2),
    ]

    let atribuidas = AlinhamentoDeFalantes.atribuir(palavras: palavras, a: segmentos)
    #expect(atribuidas[0].falanteAcustico == "S1")
}

@Test("Buraco perto de segmentos de falantes diferentes segue o mais próximo")
func alinhamentoPonteSegueOMaisProximo() {
    let palavras = [palavra("ai", 1.9, 2.0)]
    let segmentos = [
        SegmentoDeFalante(falanteId: "S1", inicio: 0, fim: 2),
        SegmentoDeFalante(falanteId: "S2", inicio: 3, fim: 4),
    ]

    let atribuidas = AlinhamentoDeFalantes.atribuir(palavras: palavras, a: segmentos)
    #expect(atribuidas[0].falanteAcustico == "S1")
}

@Test("Buraco com segmentos a distâncias parecidas é empate e fica desconhecido")
func alinhamentoPonteEquidistanteEAmbiguo() {
    // 1.35–1.45 fica no meio do buraco: a 0.15s de S1 (que termina em 1.2) e a
    // 0.15s de S2 (que começa em 1.6): distância parecida demais — sem
    // evidência, sem chute.
    let palavras = [palavra("isso", 1.35, 1.45)]
    let segmentos = [
        SegmentoDeFalante(falanteId: "S1", inicio: 0, fim: 1.2),
        SegmentoDeFalante(falanteId: "S2", inicio: 1.6, fim: 2),
    ]

    let atribuidas = AlinhamentoDeFalantes.atribuir(palavras: palavras, a: segmentos)
    #expect(atribuidas[0].falanteAcustico == nil)
}

@Test("Empate a distâncias iguais entre o mesmo falante costura sem ambiguidade")
func alinhamentoPonteEquidistanteDoMesmoFalante() {
    // O turno de S1 foi dividido em [0–1] e [1.6–2]; a palavra 1.2–1.3 fica a
    // 0.3s de ambos os pedaços — mas são o MESMO falante: não é ambiguidade.
    let palavras = [palavra("de", 1.2, 1.3)]
    let segmentos = [
        SegmentoDeFalante(falanteId: "S1", inicio: 0, fim: 1),
        SegmentoDeFalante(falanteId: "S1", inicio: 1.6, fim: 2),
    ]

    let atribuidas = AlinhamentoDeFalantes.atribuir(palavras: palavras, a: segmentos)
    #expect(atribuidas[0].falanteAcustico == "S1")
}

@Test("Palavra de duração zero num buraco pequeno também costura")
func alinhamentoPonteComDuracaoZero() {
    let palavras = [palavra("de", 0.9, 0.9)]
    let segmentos = [
        SegmentoDeFalante(falanteId: "S2", inicio: 0.5, fim: 0.6),
        SegmentoDeFalante(falanteId: "S1", inicio: 1.3, fim: 2),
    ]

    // Instante 0.9 fora de qualquer segmento (0.9 > 0.6 e 0.9 < 1.3); buraco de
    // 0.3s para S2 e 0.4s para S1 → segue S2, o mais próximo (distância 0.3
    // contra 0.4 — não é empate: 0.4 > 0.3 × 1.25).
    let atribuidas = AlinhamentoDeFalantes.atribuir(palavras: palavras, a: segmentos)
    #expect(atribuidas[0].falanteAcustico == "S2")
}

@Test("Sem segmentos, nenhuma palavra muda")
func alinhamentoSemSegmentosNaoMudaNada() {
    let palavras = [palavra("oi", 0, 1)]
    let atribuidas = AlinhamentoDeFalantes.atribuir(palavras: palavras, a: [])
    #expect(atribuidas == palavras)
}

@Test("Vencedor claro ganha mesmo com segundo colocado distante")
func alinhamentoVencedorClaro() {
    // Overlap com S1 = 1,0; com S2 = 0,1 → 10% do primeiro, longe do limiar
    // de empate (80%).
    let palavras = [palavra("oi", 0, 1)]
    let segmentos = [
        SegmentoDeFalante(falanteId: "S1", inicio: 0, fim: 1),
        SegmentoDeFalante(falanteId: "S2", inicio: 1.8, fim: 2.0),
    ]

    let atribuidas = AlinhamentoDeFalantes.atribuir(palavras: palavras, a: segmentos)
    #expect(atribuidas[0].falanteAcustico == "S1")
}

@Test("Trecho deriva o falante acústico dominante das palavras")
func trechoDerivaFalanteDominante() {
    let trecho = Trecho(
        start: 0, end: 3, texto: "oi tudo bem",
        speaker: Speaker.eu,
        palavras: [
            Palavra(start: 0, end: 1, texto: "oi", falanteAcustico: "S1"),
            Palavra(start: 1, end: 2, texto: "tudo", falanteAcustico: nil),
            Palavra(start: 2, end: 3, texto: "bem", falanteAcustico: "S1"),
        ]
    )
    #expect(trecho.falanteAcusticoDominante == "S1")

    let semDiarizacao = Trecho(
        start: 0, end: 3, texto: "oi",
        speaker: Speaker.eu,
        palavras: [Palavra(start: 0, end: 1, texto: "oi")]
    )
    #expect(semDiarizacao.falanteAcusticoDominante == nil)
}