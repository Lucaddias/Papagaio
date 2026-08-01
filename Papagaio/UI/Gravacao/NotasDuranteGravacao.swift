import PapagaioCore
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

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "note.text")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(PapagaioTema.destaqueEscuro)
                    .frame(width: 44, height: 44)
                    .background(PapagaioTema.destaqueSuave, in: Circle())

                VStack(alignment: .leading, spacing: 4) {
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
                    texto: "\(gravador.notasDaGravacao.count) notas",
                    simbolo: "bookmark",
                    estilo: .neutro
                )
            }

            HStack(spacing: 10) {
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

                Text("\(tempoCurto(gravador.tempoDeGravacao))")
                    .font(.system(.callout, design: .monospaced).weight(.semibold))
                    .foregroundStyle(PapagaioTema.textoSecundario)
                    .monospacedDigit()
                    .accessibilityLabel("Tempo atual da gravação")
                    .accessibilityValue(tempoLongo(gravador.tempoDeGravacao))
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $gravador.rascunhoDaNota)
                    .font(.body)
                    .foregroundStyle(PapagaioTema.texto)
                    .scrollContentBackground(.hidden)
                    .focused($editorEstaFocado)
                    .padding(8)
                    .accessibilityLabel("Nova nota da conversa")
                    .accessibilityHint(
                        "Use Salvar nota para registrar o texto no tempo atual. O rascunho também será salvo ao finalizar a gravação."
                    )

                if rascunhoVazio {
                    Text("Escreva uma observação, sentimento ou ponto importante…")
                        .font(.body)
                        .foregroundStyle(PapagaioTema.textoSecundario.opacity(0.72))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 16)
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
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(PapagaioTema.destaque)
                    .frame(width: 4)
                    .padding(.vertical, 1)
            }
            .overlay {
                RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
                    .stroke(PapagaioTema.borda, lineWidth: 1)
            }

            HStack(spacing: 12) {
                Text("⌘↩ para salvar rapidamente")
                    .font(.caption)
                    .foregroundStyle(PapagaioTema.textoSecundario)

                Spacer()

                Button("Salvar nota", systemImage: "plus.circle.fill") {
                    gravador.adicionarNota()
                    editorEstaFocado = true
                }
                .buttonStyle(BotaoPrincipalPapagaio())
                .disabled(rascunhoVazio)
                .keyboardShortcut(.return, modifiers: [.command])
                .accessibilityHint("Adiciona a nota ao tempo atual da gravação.")
            }

            if !gravador.notasDaGravacao.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Notas registradas")
                        .font(.headline)
                        .foregroundStyle(PapagaioTema.texto)

                    ForEach(gravador.notasDaGravacao) { nota in
                        LinhaDaNotaEmGravacao(nota: nota)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(22)
        .cartaoPapagaio()
        .accessibilityElement(children: .contain)
    }

    private func tempoCurto(_ segundos: TimeInterval) -> String {
        let total = max(0, Int(segundos))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    private func tempoLongo(_ segundos: TimeInterval) -> String {
        let total = max(0, Int(segundos))
        let minutos = total / 60
        let resto = total % 60
        return minutos > 0 ? "\(minutos) minutos e \(resto) segundos" : "\(resto) segundos"
    }
}

private struct LinhaDaNotaEmGravacao: View {
    let nota: NotaDaConversa

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: nota.tipo == .marcador ? "bookmark.fill" : "text.quote")
                .foregroundStyle(nota.critica ? PapagaioTema.perigo : PapagaioTema.destaqueEscuro)
                .frame(width: 18)

            Text(tempoCurto(nota.start))
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
        .padding(12)
        .background(PapagaioTema.superficieSuave.opacity(0.68), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func tempoCurto(_ segundos: TimeInterval) -> String {
        let total = max(0, Int(segundos))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
