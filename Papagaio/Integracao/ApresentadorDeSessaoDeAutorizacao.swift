import AppKit
import AuthenticationServices
import PapagaioCore

/// `ApresentadorDeAutorizacaoOAuth` do app: abre o navegador gerenciado do
/// macOS (`ASWebAuthenticationSession`) com o scheme
/// `papagaio://oauth` declarado no Info.plist, e devolve o código de
/// autorização — validando o `state` da própria URL que abriu (defesa contra
/// o callback chegar fora de ordem ou de outra sessão).
struct ApresentadorDeSessaoDeAutorizacao: ApresentadorDeAutorizacaoOAuth {
    func autorizar(url: URL) async throws -> String {
        let estadoEsperado = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first { $0.name == "state" }?
            .value

        // A sessão não pode sair de escopo antes do callback: a continuação
        // fica guardada numa caixa também capturada pelo handler.
        let caixa = CaixaDeSessao()
        return try await withCheckedThrowingContinuation { continuacao in
            caixa.sessao = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: "papagaio",
                completionHandler: { callbackURL, erro in
                    defer { caixa.sessao = nil }
                    if let erro {
                        continuacao.resume(throwing: ErroOAuth.autorizacaoNegada)
                        return
                    }
                    guard let callbackURL,
                          let itens = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                              .queryItems,
                          itens.first(where: { $0.name == "state" })?.value == estadoEsperado,
                          let codigo = itens.first(where: { $0.name == "code" })?.value
                    else {
                        continuacao.resume(throwing: ErroOAuth.autorizacaoNegada)
                        return
                    }
                    continuacao.resume(returning: codigo)
                }
            )
            caixa.provedor = ProvedorDeAncora()
            caixa.sessao?.presentationContextProvider = caixa.provedor
            _ = caixa.sessao?.start()
        }
    }
}

/// A `ASWebAuthenticationSession` precisa de uma âncora de apresentação; o
/// `presentationContextProvider` é `weak`, então a caixa segura o provedor.
private final class CaixaDeSessao: @unchecked Sendable {
    var sessao: ASWebAuthenticationSession?
    var provedor: ProvedorDeAncora?
}

/// Âncora: a janela principal do app (ou a chave, se houver mais de uma).
private final class ProvedorDeAncora: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApp.keyWindow ?? NSApp.windows.first ?? ASPresentationAnchor()
    }
}