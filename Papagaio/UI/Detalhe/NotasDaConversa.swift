import PapagaioCore
import SwiftUI

enum FormatoDeNota {
    case negrito
    case italico
    case lista
    case imagem
    case anexo
    case link
}

struct EditorDeNotasDaConversa: View {
    @Binding var texto: String
    @Binding var notaCritica: Bool
    let estadoDeSalvamento: String
    let aoInserirMarcador: () -> Void
    let aoMarcarComoCritico: () -> Void
    let aoAplicarFormato: (FormatoDeNota) -> Void

    @FocusState private var editorEmFoco: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 34) {
            cabecalho

            HStack(alignment: .center, spacing: 16) {
                HStack(spacing: 14) {
                    Button {
                        aoInserirMarcador()
                    } label: {
                        Label("Inserir Marcador", systemImage: "plus.circle")
                    }
                    .keyboardShortcut("k", modifiers: [.command])
                    .help("Inserir marcador")

                    Button {
                        aoMarcarComoCritico()
                    } label: {
                        Label(
                            notaCritica ? "Nota Crítica" : "Marcar como Crítico",
                            systemImage: notaCritica ? "exclamationmark.circle.fill" : "exclamationmark"
                        )
                    }
                    .help("Marcar como crítico")
                }
                .buttonStyle(BotaoDeAcaoDasNotas())

                Spacer(minLength: 12)

                Text("Atalho: ⌘ + K para marcadores")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PapagaioTema.textoSecundario)
            }

            VStack(spacing: 18) {
                editor
                barraDeFormatacao
            }
        }
        .frame(maxWidth: 980, alignment: .leading)
    }

    private var cabecalho: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("Notas da Conversa")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(PapagaioTema.texto)

                Spacer()

                Label(estadoDeSalvamento, systemImage: estadoDeSalvamento == "Salvo" ? "checkmark.circle" : "clock")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PapagaioTema.textoSecundario)
            }

            Text("Registre observações, sentimentos e pontos críticos em tempo real. Suas notas serão sincronizadas com o carimbo de tempo da gravação.")
                .font(.body)
                .foregroundStyle(PapagaioTema.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 720, alignment: .leading)
        }
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $texto)
                .font(.system(size: 17))
                .foregroundStyle(PapagaioTema.texto)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .focused($editorEmFoco)
                .accessibilityLabel("Notas da conversa")

            if texto.isEmpty {
                Text("Escreva suas observações aqui...")
                    .font(.system(size: 17))
                    .foregroundStyle(PapagaioTema.textoSecundario.opacity(0.62))
                    .padding(.horizontal, 26)
                    .padding(.vertical, 26)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 420)
        .background(PapagaioTema.superficie)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(PapagaioTema.destaque)
                .frame(width: 4)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(editorEmFoco ? PapagaioTema.destaque : PapagaioTema.borda, lineWidth: editorEmFoco ? 1.4 : 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var barraDeFormatacao: some View {
        HStack(spacing: 18) {
            BotaoDeFormatoDaNota(rotulo: "B", simbolo: nil, formato: .negrito, aoAplicar: aoAplicarFormato)
                .font(.headline.weight(.bold))
                .help("Negrito")
            BotaoDeFormatoDaNota(rotulo: "I", simbolo: nil, formato: .italico, aoAplicar: aoAplicarFormato)
                .italic()
                .help("Itálico")
            BotaoDeFormatoDaNota(rotulo: nil, simbolo: "list.bullet", formato: .lista, aoAplicar: aoAplicarFormato)
                .help("Lista")

            Rectangle()
                .fill(PapagaioTema.borda)
                .frame(width: 1, height: 26)
                .padding(.horizontal, 4)

            BotaoDeFormatoDaNota(rotulo: nil, simbolo: "photo", formato: .imagem, aoAplicar: aoAplicarFormato)
                .help("Imagem")
            BotaoDeFormatoDaNota(rotulo: nil, simbolo: "paperclip", formato: .anexo, aoAplicar: aoAplicarFormato)
                .help("Anexo")
            BotaoDeFormatoDaNota(rotulo: nil, simbolo: "link", formato: .link, aoAplicar: aoAplicarFormato)
                .help("Link")
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 14)
        .background(PapagaioTema.superficieSuave, in: Capsule())
        .overlay {
            Capsule()
                .stroke(PapagaioTema.borda, lineWidth: 1)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct BotaoDeFormatoDaNota: View {
    let rotulo: String?
    let simbolo: String?
    let formato: FormatoDeNota
    let aoAplicar: (FormatoDeNota) -> Void

    var body: some View {
        Button {
            aoAplicar(formato)
        } label: {
            Group {
                if let simbolo {
                    Image(systemName: simbolo)
                } else {
                    Text(rotulo ?? "")
                }
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(PapagaioTema.textoSecundario)
            .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
    }
}

private struct BotaoDeAcaoDasNotas: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .foregroundStyle(PapagaioTema.textoSecundario)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(PapagaioTema.superficie, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(PapagaioTema.borda, lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.74 : 1)
    }
}

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
