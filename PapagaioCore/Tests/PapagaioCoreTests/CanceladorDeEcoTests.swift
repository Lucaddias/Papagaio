import XCTest
@testable import PapagaioCore

final class CanceladorDeEcoTests: XCTestCase {

    func testSaidaMesmoTamanhoDoInput() {
        let cancelador = CanceladorDeEco(tamanhoBloco: 256, comprimentoFiltro: 512)
        let mic = [Float](repeating: 0.1, count: 256)
        let sis = [Float](repeating: 0.05, count: 256)
        let saida = cancelador.processar(blocoMicrofone: mic, blocoSistema: sis)
        XCTAssertEqual(saida.count, 256)
    }

    func testRetornaMicrofoneSeTamanhosDiferem() {
        let cancelador = CanceladorDeEco(tamanhoBloco: 256)
        let mic = [Float](repeating: 0.1, count: 100)
        let sis = [Float](repeating: 0.05, count: 256)
        let saida = cancelador.processar(blocoMicrofone: mic, blocoSistema: sis)
        XCTAssertEqual(saida, mic)
    }

    func testSubtraiEcoQuandoSinalReferenciaEIdentico() {
        let cancelador = CanceladorDeEco(tamanhoBloco: 512, comprimentoFiltro: 1024, mu: 0.3)
        // Eco atrasado: o sinal do sistema chega ao microfone com 10 amostras de atraso.
        var eco = [Float](repeating: 0, count: 512)
        for i in 10..<512 { eco[i] = Float(i) / 512.0 }

        var energiaAntes: Float = 0
        var energiaDepois: Float = 0

        // Alimenta o cancelador com blocos repetidos para que o filtro convirja.
        for passo in 0..<50 {
            let resultado = cancelador.processar(blocoMicrofone: eco, blocoSistema: eco)
            if passo < 20 { energiaAntes = resultado.reduce(0) { $0 + $1 * $1 } }
            if passo >= 40 { energiaDepois = resultado.reduce(0) { $0 + $1 * $1 } }
        }

        // Após convergência, a energia residual deve ser menor que no início.
        XCTAssertLessThan(energiaDepois, energiaAntes,
                          "O filtro deveria ter reduzido o eco ao longo do tempo")
    }

    func testNaoDestruiSinalDeVoz() {
        let cancelador = CanceladorDeEco(tamanhoBloco: 512, comprimentoFiltro: 1024, mu: 0.3)
        // Voz: seno de 300 Hz (frequência típica de fala).
        let voz = (0..<512).map { sin(2.0 * .pi * 300.0 * Float($0) / 16_000.0) }
        // Sistema: silêncio (sem eco).
        let silencio = [Float](repeating: 0, count: 512)

        let resultado = cancelador.processar(blocoMicrofone: voz, blocoSistema: silencio)
        let energiaEntrada = voz.reduce(0) { $0 + $1 * $1 }
        let energiaSaida = resultado.reduce(0) { $0 + $1 * $1 }

        // Com sistema em silêncio, o filtro não deveria alterar muito a voz.
        XCTAssertGreaterThan(energiaSaida, energiaEntrada * 0.5,
                             "A voz não deveria ser destruída quando não há eco")
    }

    func testResetarLimpaEstado() {
        let cancelador = CanceladorDeEco(tamanhoBloco: 256, comprimentoFiltro: 512)
        let mic = [Float](repeating: 0.1, count: 256)
        let sis = [Float](repeating: 0.05, count: 256)

        _ = cancelador.processar(blocoMicrofone: mic, blocoSistema: sis)
        cancelador.resetar()

        // Após reset, comportamento deve ser como novo.
        let resultado = cancelador.processar(blocoMicrofone: mic, blocoSistema: sis)
        XCTAssertEqual(resultado.count, 256)
    }

    func test_blocosSequenciaisNaoCrasham() {
        let cancelador = CanceladorDeEco(tamanhoBloco: 128, comprimentoFiltro: 256)
        let mic = [Float](repeating: 0.05, count: 128)
        let sis = [Float](repeating: 0.02, count: 128)

        // Processa 100 blocos sequenciais.
        for _ in 0..<100 {
            let saida = cancelador.processar(blocoMicrofone: mic, blocoSistema: sis)
            XCTAssertEqual(saida.count, 128)
        }
    }
}
