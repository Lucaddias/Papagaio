import Foundation

/// Alinha palavras da transcrição com segmentos da diarização, atribuindo o
/// falante acústico por **overlap temporal**.
///
/// Regra (skill `papagaio-speaker-attribution`):
/// - nenhum segmento cobre a palavra → `nil` (sem falante atribuído);
/// - um segmento cobre claramente mais do que todos os outros → o falante dele;
/// - topo de dois segmentos com overlap parecido (segundo ≥ 80% do primeiro) →
///   `nil`: é um empate técnico, e chutar um falante aqui inventa atribuição
///   sem evidência — **salvo quando os dois lados são o mesmo falante**: aí o
///   turno foi só dividido em dois segmentos, e a costura é segura.
///
/// E, porque o diarizador não cobre cada instante do áudio (segmentos de fala
/// separados por pausas) —
/// - palavra de duração zero (artefato do Whisper) com seu instante dentro de
///   um único segmento → o falante dele (o ponto, não o intervalo, decide);
/// - palavra num buraco pequeno (≤ 2s do segmento contíguo mais próximo) →
///   o falante do segmento mais próximo; dois segmentos a distâncias
///   parecidas (segunda ≤ 125% da primeira) seguem sem falante quando são
///   falantes diferentes.
///
/// Não altera nada do trecho além de `Palavra.falanteAcustico`.
public enum AlinhamentoDeFalantes {
    /// Maior buraco entre segmentos que a palavra atravessa por proximidade.
    /// Abaixo disso a fala é continuação; acima é pausa real. Medido nos
    /// áudios reais: a mediana dos buracos que o Whisper transcreve está em
    /// ~1,3s, e 91% deles ficam em ≤ 2s.
    static let ponteMaxima: TimeInterval = 2.0

    /// Segundos de sobreposição entre a palavra e o segmento. Não negativo.
    static func overlap(_ palavra: Palavra, _ segmento: SegmentoDeFalante) -> TimeInterval {
        max(0, min(palavra.end, segmento.fim) - max(palavra.start, segmento.inicio))
    }

    /// Segundos entre a palavra e o segmento: 0 quando tocam, positivo quando
    /// há buraco entre eles, desprezado o restante.
    static func distancia(_ palavra: Palavra, _ segmento: SegmentoDeFalante) -> TimeInterval {
        max(0, segmento.inicio - palavra.end, palavra.start - segmento.fim)
    }

    /// Atribui `falanteAcustico` a cada palavra, sem ordem de segmentos.
    ///
    /// Linha do tempo em segundos desde o início do áudio — mesma base das
    /// palavras e dos segmentos.
    public static func atribuir(
        palavras: [Palavra],
        a segmentos: [SegmentoDeFalante]
    ) -> [Palavra] {
        guard !segmentos.isEmpty else { return palavras }

        return palavras.map { atribuir(palavra: $0, a: segmentos) }
    }

    private static func atribuir(
        palavra: Palavra,
        a segmentos: [SegmentoDeFalante]
    ) -> Palavra {
        let coberturas = segmentos
            .map { (segmento: $0, overlap: overlap(palavra, $0)) }
            .filter { $0.overlap > 0 }
            .sorted { $0.overlap > $1.overlap }

        if let primeiro = coberturas.first {
            // Empate técnico: o segundo colocado cobre quase tanto quanto o
            // primeiro — a fronteira entre os segmentos cortou a palavra.
            // Dois segmentos do MESMO falante não são ambiguidade: o turno foi
            // só dividido na fronteira, e a costura é segura.
            if let segundo = coberturas.dropFirst().first,
               segundo.overlap >= primeiro.overlap * 0.8,
               segundo.segmento.falanteId != primeiro.segmento.falanteId {
                return palavra
            }
            return comFalante(palavra, primeiro.segmento.falanteId)
        }

        // Nenhum segmento toca o intervalo da palavra. O instante da palavra
        // (um ponto, não o intervalo) resolve as de duração zero do Whisper.
        let ponto = palavra.start
        let contidos = segmentos.filter { $0.inicio <= ponto && ponto <= $0.fim }
        if let unico = contidos.only {
            return comFalante(palavra, unico.falanteId)
        }
        if contidos.count > 1 {
            // O instante cai na fronteira entre segmentos: vago, sem falante.
            return palavra
        }

        // Buraco: costura até o segmento contíguo mais próximo, se pequeno.
        // Distâncias parecidas (2º ≤ 125% do 1º) é empate do mesmo tipo do
        // overlap — nada de chute quando os dois lados são falantes diferentes.
        // Com o mesmo falante dos dois lados o empate não é ambíguo: costura.
        let distancias = segmentos
            .map { (segmento: $0, distancia: distancia(palavra, $0)) }
            .sorted { $0.distancia < $1.distancia }
        guard let maisProximo = distancias.first,
              maisProximo.distancia <= ponteMaxima else {
            return palavra
        }
        if let segundo = distancias.dropFirst().first,
           segundo.distancia <= maisProximo.distancia * 1.25,
           segundo.segmento.falanteId != maisProximo.segmento.falanteId {
            return palavra
        }
        return comFalante(palavra, maisProximo.segmento.falanteId)
    }

    private static func comFalante(_ palavra: Palavra, _ falante: String) -> Palavra {
        Palavra(
            id: palavra.id,
            start: palavra.start,
            end: palavra.end,
            texto: palavra.texto,
            falanteAcustico: falante
        )
    }
}

private extension Collection {
    /// O único elemento da coleção, ou `nil` se vazia ou com mais de um.
    var only: Element? {
        guard count == 1, let primeiro = first else { return nil }
        return primeiro
    }
}