import Testing
@testable import Papagaio

// O marcador de recomposição que substituiu o contador solto da
// BibliotecaHomeView: simples, mas é o que mantém favoritos, pastas e
// lixeiras sincronizados com a tela — vale o teste.

@MainActor
@Test("Cada mudança avança a geração, começando do zero")
func invalidacaoVisualAvanca() {
    let invalidacao = InvalidacaoVisual()
    #expect(invalidacao.geracao == 0)

    invalidacao.marcarMudanca()
    invalidacao.marcarMudanca()

    #expect(invalidacao.geracao == 2)
}
