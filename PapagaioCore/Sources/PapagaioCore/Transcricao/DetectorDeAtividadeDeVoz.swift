import Foundation

/// VAD — corta silêncio **dentro** do áudio antes de mandar para o Whisper,
/// não só decide se o arquivo inteiro tem fala ou não.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ATUALIZAÇÃO: a versão anterior só fazia `contemFala(nas:)` — um portão de
/// tudo-ou-nada para o arquivo inteiro. Isso NÃO evita o que o diagrama
/// original chama de "obrigatório: whisper alucina em silêncio": um arquivo
/// de 40 minutos com fala real passava no portão (`contemFala == true`) e
/// então ia inteiro, silêncios longos inclusos, para uma ÚNICA chamada de
/// `whisper_full`. É exatamente esse o cenário clássico de alucinação e
/// repetição em cascata do Whisper — o modelo tem que decodificar "alguma
/// coisa" para os trechos sem fala, erra, e (mesmo com `no_context = true`
/// entre janelas do whisper.cpp) o padrão degenerado de repetição acontece
/// DENTRO da própria janela deslizante interna do whisper.cpp, que
/// `no_context` não alcança.
///
/// A correção: identificar as janelas de fala dentro do áudio e mandar cada
/// uma para o Whisper separadamente — silêncio nunca chega ao decoder. Ver
/// `WhisperEngine.transcribe`, que agora itera essas janelas.
///
/// SEGUNDA ATUALIZAÇÃO: o gate por quadro era só energia — qualquer sinal
/// com energia sustenta passa (DC, tom, ruído). A energia foi mantida como
/// filtro rápido e barato, mas a decisão agora é do Silero VAD (M.1), que
/// distingue fala real de tom/DC/ruído. Ver `SileroVAD`.
/// ═══════════════════════════════════════════════════════════════════════
public enum DetectorDeAtividadeDeVoz {
    public struct JanelaDeFala: Sendable, Equatable {
        public let inicio: TimeInterval
        public let fim: TimeInterval
    }

    /// Instância compartilhada do Silero: o modelo de 2,3 MB fica residente
    /// entre arquivos. O caminho inexistente é proposital — `SessaoOnnx`
    /// devolve erro de carga em vez de crashar se o resource faltar.
    private static let sileroVAD = SileroVAD(
        modelo: Bundle.module.url(forResource: "silero_vad", withExtension: "onnx")
            ?? URL(fileURLWithPath: "/inexistente/silero_vad.onnx")
    )

    /// Portão de arquivo inteiro — mantido só para quem ainda chama esta API
    /// (ex.: testes). Prefira `janelasDeFala` para transcrição de verdade.
    public static func contemFala(
        nas amostras: [Float],
        taxa: Double = FormatoAudio.taxaCanonica
    ) async throws -> Bool {
        try await !janelasDeFala(nas: amostras, taxa: taxa).isEmpty
    }

    /// Identifica as janelas com fala dentro do áudio, tolerando pausas
    /// curtas (respiração, hesitação natural) sem fragmentar a frase, e
    /// devolve com uma margem de segurança antes/depois de cada janela para
    /// não cortar o início/fim de uma palavra.
    ///
    /// - Parameters:
    ///   - duracaoDoQuadro: 32 ms por padrão — é o quadro do Silero VAD
    ///     (512 amostras @ 16 kHz). Trocar exige trocar o tamanho esperado
    ///     pelo `SileroVAD` também.
    ///   - limiarDeEnergia: filtro rápido antes do Silero — energia RMS do
    ///     quadro abaixo disso nunca é fala (silêncio digital não passa pelo
    ///     modelo neural à toa).
    ///   - limiarDeFala: probabilidade mínima de fala do Silero, validada
    ///     empiricamente em 0,5 (fala real chega a ~1,0; DC/tom/ruído ficam
    ///     abaixo de 0,2).
    public static func janelasDeFala(
        nas amostras: [Float],
        taxa: Double = FormatoAudio.taxaCanonica,
        duracaoDoQuadro: TimeInterval = 0.032,
        limiarDeEnergia: Float = 0.008,
        limiarDeFala: Float = 0.5,
        silencioMinimoParaCortar: TimeInterval = 0.6,
        margem: TimeInterval = 0.2
    ) async throws -> [JanelaDeFala] {
        guard !amostras.isEmpty else { return [] }
        let tamanhoDoQuadro = max(1, Int(duracaoDoQuadro * taxa))

        // Sequência nova = contexto e estado do Silero zerados. Sem isto, a
        // "memória" de fala de um arquivo vazaria para o seguinte.
        await sileroVAD.novaSequencia()

        var quadroTemFala: [Bool] = []
        quadroTemFala.reserveCapacity(amostras.count / tamanhoDoQuadro + 1)
        var inicio = 0
        while inicio < amostras.count {
            let fim = min(inicio + tamanhoDoQuadro, amostras.count)
            let quadro = amostras[inicio..<fim]
            let energia = sqrt(quadro.reduce(Float.zero) { $0 + $1 * $1 } / Float(max(1, quadro.count)))
            var temFala = energia >= limiarDeEnergia
            if temFala {
                // O Silero só é consultado quando a energia já passou — é o
                // filtro rápido contra silêncio digital.
                temFala = try await sileroVAD.probabilidadeDeFala(quadro: Array(quadro)) >= limiarDeFala
            }
            quadroTemFala.append(temFala)
            inicio = fim
        }

        var janelas: [JanelaDeFala] = []
        var inicioDaJanela: Int?
        var ultimoQuadroComFala = -1
        let quadrosDeSilencioParaCortar = max(1, Int(silencioMinimoParaCortar / duracaoDoQuadro))

        func fechar(ateQuadro fimQuadro: Int) {
            guard let inicioQuadro = inicioDaJanela else { return }
            let duracaoTotal = Double(amostras.count) / taxa
            let comecoSegundos = max(0, Double(inicioQuadro) * duracaoDoQuadro - margem)
            let fimSegundos = min(duracaoTotal, Double(fimQuadro + 1) * duracaoDoQuadro + margem)
            if fimSegundos > comecoSegundos {
                janelas.append(JanelaDeFala(inicio: comecoSegundos, fim: fimSegundos))
            }
        }

        for (indice, temFala) in quadroTemFala.enumerated() {
            if temFala {
                if inicioDaJanela == nil { inicioDaJanela = indice }
                ultimoQuadroComFala = indice
            } else if inicioDaJanela != nil, indice - ultimoQuadroComFala > quadrosDeSilencioParaCortar {
                fechar(ateQuadro: ultimoQuadroComFala)
                inicioDaJanela = nil
            }
        }
        if inicioDaJanela != nil {
            fechar(ateQuadro: ultimoQuadroComFala)
        }

        return janelas
    }

    /// Recorta as amostras de uma janela específica.
    public static func amostras(
        de amostras: [Float],
        na janela: JanelaDeFala,
        taxa: Double = FormatoAudio.taxaCanonica
    ) -> [Float] {
        let inicio = max(0, Int(janela.inicio * taxa))
        let fim = min(amostras.count, Int(janela.fim * taxa))
        guard inicio < fim else { return [] }
        return Array(amostras[inicio..<fim])
    }
}
