/// Executa cleanup assíncrono de forma estruturada. Diferente de um
/// `defer { Task { ... } }`, só devolve o controle depois que a liberação
/// terminou, inclusive quando a operação lança erro ou `CancellationError`.
enum OperacaoComLimpeza {
    static func executar<Resultado>(
        _ operacao: () async throws -> Resultado,
        limpar: () async -> Void,
        isolation: isolated (any Actor)? = #isolation
    ) async rethrows -> Resultado {
        do {
            let resultado = try await operacao()
            await limpar()
            return resultado
        } catch {
            await limpar()
            throw error
        }
    }
}
