import Foundation

/// Impede que o host dos testes alcance integrações reais durante o lançamento.
///
/// O host dos testes não constrói a cena de produção: nem biblioteca local,
/// migrações, conta, Keychain, navegador, rede ou permissões do sistema.
/// O sinal explícito do scheme deixa a regra reproduzível na CI,
/// enquanto `XCTestConfigurationFilePath` protege execuções iniciadas fora dele.
@MainActor
struct PoliticaDeInicializacaoExterna {
    let permiteServicosExternos: Bool

    init(ambiente: [String: String] = ProcessInfo.processInfo.environment) {
        let execucaoDeTeste = ambiente["PAPAGAIO_TEST_MODE"] == "1"
            || ambiente["XCTestConfigurationFilePath"] != nil
        permiteServicosExternos = !execucaoDeTeste
    }

    func executar(_ operacao: @MainActor () async -> Void) async {
        guard permiteServicosExternos else { return }
        await operacao()
    }
}
