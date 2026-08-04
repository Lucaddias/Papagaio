import SwiftUI

/// Preferências que mudam o gatilho do pipeline local, sem criar um caminho de
/// processamento paralelo. Por enquanto há uma única configuração.
struct ConfiguracoesView: View {
    @Binding var processamentoAutomatico: Bool

    private var processamentoPausado: Binding<Bool> {
        Binding(
            get: { !processamentoAutomatico },
            set: { processamentoAutomatico = !$0 }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            CabecalhoDePagina(
                titulo: "Configurações",
                subtitulo: "Gerencie quando as transcrições e os resumos começam."
            )

            Form {
                Section {
                    Toggle(isOn: processamentoPausado) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Pausar transcrições e resumos automáticos")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(PapagaioTema.texto)

                            Text("Gravações e anexos ficarão prontos para transcrever. Você inicia o processamento pela aba Transcrição.")
                                .font(.callout)
                                .foregroundStyle(PapagaioTema.textoSecundario)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .toggleStyle(.switch)
                    .accessibilityHint(
                        "Quando ativado, novos áudios não entram na fila até você selecionar Transcrever."
                    )
                } header: {
                    Label("Transcrição", systemImage: "text.quote")
                        .font(.headline)
                        .foregroundStyle(PapagaioTema.destaqueEscuro)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(PapagaioTema.superficie, in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeCard, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PapagaioTema.raioDeCard, style: .continuous)
                    .stroke(PapagaioTema.borda, lineWidth: 1)
            }
            .frame(maxWidth: 760, minHeight: 180, alignment: .top)

            Spacer(minLength: 0)
        }
        .larguraDeConteudoPapagaio()
        .padding(.horizontal, PapagaioTema.espacamentoDePagina)
        .padding(.vertical, PapagaioTema.espacamentoDePagina)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(PapagaioTema.fundo)
    }
}
