import SwiftUI

struct LegendaGlobalDaBarra: View {
    let texto: LegendaDaBarra?

    var body: some View {
        GeometryReader { geometria in
            Group {
                if let texto {
                    Text(texto.texto)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(PapagaioTema.texto)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: true)
                        .padding(.horizontal, PapagaioTema.Espaco.curto)
                        .padding(.vertical, PapagaioTema.Espaco.minimo)
                        .background(PapagaioTema.superficie, in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(PapagaioTema.borda.opacity(0.92), lineWidth: 1)
                        }
                        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
                        .position(x: posicaoLimitada(texto.x, largura: geometria.size.width), y: 14)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .animation(.easeOut(duration: 0.12), value: texto)
        .allowsHitTesting(false)
        .zIndex(100)
    }

    private func posicaoLimitada(_ x: CGFloat, largura: CGFloat) -> CGFloat {
        min(max(x, 80), max(80, largura - 80))
    }
}

struct LegendaDaBarra: Equatable {
    let texto: String
    let x: CGFloat
}
