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
            cabecalho

            acoes

            ZStack(alignment: .topLeading) {
                EditorDeNotaAlinhado(texto: $gravador.rascunhoDaNota)
                    .focused($editorEstaFocado)
                    // Enter numa linha de tópico já abre o próximo item, como
                    // em qualquer editor. Enter num tópico vazio sai da lista.
                    .onChange(of: gravador.rascunhoDaNota) { anterior, novo in
                        let ajustado = Self.continuandoTopico(de: anterior, para: novo)
                        if ajustado != novo { gravador.rascunhoDaNota = ajustado }
                    }
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

            Text("⌘↩ salva a nota no instante atual. O que sobrar escrito é salvo ao finalizar a gravação.")
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

    /// Os controles não podem impor a largura mínima da janela. A sequência
    /// preserva a linha única em telas largas e passa para duas linhas, depois
    /// para uma coluna, conforme o espaço realmente disponível.
    private var cabecalho: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: PapagaioTema.Espaco.medio) {
                iconeDoCabecalho
                descricaoDoCabecalho
                Spacer(minLength: 12)
                contadorDeNotas
            }

            VStack(alignment: .leading, spacing: PapagaioTema.Espaco.medio) {
                HStack(alignment: .top, spacing: PapagaioTema.Espaco.medio) {
                    iconeDoCabecalho
                    descricaoDoCabecalho
                }
                contadorDeNotas
            }
        }
    }

    private var iconeDoCabecalho: some View {
        Image(systemName: "note.text")
            .font(.title3.weight(.semibold))
            .foregroundStyle(PapagaioTema.destaqueEscuro)
            .frame(width: 44, height: 44)
            .background(PapagaioTema.destaqueSuave, in: Circle())
    }

    private var descricaoDoCabecalho: some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.minimo) {
            Text("Notas da conversa")
                .font(.title3.weight(.semibold))
                .foregroundStyle(PapagaioTema.texto)

            Text("Registre observações em tempo real. Cada nota fica sincronizada com o ponto atual da gravação.")
                .font(.callout)
                .foregroundStyle(PapagaioTema.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var contadorDeNotas: some View {
        SeloDeStatus(
            texto: "\(quantidadeDeNotas) notas",
            simbolo: "bookmark",
            estilo: .neutro
        )
    }

    private var acoes: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: PapagaioTema.Espaco.curto) {
                botoesDeNota
                Spacer(minLength: 8)
                cronometro
            }

            VStack(alignment: .leading, spacing: PapagaioTema.Espaco.curto) {
                HStack(spacing: PapagaioTema.Espaco.curto) {
                    botaoInserirMarcador
                    botaoMarcarCritica
                }
                HStack(spacing: PapagaioTema.Espaco.curto) {
                    botaoSalvarNota
                    Spacer(minLength: 8)
                    cronometro
                }
            }

            VStack(alignment: .leading, spacing: PapagaioTema.Espaco.curto) {
                botaoInserirMarcador.frame(maxWidth: .infinity)
                botaoMarcarCritica.frame(maxWidth: .infinity)
                HStack {
                    botaoSalvarNota
                    Spacer(minLength: 8)
                    cronometro
                }
            }
        }
    }

    @ViewBuilder
    private var botoesDeNota: some View {
        botaoInserirMarcador
        botaoMarcarCritica
        botaoSalvarNota
    }

    private var botaoInserirMarcador: some View {
        Button("Inserir marcador", systemImage: "bookmark.badge.plus") {
            gravador.inserirMarcador()
        }
        .buttonStyle(BotaoDeContornoPapagaio())
        .accessibilityHint("Salva um marcador no tempo atual da gravação.")
    }

    private var botaoMarcarCritica: some View {
        Button {
            gravador.proximaNotaSeraCritica.toggle()
        } label: {
            Label(
                gravador.proximaNotaSeraCritica ? "Próxima nota é crítica" : "Marcar como crítica",
                systemImage: "exclamationmark.triangle"
            )
        }
        .buttonStyle(BotaoDeContornoPapagaio())
        .accessibilityValue(gravador.proximaNotaSeraCritica ? "Ativado" : "Desativado")
    }

    private var botaoSalvarNota: some View {
        Button("Salvar nota", systemImage: "return") {
            gravador.adicionarNota()
        }
        .buttonStyle(BotaoDeContornoPapagaio())
        .keyboardShortcut(.return, modifiers: [.command])
        .disabled(rascunhoVazio)
        .help("Salva a nota no instante atual (⌘↩)")
    }

    private var cronometro: some View {
        Text("\(gravador.tempoDeGravacao.comoCronometro)")
            .font(.system(.callout, design: .monospaced).weight(.semibold))
            .foregroundStyle(PapagaioTema.textoSecundario)
            .monospacedDigit()
            .accessibilityLabel("Tempo atual da gravação")
            .accessibilityValue(gravador.tempoDeGravacao.faladoPorExtenso)
    }

    /// Continua a lista de tópicos ao apertar Enter; tópico vazio encerra.
    static func continuandoTopico(de anterior: String, para novo: String) -> String {
        guard novo.count == anterior.count + 1, novo.hasSuffix("\n") else { return novo }

        let linhas = novo.components(separatedBy: "\n")
        guard linhas.count >= 2 else { return novo }
        let ultima = linhas[linhas.count - 2]

        guard let marca = ["- ", "* "].first(where: { ultima.hasPrefix($0) }) else { return novo }

        if ultima.trimmingCharacters(in: .whitespaces) == marca.trimmingCharacters(in: .whitespaces) {
            var semUltima = linhas
            semUltima[semUltima.count - 2] = ""
            return semUltima.joined(separator: "\n")
        }

        return novo + marca
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
