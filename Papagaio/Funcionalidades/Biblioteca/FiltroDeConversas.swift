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
    var compacto = false

    var body: some View {
        HStack(spacing: PapagaioTema.Espaco.curto) {
            ForEach(FiltroDaBiblioteca.allCases) { filtro in
                // Sem `Button`, e com `onTapGesture` na pastilha.
                //
                // Um `Button` decide sozinho onde termina o alvo, a partir do
                // que o rótulo desenha — e foi essa decisão implícita que
                // deixou "Todas" respondendo só sobre o texto, porque a
                // pastilha não selecionada não desenha fundo nenhum. O
                // `onTapGesture` não tem essa liberdade: ele vale exatamente na
                // forma declarada logo antes dele, e essa forma é o retângulo
                // inteiro da pastilha.
                PastilhaDeFiltro(
                    filtro: filtro,
                    selecionada: selecionado == filtro,
                    compacto: compacto
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.snappy(duration: 0.18)) {
                        selecionado = filtro
                        pastaSelecionada = nil
                        atalhoSelecionado = nil
                        aoLimparAtalhoVisual()
                    }
                }
                .help(filtro.rawValue)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Mostrar \(filtro.rawValue.localizedLowercase)")
                .accessibilityAddTraits(selecionado == filtro ? [.isSelected] : [])
            }
        }
    }
}

/// O filtro era texto solto: só o glifo e as letras respondiam ao clique, e o
/// espaço entre eles não. Como pastilha, a área clicável é o retângulo inteiro
/// — e o estado selecionado deixa de depender só da cor da fonte, que some em
/// tela clara.
private struct PastilhaDeFiltro: View {
    let filtro: FiltroDaBiblioteca
    let selecionada: Bool
    let compacto: Bool
    @State private var pairando = false

    var body: some View {
        Label(filtro.rawValue, systemImage: filtro.simbolo)
            .font((compacto ? Font.caption : Font.callout).weight(.semibold))
            .foregroundStyle(corDoTexto)
            .padding(.horizontal, compacto ? PapagaioTema.Espaco.curto : PapagaioTema.Espaco.medio)
            .frame(height: compacto ? 36 : PapagaioTema.Altura.compacta)
            .background(fundo, in: Capsule())
            .overlay {
                Capsule().stroke(
                    selecionada
                        ? PapagaioTema.destaque.opacity(0.58)
                        : PapagaioTema.borda.opacity(pairando ? 1 : 0.76),
                    lineWidth: 1
                )
            }
            // A forma de clique é o retângulo inteiro da pastilha.
            //
            // Sem ela, o alvo era só o que está **desenhado** — e a pastilha
            // não selecionada tem fundo `Color.clear`, que o SwiftUI não
            // considera desenhado. Sobravam as letras e o glifo. Como a
            // pastilha selecionada tem fundo com cor, ela funcionava inteira:
            // por isso "Pastas" respondia enquanto se estava em Pastas, e
            // "Todas" só respondia se o clique caísse exatamente sobre o texto.
            // O sintoma trocava de lado junto com a seleção, o que fazia
            // parecer que só um dos dois botões estava quebrado.
            .contentShape(Rectangle())
            .onHover { pairando = $0 }
            .animation(.easeOut(duration: 0.14), value: pairando)
            .animation(.easeOut(duration: 0.14), value: selecionada)
    }

    private var corDoTexto: Color {
        selecionada || pairando ? PapagaioTema.destaqueEscuro : PapagaioTema.textoSecundario
    }

    private var fundo: Color {
        if selecionada { return PapagaioTema.destaque.opacity(0.14) }
        // `superficie` com opacidade quase nula, e não `.clear`: visualmente é
        // a mesma coisa, mas é uma cor desenhada — e cor desenhada recebe
        // clique. Sozinha já resolveria; com o `contentShape` acima, é a
        // segunda trava contra o mesmo problema voltar.
        return pairando ? PapagaioTema.superficie : PapagaioTema.superficie.opacity(0.001)
    }
}
