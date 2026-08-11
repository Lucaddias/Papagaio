import Foundation
import Testing
@testable import PapagaioCore

// Testes de integração com os modelos estagiados pelo bootstrap. Só validam
// layout — carregar CoreML em teste unitário custaria minutos e não testaria
// regra de negócio nenhuma (a qualidade acústica é da comunidade-1, não nossa).

@Test("Modelos de diarização estagiados pelo bootstrap estão no bundle")
func modelosDeDiarizacaoEstagiadosNoBundle() {
    let gerente = GerenciadorDeModelosDeDiarizacao.embutido()
    #expect(gerente.disponivel, "rode Scripts/bootstrap-runtimes.sh")
}

@Test("Sem diretório, o gerente reporta indisponível em vez de falhar feio")
func gerenteSemModelosEstaIndisponivel() {
    let gerente = GerenciadorDeModelosDeDiarizacao(diretorio: nil)
    #expect(gerente.disponivel == false)
}