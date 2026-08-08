import Foundation

struct MetadadosVisuaisDoArquivo: Codable, Equatable {
    var entrevistado: String = ""
    var emailDoEntrevistado: String = ""
    var entrevistadores: String = ""
    var emailDosEntrevistadores: String = ""
    var descricao: String = ""
    var formato: String = ""
    var participantes: Int?
}
