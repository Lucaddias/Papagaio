import Foundation

/// Onde a reprodução está, em termos de trecho.
///
/// `Trecho.start` é a chave da navegação desde o Passo 1 — aqui ela é usada nas
/// duas direções: do clique para o tempo (`saltar`) e do tempo para o destaque
/// na lista (`indiceAtivo`). Ver skill `papagaio-app-surface`.
public enum NavegacaoPorTrecho {
    /// Índice do trecho que o usuário está lendo no instante `tempo`.
    ///
    /// Busca binária pelo **último** trecho que já começou. A consequência é
    /// deliberada: num silêncio entre dois trechos o destaque **fica no trecho
    /// que acabou de tocar** em vez de sumir. Destaque que pisca a cada pausa
    /// parece defeito, e o texto que o usuário está lendo continua sendo aquele
    /// (ver D-10.2).
    ///
    /// Devolve `nil` só antes do primeiro trecho — silêncio inicial não tem
    /// texto para destacar.
    ///
    /// - Precondition: `trechos` ordenado por `start`, que é como a
    ///   `Segmentacao` e o `SwiftDataRepository` entregam.
    public static func indiceAtivo(em tempo: TimeInterval, trechos: [Trecho]) -> Int? {
        guard let primeiro = trechos.first, tempo >= primeiro.start else { return nil }

        var baixo = 0
        var alto = trechos.count - 1
        var achado = 0
        while baixo <= alto {
            let meio = (baixo + alto) / 2
            if trechos[meio].start <= tempo {
                achado = meio
                baixo = meio + 1
            } else {
                alto = meio - 1
            }
        }
        return achado
    }

    /// Conveniência sobre `indiceAtivo`.
    public static func trechoAtivo(em tempo: TimeInterval, trechos: [Trecho]) -> Trecho? {
        indiceAtivo(em: tempo, trechos: trechos).map { trechos[$0] }
    }
}
