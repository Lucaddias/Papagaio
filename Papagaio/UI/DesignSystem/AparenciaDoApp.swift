import SwiftUI

/// Tema escolhido pelo usuário em Configurações.
///
/// As cores do `PapagaioTema` já sabem se desenhar clara ou escura; o que faltava
/// era decidir **qual** aparência vale. `sistema` deixa o Mac mandar, mas quem
/// prefere um tema fixo não deveria ter de trocar o ajuste do sistema inteiro só
/// por causa deste app.
enum AparenciaDoApp: String, CaseIterable, Identifiable {
    case sistema
    case claro
    case escuro

    var id: Self { self }

    var titulo: String {
        switch self {
        case .sistema: "Sistema"
        case .claro: "Claro"
        case .escuro: "Escuro"
        }
    }

    var simbolo: String {
        switch self {
        case .sistema: "circle.lefthalf.filled"
        case .claro: "sun.max"
        case .escuro: "moon"
        }
    }

    var descricao: String {
        switch self {
        case .sistema: "Acompanha o ajuste de aparência do seu Mac."
        case .claro: "Mantém o app claro, mesmo com o Mac no escuro."
        case .escuro: "Mantém o app escuro, mesmo com o Mac no claro."
        }
    }

    /// `nil` em `sistema`: sem esquema preferido, o SwiftUI herda a aparência da
    /// janela — que é justamente o comportamento de acompanhar o sistema.
    var esquemaPreferido: ColorScheme? {
        switch self {
        case .sistema: nil
        case .claro: .light
        case .escuro: .dark
        }
    }
}
