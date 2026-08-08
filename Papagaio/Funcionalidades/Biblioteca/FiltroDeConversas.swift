import SwiftUI

enum FiltroDaBiblioteca: String, CaseIterable, Identifiable {
    case todas = "Todas"
    case pastas = "Pastas"

    var id: Self { self }

    var simbolo: String {
        switch self {
        case .todas: "tray.full"
        case .pastas: "folder"
        }
    }
}

struct FiltroDeConversas: View {
    @Binding var selecionado: FiltroDaBiblioteca
    @Binding var pastaSelecionada: String?
    @Binding var atalhoSelecionado: AtalhoDaBiblioteca?
    let aoLimparAtalhoVisual: () -> Void

    var body: some View {
        HStack(spacing: PapagaioTema.Espaco.largo) {
            ForEach(FiltroDaBiblioteca.allCases) { filtro in
                Button {
                    withAnimation(.snappy(duration: 0.18)) {
                        selecionado = filtro
                        pastaSelecionada = nil
                        atalhoSelecionado = nil
                        aoLimparAtalhoVisual()
                    }
                } label: {
                    Label(filtro.rawValue, systemImage: filtro.simbolo)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(selecionado == filtro ? PapagaioTema.destaqueEscuro : PapagaioTema.textoSecundario)
                }
                .buttonStyle(.plain)
                .help(filtro.rawValue)
                .accessibilityLabel("Mostrar \(filtro.rawValue.localizedLowercase)")
            }
        }
    }
}
