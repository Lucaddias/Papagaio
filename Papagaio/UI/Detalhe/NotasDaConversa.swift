import PapagaioCore
import SwiftUI

/// Lista apenas visual de anotações que já pertencem ao arquivo. A ação de
/// tocar fica no detalhe, onde existe o `ReprodutorDeArquivo`.
struct ListaDeNotasDaConversa: View {
    let notas: [NotaDaConversa]
    let aoSelecionar: (NotaDaConversa) -> Void

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 10) {
            ForEach(notas) { nota in
                Button {
                    aoSelecionar(nota)
                } label: {
                    LinhaDaNotaDaConversa(nota: nota)
                }
                .buttonStyle(.plain)
                .accessibilityHint(
                    "Inicia a reprodução a partir de \(tempoLongo(nota.start))."
                )
            }
        }
    }

    private func tempoLongo(_ segundos: TimeInterval) -> String {
        let total = max(0, Int(segundos))
        let minutos = total / 60
        let resto = total % 60
        return minutos > 0 ? "\(minutos) min \(resto) s" : "\(resto) s"
    }
}

private struct LinhaDaNotaDaConversa: View {
    let nota: NotaDaConversa

    private var ehMarcador: Bool { nota.tipo == .marcador }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(tempoCurto(nota.start))
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(nota.critica ? PapagaioTema.perigo : PapagaioTema.destaqueEscuro)
                .frame(width: 52, alignment: .trailing)

            Image(systemName: ehMarcador ? "bookmark.fill" : "note.text")
                .font(.callout.weight(.semibold))
                .foregroundStyle(nota.critica ? PapagaioTema.perigo : PapagaioTema.destaqueEscuro)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(ehMarcador ? "Marcador" : "Nota")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PapagaioTema.textoSecundario)

                    if nota.critica {
                        SeloDeStatus(
                            texto: "Crítica",
                            simbolo: "exclamationmark.triangle",
                            estilo: .erro
                        )
                    }
                }

                Text(nota.texto)
                    .font(.body)
                    .foregroundStyle(PapagaioTema.texto)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "play.circle")
                .foregroundStyle(PapagaioTema.textoSecundario)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PapagaioTema.superficie, in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))
        .overlay(alignment: .leading) {
            Capsule()
                .fill(nota.critica ? PapagaioTema.perigo : PapagaioTema.destaque)
                .frame(width: 4)
                .padding(.vertical, 11)
        }
        .overlay {
            RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
                .stroke(PapagaioTema.borda.opacity(0.72), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(tempoLongo(nota.start)). \(ehMarcador ? "Marcador" : "Nota"). \(nota.texto)\(nota.critica ? ". Crítica." : "")")
    }

    private func tempoCurto(_ segundos: TimeInterval) -> String {
        let total = max(0, Int(segundos))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private func tempoLongo(_ segundos: TimeInterval) -> String {
        let total = max(0, Int(segundos))
        let minutos = total / 60
        let resto = total % 60
        return minutos > 0 ? "\(minutos) min \(resto) s" : "\(resto) s"
    }
}
