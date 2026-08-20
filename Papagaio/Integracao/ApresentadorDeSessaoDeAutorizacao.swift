import AppKit
import os
import PapagaioCore

/// `ApresentadorDeAutorizacaoOAuth` do app: abre a autorização no navegador
/// padrão do sistema (`NSWorkspace`) e devolve o código de autorização —
/// validando o `state` da própria URL que abriu (defesa contra o callback
/// chegar fora de ordem ou de outra sessão).
///
/// O retorno `papagaio://` é entregue pelo `GerenciadorDeCallbackDeAutorizacao`
/// via `onOpenURL` do app (scheme declarado no Info.plist). Um tempo limite de
/// 5 minutos encerra qualquer espera que sobrar.
struct ApresentadorDeSessaoDeAutorizacao: ApresentadorDeAutorizacaoOAuth {
    private let registro = Logger(subsystem: "Papagaio", category: "Granola")

    @MainActor
    func autorizar(url: URL) async throws -> String {
        let estadoEsperado = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first { $0.name == "state" }?
            .value ?? ""
        registro.info("Pedindo autorização (state \(estadoEsperado, privacy: .public))")

        return try await withCheckedThrowingContinuation { continuacao in
            GerenciadorDeCallbackDeAutorizacao.compartilhado
                .aguardar(estado: estadoEsperado) { resultado in
                    continuacao.resume(with: resultado)
                }

            if !NSWorkspace.shared.open(url) {
                registro.fault("Navegador padrão não abriu a URL de autorização")
                GerenciadorDeCallbackDeAutorizacao.compartilhado.resolver(
                    estado: estadoEsperado,
                    com: .failure(.navegadorNaoAbriu)
                )
                return
            }

            // Garantia contra espera eterna: encerra a autorização depois de
            // 5 minutos, não importa o caminho (navegador perdido, aba
            // fechada sem voltar ao app etc.).
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