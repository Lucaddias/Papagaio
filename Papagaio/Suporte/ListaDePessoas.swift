import Foundation

/// Junta em uma linha só os nomes que a pessoa digitou um por linha na ficha
/// da entrevista, descartando as linhas vazias.
///
/// Devolve `""` quando não sobrou nome nenhum — quem chama omite a linha
/// inteira nesse caso, em vez de imprimir "Não informado" como se fosse dado.
/// Os nomes um a um, na ordem em que foram digitados.
///
/// Aceita uma pessoa por linha **e** separadas por vírgula: o formulário usa
/// linhas, mas todo mundo em algum momento digita "Ana, João" numa linha só.
func nomesDePessoas(_ texto: String) -> [String] {
    texto
        .split(whereSeparator: { $0.isNewline || $0 == "," })
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
}

/// As iniciais que vão no círculo: primeira letra do nome e a do sobrenome.
///
/// Só a primeira letra confundiria "Ana Silva" com "André Souza" — que é
/// exatamente o caso de quem tem vários participantes recorrentes.
func iniciaisDe(_ nome: String) -> String {
    let partes = nome.split(separator: " ").filter { !$0.isEmpty }
    guard let primeira = partes.first?.first else { return "?" }
    guard partes.count > 1, let ultima = partes.last?.first else {
        return String(primeira).uppercased()
    }
    return "\(primeira)\(ultima)".uppercased()
}

func listaDePessoas(_ texto: String) -> String {
    texto
        .split(whereSeparator: \.isNewline)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: ", ")
}
