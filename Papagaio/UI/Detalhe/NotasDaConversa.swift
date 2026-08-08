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
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.pagina) {
            cabecalho

            HStack(alignment: .center, spacing: PapagaioTema.Espaco.largo) {
                HStack(spacing: PapagaioTema.Espaco.medio) {
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

            VStack(spacing: PapagaioTema.Espaco.largo) {
                editor
                barraDeFormatacao
            }
        }
        .frame(maxWidth: 980, alignment: .leading)
    }

    private var cabecalho: some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.minimo) {
            HStack(alignment: .firstTextBaseline) {
                Text("Notas da Conversa")
                    .font(PapagaioTema.Tipo.tituloDePagina)
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
                .textEditorStyle(.plain)
                .padding(.horizontal, PapagaioTema.Espaco.largo)
                .padding(.vertical, PapagaioTema.Espaco.largo)
                .focused($editorEmFoco)
                .accessibilityLabel("Notas da conversa")

            if texto.isEmpty {
                Text("Escreva suas observações aqui...")
                    .font(.system(size: 17))
                    .foregroundStyle(PapagaioTema.textoSecundario.opacity(0.62))
                    .padding(.horizontal, PapagaioTema.Espaco.largo)
                    .padding(.vertical, PapagaioTema.Espaco.largo)
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
        .clipShape(RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
                .stroke(editorEmFoco ? PapagaioTema.destaque : PapagaioTema.borda, lineWidth: editorEmFoco ? 1.4 : 1)
        }
    }

    private var barraDeFormatacao: some View {
        HStack(spacing: PapagaioTema.Espaco.largo) {
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
                .padding(.horizontal, PapagaioTema.Espaco.minimo)

            BotaoDeFormatoDaNota(rotulo: nil, simbolo: "photo", formato: .imagem, aoAplicar: aoAplicarFormato)
                .help("Imagem")
            BotaoDeFormatoDaNota(rotulo: nil, simbolo: "paperclip", formato: .anexo, aoAplicar: aoAplicarFormato)
                .help("Anexo")
            BotaoDeFormatoDaNota(rotulo: nil, simbolo: "link", formato: .link, aoAplicar: aoAplicarFormato)
                .help("Link")
        }
        .padding(.horizontal, PapagaioTema.Espaco.secao)
        .padding(.vertical, PapagaioTema.Espaco.medio)
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
            .padding(.horizontal, PapagaioTema.Espaco.largo)
            .padding(.vertical, PapagaioTema.Espaco.curto)
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
        LazyVStack(alignment: .leading, spacing: PapagaioTema.Espaco.curto) {
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
        HStack(alignment: .top, spacing: PapagaioTema.Espaco.medio) {
            Text(nota.start.comoRelogio)
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(nota.critica ? PapagaioTema.perigo : PapagaioTema.destaqueEscuro)
                .frame(width: 52, alignment: .trailing)

            Image(systemName: ehMarcador ? "bookmark.fill" : "note.text")
                .font(.callout.weight(.semibold))
                .foregroundStyle(nota.critica ? PapagaioTema.perigo : PapagaioTema.destaqueEscuro)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: PapagaioTema.Espaco.minimo) {
                HStack(spacing: PapagaioTema.Espaco.curto) {
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
        .padding(.vertical, PapagaioTema.Espaco.medio)
        .padding(.horizontal, PapagaioTema.Espaco.largo)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PapagaioTema.superficie, in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))
        .overlay(alignment: .leading) {
            Capsule()
                .fill(nota.critica ? PapagaioTema.perigo : PapagaioTema.destaque)
                .frame(width: 4)
                .padding(.vertical, PapagaioTema.Espaco.medio)
        }
        .overlay {
            RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
                .stroke(PapagaioTema.borda.opacity(0.72), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(tempoLongo(nota.start)). \(ehMarcador ? "Marcador" : "Nota"). \(nota.texto)\(nota.critica ? ". Crítica." : "")")
    }

    private func tempoLongo(_ segundos: TimeInterval) -> String {
        let total = max(0, Int(segundos))
        let minutos = total / 60
        let resto = total % 60
        return minutos > 0 ? "\(minutos) min \(resto) s" : "\(resto) s"
    }
}
