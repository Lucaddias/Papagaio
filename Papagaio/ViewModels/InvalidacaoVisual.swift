import Foundation
import Observation

/// Marcador de recomposição para estado que vem de `UserDefaults` (favoritos,
/// pastas, lixeiras) — que não notifica observadores sozinho. Quem muta chama
/// `marcarMudanca()`; as views que leem do disco observam `geracao` e
/// recompõem.
///
/// Substitui o antigo contador solto na `BibliotecaHomeView`
/// (`versaoDasPreferenciasVisuais`, lido com `_ =` em seis computed
/// properties): mesmo mecanismo, mas observável, com nome e API explícita —
/// e sem depender de `@State` de cada tela.
@MainActor
@Observable
final class InvalidacaoVisual {
    private(set) var geracao = 0

    func marcarMudanca() {
        geracao += 1
    }
}
