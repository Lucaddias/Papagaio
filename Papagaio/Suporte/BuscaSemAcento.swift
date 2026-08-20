import Foundation

extension String {
    /// Compara ignorando acento e maiúscula/minúscula.
    ///
    /// `localizedCaseInsensitiveContains` já ignora caixa, mas não acento:
    /// buscar "reuniao" não achava "Reunião", e boa parte de quem digita
    /// rápido no teclado do Mac nem sempre acentua. A busca não pode dar
    /// zero resultado por causa disso.
    func casaComBusca(_ termo: String) -> Bool {
        range(of: termo, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}
