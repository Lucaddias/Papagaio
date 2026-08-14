import SwiftUI

/// Preferências que mudam a aparência do app e o gatilho do pipeline local,
/// sem criar um caminho de processamento paralelo.
struct ConfiguracoesView: View {
    @Binding var processamentoAutomatico: Bool
    @Binding var aparencia: AparenciaDoApp
    /// Mesma chave lida pelo `PapagaioApp`, que é quem abre e fecha o painel.
    @AppStorage("painelFlutuanteDuranteGravacao") private var painelFlutuante = true

    private var processamentoPausado: Binding<Bool> {
        Binding(
            get: { !processamentoAutomatico },
            set: { processamentoAutomatico = !$0 }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PapagaioTema.Espaco.pagina) {
                CabecalhoDePagina(
                    titulo: "Configurações",
                    subtitulo: "Aparência do app e quando as transcrições começam."
                )

                secaoDeAparencia

                secaoDeTranscricao
            }
            .larguraDeConteudoPapagaio()
            .padding(.horizontal, PapagaioTema.espacamentoDePagina)
            .padding(.vertical, PapagaioTema.espacamentoDePagina)
        }
        .background(PapagaioTema.fundo)
    }

    private var secaoDeAparencia: some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.largo) {
            Label("Aparência", systemImage: "paintpalette")
                .font(PapagaioTema.Tipo.tituloDeSecao)
                .foregroundStyle(PapagaioTema.destaqueEscuro)

            SeparadorPapagaio()

            // Amostras em vez de um menu: a escolha é visual, então mostrar as
            // três superfícies lado a lado responde à pergunta sem obrigar a
            // aplicar e desfazer para comparar.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: PapagaioTema.Espaco.medio) {
                    opcoesDeAparencia
                }

                VStack(alignment: .leading, spacing: PapagaioTema.Espaco.medio) {
                    opcoesDeAparencia
                }
            }

            Text(aparencia.descricao)
                .font(PapagaioTema.Tipo.apoio)
                .foregroundStyle(PapagaioTema.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(PapagaioTema.Espaco.secao)
        .frame(maxWidth: 760, alignment: .leading)
        .cartaoPapagaio()
    }

    private var opcoesDeAparencia: some View {
        ForEach(AparenciaDoApp.allCases) { opcao in
            AmostraDeAparencia(
                opcao: opcao,
                selecionada: aparencia == opcao
            ) {
                withAnimation(.snappy(duration: 0.18)) {
                    aparencia = opcao
                }
            }
        }
    }

    private var secaoDeTranscricao: some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.largo) {
            Label("Transcrição", systemImage: "text.quote")
                .font(PapagaioTema.Tipo.tituloDeSecao)
                .foregroundStyle(PapagaioTema.destaqueEscuro)

            SeparadorPapagaio()

            Toggle(isOn: processamentoPausado) {
                VStack(alignment: .leading, spacing: PapagaioTema.Espaco.minimo) {
                    Text("Pausar transcrições e resumos automáticos")
                        .font(PapagaioTema.Tipo.corpo.weight(.semibold))
                        .foregroundStyle(PapagaioTema.texto)

                    Text("Gravações e anexos ficarão prontos para transcrever. Você inicia o processamento pela aba Transcrição.")
                        .font(PapagaioTema.Tipo.apoio)
                        .foregroundStyle(PapagaioTema.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .toggleStyle(.switch)

            Toggle(isOn: $painelFlutuante) {
                VStack(alignment: .leading, spacing: PapagaioTema.Espaco.minimo) {
                    Text("Mostrar painel flutuante durante a gravação")
                        .font(PapagaioTema.Tipo.corpo.weight(.semibold))
                        .foregroundStyle(PapagaioTema.texto)

                    Text("Uma janela pequena, sempre visível por cima dos outros apps, para anotar, pausar e finalizar sem voltar ao Papagaio.")
                        .font(PapagaioTema.Tipo.apoio)
                        .foregroundStyle(PapagaioTema.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .toggleStyle(.switch)
            .tint(PapagaioTema.preenchimentoPrimario)
            .accessibilityHint(
                "Quando ativado, novos áudios não entram na fila até você selecionar Transcrever."
            )
        }
        .padding(PapagaioTema.Espaco.secao)
        .frame(maxWidth: 760, alignment: .leading)
        .cartaoPapagaio()
    }
}

/// Botão de tema com uma miniatura da interface no esquema correspondente.
private struct AmostraDeAparencia: View {
    let opcao: AparenciaDoApp
    let selecionada: Bool
    let acao: () -> Void

    var body: some View {
        Button(action: acao) {
            VStack(spacing: PapagaioTema.Espaco.curto) {
                miniatura

                Label(opcao.titulo, systemImage: opcao.simbolo)
                    .font(PapagaioTema.Tipo.apoio.weight(selecionada ? .semibold : .regular))
                    .foregroundStyle(selecionada ? PapagaioTema.destaqueEscuro : PapagaioTema.textoSecundario)
                    .lineLimit(1)
            }
            .padding(PapagaioTema.Espaco.medio)
            .frame(maxWidth: .infinity)
            .background(
                selecionada ? PapagaioTema.destaqueSuave.opacity(0.55) : Color.clear,
                in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
                    .stroke(
                        selecionada ? PapagaioTema.destaque : PapagaioTema.borda,
                        lineWidth: selecionada ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .help(opcao.descricao)
        .accessibilityLabel("Aparência \(opcao.titulo)")
        .accessibilityHint(opcao.descricao)
        .accessibilityAddTraits(selecionada ? [.isSelected] : [])
    }

    /// Miniatura desenhada com cores fixas — ela precisa mostrar como o tema
    /// **ficaria**, então não pode usar os tokens dinâmicos: eles responderiam à
    /// aparência atual e deixariam as três amostras idênticas.
    private var miniatura: some View {
        let escuro = opcao == .escuro
        let claroFundo = Color(red: 0.980, green: 0.976, blue: 0.969)
        let escuroFundo = Color(red: 0.086, green: 0.080, blue: 0.075)
        let superficie = escuro ? Color(red: 0.137, green: 0.129, blue: 0.122) : .white
        let traco = escuro ? Color(red: 0.286, green: 0.247, blue: 0.227) : Color(red: 0.910, green: 0.796, blue: 0.761)
        let realce = escuro ? Color(red: 1.000, green: 0.576, blue: 0.435) : Color(red: 0.663, green: 0.278, blue: 0.161)

        return ZStack {
            if opcao == .sistema {
                // Metade e metade: comunica "os dois, conforme o Mac".
                HStack(spacing: 0) {
                    claroFundo
                    escuroFundo
                }
            } else {
                escuro ? escuroFundo : claroFundo
            }

            VStack(alignment: .leading, spacing: PapagaioTema.Espaco.minimo) {
                Capsule()
                    .fill(realce)
                    .frame(width: 34, height: 6)

                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(opcao == .sistema ? Color.white.opacity(0.9) : superficie)
                    .frame(height: 22)
                    .overlay {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .stroke(traco, lineWidth: 1)
                    }
            }
            .padding(PapagaioTema.Espaco.curto)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(height: 64)
        .clipShape(RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
                .stroke(PapagaioTema.borda, lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}
