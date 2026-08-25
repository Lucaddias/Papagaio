import SwiftUI

struct BarraSuperiorPapagaioView: View {
    @Binding var consulta: String
    @Binding var legendaAtiva: LegendaDaBarra?
    @State private var exibindoMenuDePerfil = false
    @State private var exibindoNotificacoes = false
    @State private var larguraDaBarra: CGFloat = 0
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
    /// Só some durante a gravação — nem Configurações fica de fora: agora a
    /// busca filtra as próprias seções da tela (Aparência, Cartões,
    /// Transcrição, Atalhos...), então esconder ali deixaria de valer a
    /// mesma promessa que a busca faz em qualquer outra tela.
    private var exibindoBusca: Bool { !gravando }

    /// "Buscar conversas…" não servia em nenhuma das outras duas telas com
    /// busca: no painel de tarefas o termo casa o nome da tarefa, e na
    /// lixeira ele também alcança mídia e tarefas apagadas — dizer só
    /// "conversas" ali prometia menos do que a busca de fato cobre.
    private var placeholderDeBusca: String {
        if tarefasSelecionada { return "Buscar tarefas…" }
        if lixeiraSelecionada { return "Buscar na lixeira…" }
        if configuracoesSelecionada { return "Buscar nas configurações…" }
        return "Buscar conversas…"
    }

    /// Só centraliza quando sobra largura para os três blocos conviverem: a
    /// busca no meio, o voltar à esquerda e conta mais ações à direita.
    private var exibindoBuscaCentralizada: Bool {
        exibindoBusca && larguraDaBarra >= 1_040
    }

    /// Estágio do bloco de ações (notificações, lixeira, configurações,
    /// perfil), por largura medida da barra — e não mais `ViewThatFits`
    /// escolhendo sozinho. O `ViewThatFits` nunca chegava a encolher para o
    /// menu "…": o campo de busca é elástico (`minWidth: 100`) e cedia
    /// espaço primeiro, deixando o grupo de ações sempre "caber" no estágio
    /// cheio, por mais estreita que a janela ficasse — a busca simplesmente
    /// virava um campo minúsculo e o "…" nunca aparecia. Com a decisão
    /// amarrada à largura da barra, e não ao que sobra depois da busca
    /// encolher, o menu aparece de verdade nas janelas estreitas.
    ///
    /// 0 = ícones com rótulo, 1 = só ícone, 2 = tudo dentro do menu "…".
    private var estagioDoGrupoDeAcoes: Int {
        if larguraDaBarra >= 900 { return 0 }
        if larguraDaBarra >= 640 { return 1 }
        return 2
    }

    var body: some View {
        // A busca fica no centro da **janela**, não no meio do que sobra entre
        // os dois grupos. Num `HStack` com espaçadores ela pousaria à esquerda
        // do centro, porque o grupo da conta é bem mais largo que o do voltar.
        // Daí a sobreposição centralizada por cima da linha.
        HStack(spacing: PapagaioTema.Espaco.medio) {
            if exibindoBotaoVoltar || gravando {
                BotaoCircularPapagaio(
                    simbolo: "chevron.backward",
                    ajuda: "Voltar para a biblioteca",
                    legendaAtiva: $legendaAtiva,
                    acao: aoVoltar
                )
            }

            // Sem espaço para centralizar, busca e atalhos voltam para a linha,
            // logo depois do voltar, e encolhem junto com ela.
            if exibindoBusca, !exibindoBuscaCentralizada {
                campoDeBusca
                // Some no estágio mais compacto (menu "…"): ali Biblioteca e
                // Tarefas já estão dentro do menu, então mantê-las aqui era
                // repetir o mesmo atalho duas vezes brigando por espaço com
                // ele — o motivo original desta reclamação.
                if estagioDoGrupoDeAcoes < 2 {
                    atalhos
                }
            }

            Spacer(minLength: PapagaioTema.Espaco.curto)

            // Degradação em três estágios, decidida por `estagioDoGrupoDeAcoes`
            // (largura medida da barra) — não mais `ViewThatFits` escolhendo
            // sozinho, pelo motivo explicado ali.
            if !gravando {
                switch estagioDoGrupoDeAcoes {
                case 0:
                    HStack(spacing: PapagaioTema.Espaco.medio) {
                        grupoDeAcoes
                        botaoDePerfil(comRotulo: true)
                    }
                case 1:
                    HStack(spacing: PapagaioTema.Espaco.curto) {
                        grupoDeAcoes
                        botaoDePerfil(comRotulo: false)
                    }
                default:
                    HStack(spacing: PapagaioTema.Espaco.curto) {
                        menuDeAcoesCompacto
                        botaoDePerfil(comRotulo: false)
                    }
                }
            }
        }
        // Gravando, a barra some inteira e sobra só o botão de voltar: buscar
        // ou trocar de seção no meio de uma captura só tira a pessoa da tela
        // em que ela está trabalhando.
        // A busca centralizada é uma sobreposição, e sobreposição não empurra
        // ninguém: em janela estreita ela passava por cima dos botões da
        // direita. Por isso a largura decide o layout — centralizada quando há
        // espaço, dentro da linha quando não há.
        .overlay {
            if exibindoBuscaCentralizada {
                HStack(spacing: PapagaioTema.Espaco.medio) {
                    campoDeBusca
                    atalhos
                }
                .fixedSize()
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { larguraDaBarra = $0 }
        // A barra segue a mesma coluna das páginas: margem igual **e** o mesmo
        // teto de largura. Só igualar o padding não bastava — as páginas usam
        // `larguraDeConteudoPapagaio`, que centraliza o conteúdo numa coluna
        // limitada, então em tela larga o título começava bem depois da busca.
        // A ordem importa: primeiro a coluna, depois a margem — igual às
        // páginas, que fazem `larguraDeConteudoPapagaio()` e só então o
        // `padding`. Invertido, a margem entra **dentro** da coluna e soma
        // 24pt, jogando a busca para a direita do título em tela larga.
        .padding(.vertical, PapagaioTema.Espaco.curto)
        .larguraDeConteudoPapagaio()
        .padding(.horizontal, PapagaioTema.espacamentoDePagina)
        // Sem linha divisória: a régua horizontal separava a barra da página
        // como se fossem duas superfícies, e são a mesma. Os próprios botões
        // já têm contorno, então a hierarquia não depende dela.
        .background(PapagaioTema.fundo)
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

            // De volta na barra, e não mais só dentro do menu de conta: a
            // busca agora filtra as seções de Configurações (ver
            // `exibindoBusca`), então ela ganhou o mesmo direito de vizinhar
            // Tarefas/Biblioteca/Lixeira que tinha sido negado a ela antes
            // por não ter busca nenhuma.
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
        }
        // Sem cápsula em volta: eram dois contornos concêntricos para a mesma
        // coisa. Cada ícone já se anuncia como botão pelo próprio círculo, e
        // agrupá-los de novo só engrossava a moldura.
        .frame(height: PapagaioTema.Altura.padrao)
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
            Button("Lixeira", systemImage: "trash", action: aoAbrirLixeira)
            Button("Configurações", systemImage: "gearshape", action: aoAbrirConfiguracoes)
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
            // O placeholder muda com a tela: "conversas" não dizia nada de
            // útil no painel de tarefas, onde o termo casa é o nome da
            // tarefa (ou da conversa que a gerou) — nem na lixeira, onde a
            // busca também alcança mídia e tarefas apagadas, não só
            // conversas.
            TextField(placeholderDeBusca, text: $consulta)
                .textFieldStyle(.plain)
                .foregroundStyle(PapagaioTema.texto)
                .accessibilityLabel(placeholderDeBusca)
                // Em janela estreita, o placeholder mais longo ("Buscar nas
                // configurações…") pode não caber. Sem isto, o AppKit corta
                // no meio da palavra sem reticências, como as demais telas —
                // com isto, corta igual a qualquer outro texto do app.
                .lineLimit(1)
                .truncationMode(.tail)
        }
        // Único elemento elástico da barra: cresce até 620 e cede até 100.
        // Sem `layoutPriority` — ele deve ser servido depois dos grupos de
        // ícones, que são `fixedSize` e não têm como encolher em troca.
        .frame(minWidth: 100, idealWidth: 520, maxWidth: 620)
        // Cápsula, como os atalhos e o botão de perfil ao lado —
        // `molduraDeControlePapagaio()` desenha um retângulo de cantos só
        // discretamente arredondados (o raio padrão de qualquer controle do
        // app), e aqui ela ficava a única peça quadrada no meio de tudo o
        // mais redondo da barra.
        .padding(.horizontal, PapagaioTema.Espaco.medio)
        .frame(height: PapagaioTema.Altura.padrao)
        .background(PapagaioTema.superficie, in: Capsule())
        .overlay {
            Capsule().stroke(PapagaioTema.borda, lineWidth: 1)
        }
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
        // Cápsula, como o campo de busca e o botão de perfil ao lado — não
        // um retângulo de cantos arredondados. Era o único componente
        // quadrado no meio de tudo o mais redondo da barra.
        .background(PapagaioTema.superficie, in: Capsule())
        .overlay {
            Capsule().stroke(PapagaioTema.borda, lineWidth: 1)
        }
        .fixedSize()
    }

    private var tituloDaContaAtiva: String {
        contextoDaConta == .perfil ? "Perfil pessoal" : (equipeAtiva?.nome ?? "Nenhuma equipe ainda")
    }
}
