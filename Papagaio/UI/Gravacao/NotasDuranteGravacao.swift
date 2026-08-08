import PapagaioCore
import AppKit
import SwiftUI

/// Editor de observações da conversa enquanto o áudio ainda está sendo
/// capturado. O estado pertence ao `GravadorViewModel`, não a esta view: assim
/// o rascunho não desaparece se a hierarquia SwiftUI for recomposta.
struct PainelDeNotasDuranteGravacao: View {
    @Bindable var gravador: GravadorViewModel
    @FocusState private var editorEstaFocado: Bool

    private var rascunhoVazio: Bool {
        gravador.rascunhoDaNota.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var quantidadeDeNotas: Int {
        gravador.notasDaGravacao.count + (rascunhoVazio ? 0 : 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.largo) {
            HStack(alignment: .top, spacing: PapagaioTema.Espaco.medio) {
                Image(systemName: "note.text")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(PapagaioTema.destaqueEscuro)
                    .frame(width: 44, height: 44)
                    .background(PapagaioTema.destaqueSuave, in: Circle())

                VStack(alignment: .leading, spacing: PapagaioTema.Espaco.minimo) {
                    Text("Notas da conversa")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(PapagaioTema.texto)

                    Text(
                        "Registre observações em tempo real. Cada nota fica sincronizada com o ponto atual da gravação."
                    )
                    .font(.callout)
                    .foregroundStyle(PapagaioTema.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                SeloDeStatus(
                    texto: "\(quantidadeDeNotas) notas",
                    simbolo: "bookmark",
                    estilo: .neutro
                )
            }

            HStack(spacing: PapagaioTema.Espaco.curto) {
                Button("Inserir marcador", systemImage: "bookmark.badge.plus") {
                    gravador.inserirMarcador()
                }
                .buttonStyle(BotaoDeContornoPapagaio())
                .accessibilityHint("Salva um marcador no tempo atual da gravação.")

                Button {
                    gravador.proximaNotaSeraCritica.toggle()
                } label: {
                    Label(
                        gravador.proximaNotaSeraCritica ? "Próxima nota é crítica" : "Marcar como crítica",
                        systemImage: "exclamationmark.triangle"
                    )
                }
                .buttonStyle(BotaoDeContornoPapagaio())
                .accessibilityValue(
                    gravador.proximaNotaSeraCritica ? "Ativado" : "Desativado"
                )

                Spacer(minLength: 8)

                Text("\(gravador.tempoDeGravacao.comoCronometro)")
                    .font(.system(.callout, design: .monospaced).weight(.semibold))
                    .foregroundStyle(PapagaioTema.textoSecundario)
                    .monospacedDigit()
                    .accessibilityLabel("Tempo atual da gravação")
                    .accessibilityValue(tempoLongo(gravador.tempoDeGravacao))
            }

            ZStack(alignment: .topLeading) {
                EditorDeNotaAlinhado(texto: $gravador.rascunhoDaNota)
                    .focused($editorEstaFocado)
                    .accessibilityLabel("Nova nota da conversa")
                    .accessibilityHint(
                        "O texto será salvo automaticamente quando a gravação finalizar."
                    )

                if rascunhoVazio {
                    Text("Escreva uma observação, sentimento ou ponto importante…")
                        .font(.body)
                        .foregroundStyle(PapagaioTema.textoSecundario.opacity(0.72))
                        .padding(.leading, PapagaioTema.Espaco.largo)
                        .padding(.top, PapagaioTema.Espaco.medio)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: 148, maxHeight: 230)
            .background(
                PapagaioTema.superficie,
                in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
            )
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(PapagaioTema.destaque)
                    .frame(width: 4)
            }
            .clipShape(RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
                    .stroke(PapagaioTema.borda, lineWidth: 1)
            }

            Text("As notas são salvas automaticamente ao finalizar a gravação.")
                .font(.caption)
                .foregroundStyle(PapagaioTema.textoSecundario)

            if !gravador.notasDaGravacao.isEmpty {
                VStack(alignment: .leading, spacing: PapagaioTema.Espaco.curto) {
                    Text("Notas registradas")
                        .font(.headline)
                        .foregroundStyle(PapagaioTema.texto)

                    ForEach(gravador.notasDaGravacao) { nota in
                        LinhaDaNotaEmGravacao(nota: nota)
                    }
                }
                .padding(.top, PapagaioTema.Espaco.minimo)
            }
        }
        .padding(PapagaioTema.Espaco.secao)
        .cartaoPapagaio()
        .accessibilityElement(children: .contain)
    }

    private func tempoLongo(_ segundos: TimeInterval) -> String {
        let total = max(0, Int(segundos))
        let minutos = total / 60
        let resto = total % 60
        return minutos > 0 ? "\(minutos) minutos e \(resto) segundos" : "\(resto) segundos"
    }
}

private struct EditorDeNotaAlinhado: NSViewRepresentable {
    @Binding var texto: String

    func makeCoordinator() -> Coordenador {
        Coordenador(texto: $texto)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder

        let editor = NSTextView()
        editor.delegate = context.coordinator
        editor.drawsBackground = false
        editor.isRichText = false
        editor.allowsUndo = true
        editor.font = .systemFont(ofSize: NSFont.systemFontSize)
        editor.textColor = NSColor(PapagaioTema.texto)
        editor.textContainerInset = NSSize(width: 18, height: 14)
        editor.textContainer?.lineFragmentPadding = 0
        editor.string = texto
        editor.minSize = NSSize(width: 0, height: 0)
        editor.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true

        scroll.documentView = editor
        context.coordinator.editor = editor
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let editor = context.coordinator.editor, editor.string != texto else { return }
        editor.string = texto
    }

    final class Coordenador: NSObject, NSTextViewDelegate {
        @Binding var texto: String
        weak var editor: NSTextView?

        init(texto: Binding<String>) {
            _texto = texto
        }

        func textDidChange(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView else { return }
            texto = editor.string
        }
    }
}

private struct LinhaDaNotaEmGravacao: View {
    let nota: NotaDaConversa

    var body: some View {
        HStack(alignment: .top, spacing: PapagaioTema.Espaco.curto) {
            Image(systemName: nota.tipo == .marcador ? "bookmark.fill" : "text.quote")
                .foregroundStyle(nota.critica ? PapagaioTema.perigo : PapagaioTema.destaqueEscuro)
                .frame(width: 18)

            Text(nota.start.comoCronometro)
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .foregroundStyle(PapagaioTema.textoSecundario)
                .monospacedDigit()

            Text(nota.texto)
                .font(.callout)
                .foregroundStyle(PapagaioTema.texto)
                .lineLimit(2)

            Spacer(minLength: 8)

            if nota.critica {
                SeloDeStatus(texto: "Crítica", simbolo: "exclamationmark.triangle", estilo: .erro)
            }
        }
        .padding(PapagaioTema.Espaco.medio)
        .background(PapagaioTema.superficieSuave.opacity(0.68), in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))
        .accessibilityElement(children: .combine)
    }

}
