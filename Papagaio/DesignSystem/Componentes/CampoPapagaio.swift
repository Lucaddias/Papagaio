import SwiftUI

extension View {
    /// `altura: nil` para campos que crescem com o texto — a moldura acompanha
    /// em vez de cortar as linhas na altura fixa.
    func campoPapagaio(altura: CGFloat? = PapagaioTema.Altura.padrao) -> some View {
        self
            .font(.body)
            .padding(.horizontal, PapagaioTema.Espaco.medio)
            .padding(.vertical, altura == nil ? PapagaioTema.Espaco.curto : 0)
            .frame(height: altura)
            .background(PapagaioTema.superficie, in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
                    .stroke(PapagaioTema.borda, lineWidth: 1)
            }
    }
}
