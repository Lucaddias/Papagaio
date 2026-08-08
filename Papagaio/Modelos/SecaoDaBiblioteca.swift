import Foundation
import PapagaioCore


/// As duas coleções reais da biblioteca. A lixeira é aberta pelas
/// Configurações, mas continua uma área separada porque não é exclusão
/// definitiva.
enum SecaoDaBiblioteca: String, Identifiable {
    case todos = "Todos os arquivos"
    case lixeira = "Lixeira"

    var id: Self { self }
}
