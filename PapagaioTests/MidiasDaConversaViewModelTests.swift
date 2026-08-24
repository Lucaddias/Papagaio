import Foundation
import Testing
@testable import Papagaio

// A tradução de erro do Cocoa vivia enterrada na `ArquivoDetalheView`.
// No `MidiasDaConversaViewModel` ela vira função pura — e ganha teste.

@MainActor
@Test("iPhone bloqueado ganha mensagem acionável, não código genérico")
func mensagemParaIPhoneBloqueado() {
    let erro = NSError(
        domain: NSCocoaErrorDomain,
        code: 257,
        userInfo: [NSLocalizedDescriptionKey: "O arquivo não pôde ser aberto porque o iPhone está bloqueado."]
    )

    let mensagem = MidiasDaConversaViewModel.mensagemAmigavel(erro)

    #expect(mensagem.contains("desbloquear"))
}

@MainActor
@Test("Códigos de acesso do Cocoa viram orientação, não jargão")
func mensagemParaCodigosDeAcesso() {
    for codigo in [257, 260, 513] {
        let erro = NSError(
            domain: NSCocoaErrorDomain,
            code: codigo,
            userInfo: [NSLocalizedDescriptionKey: "sem permissão"]
        )
        #expect(MidiasDaConversaViewModel.mensagemAmigavel(erro).contains("acessar"))
    }
}

@MainActor
@Test("Erro desconhecido mantém a descrição original, sem inventar")
func mensagemGenericaPreservaDescricao() {
    let erro = NSError(
        domain: NSCocoaErrorDomain,
        code: 4,
        userInfo: [NSLocalizedDescriptionKey: "O disco está cheio."]
    )

    let mensagem = MidiasDaConversaViewModel.mensagemAmigavel(erro)

    #expect(mensagem.contains("O disco está cheio."))
}
