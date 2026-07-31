import Foundation

/// Normaliza os segmentos nativos do Whisper em trechos navegáveis.
///
/// O Whisper já corta em fronteira de fala — o que falta é **tamanho**: os
/// segmentos nativos têm 2 a 10 s, curtos demais para ler e para servir de
/// unidade de navegação. Aqui eles são agrupados até a janela alvo.
///
/// Isto é normalização, não re-segmentação: **nenhum segmento do Whisper é
/// dividido**, porque cortar no meio de um significa cortar no meio de uma
/// frase. Ver skill `papagaio-segmentation`.
public enum Segmentacao {
    /// Janela alvo. O agrupamento fecha o trecho ao cruzar `alvo`, e nunca
    /// começa um segmento novo se isso for passar de `maxima`.
    public static let alvo: TimeInterval = 40
    public static let maxima: TimeInterval = 60

    /// Uma pausa longa é fronteira natural: fecha o trecho mesmo antes do alvo.
    public static let pausaQueSepara: TimeInterval = 2.0

    /// Agrupa segmentos de um único canal.
    ///
    /// - Precondition: `segmentos` vem ordenado por `start` — é o que o
    ///   `whisper_full` devolve.
    public static func agrupar(_ segmentos: [Trecho]) -> [Trecho] {
        guard !segmentos.isEmpty else { return [] }

        var trechos: [Trecho] = []
        var acumulados: [Trecho] = []

        func fechar() {
            guard let primeiro = acumulados.first, let ultimo = acumulados.last else { return }
            trechos.append(Trecho(
                start: primeiro.start,
                end: ultimo.end,
                texto: acumulados.map(\.texto).joined(separator: " "),
                speaker: primeiro.speaker
            ))
            acumulados.removeAll()
        }

        for segmento in segmentos {
            guard let ultimo = acumulados.last else {
                acumulados.append(segmento)
                continue
            }

            let inicio = acumulados[0].start
            let duracaoSeIncluir = segmento.end - inicio
            let pausa = segmento.start - ultimo.end
            let trocouDeFalante = segmento.speaker != ultimo.speaker

            // Troca de falante fecha o trecho sempre: misturar as duas vozes
            // num trecho só destruiria a atribuição por canal.
            if trocouDeFalante || duracaoSeIncluir > maxima
                || (pausa >= pausaQueSepara && (ultimo.end - inicio) >= alvo / 2)
            {
                fechar()
            }
            acumulados.append(segmento)

            if let comeco = acumulados.first, segmento.end - comeco.start >= alvo {
                fechar()
            }
        }
        fechar()
        return trechos
    }

    /// Mescla os dois canais numa linha do tempo única e agrupa.
    ///
    /// O falante vem do **canal de origem** — microfone é `"eu"`, tap do
    /// sistema é `"interlocutor"` — e não de um modelo de diarização. Ver skill
    /// `papagaio-speaker-attribution`.
    public static func mesclarCanais(
        microfone: [Trecho],
        sistema: [Trecho]
    ) -> [Trecho] {
        let comFalante = microfone.map { marcar($0, como: Speaker.eu) }
            + sistema.map { marcar($0, como: Speaker.interlocutor) }
        let ordenados = comFalante.sorted { $0.start < $1.start }
        return agrupar(ordenados)
    }

    private static func marcar(_ trecho: Trecho, como speaker: String) -> Trecho {
        Trecho(
            id: trecho.id,
            start: trecho.start,
            end: trecho.end,
            texto: trecho.texto,
            speaker: speaker
        )
    }
}
