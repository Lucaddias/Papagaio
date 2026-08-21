import Foundation

/// Deriva um nome de pasta ou arquivo a partir de um texto livre — como o
/// título de uma conversa — trocando só os caracteres que o Finder não
/// aceita, sem descaracterizar acentos ou espaços.
///
/// Usado para nomear as pastas de mídia de cada conversa: quem chega até lá
/// pelo "Mostrar no Finder" deve ver o nome da conversa, não um UUID.
enum NomeDeArquivoSeguro {
    static func gerar(de texto: String, reserva: String = "Conversa", limite: Int = 80) -> String {
        let ilegal = CharacterSet(charactersIn: "/:\\")
        var nome = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        nome = nome.components(separatedBy: ilegal).joined(separator: "-")
        if nome.count > limite { nome = String(nome.prefix(limite)) }
        return nome.isEmpty ? reserva : nome
    }
}
