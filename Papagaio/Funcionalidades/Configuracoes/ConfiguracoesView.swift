import SwiftUI

/// Preferências que mudam a aparência do app e o gatilho do pipeline local,
/// sem criar um caminho de processamento paralelo.
struct ConfiguracoesView: View {
    @Binding var processamentoAutomatico: Bool
    @Binding var aparencia: AparenciaDoApp
    /// O que a pessoa digitou na busca da barra superior — aqui ela não
    /// filtra uma lista, filtra quais seções da tela ficam visíveis.
    let consulta: String
    /// Mesma chave lida pelo `PapagaioApp`, que é quem abre e fecha o painel.
    @AppStorage("painelFlutuanteDuranteGravacao") private var painelFlutuante = true

    private var processamentoPausado: Binding<Bool> {
        Binding(
            get: { !processamentoAutomatico },
            set: { processamentoAutomatico = !$0 }
        )
    }

    private var termo: String { consulta.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Cada seção declara as próprias palavras-chave (título, o que ela
    /// controla, sinônimos comuns) — sem termo digitado, todas passam.
    private func casaComATela(_ palavrasChave: String...) -> Bool {
        guard !termo.isEmpty else { return true }
        return palavrasChave.contains { $0.casaComBusca(termo) }
    }

    private var mostrarAparencia: Bool {
        casaComATela("Aparência", "Tema", "Claro", "Escuro", "Sistema", "cor")
    }
    private var mostrarCartoes: Bool {
        casaComATela("Cartões da biblioteca", "Modelo do cartão", "Campos do cartão", "grade")
    }
    private var mostrarTranscricao: Bool {
        casaComATela(
            "Transcrição", "Pausar transcrições e resumos automáticos", "processamento automático",
            "Painel flutuante durante a gravação", "PiP", "gravação"
        )
    }
    private var mostrarAtalhos: Bool {
        casaComATela("Atalhos de teclado", "Atalhos", "Teclado", "Gravar", "Voltar")
    }

    private var nadaEncontrado: Bool {
        !termo.isEmpty && !mostrarAparencia && !mostrarCartoes && !mostrarTranscricao && !mostrarAtalhos
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PapagaioTema.Espaco.pagina) {
                cabecalhoDeConfiguracoes

                if nadaEncontrado {
                    CartaoDeEstadoVazio(
                        simbolo: "magnifyingglass",
                        titulo: "Nada encontrado",
                        mensagem: "Nenhuma configuração bate com \"\(termo)\"."
                    )
                    .frame(minHeight: 240)
                    .cartaoPapagaio()
                } else {
                    if mostrarAparencia {
                        secaoDeAparencia
                    }

                    if mostrarCartoes {
                        SecaoDePersonalizacaoDosCartoes()
                    }

                    if mostrarTranscricao {
                        secaoDeTranscricao
                    }

                    if mostrarAtalhos {
                        secaoDeAtalhos
                    }
                }
            }
            .larguraDeConteudoPapagaio()
            .padding(.horizontal, PapagaioTema.espacamentoDePagina)
            .padding(.vertical, PapagaioTema.espacamentoDePagina)
        }
        .background(PapagaioTema.fundo)
    }

    /// O cabeçalho da tela, no mesmo molde do cartão de "Biblioteca de
    /// Conversas" e do de "Lixeira": título e um botão "i" com a explicação
    /// — em vez do subtítulo fixo, texto que se lê uma vez e depois só
    /// ocupa espaço — dentro de um cartão com borda e sombra.
    private var cabecalhoDeConfiguracoes: some View {
        HStack(alignment: .firstTextBaseline, spacing: PapagaioTema.Espaco.medio) {
            Text("Configurações")
                .font(.title2.weight(.semibold))
                .foregroundStyle(PapagaioTema.texto)

            BotaoDeAjudaPapagaio(
                texto: "Aparência do app, os cartões da biblioteca e quando as transcrições começam.",
                ajuda: "Sobre Configurações",
                largura: 300
            )

            Spacer(minLength: 0)
        }
        .padding(PapagaioTema.Espaco.secao)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            PapagaioTema.superficie,
            in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeCard, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: PapagaioTema.raioDeCard, style: .continuous)
                .stroke(PapagaioTema.borda, lineWidth: 1.5)
        }
        .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
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
        // Largura cheia: os 760pt fixos deixavam metade da janela vazia à
        // direita e faziam cada seção terminar num ponto diferente do painel
        // de baixo. O limite de leitura já vem do `larguraDeConteudoPapagaio`
        // da página.
        .frame(maxWidth: .infinity, alignment: .leading)
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
        // Largura cheia: os 760pt fixos deixavam metade da janela vazia à
        // direita e faziam cada seção terminar num ponto diferente do painel
        // de baixo. O limite de leitura já vem do `larguraDeConteudoPapagaio`
        // da página.
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoPapagaio()
    }

    /// Atalhos globais do app — os mesmos botões invisíveis de sempre em
    /// `ContentView` (⌘R e ⌘[), só que agora com um lugar visível e buscável
    /// para alguém descobrir que existem.
    private var secaoDeAtalhos: some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.largo) {
            Label("Atalhos de teclado", systemImage: "keyboard")
                .font(PapagaioTema.Tipo.tituloDeSecao)
                .foregroundStyle(PapagaioTema.destaqueEscuro)

            SeparadorPapagaio()

            VStack(alignment: .leading, spacing: PapagaioTema.Espaco.medio) {
                linhaDeAtalho(tecla: "⌘R", descricao: "Iniciar ou finalizar a gravação")
                linhaDeAtalho(tecla: "⌘[", descricao: "Voltar para a tela anterior")
            }
        }
        .padding(PapagaioTema.Espaco.secao)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoPapagaio()
    }

    private func linhaDeAtalho(tecla: String, descricao: String) -> some View {
        HStack(spacing: PapagaioTema.Espaco.medio) {
            Text(tecla)
                .font(.system(.callout, design: .monospaced).weight(.semibold))
                .foregroundStyle(PapagaioTema.texto)
                .padding(.horizontal, PapagaioTema.Espaco.medio)
                .frame(minWidth: 56)
                .frame(height: PapagaioTema.Altura.compacta)
                .background(PapagaioTema.superficieSuave, in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
                        .stroke(PapagaioTema.borda, lineWidth: 1)
                }

            Text(descricao)
                .font(PapagaioTema.Tipo.corpo)
                .foregroundStyle(PapagaioTema.textoSecundario)
        }
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

                // Sem `.lineLimit`: mesmo sendo um rótulo curto e fixo
                // ("Claro", "Escuro", "Sistema"), nenhum texto desta tela
                // deve depender de truncar para caber — a régua vale para
                // qualquer rótulo, não só para os que vêm de dados do
                // usuário.
                Label(opcao.titulo, systemImage: opcao.simbolo)
                    .font(PapagaioTema.Tipo.apoio.weight(selecionada ? .semibold : .regular))
                    .foregroundStyle(selecionada ? PapagaioTema.destaqueEscuro : PapagaioTema.textoSecundario)
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
            // A forma vai **dentro** do rótulo, e não no botão.
            //
            // Fora, ela descreve o botão para quem o contém — o botão continua
            // decidindo o próprio alvo pelo desenho do rótulo, que aqui é a
            // miniatura e o texto. Na opção não selecionada, cujo fundo é
            // transparente, sobrava só isso de clicável e o resto do cartão era
            // buraco. Dentro, ela é o alvo.
            .contentShape(Rectangle())
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
