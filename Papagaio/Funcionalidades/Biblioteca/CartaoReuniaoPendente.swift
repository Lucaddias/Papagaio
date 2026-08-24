import AppKit
import PapagaioCore
import SwiftUI

struct CartaoReuniaoPendente: View {
    let arquivo: Arquivo
    let aoGravar: () -> Void
    let aoImportarNotas: () -> Void
    let aoIgnorar: () -> Void

    private var horarioFormatado: String {
        arquivo.criadoEm.formatted(date: .omitted, time: .shortened)
    }

    private var dataFormatada: String {
        let formatador = DateFormatter()
        formatador.locale = Locale(identifier: "pt_BR")
        formatador.dateFormat = "EEEE, d 'de' MMMM"
        return formatador.string(from: arquivo.criadoEm).capitalized
    }

    private var participantesTexto: String {
        // participantes estão no campo notas ou podemos extrair de outro lugar
        // por enquanto mostramos o primeiro trecho se houver, ou o título
        if let primeiroTrecho = arquivo.trechos.first, !primeiroTrecho.texto.isEmpty {
            return primeiroTrecho.texto.prefix(80) + (primeiroTrecho.texto.count > 80 ? "…" : "")
        }
        return ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.medio) {
            HStack(alignment: .top, spacing: PapagaioTema.Espaco.medio) {
                // Ícone do Calendar
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(PapagaioTema.destaque)
                    .frame(width: 36, height: 36)
                    .background(PapagaioTema.destaqueSuave, in: Circle())

                VStack(alignment: .leading, spacing: PapagaioTema.Espaco.minimo) {
                    Text(arquivo.titulo)
                        .font(PapagaioTema.Tipo.corpo.weight(.semibold))
                        .foregroundStyle(PapagaioTema.texto)
                        .lineLimit(2)

                    HStack(spacing: PapagaioTema.Espaco.curto) {
                        Text(dataFormatada)
                        Text("·")
                        Text(horarioFormatado)
                    }
                    .font(PapagaioTema.Tipo.apoio)
                    .foregroundStyle(PapagaioTema.textoSecundario)

                    if !participantesTexto.isEmpty {
                        Text(participantesTexto)
                            .font(PapagaioTema.Tipo.apoio)
                            .foregroundStyle(PapagaioTema.textoSecundario)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }

            // Botões de ação
            HStack(spacing: PapagaioTema.Espaco.medio) {
                Button(action: aoGravar) {
                    Label("Gravar agora", systemImage: "record.circle")
                        .font(PapagaioTema.Tipo.corpo.weight(.medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(PapagaioTema.perigo)
                .help("Inicia uma gravação para esta reunião com título e data pré-preenchidos")

                Button(action: aoImportarNotas) {
                    Label("Importar notas", systemImage: "doc.text")
                        .font(PapagaioTema.Tipo.corpo.weight(.medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .help("Importa apenas as notas e descrição do evento do Calendar")

                Button(action: aoIgnorar) {
                    Label("Ignorar", systemImage: "trash")
                        .font(PapagaioTema.Tipo.corpo.weight(.medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(PapagaioTema.aviso)
                .help("Move esta reunião para a lixeira (pode ser restaurada depois)")
            }
        }
        .padding(PapagaioTema.Espaco.secao)
        .background(
            PapagaioTema.superficie,
            in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeCard, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: PapagaioTema.raioDeCard, style: .continuous)
                .stroke(PapagaioTema.borda, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }
}

#Preview {
    CartaoReuniaoPendente(
        arquivo: Arquivo(
            titulo: "Reunião de planejamento Q4",
            criadoEm: Date().addingTimeInterval(3600),
            duracao: 0,
            pastaRelativa: "",
            espaco: .legado,
            idExterno: "google-calendar-api:abc123"
        ),
        aoGravar: {},
        aoImportarNotas: {},
        aoIgnorar: {}
    )
    .padding()
    .background(PapagaioTema.fundo)
}