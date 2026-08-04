import AppKit
import SwiftUI

struct BarraSuperiorPapagaioView: View {
    @Binding var consulta: String
    @Binding var legendaAtiva: LegendaDaBarra?
    @State private var exibindoMenuDePerfil = false
    @State private var exibindoNotificacoes = false
    let exibindoBotaoVoltar: Bool
    let bibliotecaSelecionada: Bool
    let tarefasSelecionada: Bool
    let configuracoesSelecionada: Bool
    let lixeiraSelecionada: Bool
    let perfilConectado: Bool
    let perfilVerificando: Bool
    let avatarURL: URL?
    let contextoDaConta: ContextoDaConta
    let equipeAtiva: EquipeDisponivel
    let gravando: Bool
    let processandoBiblioteca: Bool
    let quantidadeDeAvisos: Int
    let notificacoes: [NotificacaoDoApp]
    let aoEntrar: () -> Void
    let aoSair: () -> Void
    let aoMarcarNotificacoesComoLidas: () -> Void
    let aoLimparNotificacoes: () -> Void
    let aoVoltar: () -> Void
    let aoAbrirBiblioteca: () -> Void
    let aoAbrirTarefas: () -> Void
    let aoAbrirConfiguracoes: () -> Void
    let aoAbrirLixeira: () -> Void
    let aoUsarPerfil: () -> Void
    let aoUsarEquipe: () -> Void
    let aoGerenciarPerfil: () -> Void
    let aoGerenciarEquipe: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                if exibindoBotaoVoltar {
                    Button(action: aoVoltar) {
                        Image(systemName: "chevron.backward")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(PapagaioTema.textoSecundario)
                            .frame(width: 38, height: 38)
                            .background(PapagaioTema.superficie, in: Circle())
                            .overlay {
                                Circle().stroke(PapagaioTema.borda, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .help("Voltar")
                    .accessibilityLabel("Voltar")
                }

                BarraDeBuscaEAtalhos(
                    consulta: $consulta,
                    legendaAtiva: $legendaAtiva,
                    exibindoBotaoVoltar: exibindoBotaoVoltar,
                    bibliotecaSelecionada: bibliotecaSelecionada,
                    tarefasSelecionada: tarefasSelecionada,
                    aoAbrirBiblioteca: aoAbrirBiblioteca,
                    aoAbrirTarefas: aoAbrirTarefas
                )

                Spacer(minLength: 18)

                grupoDeAcoes
                botaoDePerfil
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            .frame(minWidth: 760, maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .background(PapagaioTema.fundo)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PapagaioTema.borda.opacity(0.75))
                .frame(height: 1)
        }
    }

    private var grupoDeAcoes: some View {
        HStack(spacing: 12) {
            Button {
                exibindoNotificacoes = true
                aoMarcarNotificacoesComoLidas()
            } label: {
                BotaoDeIconeDaBarra(
                    simbolo: "bell",
                    legenda: "Notificações",
                    legendaAtiva: $legendaAtiva,
                    selecionado: exibindoNotificacoes,
                    mostraIndicador: quantidadeDeAvisos > 0
                )
            }
            .buttonStyle(.plain)
            .help("Notificações")
            .popover(isPresented: $exibindoNotificacoes, arrowEdge: .top) {
                ListaDeNotificacoesDoApp(
                    notificacoes: notificacoes,
                    processandoBiblioteca: processandoBiblioteca,
                    gravando: gravando,
                    aoLimpar: aoLimparNotificacoes
                )
            }

            Button(action: aoAbrirConfiguracoes) {
                BotaoDeIconeDaBarra(
                    simbolo: "gearshape",
                    legenda: "Configurações",
                    legendaAtiva: $legendaAtiva,
                    selecionado: configuracoesSelecionada
                )
            }
            .buttonStyle(.plain)
            .help("Configurações")

            Button(action: aoAbrirLixeira) {
                BotaoDeIconeDaBarra(
                    simbolo: "trash",
                    legenda: "Lixeira",
                    legendaAtiva: $legendaAtiva,
                    selecionado: lixeiraSelecionada
                )
            }
            .buttonStyle(.plain)
            .help("Lixeira")
        }
        .padding(.horizontal, 8)
        .frame(height: 46)
        .background(PapagaioTema.superficie, in: Capsule())
        .overlay {
            Capsule().stroke(PapagaioTema.borda.opacity(0.82), lineWidth: 1)
        }
    }

    private var botaoDePerfil: some View {
        Button {
            exibindoMenuDePerfil = true
        } label: {
            HStack(spacing: 9) {
                AvatarDaContaNaBarra(
                    url: contextoDaConta == .perfil ? avatarURL : nil,
                    simbolo: contextoDaConta.simbolo,
                    conectado: perfilConectado
                )

                Text(tituloDaContaAtiva)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(PapagaioTema.textoSecundario)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PapagaioTema.textoSecundario.opacity(0.72))
            }
            .padding(.leading, 3)
            .padding(.trailing, 10)
            .frame(minWidth: 176, idealWidth: 190, alignment: .leading)
            .frame(height: 40)
            .background(PapagaioTema.superficie, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(PapagaioTema.borda.opacity(0.82), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .help(perfilConectado ? tituloDaContaAtiva : "Perfil")
        .popover(isPresented: $exibindoMenuDePerfil, arrowEdge: .top) {
            menuDePerfil
        }
    }

    private var menuDePerfil: some View {
        VStack(alignment: .leading, spacing: 12) {
            if perfilConectado {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Conta ativa")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PapagaioTema.textoSecundario)
                    Text(tituloDaContaAtiva)
                        .font(.headline)
                        .foregroundStyle(PapagaioTema.texto)
                }

                SeletorDeContextoDaConta(
                    contexto: contextoDaConta,
                    equipeAtiva: equipeAtiva,
                    aoUsarPerfil: {
                        exibindoMenuDePerfil = false
                        aoUsarPerfil()
                    },
                    aoUsarEquipe: {
                        exibindoMenuDePerfil = false
                        aoUsarEquipe()
                    }
                )

                Divider()

                Button("Gerenciar perfil", systemImage: "person.crop.circle") {
                    exibindoMenuDePerfil = false
                    aoGerenciarPerfil()
                }

                Button("Gerenciar equipe", systemImage: "person.3.sequence") {
                    exibindoMenuDePerfil = false
                    aoGerenciarEquipe()
                }

                Button("Sair", role: .destructive) {
                    exibindoMenuDePerfil = false
                    aoSair()
                }
            } else {
                Button("Entrar com Apple") {
                    exibindoMenuDePerfil = false
                    aoEntrar()
                }
                .disabled(perfilVerificando)
            }
        }
        .padding(14)
        .frame(width: 280, alignment: .leading)
    }

    private var tituloDaContaAtiva: String {
        contextoDaConta == .perfil ? "Perfil pessoal" : equipeAtiva.nome
    }
}

/// Conteúdo da barra de ferramentas nativa. Só expõe ações existentes — não
/// adiciona ícones decorativos sem comportamento.
struct BarraSuperiorPapagaio: ToolbarContent {
    @Binding var consulta: String
    @Binding var legendaAtiva: LegendaDaBarra?
    @State private var exibindoMenuDePerfil = false
    @State private var exibindoNotificacoes = false
    let exibindoBotaoVoltar: Bool
    let bibliotecaSelecionada: Bool
    let tarefasSelecionada: Bool
    let configuracoesSelecionada: Bool
    let lixeiraSelecionada: Bool
    let perfilConectado: Bool
    let perfilVerificando: Bool
    let avatarURL: URL?
    let contextoDaConta: ContextoDaConta
    let equipeAtiva: EquipeDisponivel
    let gravando: Bool
    let processandoBiblioteca: Bool
    let quantidadeDeAvisos: Int
    let notificacoes: [NotificacaoDoApp]
    let aoEntrar: () -> Void
    let aoSair: () -> Void
    let aoMarcarNotificacoesComoLidas: () -> Void
    let aoLimparNotificacoes: () -> Void
    let aoVoltar: () -> Void
    let aoAbrirBiblioteca: () -> Void
    let aoAbrirTarefas: () -> Void
    let aoAbrirConfiguracoes: () -> Void
    let aoAbrirLixeira: () -> Void
    let aoUsarPerfil: () -> Void
    let aoUsarEquipe: () -> Void
    let aoGerenciarPerfil: () -> Void
    let aoGerenciarEquipe: () -> Void

    var body: some ToolbarContent {
        if exibindoBotaoVoltar {
            ToolbarItem(placement: .navigation) {
                Button(action: aoVoltar) {
                    Image(systemName: "chevron.backward")
                }
                .help("Voltar à biblioteca")
                .accessibilityLabel("Voltar à biblioteca")
            }
        }

        ToolbarItem(placement: .principal) {
            BarraDeBuscaEAtalhos(
                consulta: $consulta,
                legendaAtiva: $legendaAtiva,
                exibindoBotaoVoltar: exibindoBotaoVoltar,
                bibliotecaSelecionada: bibliotecaSelecionada,
                tarefasSelecionada: tarefasSelecionada,
                aoAbrirBiblioteca: aoAbrirBiblioteca,
                aoAbrirTarefas: aoAbrirTarefas
            )
        }
        ToolbarItem(placement: .primaryAction) {
            HStack(spacing: 10) {
                Button {
                    exibindoNotificacoes = true
                    aoMarcarNotificacoesComoLidas()
                } label: {
                    BotaoDeIconeDaBarra(
                        simbolo: "bell",
                        legenda: "Notificações",
                        legendaAtiva: $legendaAtiva,
                        selecionado: exibindoNotificacoes,
                        mostraIndicador: temNotificacoesAtivas
                    )
                }
                .buttonStyle(.plain)
                .help("Notificações")
                .accessibilityLabel("Notificações")
                .popover(isPresented: $exibindoNotificacoes, arrowEdge: .top) {
                    ListaDeNotificacoesDoApp(
                        notificacoes: notificacoes,
                        processandoBiblioteca: processandoBiblioteca,
                        gravando: gravando,
                        aoLimpar: aoLimparNotificacoes
                    )
                }

                Button(action: aoAbrirConfiguracoes) {
                    BotaoDeIconeDaBarra(
                        simbolo: "gearshape",
                        legenda: "Configurações",
                        legendaAtiva: $legendaAtiva,
                        selecionado: configuracoesSelecionada
                    )
                }
                .buttonStyle(.plain)
                .help("Configurações")
                .accessibilityLabel("Configurações")
                .accessibilityHint("Abre as preferências de transcrição.")

                Button(action: aoAbrirLixeira) {
                    BotaoDeIconeDaBarra(
                        simbolo: "trash",
                        legenda: "Lixeira",
                        legendaAtiva: $legendaAtiva,
                        selecionado: lixeiraSelecionada
                    )
                }
                .buttonStyle(.plain)
                .help("Lixeira")
                .accessibilityLabel("Lixeira")
                .accessibilityHint("Abre os arquivos removidos da biblioteca.")
            }
            .padding(.horizontal, 4)
        }

        ToolbarSpacer(.fixed, placement: .primaryAction)

        ToolbarItem(placement: .primaryAction) {
            Button {
                exibindoMenuDePerfil = true
            } label: {
                HStack(spacing: 8) {
                    AvatarDaContaNaBarra(
                        url: contextoDaConta == .perfil ? avatarURL : nil,
                        simbolo: contextoDaConta.simbolo,
                        conectado: perfilConectado
                    )

                    Text(tituloDaContaAtiva)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(PapagaioTema.textoSecundario)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PapagaioTema.textoSecundario.opacity(0.72))
                }
                .padding(.leading, 2)
                .padding(.trailing, 8)
                .frame(height: 36)
                .background(PapagaioTema.superficie, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(PapagaioTema.borda.opacity(0.82), lineWidth: 1)
                }
                .frame(minWidth: 44, idealWidth: 160, maxWidth: 190)
            }
            .buttonStyle(.plain)
            .help(perfilConectado ? tituloDaContaAtiva : "Perfil")
            .accessibilityLabel(perfilConectado ? "Conta ativa: \(tituloDaContaAtiva)" : "Perfil")
            .popover(isPresented: $exibindoMenuDePerfil, arrowEdge: .top) {
                VStack(alignment: .leading, spacing: 12) {
                    if perfilConectado {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Conta ativa")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(PapagaioTema.textoSecundario)
                            Text(tituloDaContaAtiva)
                                .font(.headline)
                                .foregroundStyle(PapagaioTema.texto)
                        }

                        SeletorDeContextoDaConta(
                            contexto: contextoDaConta,
                            equipeAtiva: equipeAtiva,
                            aoUsarPerfil: {
                                exibindoMenuDePerfil = false
                                aoUsarPerfil()
                            },
                            aoUsarEquipe: {
                                exibindoMenuDePerfil = false
                                aoUsarEquipe()
                            }
                        )

                        Divider()

                        Button("Gerenciar perfil", systemImage: "person.crop.circle") {
                            exibindoMenuDePerfil = false
                            aoGerenciarPerfil()
                        }

                        Button("Gerenciar equipe", systemImage: "person.3.sequence") {
                            exibindoMenuDePerfil = false
                            aoGerenciarEquipe()
                        }

                        Button("Sair", role: .destructive) {
                            exibindoMenuDePerfil = false
                            aoSair()
                        }
                    } else {
                        Button("Entrar com Apple") {
                            exibindoMenuDePerfil = false
                            aoEntrar()
                        }
                        .disabled(perfilVerificando)
                    }
                }
                .padding(14)
                .frame(width: 260, alignment: .leading)
            }
        }
    }

    private var temNotificacoesAtivas: Bool {
        quantidadeDeAvisos > 0
    }

    private var tituloDaContaAtiva: String {
        contextoDaConta == .perfil ? "Perfil pessoal" : equipeAtiva.nome
    }
}

private struct AvatarDaContaNaBarra: View {
    let url: URL?
    let simbolo: String
    let conectado: Bool

    private var imagem: NSImage? {
        guard let url else { return nil }
        let acessou = url.startAccessingSecurityScopedResource()
        defer {
            if acessou { url.stopAccessingSecurityScopedResource() }
        }
        return NSImage(contentsOf: url)
    }

    var body: some View {
        ZStack {
            if let imagem {
                Image(nsImage: imagem)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: simbolo)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(conectado ? PapagaioTema.destaqueEscuro : PapagaioTema.textoSecundario)
                    .frame(width: 32, height: 32)
            }
        }
        .frame(width: 32, height: 32)
        .background(.regularMaterial, in: Circle())
        .clipShape(Circle())
        .overlay {
            Circle()
                .strokeBorder(PapagaioTema.borda.opacity(0.8), lineWidth: 1)
        }
    }
}

private struct BotaoDeIconeDaBarra: View {
    let simbolo: String
    let legenda: String
    @Binding var legendaAtiva: LegendaDaBarra?
    let selecionado: Bool
    var mostraIndicador = false
    @State private var pairando = false

    var body: some View {
        GeometryReader { geometria in
            ZStack(alignment: .topTrailing) {
                Image(systemName: simbolo)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(selecionado || pairando ? PapagaioTema.destaqueEscuro : PapagaioTema.textoSecundario)
                    .frame(width: 38, height: 38)
                    .background(fundo, in: Circle())
                    .overlay {
                        Circle()
                            .stroke(selecionado ? PapagaioTema.destaque.opacity(0.58) : PapagaioTema.borda.opacity(pairando ? 1 : 0.76), lineWidth: 1)
                    }
                    .contentShape(Circle())

                if mostraIndicador {
                    Circle()
                        .fill(PapagaioTema.destaque)
                        .frame(width: 8, height: 8)
                        .offset(x: -5, y: 5)
                }
            }
            .onHover { ativo in
                pairando = ativo
                if ativo {
                    legendaAtiva = LegendaDaBarra(texto: legenda, x: geometria.frame(in: .global).midX)
                } else if legendaAtiva?.texto == legenda {
                    legendaAtiva = nil
                }
            }
        }
        .frame(width: 38, height: 38)
        .zIndex(pairando ? 10 : 0)
        .animation(.easeOut(duration: 0.14), value: pairando)
        .animation(.easeOut(duration: 0.14), value: selecionado)
    }

    private var fundo: Color {
        if selecionado { return PapagaioTema.destaqueSuave.opacity(0.76) }
        if pairando { return PapagaioTema.destaqueSuave.opacity(0.46) }
        return PapagaioTema.superficie
    }
}

private struct BotaoDeAtalhoDaBarra: View {
    let simbolo: String
    let legenda: String
    @Binding var legendaAtiva: LegendaDaBarra?
    let selecionado: Bool
    @State private var pairando = false

    var body: some View {
        GeometryReader { geometria in
            Image(systemName: simbolo)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(selecionado || pairando ? PapagaioTema.destaqueEscuro : PapagaioTema.textoSecundario)
                .frame(width: 42, height: 32)
                .background(fundo, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .contentShape(Rectangle())
                .onHover { ativo in
                    pairando = ativo
                    if ativo {
                        legendaAtiva = LegendaDaBarra(texto: legenda, x: geometria.frame(in: .global).midX)
                    } else if legendaAtiva?.texto == legenda {
                        legendaAtiva = nil
                    }
                }
        }
            .frame(width: 42, height: 32)
            .onHover { ativo in
                if !ativo, legendaAtiva?.texto == legenda {
                    legendaAtiva = nil
                }
            }
            .zIndex(pairando ? 10 : 0)
            .animation(.easeOut(duration: 0.14), value: pairando)
            .animation(.easeOut(duration: 0.14), value: selecionado)
    }

    private var fundo: Color {
        if selecionado { return PapagaioTema.destaqueSuave.opacity(0.72) }
        if pairando { return PapagaioTema.destaqueSuave.opacity(0.42) }
        return .clear
    }
}

private struct BarraDeBuscaEAtalhos: View {
    @Binding var consulta: String
    @Binding var legendaAtiva: LegendaDaBarra?
    let exibindoBotaoVoltar: Bool
    let bibliotecaSelecionada: Bool
    let tarefasSelecionada: Bool
    let aoAbrirBiblioteca: () -> Void
    let aoAbrirTarefas: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                campoDeBusca
                atalhos
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    campoDeBusca
                    atalhos
                }
                .padding(.horizontal, 2)
            }
            .frame(minWidth: 220, maxWidth: 390)
        }
    }

    private var campoDeBusca: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(PapagaioTema.textoSecundario)
            TextField("Buscar conversas…", text: $consulta)
                .textFieldStyle(.plain)
                .foregroundStyle(PapagaioTema.texto)
                .accessibilityLabel("Buscar conversas")
        }
        .padding(.horizontal, 14)
        .frame(
            minWidth: 170,
            idealWidth: exibindoBotaoVoltar ? 360 : 520,
            maxWidth: exibindoBotaoVoltar ? 500 : 700
        )
        .frame(height: 38)
        .background(PapagaioTema.superficie, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(PapagaioTema.borda, lineWidth: 1)
        }
    }

    private var atalhos: some View {
        HStack(spacing: 4) {
            HStack(spacing: 4) {
                Button(action: aoAbrirBiblioteca) {
                    BotaoDeAtalhoDaBarra(
                        simbolo: "folder",
                        legenda: "Biblioteca de conversas",
                        legendaAtiva: $legendaAtiva,
                        selecionado: bibliotecaSelecionada
                    )
                }
                .buttonStyle(.plain)
                .help("Biblioteca de conversas")
                .accessibilityLabel("Biblioteca de conversas")

                Button(action: aoAbrirTarefas) {
                    BotaoDeAtalhoDaBarra(
                        simbolo: "list.clipboard",
                        legenda: "Tarefas",
                        legendaAtiva: $legendaAtiva,
                        selecionado: tarefasSelecionada
                    )
                }
                .buttonStyle(.plain)
                .help("Tarefas")
                .accessibilityLabel("Tarefas")
            }
        }
        .padding(.horizontal, 4)
        .frame(height: 38)
        .background(PapagaioTema.superficie, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(PapagaioTema.borda, lineWidth: 1)
        }
    }
}

private struct ListaDeNotificacoesDoApp: View {
    let notificacoes: [NotificacaoDoApp]
    let processandoBiblioteca: Bool
    let gravando: Bool
    let aoLimpar: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Notificações")
                    .font(.headline)
                    .foregroundStyle(PapagaioTema.texto)

                Spacer()

                Button("Limpar", systemImage: "trash", action: aoLimpar)
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(PapagaioTema.textoSecundario)
                    .disabled(notificacoes.isEmpty)
            }

            if gravando || processandoBiblioteca {
                VStack(alignment: .leading, spacing: 8) {
                    if gravando {
                        LinhaDeNotificacaoTemporaria(
                            simbolo: "mic.fill",
                            titulo: "Gravação ativa",
                            mensagem: "Ao finalizar, a conversa será salva na biblioteca."
                        )
                    }

                    if processandoBiblioteca {
                        LinhaDeNotificacaoTemporaria(
                            simbolo: "waveform.badge.magnifyingglass",
                            titulo: "Processando conversa",
                            mensagem: "Você será avisado quando a transcrição terminar."
                        )
                    }
                }
            }

            if notificacoes.isEmpty {
                Text("Nenhum aviso ainda.")
                    .font(.callout)
                    .foregroundStyle(PapagaioTema.textoSecundario)
                    .frame(maxWidth: .infinity, minHeight: 72, alignment: .center)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(notificacoes) { notificacao in
                            LinhaDeNotificacaoDoApp(notificacao: notificacao)
                        }
                    }
                }
                .frame(maxHeight: 280)
            }
        }
        .padding(14)
        .frame(width: 340, alignment: .leading)
        .background(PapagaioTema.fundo)
    }
}

private struct LinhaDeNotificacaoDoApp: View {
    let notificacao: NotificacaoDoApp

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: notificacao.simbolo)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(cor)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(notificacao.titulo)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(PapagaioTema.texto)
                    .lineLimit(2)

                Text(notificacao.mensagem)
                    .font(.caption)
                    .foregroundStyle(PapagaioTema.textoSecundario)
                    .lineLimit(3)

                Text(notificacao.data.formatted(.dateTime.hour().minute()))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(PapagaioTema.textoSecundario.opacity(0.72))
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            notificacao.lida ? PapagaioTema.superficie : PapagaioTema.destaqueSuave.opacity(0.65),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(PapagaioTema.borda.opacity(0.75), lineWidth: 1)
        }
    }

    private var cor: Color {
        switch notificacao.tipo {
        case .sucesso: PapagaioTema.sucesso
        case .aviso: PapagaioTema.aviso
        case .erro: PapagaioTema.perigo
        }
    }
}

private struct LinhaDeNotificacaoTemporaria: View {
    let simbolo: String
    let titulo: String
    let mensagem: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: simbolo)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(PapagaioTema.destaqueEscuro)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(titulo)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(PapagaioTema.texto)
                Text(mensagem)
                    .font(.caption)
                    .foregroundStyle(PapagaioTema.textoSecundario)
            }
        }
        .padding(10)
        .background(PapagaioTema.superficieSuave, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct SeletorDeContextoDaConta: View {
    let contexto: ContextoDaConta
    let equipeAtiva: EquipeDisponivel
    let aoUsarPerfil: () -> Void
    let aoUsarEquipe: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            BotaoDeContextoDaConta(
                titulo: "Perfil pessoal",
                subtitulo: "Conta pessoal",
                simbolo: "person.crop.circle",
                selecionado: contexto == .perfil,
                acao: aoUsarPerfil
            )

            BotaoDeContextoDaConta(
                titulo: "Equipe",
                subtitulo: equipeAtiva.nome,
                simbolo: "person.3",
                selecionado: contexto == .equipe,
                acao: aoUsarEquipe
            )
        }
    }
}

private struct BotaoDeContextoDaConta: View {
    let titulo: String
    let subtitulo: String
    let simbolo: String
    let selecionado: Bool
    let acao: () -> Void

    var body: some View {
        Button(action: acao) {
            HStack(spacing: 10) {
                Image(systemName: simbolo)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(selecionado ? PapagaioTema.destaqueEscuro : PapagaioTema.textoSecundario)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(titulo)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(PapagaioTema.texto)
                    Text(subtitulo)
                        .font(.caption)
                        .foregroundStyle(PapagaioTema.textoSecundario)
                        .lineLimit(1)
                }

                Spacer()

                if selecionado {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PapagaioTema.destaqueEscuro)
                }
            }
            .padding(10)
            .background(
                selecionado ? PapagaioTema.destaqueSuave.opacity(0.7) : Color.clear,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }
}

struct CabecalhoDePagina<Acoes: View>: View {
    let titulo: String
    let subtitulo: String?
    @ViewBuilder let acoes: () -> Acoes

    init(
        titulo: String,
        subtitulo: String? = nil,
        @ViewBuilder acoes: @escaping () -> Acoes = { EmptyView() }
    ) {
        self.titulo = titulo
        self.subtitulo = subtitulo
        self.acoes = acoes
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .bottom, spacing: 20) {
                texto
                Spacer(minLength: 16)
                acoes()
            }

            VStack(alignment: .leading, spacing: 16) {
                texto
                acoes()
            }
        }
    }

    private var texto: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titulo)
                .font(.system(size: 32, weight: .bold, design: .default))
                .foregroundStyle(PapagaioTema.texto)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
            if let subtitulo {
                Text(subtitulo)
                    .font(.title3)
                    .foregroundStyle(PapagaioTema.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct CartaoDeEstadoVazio: View {
    let simbolo: String
    let titulo: String
    let mensagem: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: simbolo)
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(PapagaioTema.destaqueEscuro)
                .frame(width: 64, height: 64)
                .background(PapagaioTema.destaqueSuave, in: Circle())
            Text(titulo)
                .font(.title3.weight(.semibold))
                .foregroundStyle(PapagaioTema.texto)
            Text(mensagem)
                .multilineTextAlignment(.center)
                .foregroundStyle(PapagaioTema.textoSecundario)
                .frame(maxWidth: 420)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

struct SeparadorPapagaio: View {
    var body: some View {
        Rectangle()
            .fill(PapagaioTema.borda.opacity(0.75))
            .frame(height: 1)
    }
}
