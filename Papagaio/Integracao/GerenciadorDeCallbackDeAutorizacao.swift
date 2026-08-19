import Foundation

/// Ponto único de entrega do retorno `papagaio://` do fluxo OAuth.
///
/// Quando o navegador é o padrão do sistema (fallback do fluxo, quando a
/// `ASWebAuthenticationSession` não abre), o retorno da autorização chega ao
/// app pelo scheme declarado no Info.plist; o `ContentView` encaminha o URL
/// para cá, que valida o `state` e entrega o código a quem está esperando.
///
/// As três vias de retorno (sessão gerenciada do macOS, navegador padrão e o
/// tempo limite) disputam a mesma espera: só quem retira a entrada do
/// repositório chama a continuação, então sempre exatamente um resultado
/// chega — nunca duas.
final class GerenciadorDeCallbackDeAutorizacao: @unchecked Sendable {
    static let compartilhado = GerenciadorDeCallbackDeAutorizacao()

    private let trava = NSLock()
    private var esperas: [String: (Result<String, ErroOAuth>) -> Void] = [:]

    /// Registra a espera do `state` da URL que abriu no navegador.
    func aguardar(
        estado: String,
        fim: @escaping (Result<String, ErroOAuth>) -> Void
    ) {
        trava.lock()
        esperas[estado] = fim
        trava.unlock()
    }

    /// Entrega um `papagaio://` recebido pelo app (navegador padrão). Devolve
    /// `true` se o URL tinha um `state` com espera registrada.
    func entregar(_ url: URL) -> Bool {
        guard let itens = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems,
            let estado = itens.first(where: { $0.name == "state" })?.value
        else { return false }

        let codigo = itens.first(where: { $0.name == "code" })?.value
        if let codigo {
            resolver(estado: estado, com: .success(codigo))
        } else {
            resolver(estado: estado, com: .failure(.autorizacaoNegada))
        }
        return true
    }

    /// Resolve a espera com um resultado determinado. Só a primeira chamada
    /// por `state` tem efeito; as demais são ignoradas.
    func resolver(estado: String, com resultado: Result<String, ErroOAuth>) {
        trava.lock()
        let fim = esperas.removeValue(forKey: estado)
        trava.unlock()
        fim?(resultado)
    }
}