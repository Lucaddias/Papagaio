import Foundation

/// Junta em uma linha só os nomes que a pessoa digitou um por linha na ficha
/// da entrevista, descartando as linhas vazias.
///
/// Devolve `""` quando não sobrou nome nenhum — quem chama omite a linha
/// inteira nesse caso, em vez de imprimir "Não informado" como se fosse dado.
func listaDePessoas(_ texto: String) -> String {
    texto
        .split(whereSeparator: \.isNewline)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: ", ")
}
