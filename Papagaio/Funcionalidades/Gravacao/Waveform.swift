import SwiftUI


/// Waveform leve: o caminho é o único elemento que recebe atualizações a
/// ~20 Hz durante a captura, evitando efeitos de layout ou animações caras.
struct Waveform: View {
    let amostras: [Float]
    let ativo: Bool

    var body: some View {
        GeometryReader { geometria in
            let largura = geometria.size.width
            let altura = geometria.size.height
            let passo = amostras.isEmpty ? 0 : largura / CGFloat(amostras.count)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
                    .fill(PapagaioTema.superficieSuave)

                Path { caminho in
                    for (indice, amostra) in amostras.enumerated() {
                        let x = CGFloat(indice) * passo
                        let alturaBarra = max(2, CGFloat(amostra) * altura * 0.78)
                        caminho.addRect(
                            CGRect(
                                x: x,
                                y: (altura - alturaBarra) / 2,
                                width: max(1, passo * 0.58),
                                height: alturaBarra
                            )
                        )
                    }
                }
                .fill(ativo ? PapagaioTema.destaque : PapagaioTema.textoSecundario.opacity(0.5))
            }
        }
        .accessibilityHidden(true)
    }
}
