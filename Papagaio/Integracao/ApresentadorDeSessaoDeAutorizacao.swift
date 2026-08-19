import AppKit
import AuthenticationServices
import os
import PapagaioCore

/// `ApresentadorDeAutorizacaoOAuth` do app: abre o navegador gerenciado do
/// macOS (`ASWebAuthenticationSession`) com o scheme `papagaio://` declarado
/// no Info.plist, e devolve o código de autorização — validando o `state` da
/// própria URL que abriu (defesa contra o callback chegar fora de ordem ou de
/// outra sessão).
///
/// Se a sessão gerenciada se recusar a abrir (`start()` devolvendo `false`,
/// o que acontece sem o app ativo ou sem a âncora adequada), o fluxo cai no
/// navegador padrão via `NSWorkspace`, e o retorno `papagaio://` é entregue
/// pelo `GerenciadorDeCallbackDeAutorizacao`. Um tempo limite de 5 minutos
/// encerra qualquer espera que sobrar.
struct ApresentadorDeSessaoDeAutorizacao: ApresentadorDeAutorizacaoOAuth {
    private let registro = Logger(subsystem: "Papagaio", category: "Granola")

    // A `ASWebAuthenticationSession` precisa nascer e ser iniciada na main
    // thread. A sessão OAuth roda no executor global (os `await` do fluxo
    // saltam de thread), então esta implementação é isolada no MainActor: em
    // background o `start()` fica preso sem apresentar o navegador.
    @MainActor
    func autorizar(url: URL) async throws -> String {
        let estadoEsperado = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first { $0.name == "state" }?
            .value ?? ""
        registro.info("Pedindo autorização (state \(estadoEsperado, privacy: .public))")

        return try await withCheckedThrowingContinuation { continuacao in
            // A continuação é a MESMA para as três vias de retorno
            // (sessão gerenciada, navegador padrão e tempo limite); o
            // gerenciador garante que só a primeira tenha efeito.
            GerenciadorDeCallbackDeAutorizacao.compartilhado.aguardar(estado: estadoEsperado) { resultado in
                continuacao.resume(with: resultado)
            }

            let caixa = CaixaDeSessao()
            caixa.sessao = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: "papagaio",
                completionHandler: { callbackURL, erro in
                    defer { caixa.sessao = nil }
                    if let erro {
                        registro.info("Sessão gerenciada terminou com erro: \(erro.localizedDescription, privacy: .public)")
                        GerenciadorDeCallbackDeAutorizacao.compartilhado.resolver(
                            estado: estadoEsperado,
                            com: .failure(.autorizacaoNegada)
                        )
                        return
                    }
                    guard let callbackURL,
                          let itens = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                              .queryItems,
                          itens.first(where: { $0.name == "state" })?.value == estadoEsperado,
                          let codigo = itens.first(where: { $0.name == "code" })?.value
                    else {
                        registro.info("Sessão gerenciada voltou sem código válido")
                        GerenciadorDeCallbackDeAutorizacao.compartilhado.resolver(
                            estado: estadoEsperado,
                            com: .failure(.autorizacaoNegada)
                        )
                        return
                    }
                    registro.info("Código de autorização recebido pela sessão gerenciada")
                    GerenciadorDeCallbackDeAutorizacao.compartilhado.resolver(
                        estado: estadoEsperado,
                        com: .success(codigo)
                    )
                }
            )
            caixa.provedor = ProvedorDeAncora()
            caixa.sessao?.presentationContextProvider = caixa.provedor

            // A janela do app tem que estar ativa na frente das outras para
            // a sessão gerenciada apresentar o navegador — sem isto o
            // `start()` se recusa em silêncio.
            NSApp.activate(ignoringOtherApps: true)

            // A sessão não pode sair de escopo antes do callback: a caixa é
            // capturada também pelo handler acima.
            if caixa.sessao?.start() == true {
                registro.info("Navegador gerenciado do macOS apresentado")
            } else {
                registro.fault("Sessão gerenciada não abriu; usando o navegador padrão")
                NSWorkspace.shared.open(url)
            }

            // Garantia contra espera eterna: encerra a autorização depois de
            // 5 minutos, não importa o caminho (navegador perdido, sessão que
            // não apresentou janela etc.).
            Task {
                try? await Task.sleep(for: .seconds(300))
                GerenciadorDeCallbackDeAutorizacao.compartilhado.resolver(
                    estado: estadoEsperado,
                    com: .failure(.tempoEsgotado)
                )
            }
        }
    }
}

/// A `ASWebAuthenticationSession` precisa de uma âncora de apresentação; o
/// `presentationContextProvider` é `weak`, então a caixa segura o provedor.
private final class CaixaDeSessao: @unchecked Sendable {
    var sessao: ASWebAuthenticationSession?
    var provedor: ProvedorDeAncora?
}

/// Âncora: a janela principal do app (ou a primeira visível), nunca uma
/// janela fantasma — uma âncora inválida faz o `start()` falhar em silêncio.
private final class ProvedorDeAncora: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApp.mainWindow
            ?? NSApp.windows.first(where: \.isVisible)
            ?? ASPresentationAnchor()
    }
}