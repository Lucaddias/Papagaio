import PapagaioCore
import SwiftUI


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

    private var tipoDoItem: (titulo: String, simbolo: String) {
        if arquivo.resumo != nil || !arquivo.trechos.isEmpty {
            return ("TRANSCRIÇÃO", "text.bubble")
        }
        if arquivo.duracao > 0 {
            return ("ÁUDIO", "waveform")
        }
        if !arquivo.notas.isEmpty {
            return ("NOTA", "note.text")
        }
        return ("ARQUIVO", "doc")
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
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.largo) {
            HStack(alignment: .top, spacing: PapagaioTema.Espaco.medio) {
                Label(tipoDoItem.titulo, systemImage: tipoDoItem.simbolo)
                    .font(.callout.weight(.bold))
                    .foregroundStyle(PapagaioTema.textoSobrePrimario)
                    .padding(.horizontal, PapagaioTema.Espaco.medio)
                    .frame(height: PapagaioTema.Altura.compacta)
                    .background(PapagaioTema.preenchimentoPrimario, in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))

                Spacer(minLength: 8)

                HStack(spacing: PapagaioTema.Espaco.largo) {
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

            VStack(alignment: .leading, spacing: PapagaioTema.Espaco.medio) {
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

            VStack(alignment: .leading, spacing: PapagaioTema.Espaco.minimo) {
                // Exatamente a mesma data e duração do cartão da biblioteca —
                // `DataDigitada.textoComHora` e `comoDuracaoPorExtenso`, e não
                // um formato próprio da lixeira. A conversa aqui é a mesma
                // que já apareceu lá; mostrar as datas de outro jeito faria
                // parecer um dado diferente, quando é o mesmo dado, só
                // noutro lugar.
                HStack(spacing: PapagaioTema.Espaco.largo) {
                    Label(DataDigitada.textoComHora(de: arquivo.criadoEm), systemImage: "calendar")
                    Label(arquivo.duracao.comoDuracaoPorExtenso, systemImage: "clock")

                    Spacer(minLength: 8)

                    Text(prazoDeExclusao)
                        .font(.callout.weight(.bold))
                        .foregroundStyle(PapagaioTema.perigo)
                }
                .font(.callout.weight(.semibold))
                .foregroundStyle(PapagaioTema.textoSecundario.opacity(0.62))

                // O que aconteceu com o arquivo depois de gravado: se foi
                // importado, quando — e quando foi para a lixeira. As duas
                // são datas reais e independentes uma da outra: importar e
                // apagar não precisam ter acontecido no mesmo dia, alguém
                // pode ter importado um arquivo e só semanas depois decidido
                // apagá-lo. Cada uma mostra a data que de fato lhe pertence,
                // não uma suposição de que elas coincidem.
                if arquivo.importadoEm != nil || arquivo.apagadoEm != nil {
                    HStack(spacing: PapagaioTema.Espaco.medio) {
                        if let importadoEm = arquivo.importadoEm {
                            Text("Importado em \(DataDigitada.texto(de: importadoEm))")
                        }
                        if let apagadoEm = arquivo.apagadoEm {
                            Text("Apagado em \(DataDigitada.texto(de: apagadoEm))")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(PapagaioTema.textoSecundario.opacity(0.55))
                }
            }
        }
        .padding(PapagaioTema.Espaco.secao)
        .frame(maxWidth: .infinity, minHeight: 310, alignment: .topLeading)
        .cartaoPapagaio()
        .opacity(emOperacao ? 0.72 : 1)
        .accessibilityElement(children: .contain)
    }
}
