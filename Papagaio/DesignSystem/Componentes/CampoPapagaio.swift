import SwiftUI

extension View {
    func campoPapagaio() -> some View {
        self
            .font(.body)
            .padding(.horizontal, PapagaioTema.Espaco.medio)
            .frame(height: PapagaioTema.Altura.padrao)
            .background(PapagaioTema.superficie, in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
                    .stroke(PapagaioTema.borda, lineWidth: 1)
            }
    }
}
