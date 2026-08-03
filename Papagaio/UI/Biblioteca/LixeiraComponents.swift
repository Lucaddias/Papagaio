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

/// Um item recuperável. As ações ficam visíveis no card para seguir o fluxo da
/// referência: restaurar ou apagar definitivamente sem abrir um menu extra.
struct CartaoDaLixeira: View {
    let arquivo: Arquivo
    let emOperacao: Bool
    let aoRestaurar: () -> Void
    let aoPedirExclusaoDefinitiva: () -> Void

    private var titulo: String { arquivo.resumo?.titulo ?? arquivo.titulo }
    private var descricao: String {
        let texto = arquivo.resumo?.visaoGeral
            ?? arquivo.trechos.map(\.texto).joined(separator: " ")
        let limpo = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        return limpo.isEmpty
            ? "Conversa movida para a lixeira. Restaure para acessar transcrição, notas e mídia."
            : limpo
    }

    private var dataCurta: String {
        arquivo.criadoEm.formatted(.dateTime.day().month(.abbreviated))
            .uppercased()
            .replacingOccurrences(of: ".", with: "")
    }

    private var duracaoCurta: String {
        let total = Int(max(0, arquivo.duracao.rounded()))
        if total < 60 { return "\(max(1, total)) SEG" }
        let minutos = total / 60
        if minutos < 60 { return "\(minutos) MIN" }
        let horas = minutos / 60
        let resto = minutos % 60
        return resto == 0 ? "\(horas) H" : "\(horas) H \(resto) MIN"
    }

    private var prazoDeExclusao: String {
        guard let apagadoEm = arquivo.apagadoEm,
              let limite = Calendar.current.date(byAdding: .day, value: 30, to: apagadoEm)
        else { return "Exclui em 30 dias" }

        let dias = Calendar.current.dateComponents([.day], from: Date(), to: limite).day ?? 0
        if dias <= 0 { return "Exclui hoje" }
        if dias == 1 { return "Exclui em 1 dia" }
        return "Exclui em \(dias) dias"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                HStack(spacing: 10) {
                    Text("ENTREVISTA")
                        .font(.callout.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .frame(height: 30)
                        .background(PapagaioTema.destaque, in: RoundedRectangle(cornerRadius: 5, style: .continuous))

                    Text("ÁUDIOS")
                        .font(.callout.weight(.bold))
                        .foregroundStyle(PapagaioTema.textoSecundario.opacity(0.72))
                        .padding(.horizontal, 12)
                        .frame(height: 30)
                        .background(PapagaioTema.superficie, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .stroke(PapagaioTema.borda, lineWidth: 1)
                        }
                }

                Spacer(minLength: 8)

                HStack(spacing: 16) {
                    if emOperacao {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityLabel("Atualizando arquivo na lixeira")
                    } else {
                        Button(action: aoRestaurar) {
                            Image(systemName: "arrow.uturn.backward.circle")
                                .font(.system(size: 18, weight: .bold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(PapagaioTema.destaqueEscuro)
                        .help("Restaurar")
                        .accessibilityLabel("Restaurar \(titulo)")

                        Button(role: .destructive, action: aoPedirExclusaoDefinitiva) {
                            Image(systemName: "trash")
                                .font(.system(size: 18, weight: .bold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(PapagaioTema.perigo)
                        .help("Apagar definitivamente")
                        .accessibilityLabel("Apagar definitivamente \(titulo)")
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(titulo)
                    .font(.title.weight(.semibold))
                    .foregroundStyle(PapagaioTema.textoSecundario.opacity(0.68))
                    .strikethrough(true, color: PapagaioTema.textoSecundario.opacity(0.68))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(descricao)
                    .font(.body)
                    .foregroundStyle(PapagaioTema.textoSecundario)
                    .lineSpacing(3)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            SeparadorPapagaio()

            HStack(spacing: 18) {
                Label(dataCurta, systemImage: "calendar")
                Label(duracaoCurta, systemImage: "clock")

                Spacer(minLength: 8)

                Text(prazoDeExclusao)
                    .font(.callout.weight(.bold))
                    .foregroundStyle(PapagaioTema.perigo)
            }
            .font(.callout.weight(.semibold))
            .foregroundStyle(PapagaioTema.textoSecundario.opacity(0.62))
        }
        .padding(28)
        .frame(maxWidth: .infinity, minHeight: 310, alignment: .topLeading)
        .cartaoPapagaio()
        .opacity(emOperacao ? 0.72 : 1)
        .accessibilityElement(children: .contain)
    }
}

struct AcoesDaLixeira: View {
    let temArquivos: Bool
    let aoRestaurarTudo: () -> Void
    let aoEsvaziar: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button("Restaurar Tudo", systemImage: "arrow.counterclockwise", action: aoRestaurarTudo)
                .buttonStyle(BotaoDeContornoPapagaio())
                .disabled(!temArquivos)
                .help("Restaurar todos os arquivos da lixeira")

            Button("Esvaziar Lixeira", systemImage: "trash.square", role: .destructive, action: aoEsvaziar)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .frame(minHeight: 44)
                .background(PapagaioTema.destaque, in: Capsule())
                .buttonStyle(.plain)
                .disabled(!temArquivos)
                .opacity(temArquivos ? 1 : 0.45)
                .help("Apagar definitivamente todos os arquivos da lixeira")
        }
    }
}
