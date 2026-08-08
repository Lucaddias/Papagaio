import SwiftUI

struct SeloDePrioridade: View {
    let prioridade: PrioridadeDaTarefa

    var body: some View {
        Text(texto)
            .font(.caption.weight(.bold))
            .foregroundStyle(cor)
            .padding(.horizontal, PapagaioTema.Espaco.curto)
            .frame(height: PapagaioTema.Altura.compacta)
            .background(cor.opacity(0.12), in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))
    }

    private var texto: String {
        "\(prioridade.simbolo) \(prioridade.rawValue)"
    }

    private var cor: Color {
        prioridade.cor
    }
}

struct SeloDeStatusDaTarefa: View {
    let status: StatusDaTarefa

    var body: some View {
        Text(status.titulo)
            .font(.caption.weight(.bold))
            .foregroundStyle(cor)
            .padding(.horizontal, PapagaioTema.Espaco.curto)
            .frame(height: PapagaioTema.Altura.compacta)
            .background(cor.opacity(0.12), in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))
    }

    private var cor: Color {
        switch status {
        case .emAndamento: PapagaioTema.destaque
        case .concluida: PapagaioTema.sucesso
        }
    }
}
