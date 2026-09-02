import Accelerate

/// Cancelador de eco acústico (AEC) em software.
///
/// Quando o usuário **não** está com fones, o áudio do sistema vaza para o
/// microfone: o som dos alto-falantes é capturado junto com a voz. Este
/// cancelador usa um filtro adaptativo NLMS (Normalized Least Mean Squares)
/// para estimar e subtrair o sinal de eco do microfone.
///
/// **Pré-condições de uso:**
/// - Ambos os sinais (microfone e sistema) devem estar em 16 kHz mono.
/// - O sinal do sistema é o *reference*; o do microfone é o *input*.
public final class CanceladorDeEco: @unchecked Sendable {

    /// Tamanho do bloco processado por chamada.
    public let tamanhoBloco: Int

    /// Comprimento do filtro adaptativo em amostras. 4096 taps ≈ 256 ms a 16 kHz.
    public let comprimentoFiltro: Int

    /// Passo (learning rate) do NLMS.
    private let mu: Float

    /// Coeficientes do filtro adaptativo.
    private var filtros: [Float]

    /// Energia do vetor de referência (para normalização NLMS).
    private var energiaRef: Float = 1e-6

    /// Buffer circular com as últimas amostras de referência (sistema).
    private var refBuffer: [Float]

    /// Posição de escrita no buffer circular.
    private var refIdx: Int = 0

    /// Contador de amostras desde a última estimativa de atraso.
    private var contadorEstimativa: Int = 0

    // MARK: - Init

    /// - Parameters:
    ///   - tamanhoBloco: Número de amostras por chamada de `processar()`.
    ///   - comprimentoFiltro: Número de taps do filtro adaptativo.
    ///   - mu: Passo do NLMS (0 < μ ≤ 1).
    public init(
        tamanhoBloco: Int = 512,
        comprimentoFiltro: Int = 4096,
        mu: Float = 0.5
    ) {
        precondition(tamanhoBloco > 0)
        precondition(comprimentoFiltro >= tamanhoBloco)
        precondition(mu > 0 && mu <= 1)

        self.tamanhoBloco = tamanhoBloco
        self.comprimentoFiltro = comprimentoFiltro
        self.mu = mu
        self.filtros = [Float](repeating: 0, count: comprimentoFiltro)
        self.refBuffer = [Float](repeating: 0, count: comprimentoFiltro)
    }

    // MARK: - API pública

    /// Processa um bloco de microfone e retorna o sinal com eco reduzido.
    public func processar(
        blocoMicrofone: [Float],
        blocoSistema: [Float]
    ) -> [Float] {
        guard blocoMicrofone.count == tamanhoBloco,
              blocoSistema.count == tamanhoBloco else {
            return blocoMicrofone
        }

        var saida = [Float](repeating: 0, count: tamanhoBloco)

        for i in 0..<tamanhoBloco {
            // Insere a amostra de referência no buffer circular.
            let idx = (refIdx + i) % comprimentoFiltro
            refBuffer[idx] = blocoSistema[i]

            // Extrai o vetor de referência na ordem do filtro (mais recente → mais antigo).
            var refBloco = [Float](repeating: 0, count: comprimentoFiltro)
            for j in 0..<comprimentoFiltro {
                refBloco[j] = refBuffer[(idx &- j &+ comprimentoFiltro) % comprimentoFiltro]
            }

            // Saída do filtro: y = w^T · x
            var estimativaEcho: Float = 0
            vDSP_dotpr(filtros, 1, refBloco, 1, &estimativaEcho, vDSP_Length(comprimentoFiltro))

            let erro = blocoMicrofone[i] - estimativaEcho
            saida[i] = erro

            // NLMS: w = w + μ · e · x / (‖x‖² + δ)
            var normaQuadrada: Float = 0
            vDSP_svesq(refBloco, 1, &normaQuadrada, vDSP_Length(comprimentoFiltro))
            let norma = normaQuadrada + 1e-6

            guard norma.isFinite, erro.isFinite else { continue }
            let escalar = mu * erro / norma

            for j in 0..<comprimentoFiltro {
                filtros[j] += escalar * refBloco[j]
            }
        }

        refIdx = (refIdx + tamanhoBloco) % comprimentoFiltro

        return saida
    }

    /// Redefine o estado interno do cancelador.
    public func resetar() {
        filtros = [Float](repeating: 0, count: comprimentoFiltro)
        refBuffer = [Float](repeating: 0, count: comprimentoFiltro)
        refIdx = 0
        energiaRef = 1e-6
        contadorEstimativa = 0
    }
}
