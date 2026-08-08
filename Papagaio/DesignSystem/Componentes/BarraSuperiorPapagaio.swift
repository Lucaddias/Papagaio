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
    let equipeAtiva: EquipeDisponivel?
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

    /// A barra era um `ScrollView` horizontal com `minWidth: 760`. Abaixo disso
    /// ela não encolhia: rolava, e o botão de conta — único acesso a perfil,
    /// equipe e sair — saía da tela sem nenhum indício de que ainda estava lá.
    ///
    /// Agora ela se resolve sozinha em três estágios: completa; sem o rótulo da
    /// conta; e, no mais apertado, com os dois grupos de ícones fundidos num
    /// menu "⋯". Nenhuma ação fica inalcançável em nenhuma largura.
    var body: some View {
        HStack(spacing: PapagaioTema.Espaco.medio) {
            if exibindoBotaoVoltar {
                Button(action: aoVoltar) {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(PapagaioTema.textoSecundario)
                        .frame(width: PapagaioTema.Altura.padrao, height: PapagaioTema.Altura.padrao)
                        .background(PapagaioTema.superficie, in: Circle())
                        .overlay {
                            Circle().stroke(PapagaioTema.borda, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .help("Voltar")
                .accessibilityLabel("Voltar")
            }

            campoDeBusca

            Spacer(minLength: PapagaioTema.Espaco.curto)

            // Degradação em três estágios. Depender do tamanho mínimo da janela
            // não funcionou — `windowResizability(.contentMinSize)` não segurou
            // o `minWidth` através do `NavigationStack`, e a janela continuava
            // encolhendo até a barra transbordar pelos dois lados. Aqui a barra
            // se resolve sozinha em qualquer largura.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: PapagaioTema.Espaco.medio) {
                    atalhos
                    grupoDeAcoes
                    botaoDePerfil(comRotulo: true)
                }

                HStack(spacing: PapagaioTema.Espaco.curto) {
                    atalhos
                    grupoDeAcoes
                    botaoDePerfil(comRotulo: false)
                }

                HStack(spacing: PapagaioTema.Espaco.curto) {
                    menuDeAcoesCompacto
                    botaoDePerfil(comRotulo: false)
                }
            }
        }
        // Padding menor que o das páginas: a barra é cromo, e cada ponto aqui
        // é ponto que falta para o botão de conta caber na janela mínima.
        .padding(.horizontal, PapagaioTema.Espaco.medio)
        .padding(.vertical, PapagaioTema.Espaco.curto)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PapagaioTema.fundo)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PapagaioTema.borda.opacity(0.75))
                .frame(height: 1)
        }
    }

    private var grupoDeAcoes: some View {
        HStack(spacing: PapagaioTema.Espaco.medio) {
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
        .padding(.horizontal, PapagaioTema.Espaco.minimo)
        .frame(height: PapagaioTema.Altura.padrao)
        .background(PapagaioTema.superficie, in: Capsule())
        .overlay {
            Capsule().stroke(PapagaioTema.borda.opacity(0.82), lineWidth: 1)
        }
        .fixedSize()
    }

    /// Estágio final da barra: um menu só com tudo o que os dois grupos de
    /// ícones ofereciam. Nada fica inacessível quando a janela aperta.
    private var menuDeAcoesCompacto: some View {
        Menu {
            Button("Biblioteca de conversas", systemImage: "folder", action: aoAbrirBiblioteca)
            Button("Tarefas", systemImage: "list.clipboard", action: aoAbrirTarefas)

            Divider()

            Button(action: {
                exibindoNotificacoes = true
                aoMarcarNotificacoesComoLidas()
            }) {
                Label(
                    quantidadeDeAvisos > 0 ? "Notificações (\(quantidadeDeAvisos))" : "Notificações",
                    systemImage: "bell"
                )
            }
            Button("Configurações", systemImage: "gearshape", action: aoAbrirConfiguracoes)
            Button("Lixeira", systemImage: "trash", action: aoAbrirLixeira)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(PapagaioTema.textoSecundario)
                .frame(width: PapagaioTema.Altura.padrao, height: PapagaioTema.Altura.padrao)
                .background(PapagaioTema.superficie, in: Circle())
                .overlay {
                    Circle().stroke(PapagaioTema.borda.opacity(0.82), lineWidth: 1)
                }
                .overlay(alignment: .topTrailing) {
                    if quantidadeDeAvisos > 0 {
                        Circle()
                            .fill(PapagaioTema.destaque)
                            .frame(width: 8, height: 8)
                    }
                }
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Mais ações")
        .accessibilityLabel("Mais ações")
        .popover(isPresented: $exibindoNotificacoes, arrowEdge: .top) {
            ListaDeNotificacoesDoApp(
                notificacoes: notificacoes,
                processandoBiblioteca: processandoBiblioteca,
                gravando: gravando,
                aoLimpar: aoLimparNotificacoes
            )
        }
    }

    private func botaoDePerfil(comRotulo: Bool) -> some View {
        Button {
            exibindoMenuDePerfil = true
        } label: {
            conteudoDoBotaoDePerfil(comRotulo: comRotulo)
        }
        .buttonStyle(.plain)
        .fixedSize()
        .help(perfilConectado ? tituloDaContaAtiva : "Perfil")
        .accessibilityLabel(perfilConectado ? "Conta ativa: \(tituloDaContaAtiva)" : "Perfil")
        .popover(isPresented: $exibindoMenuDePerfil, arrowEdge: .top) {
            menuDePerfil
        }
    }

    private func conteudoDoBotaoDePerfil(comRotulo: Bool) -> some View {
        HStack(spacing: PapagaioTema.Espaco.curto) {
            AvatarDaContaNaBarra(
                url: contextoDaConta == .perfil ? avatarURL : nil,
                simbolo: contextoDaConta.simbolo,
                conectado: perfilConectado
            )

            if comRotulo {
                Text(tituloDaContaAtiva)
                    .font(PapagaioTema.Tipo.apoio.weight(.semibold))
                    .foregroundStyle(PapagaioTema.textoSecundario)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PapagaioTema.textoSecundario.opacity(0.72))
            }
        }
        .padding(.leading, PapagaioTema.Espaco.minimo)
        .padding(.trailing, comRotulo ? PapagaioTema.Espaco.medio : PapagaioTema.Espaco.minimo)
        .frame(height: PapagaioTema.Altura.padrao)
        .background(PapagaioTema.superficie, in: Capsule())
        .overlay {
            Capsule()
                .stroke(PapagaioTema.borda.opacity(0.82), lineWidth: 1)
        }
    }

    private var menuDePerfil: some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.medio) {
            if perfilConectado {
                VStack(alignment: .leading, spacing: PapagaioTema.Espaco.minimo) {
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
        .padding(PapagaioTema.Espaco.medio)
        .frame(width: 280, alignment: .leading)
    }

    private var campoDeBusca: some View {
        HStack(spacing: PapagaioTema.Espaco.curto) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(PapagaioTema.textoSecundario)
            TextField("Buscar conversas…", text: $consulta)
                .textFieldStyle(.plain)
                .foregroundStyle(PapagaioTema.texto)
                .accessibilityLabel("Buscar conversas")
        }
        // Único elemento elástico da barra: cresce até 420 e cede até 100.
        // Sem `layoutPriority` — ele deve ser servido depois dos grupos de
        // ícones, que são `fixedSize` e não têm como encolher em troca.
        .frame(minWidth: 100, idealWidth: 360, maxWidth: 420)
        .molduraDeControlePapagaio()
    }

    private var atalhos: some View {
        HStack(spacing: PapagaioTema.Espaco.minimo) {
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
        .padding(.horizontal, PapagaioTema.Espaco.minimo)
        .frame(height: PapagaioTema.Altura.padrao)
        .background(
            PapagaioTema.superficie,
            in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
                .stroke(PapagaioTema.borda, lineWidth: 1)
        }
        .fixedSize()
    }

    private var tituloDaContaAtiva: String {
        contextoDaConta == .perfil ? "Perfil pessoal" : (equipeAtiva?.nome ?? "Nenhuma equipe ainda")
    }
}
