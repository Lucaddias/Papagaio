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
/// - palavra num buraco pequeno (≤ `ponteMaxima` do segmento contíguo mais
///   próximo) → o falante do segmento mais próximo, quando **todos os
///   segmentos por perto são do mesmo falante** (o turno foi dividido em
///   pedaços pelo diarizador e a costura é segura);
/// - buraco **entre falantes diferentes** é fronteira de turno, não costura:
///   só é atribuído quando o segmento mais próximo está a ≤ `ponteCrossFalante`
///   (reação à resposta começando logo após a pergunta); dois segmentos a
///   distâncias parecidas (segunda ≤ 125% da primeira) seguem sem falante.
///
/// Por fim, o overlap germinal:
/// - palavra cujo segmento vencedor cobre **menos da metade** da sua duração
///   fica sem falante — a franja é imprecisão de timestamp do Whisper ou de
///   fronteira do diarizador, e chutar ali é inventar atribuição.
///
/// Tudo que aqui fica sem falante alimenta a resolução contextual (ver
/// `ResolvedorDeFalantes`): a marca de "não confio nesta fronteira" é o que
/// permite ao modelo de linguagem decidir pelo contexto em vez de errar.
///
/// Não altera nada do trecho além de `Palavra.falanteAcustico`.
public enum AlinhamentoDeFalantes {
    /// Maior buraco entre segmentos que a palavra atravessa por proximidade,
    /// quando todos os segmentos por perto são do **mesmo falante**. Abaixo
    /// disso a fala é continuação; acima é pausa real. Medido nos áudios
    /// reais: a mediana dos buracos que o Whisper transcreve está em ~1,3s, e
    /// 91% deles ficam em ≤ 2s.
    static let ponteMaxima: TimeInterval = 2.0

    /// Maior buraco entre segmentos de **falantes diferentes** que a palavra
    /// atravessa por proximidade. Fronteira de turno: a resposta começa logo
    /// depois da pergunta, mas o diarizador começa o segmento dela com atraso
    /// — costurar com a ponte de 2s colaria o começo da fala nova na cauda da
    /// fala anterior. O que sobra vira "sem falante" e segue para a resolução
    /// contextual (`ResolvedorDeFalantes`).
    static let ponteCrossFalante: TimeInterval = 0.5

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
            // Overlap germinal: o vencedor cobre menos da metade da palavra —
            // a franja é imprecisão de fronteira, não evidência. Fica sem
            // falante para a resolução contextual decidir.
            let duracao = palavra.end - palavra.start
            if duracao > 0, primeiro.overlap < duracao / 2 {
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

        // Buraco: costura até o segmento contíguo mais próximo, se pequeno —
        // mas o tamanho da ponte depende de quem está dos lados. Todos do
        // MESMO falante é continuação de turno (ponte de `ponteMaxima`);
        // falantes diferentes é fronteira de turno: só costura perto
        // (`ponteCrossFalante`), e distâncias parecidas (2º ≤ 125% do 1º) é
        // empate — nada de chute.
        let distancias = segmentos
            .map { (segmento: $0, distancia: distancia(palavra, $0)) }
            .sorted { $0.distancia < $1.distancia }
        guard let maisProximo = distancias.first,
              maisProximo.distancia <= ponteMaxima else {
            return palavra
        }
        if let segundo = distancias.dropFirst().first,
           segundo.segmento.falanteId != maisProximo.segmento.falanteId {
            guard maisProximo.distancia <= ponteCrossFalante else {
                return palavra
            }
            if segundo.distancia <= maisProximo.distancia * 1.25 {
                return palavra
            }
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