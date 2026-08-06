import Foundation

/// Onde a reprodução está, em termos de palavra dentro do trecho ativo.
///
/// Mesma semântica de `NavegacaoPorTrecho`: busca binária pelo **último** que
/// começou, para o destaque não piscar no silêncio entre palavras. A diferença
/// é que aqui só se consultam as palavras do **trecho ativo** — um trecho tem
/// ~150 palavras no máximo, então a busca é barata mesmo feita a cada tick.
///
/// - Precondition: `palavras` ordenado por `start`, que é como a
///   `Segmentacao` (concatenação em ordem) e o `WhisperEngine` entregam.
public enum NavegacaoPorPalavra {
    /// Índice da palavra tocando no instante `tempo, dentro do trecho.
    ///
    /// Devolve `nil` só antes da primeira palavra — o trecho não tem "palavra
    /// anterior" para manter o destaque, e o usuário ainda está lendo o título.
    public static func indiceAtivo(em tempo: TimeInterval, palavras: [Palavra]) -> Int? {
        guard let primeira = palavras.first, tempo >= primeira.start else { return nil }

        var baixo = 0
        var alto = palavras.count - 1
        var achado = 0
        while baixo <= alto {
            let meio = (baixo + alto) / 2
            if palavras[meio].start <= tempo {
                achado = meio
                baixo = meio + 1
            } else {
                alto = meio - 1
            }
        }
        return achado
    }
}