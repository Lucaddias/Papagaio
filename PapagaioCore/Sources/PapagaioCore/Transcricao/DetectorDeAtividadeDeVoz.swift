import Foundation

/// Barreira leve contra alucinação em um canal sem fala. Não tenta identificar
/// palavras: só exige energia sustentada antes de chamar o Whisper.
public enum DetectorDeAtividadeDeVoz {
    public static func contemFala(
        nas amostras: [Float],
        taxa: Double = FormatoAudio.taxaCanonica
    ) -> Bool {
        let tamanhoDoQuadro = max(1, Int(taxa * 0.03))
        let limiar: Float = 0.008
        let quadrosConsecutivosNecessarios = 4
        var consecutivos = 0

        for inicio in stride(from: 0, to: amostras.count, by: tamanhoDoQuadro) {
            let fim = min(inicio + tamanhoDoQuadro, amostras.count)
            let quadro = amostras[inicio..<fim]
            let energia = sqrt(quadro.reduce(Float.zero) { $0 + $1 * $1 } / Float(max(1, quadro.count)))
            if energia >= limiar {
                consecutivos += 1
                if consecutivos >= quadrosConsecutivosNecessarios { return true }
            } else {
                consecutivos = 0
            }
        }
        return false
    }
}
