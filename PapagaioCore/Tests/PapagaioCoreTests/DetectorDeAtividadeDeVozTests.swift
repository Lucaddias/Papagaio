import Foundation
import Testing
@testable import PapagaioCore

/// VAD por Silero (M.1): distingue fala real de sinais que só têm energia.
/// Fala real tem que passar; DC, tom, ruído branco e rosa têm que ser
/// rejeitados mesmo com energia acima do limiar — é exatamente a garantia
/// que a heurística de energia não dava.
///
/// A frase de fala vem de uma fixture commitada (gerada **uma vez** por
/// Tests/PapagaioCoreTests/Fixtures/gerar_fixture.sh via `say`), para o teste
/// rodar sempre — sem depender de `say`/voz instalada na hora do teste.
///
/// Serializado de propósito: o `DetectorDeAtividadeDeVoz` compartilha uma
/// única instância do Silero (design de produção — modelo residente). Os
/// testes desta suite rodarem em paralelo zeraria o contexto/estado do VAD
/// uns dos outros no meio da inferência (a "memória" de frase vaza entre
/// arquivos) e a decisão sobre ruído rosa passa a depender da ordem de
/// entrelaçamento.
@Suite("Detector de atividade de voz com Silero", .serialized)
struct DetectorDeAtividadeDeVozTests {
    private func carregarFixture(_ nome: String) async throws -> [Float] {
        let pasta = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
        return try await DecodificadorDeAudio.amostras(
            de: pasta.appendingPathComponent(nome)
        )
    }

    // MARK: - Aceitação: fala real

    @Test("Aceita fala real da fixture (TTS)")
    func aceitaFalaReal() async throws {
        let amostras = try await carregarFixture("fala_ola_mundo.wav")
        // Sanidade: a fixture tem ~4 s de áudio.
        #expect(amostras.count > 16_000 * 3)
        let temFala = try await DetectorDeAtividadeDeVoz.contemFala(nas: amostras)
        #expect(temFala)
    }

    // MARK: - Rejeição: sinais que só a energia deixa passar

    @Test("Rejeita silêncio")
    func rejeitaSilencio() async throws {
        let silencio = [Float](repeating: 0, count: 16_000 * 2)
        #expect(!(try await DetectorDeAtividadeDeVoz.contemFala(nas: silencio)))
    }

    @Test("Rejeita sinal constante (engana só a energia)")
    func rejeitaSinalConstante() async throws {
        let dc = [Float](repeating: 0.02, count: 16_000 * 2)
        #expect(!(try await DetectorDeAtividadeDeVoz.contemFala(nas: dc)))
    }

    @Test("Rejeita tom puro esteja com energia")
    func rejeitaTom() async throws {
        let tom = (0..<(16_000 * 2)).map {
            Float(0.05 * sin(2 * Double.pi * 440 * Double($0) / 16_000))
        }
        #expect(!(try await DetectorDeAtividadeDeVoz.contemFala(nas: tom)))
    }

    @Test("Rejeita ruído branco em nível de fala")
    func rejeitaRuidoBranco() async throws {
        var ruido = RuidoDeterministico(seed: 42)
        let branco = ruido.branco(16_000 * 2, alvoRms: 0.02)
        #expect(!(try await DetectorDeAtividadeDeVoz.contemFala(nas: branco)))
    }

    @Test("Rejeita ruído rosa em nível de fala")
    func rejeitaRuidoRosa() async throws {
        var ruido = RuidoDeterministico(seed: 42)
        let rosa = ruido.rosa(16_000 * 2, alvoRms: 0.02)
        #expect(!(try await DetectorDeAtividadeDeVoz.contemFala(nas: rosa)))
    }
}

/// Fontes de ruído **determinísticas** (LCG de 64 bits): os testes não podem
/// depender do `random()` do sistema — CI e máquina local têm que ver a mesma
/// sequência.
private struct RuidoDeterministico {
    private var rng: UInt64

    init(seed: UInt64) {
        self.rng = seed
    }

    /// Próximo valor pseudo-aleatório em [−0,5, 0,5). Divisor por potência de
    /// dois, sem reinterpretação de sinal — o gerador é simétrico em zero, sem
    /// viés de DC.
    mutating func proximo() -> Float {
        rng = rng &* 6364136223846793005 &+ 1442695040888963407
        return Float(rng >> 33) / 2_147_483_648 - 0.5
    }

    /// Ruído branco escalado para um RMS alvo (acima do limiar de energia do
    /// detector, para provar que a rejeição vem do Silero e não da porta de
    /// energia).
    mutating func branco(_ quantidade: Int, alvoRms: Float) -> [Float] {
        var cru = (0..<quantidade).map { _ in proximo() }
        let escala = alvoRms / rms(cru)
        return cru.map { $0 * escala }
    }

    /// Ruído rosa (posto Voss–McCartney de 16 pólos, mesmos coeficientes
    /// validados no scratch).
    mutating func rosa(_ quantidade: Int, alvoRms: Float) -> [Float] {
        var b = [Float](repeating: 0, count: 16)
        var saida = [Float](repeating: 0, count: quantidade)
        for i in 0..<quantidade {
            let w = proximo()
            b[0] = 0.99886 * b[0] + w * 0.0555179
            b[1] = 0.99332 * b[1] + w * 0.0750759
            b[2] = 0.96900 * b[2] + w * 0.1538520
            b[3] = 0.86650 * b[3] + w * 0.3016212
            b[4] = 0.46650 * b[4] + w * 0.3072508
            b[5] = w * 0.4953918
            saida[i] = b[0] + b[1] + b[2] + b[3] + b[4] + b[5] + b[6] + w * 0.011
            b[6] = w * 0.125
        }
        let escala = alvoRms / rms(saida)
        return saida.map { $0 * escala }
    }

    private func rms(_ amostras: [Float]) -> Float {
        sqrt(amostras.reduce(Float.zero) { $0 + $1 * $1 } / Float(amostras.count))
    }
}
