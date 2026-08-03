import PapagaioCore
import SwiftUI

/// As duas coleções reais da biblioteca. A lixeira é aberta pelas
/// Configurações, mas continua uma área separada porque não é exclusão
/// definitiva.
enum SecaoDaBiblioteca: String, Identifiable {
    case todos = "Todos os arquivos"
    case lixeira = "Lixeira"

    var id: Self { self }
}

/// Um item recuperável. O clique abre as ações de recuperação; a exclusão
/// definitiva fica visível e exige confirmação no container.
struct CartaoDaLixeira: View {
    let arquivo: Arquivo
    let emOperacao: Bool
    let aoSelecionar: () -> Void
    let aoPedirExclusaoDefinitiva: () -> Void

    private var titulo: String { arquivo.resumo?.titulo ?? arquivo.titulo }
    private var descricaoDaData: String {
        guard let apagadoEm = arquivo.apagadoEm else { return "Movido para a lixeira" }
        return "Na lixeira desde \(apagadoEm.formatted(.dateTime.day().month(.abbreviated).year()))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: aoSelecionar) {
                VStack(alignment: .leading, spacing: 0) {
                    ZStack {
                        PapagaioTema.superficieSuave

                        Image(systemName: "trash")
                            .font(.system(size: 40, weight: .light))
                            .foregroundStyle(PapagaioTema.textoSecundario.opacity(0.62))
                    }
                    .frame(height: 116)

                    VStack(alignment: .leading, spacing: 12) {
                        Text(titulo)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(PapagaioTema.texto)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        SeloDeStatus(
                            texto: "Na lixeira",
                            simbolo: "trash",
                            estilo: .neutro
                        )

                        Label(descricaoDaData, systemImage: "calendar")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(PapagaioTema.textoSecundario)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)
            .disabled(emOperacao)
            .accessibilityLabel("\(titulo). Na lixeira. Selecione para recuperar ou apagar definitivamente.")

            SeparadorPapagaio()

            HStack(spacing: 10) {
                if emOperacao {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Atualizando arquivo na lixeira")
                }

                Label(
                    emOperacao ? "Atualizando…" : "Selecione para recuperar",
                    systemImage: emOperacao ? "arrow.triangle.2.circlepath" : "arrow.uturn.backward.circle"
                )
                .font(.caption.weight(.medium))
                .foregroundStyle(PapagaioTema.textoSecundario)

                Spacer(minLength: 8)

                Button("Apagar definitivamente…", systemImage: "trash.slash", role: .destructive) {
                    aoPedirExclusaoDefinitiva()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(PapagaioTema.perigo)
                .padding(.horizontal, 11)
                .frame(minHeight: 36)
                .background(PapagaioTema.perigo.opacity(0.08), in: Capsule())
                .overlay {
                    Capsule().stroke(PapagaioTema.perigo.opacity(0.3), lineWidth: 1)
                }
                .buttonStyle(.plain)
                .disabled(emOperacao)
                .accessibilityHint("Remove permanentemente o áudio, a transcrição e o resumo após confirmação.")
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity, minHeight: 278, alignment: .top)
        .cartaoPapagaio()
        .opacity(emOperacao ? 0.72 : 1)
    }
}
