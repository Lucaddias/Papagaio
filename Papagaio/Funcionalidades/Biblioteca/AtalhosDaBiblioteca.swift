import SwiftUI

enum AtalhoDaBiblioteca: String, Identifiable {
    case recentes = "Recentes"
    case favoritos = "Favoritos"

    var id: Self { self }
}

struct AtalhosDaBiblioteca: View {
    @Binding var selecionado: AtalhoDaBiblioteca?
    let aoSelecionarRecentes: () -> Void
    let aoSelecionarFavoritos: () -> Void
    var compacto = false

    var body: some View {
        HStack(spacing: compacto ? PapagaioTema.Espaco.curto : PapagaioTema.Espaco.largo) {
            Button(action: aoSelecionarRecentes) {
                BotaoTextualDeAtalhoDaBiblioteca(
                    titulo: "Recentes",
                    simbolo: "clock.arrow.circlepath",
                    selecionado: selecionado == .recentes,
                    compacto: compacto
                )
            }
            .buttonStyle(.plain)
            .help("Recentes")

            Button(action: aoSelecionarFavoritos) {
                BotaoTextualDeAtalhoDaBiblioteca(
                    titulo: "Favoritos",
                    simbolo: selecionado == .favoritos ? "star.fill" : "star",
                    selecionado: selecionado == .favoritos,
                    compacto: compacto
                )
            }
            .buttonStyle(.plain)
            .help("Favoritos")
        }
        .accessibilityLabel("Atalhos da biblioteca")
    }
}

struct BotaoTextualDeAtalhoDaBiblioteca: View {
    let titulo: String
    let simbolo: String
    let selecionado: Bool
    var compacto = false
    @State private var pairando = false

    var body: some View {
        Label(titulo, systemImage: simbolo)
            .font((compacto ? Font.caption : Font.callout).weight(.semibold))
            .foregroundStyle(selecionado || pairando ? PapagaioTema.destaqueEscuro : PapagaioTema.textoSecundario)
            .padding(.horizontal, compacto ? PapagaioTema.Espaco.curto : PapagaioTema.Espaco.largo)
            .frame(height: compacto ? 36 : PapagaioTema.Altura.padrao)
            .background(fundo, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(selecionado ? PapagaioTema.destaque.opacity(0.54) : PapagaioTema.borda.opacity(pairando ? 1 : 0.86), lineWidth: 1)
            }
            .contentShape(Capsule())
            .onHover { pairando = $0 }
            .animation(.easeOut(duration: 0.14), value: pairando)
            .animation(.easeOut(duration: 0.14), value: selecionado)
    }

    private var fundo: Color {
        if selecionado { return PapagaioTema.destaqueSuave.opacity(0.76) }
        if pairando { return PapagaioTema.destaqueSuave.opacity(0.42) }
        return PapagaioTema.superficie
    }
}
