import AppKit
import PapagaioCore
import SwiftUI
import UniformTypeIdentifiers

/// O formulário da ficha da entrevista num valor só. Os campos espelham os do
/// `EditorDeInformacoesDoCard`; juntá-los aqui faz abrir, salvar e resetar o
/// formulário virarem uma operação cada — antes eram dez estados soltos que
/// precisavam andar em sincronia na mão.
struct FichaDaEntrevista {
    var titulo = ""
    var entrevistado = ""
    var emailDoEntrevistado = ""
    var entrevistadores = ""
    var emailDosEntrevistadores = ""
    var descricao = ""
    var formato = ""
    var participantes = "1"
    var data = Date()
    var duracao = ""
}

/// Coordenador da interface inicial.
///
/// Mantém a identidade dos view models e as integrações de sistema (navegação,
/// importação e Sign in with Apple). A composição visual vive em componentes
/// menores para que o redesign não altere o ciclo de vida do áudio.
struct ContentView: View {
    /// A gravação é criada no `App` e passada para cá: o item da barra de menus
    /// precisa observar exatamente o mesmo objeto que a janela.
    let modelo: GravadorViewModel

    init(gravador: GravadorViewModel) {
        modelo = gravador
    }

    @State private var biblioteca: Biblioteca?
    @State private var modelos: ModelosViewModel?
    @State private var perfil = PerfilViewModel()
    @State private var notificacoes = NotificacoesViewModel()
    @State private var equipes = EquipesDoUsuario.carregar()
    @State private var falhaDeAbertura: String?
    @State private var mostrandoImportador = false
    @State private var arquivoParaConfigurar: Arquivo?
    @State private var arquivosAguardandoFicha: Set<ArquivoID> = []
    /// O formulário da ficha num valor só: abrir, salvar e resetar viram uma
    /// operação cada, no lugar de dez estados soltos que precisavam andar em
    /// sincronia na mão.
    @State private var ficha = FichaDaEntrevista()
    @State private var consulta = ""
    @State private var legendaDaBarra: LegendaDaBarra?
    @State private var confirmandoCancelamentoDaGravacao = false
    /// Espaço ocupado pelo player na tela atual, anunciado por quem o desenha.
    @State private var alturaDoPlayer: CGFloat = 0
    private let servicoDeEquipesCloudKit = ServicoDeEquipesCloudKit()

    /// Dentro de uma conversa, onde a base pertence ao player.
    private var seloNoTopo: Bool { !conversaAberta.isEmpty }
    @State private var secaoDaBiblioteca: SecaoDaBiblioteca = .todos
    @State private var telaSelecionada: TelaPrincipal = .biblioteca
    /// Foco na tela de captura. Sair dela não interrompe a gravação — some o
    /// painel e aparece o selo "Gravando", que traz de volta.
    @State private var focoNaGravacao = false
    /// Pilha de conversas abertas, para a barra saber que há uma na frente.
    @State private var conversaAberta: [UUID] = []
    @State private var pastaDaBibliotecaSelecionada: String?
    @AppStorage("processamentoAutomatico") private var processamentoAutomatico = true
    @AppStorage("contextoDaConta") private var contextoDaContaRaw = ContextoDaConta.perfil.rawValue
    @AppStorage("equipeAtiva") private var equipeAtivaID = ""
    @AppStorage("aparenciaDoApp") private var aparenciaRaw = AparenciaDoApp.sistema.rawValue

    private var aparencia: Binding<AparenciaDoApp> {
        Binding(
            get: { AparenciaDoApp(rawValue: aparenciaRaw) ?? .sistema },
            set: { aparenciaRaw = $0.rawValue }
        )
    }

    private var contextoDaConta: ContextoDaConta {
        get { ContextoDaConta(rawValue: contextoDaContaRaw) ?? .perfil }
        nonmutating set { contextoDaContaRaw = newValue.rawValue }
    }

    /// `nil` enquanto a pessoa não tiver criado nenhuma equipe.
    private var equipeAtiva: EquipeDisponivel? {
        equipes.first { $0.id == equipeAtivaID } ?? equipes.first
    }

    private var responsaveisDaEquipeAtiva: [ResponsavelDaTarefa] {
        guard let equipeAtiva else { return [] }
        return MembrosDasEquipes.carregar(equipeID: equipeAtiva.id).map {
            ResponsavelDaTarefa(nome: $0.nome, email: $0.email)
        }
    }

    var body: some View {
        NavigationStack(path: $conversaAberta) {
            VStack(spacing: 0) {
                barraSuperior

                if let falhaDeAbertura {
                    Label(falhaDeAbertura, systemImage: "xmark.octagon.fill")
                        .font(.callout)
                        .foregroundStyle(PapagaioTema.perigo)
                        .padding(PapagaioTema.Espaco.largo)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(PapagaioTema.perigo.opacity(0.08))
                }

                conteudoDaTela
            }
            .background(PapagaioTema.fundo.ignoresSafeArea())
            // A seleção de texto **não** fica na raiz.
            //
            // `.textSelection(.enabled)` aqui vale para toda a árvore, e no
            // macOS cada `Text` selecionável monta a máquina de seleção do
            // AppKit. Numa grade de vinte cartões — cada um com título,
            // descrição, datas e nomes — e numa transcrição de milhares de
            // palavras, isso é o suficiente para a janela parar de responder.
            //
            // Ela vive onde a leitura acontece: no conteúdo da conversa, em
            // `ArquivoDetalheView`. Cartão da biblioteca não é texto para
            // copiar, é alvo de clique.
        .toolbarBackground(.hidden, for: .windowToolbar)
            .overlay(alignment: .top) {
                // Sem padding: a legenda se ancora na base do próprio ícone,
                // então a folga vive dentro de LegendaGlobalDaBarra.
                LegendaGlobalDaBarra(texto: legendaDaBarra)
            }
            .navigationDestination(for: UUID.self) { id in
                if let biblioteca, let arquivo = biblioteca.arquivo(id: id) {
                    let audio = biblioteca.audio(de: arquivo)
                    let audioSecundario = biblioteca.audioSecundario(de: arquivo)
                    let importado = biblioteca.importado(arquivo)
                    let estado = biblioteca.estado(de: arquivo)
                    let processando = biblioteca.estaProcessando(arquivo)
                    let naFila = biblioteca.estaNaFila(arquivo)

                    ArquivoDetalheView(
                        arquivo: arquivo,
                        audio: audio,
                        audioSecundario: audioSecundario,
                        importado: importado,
                        estado: estado,
                        processando: processando,
                        naFila: naFila,
                        responsaveisDisponiveis: responsaveisDaEquipeAtiva,
                        aoTranscrever: { biblioteca.enfileirarProcessamento(arquivo) },
                        aoAtualizarNotas: { notas in
                            await biblioteca.atualizarNotas(notas, de: arquivo)
                        },
                        aoNotificarTarefa: { titulo, mensagem in
                            notificacoes.registrar(titulo: titulo, mensagem: mensagem, tipo: .aviso)
                        },
                        aoAtualizarMetadados: { titulo, data, duracao in
                            Task { await biblioteca.atualizarMetadados(arquivo, titulo: titulo, criadoEm: data, duracao: duracao) }
                        },
                        aoAtualizarTranscricao: { trechos in
                            await biblioteca.atualizarTrechos(trechos, de: arquivo)
                        },
                        aoDitar: { url in try await biblioteca.transcreverDitado(url) },
                    )
                }
            }
        }
        // Piso de conforto, não de correção: quem garante que nada transborda é
        // a própria barra superior, que colapsa em estágios. Este mínimo só
        // evita abrir a janela num tamanho em que a grade de cartões fica com
        // uma coluna só. Note que `windowResizability(.contentMinSize)` não
        // propaga isto de forma confiável através do `NavigationStack` — por
        // isso nenhum layout depende deste número.
        // O selo fica **fora** do `NavigationStack`: dentro dele, abrir uma
        // conversa substituía a raiz e levava o selo junto — justamente quando
        // ele mais importa, que é longe da tela de captura.
        // Dentro de uma conversa o selo vai para o topo, centralizado: embaixo
        // ele disputa espaço com o player, e subir só um pouco o deixava
        // pairando no meio do caminho. Em cima há uma faixa livre entre o
        // voltar e o compartilhar, e ele não cobre nada.
        //
        // Nas outras telas fica no canto inferior direito, longe do conteúdo e
        // perto de onde a pessoa espera avisos do sistema.
        .overlay(alignment: seloNoTopo ? .top : .bottomTrailing) {
            seloDeGravacaoEmAndamento
        }
        .onPreferenceChange(AlturaDoPlayerKey.self) { altura in
            alturaDoPlayer = altura
        }
        .frame(minWidth: 460, minHeight: 520)
        // Atalhos globais da janela: ⌘R alterna a gravação e ⌘[ volta um
        // passo, de qualquer tela. São botões invisíveis de propósito —
        // existem só para o sistema rotear as teclas; as ações vivem nos
        // mesmos lugares de sempre (selo, barra superior).
        .background {
            Group {
                Button("") {
                    Task { await aoAlternarGravacao() }
                }
                .keyboardShortcut("r", modifiers: .command)

                Button("", action: voltar)
                    .keyboardShortcut("[", modifiers: .command)
            }
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        }
        // `nil` em "Sistema": sem esquema preferido a janela herda a aparência
        // do Mac. Nos outros dois casos isto fixa a aparência da janela, e as
        // cores dinâmicas do tema resolvem em cima dela.
        .preferredColorScheme(aparencia.wrappedValue.esquemaPreferido)
        .onReceive(NotificationCenter.default.publisher(for: .equipeCloudKitAceita)) { notificacao in
            guard let equipe = notificacao.object as? EquipeDisponivel else { return }
            equipes = EquipesDoUsuario.carregar()
            usarEquipe(equipe)
        }
        .task {
            notificacoes.preparar()
            perfil.iniciar()
            await abrir()
        }
        .onChange(of: processamentoAutomatico) { _, novoValor in
            biblioteca?.processamentoAutomatico = novoValor
        }
        .fileImporter(
            isPresented: $mostrandoImportador,
            // Sai da mesma lista do arraste: antes o painel aceitava menos
            // formatos que o drop, e o mesmo arquivo entrava por um caminho e
            // era recusado pelo outro.
            allowedContentTypes: Self.tiposDeAudio
        ) { resultado in
            guard case let .success(url) = resultado,
                  url.startAccessingSecurityScopedResource()
            else { return }
            Task {
                defer { url.stopAccessingSecurityScopedResource() }
                await modelo.importar(url)
            }
        }
        .sheet(isPresented: Binding(
            get: { arquivoParaConfigurar != nil },
            set: { if !$0 { arquivoParaConfigurar = nil } }
        )) {
            EditorDeInformacoesDoCard(
                modo: .nova,
                titulo: $ficha.titulo,
                entrevistado: $ficha.entrevistado,
                emailDoEntrevistado: $ficha.emailDoEntrevistado,
                entrevistadores: $ficha.entrevistadores,
                emailDosEntrevistadores: $ficha.emailDosEntrevistadores,
                descricao: $ficha.descricao,
                formato: $ficha.formato,
                participantes: $ficha.participantes,
                data: $ficha.data,
                duracao: $ficha.duracao,
                aoCancelar: { arquivoParaConfigurar = nil },
                aoSalvar: salvarFichaDaEntrevista
            )
        }
        .alert("Não foi possível entrar", isPresented: Binding(
            get: { perfil.erro != nil },
            set: { if !$0 { perfil.dispensarErro() } }
        )) {
            Button("OK", role: .cancel) { perfil.dispensarErro() }
        } message: {
            Text(perfil.erro ?? "")
        }
    }

    private var barraSuperior: some View {
        BarraSuperiorPapagaioView(
            consulta: $consulta, legendaAtiva: $legendaDaBarra,
            exibindoBotaoVoltar: !naTelaInicial,
            bibliotecaSelecionada: telaSelecionada == .biblioteca && secaoDaBiblioteca != .lixeira,
            tarefasSelecionada: telaSelecionada == .tarefas,
            configuracoesSelecionada: telaSelecionada == .configuracoes,
            lixeiraSelecionada: telaSelecionada == .biblioteca && secaoDaBiblioteca == .lixeira,
            perfilConectado: perfil.conectado, perfilVerificando: perfil.verificando,
            avatarURL: perfil.avatarURL, contextoDaConta: contextoDaConta, equipeAtiva: equipeAtiva,
            gravando: modelo.gravando && focoNaGravacao, processandoBiblioteca: biblioteca?.processando ?? false,
            quantidadeDeAvisos: notificacoes.naoLidas, notificacoes: notificacoes.itens,
            aoEntrar: perfil.entrar, aoSair: sairDoPerfil,
            aoMarcarNotificacoesComoLidas: notificacoes.marcarComoLidas, aoLimparNotificacoes: notificacoes.limpar,
            aoVoltar: voltar, aoAbrirBiblioteca: voltarParaBiblioteca, aoAbrirTarefas: abrirTarefas,
            aoAbrirConfiguracoes: { telaSelecionada = .configuracoes }, aoAbrirLixeira: abrirLixeira,
            aoUsarPerfil: selecionarPerfilPessoal, aoUsarEquipe: selecionarEquipe,
            aoGerenciarPerfil: abrirPerfil, aoGerenciarEquipe: abrirEquipe
        )
    }

    @ViewBuilder
    private var conteudoDaTela: some View {
        switch telaSelecionada {
        case .biblioteca:
            BibliotecaHomeView(gravador: modelo, biblioteca: biblioteca, modelos: modelos, consulta: $consulta,
                               secaoSelecionada: $secaoDaBiblioteca, pastaSelecionada: $pastaDaBibliotecaSelecionada,
                               mostrandoImportador: $mostrandoImportador, processamentoAutomatico: processamentoAutomatico,
                               aoAlternarGravacao: aoAlternarGravacao, aoPausarGravacao: aoPausarGravacao,
                               aoContinuarGravacao: aoContinuarGravacao, aoCancelarGravacao: aoCancelarGravacao,
                               aoEscolherPastaDeModelos: escolherPastaDeModelos, aoUsarPastaDoApp: usarPastaDoApp,
                               aoSoltarArquivos: importarArrastados, focoNaGravacao: $focoNaGravacao)
        case .tarefas:
            TarefasView(biblioteca: biblioteca, consulta: consulta)
        case .configuracoes:
            ConfiguracoesView(processamentoAutomatico: $processamentoAutomatico, aparencia: aparencia)
        case .perfil:
            PerfilPessoalView(perfil: perfil, equipeAtiva: equipeAtiva, equipes: equipes,
                               aoSelecionarEquipe: usarEquipe, aoAdicionarEquipe: adicionarEquipe,
                               aoSair: sairDoPerfil, aoExcluirConta: excluirConta)
        case .equipe:
            GestaoDeEquipeView(equipeAtiva: equipeAtiva, equipes: equipes,
                                aoSelecionarEquipe: usarEquipe,
                                aoAtualizarQuantidadeDeMembros: atualizarQuantidadeDeMembros)
        }
    }

    private func abrir() async {
        guard biblioteca == nil else { return }
        do {
            let nova = try Biblioteca()
            nova.processamentoAutomatico = processamentoAutomatico
            nova.aoNotificar = { titulo, mensagem, tipo in
                notificacoes.registrar(titulo: titulo, mensagem: mensagem, tipo: tipo)
            }
            nova.aoConcluirProcessamento = { arquivo in
                guard arquivosAguardandoFicha.contains(arquivo.id) else { return }
                arquivosAguardandoFicha.remove(arquivo.id)
                abrirFichaDaEntrevista(para: arquivo)
            }
            biblioteca = nova

            let gerenciador = ModelosViewModel(
                pastaDoContainer: nova.armazenamento.pastaDeModelos
            )
            gerenciador.verificar()
            nova.pastaDeModelos = gerenciador.pasta
            modelos = gerenciador

            // A gravação entrega o áudio; a biblioteca salva e processa. Esta
            // ligação permanece na raiz para não desaparecer ao redesenhar uma
            // subview de biblioteca.
            modelo.aoProduzirAudio = { titulo, pasta, duracao, notas in
                if let arquivo = await nova.registrar(
                    titulo: titulo,
                    pastaRelativa: pasta,
                    duracao: duracao,
                    notas: notas
                ) {
                    if let pastaDaBibliotecaSelecionada {
                        PreferenciasVisuaisDoArquivo.definirPasta(
                            pastaDaBibliotecaSelecionada,
                            para: arquivo.id
                        )
                    }
                    if nova.processamentoAutomatico {
                        arquivosAguardandoFicha.insert(arquivo.id)
                    } else {
                        abrirFichaDaEntrevista(para: arquivo)
                    }
                }
            }
            await nova.preparar()
            atualizarEspacoDaBiblioteca()
        } catch {
            falhaDeAbertura = "Não foi possível abrir a biblioteca: \(error)"
        }
    }

    private func abrirFichaDaEntrevista(para arquivo: Arquivo) {
        let metadados = PreferenciasVisuaisDoArquivo.metadados(arquivo.id)
        arquivoParaConfigurar = arquivo
        ficha = FichaDaEntrevista(
            titulo: arquivo.resumo?.titulo ?? arquivo.titulo,
            entrevistado: metadados.entrevistado,
            emailDoEntrevistado: metadados.emailDoEntrevistado,
            entrevistadores: metadados.entrevistadores,
            emailDosEntrevistadores: metadados.emailDosEntrevistadores,
            descricao: metadados.descricao,
            formato: metadados.formato,
            participantes: "\(max(1, metadados.participantes ?? 1))",
            data: arquivo.criadoEm,
            duracao: arquivo.duracao.comoDuracaoPorExtenso
        )
    }

    private func salvarFichaDaEntrevista() {
        guard let arquivo = arquivoParaConfigurar,
              let biblioteca
        else { return }

        let tituloLimpo = ficha.titulo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tituloLimpo.isEmpty else { return }

        // Participantes deixou de ser um campo digitável na ficha: sai da soma
        // dos nomes que a pessoa acabou de preencher. Ler do estado antigo
        // deixava sempre "1", independente de quantos nomes havia.
        let quantidade = max(
            1,
            nomesInformados(ficha.entrevistado) + nomesInformados(ficha.entrevistadores)
        )
        let metadados = MetadadosVisuaisDoArquivo(
            entrevistado: ficha.entrevistado.trimmingCharacters(in: .whitespacesAndNewlines),
            emailDoEntrevistado: ficha.emailDoEntrevistado.trimmingCharacters(in: .whitespacesAndNewlines),
            entrevistadores: ficha.entrevistadores.trimmingCharacters(in: .whitespacesAndNewlines),
            emailDosEntrevistadores: ficha.emailDosEntrevistadores.trimmingCharacters(in: .whitespacesAndNewlines),
            descricao: ficha.descricao.trimmingCharacters(in: .whitespacesAndNewlines),
            formato: ficha.formato.trimmingCharacters(in: .whitespacesAndNewlines),
            participantes: quantidade
        )
        PreferenciasVisuaisDoArquivo.definirMetadados(metadados, para: arquivo.id)

        // A duração não é editável na ficha: continua sendo a do próprio áudio.
        let duracao = arquivo.duracao
        Task {
            await biblioteca.atualizarMetadados(arquivo, titulo: tituloLimpo, criadoEm: ficha.data, duracao: duracao)
            await MainActor.run {
                arquivoParaConfigurar = nil
            }
        }
    }

    private func nomesInformados(_ texto: String) -> Int {
        texto
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .count
    }

    /// Importa arquivos soltos do Finder.
    ///
    /// Vindo do `.dropDestination`, a URL **não** é security-scoped como a do
    /// `.fileImporter`: o próprio arraste é a autorização do usuário, e chamar
    /// `startAccessingSecurityScopedResource` aqui devolveria `false` e
    /// abortaria a importação de um arquivo perfeitamente acessível.
    private func importarArrastados(_ urls: [URL]) {
        let audios = urls.filter { Self.extensoesDeAudio.contains($0.pathExtension.lowercased()) }
        guard !audios.isEmpty else { return }
        // Mesmo caminho do `.fileImporter`: quem importa é o gravador, que já
        // sabe avisar sobre canal único e devolver o arquivo para a biblioteca.
        Task {
            for url in audios {
                await modelo.importar(url)
            }
        }
    }

    /// As extensões aceitas na importação — única fonte de verdade, usada
    /// pelo `.fileImporter` (via `tiposDeAudio`) e pelo filtro do arraste.
    private static let extensoesDeAudio: Set<String> = [
        "m4a", "mp3", "wav", "aac", "aiff", "aif", "caf", "flac", "mp4", "mov",
    ]

    /// Os mesmos formatos do arraste, como `UTType`, para o painel de
    /// importação. Extensão sem tipo conhecido não entra no painel — o
    /// caminho do arraste continua cobrindo.
    private static var tiposDeAudio: [UTType] {
        extensoesDeAudio.sorted().compactMap { UTType(filenameExtension: $0) }
    }

    private func abrirLixeira() {
        telaSelecionada = .biblioteca
        secaoDaBiblioteca = .lixeira
    }

    private func abrirTarefas() {
        telaSelecionada = .tarefas
        secaoDaBiblioteca = .todos
    }

    private func abrirPerfil() {
        telaSelecionada = .perfil
        secaoDaBiblioteca = .todos
    }

    private func abrirEquipe() {
        telaSelecionada = .equipe
        secaoDaBiblioteca = .todos
    }

    private func selecionarPerfilPessoal() {
        contextoDaConta = .perfil
        atualizarEspacoDaBiblioteca()
    }

    /// Entra no contexto de equipe mesmo sem equipe alguma — é lá que mora o
    /// estado vazio que convida a criar a primeira.
    private func selecionarEquipe() {
        contextoDaConta = .equipe
        if let equipeAtiva {
            equipeAtivaID = equipeAtiva.id
            garantirEspacoParaEquipe(id: equipeAtiva.id)
            atualizarEspacoDaBiblioteca()
        }
    }

    private func usarEquipe(_ equipe: EquipeDisponivel) {
        contextoDaConta = .equipe
        equipeAtivaID = equipe.id
        garantirEspacoParaEquipe(id: equipe.id)
        atualizarEspacoDaBiblioteca()
    }

    private func adicionarEquipe(nome: String) {
        let nomeLimpo = nome.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nomeLimpo.isEmpty else { return }

        let base = nomeLimpo
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: " ", with: "-")

        let nova = EquipeDisponivel(
            id: "\(base)-\(UUID().uuidString.prefix(6))",
            nome: nomeLimpo,
            papel: "Administrador",
            quantidadeDeMembros: 1,
            espacoID: UUID().uuidString
        )
        Task { @MainActor in
            do {
                let publicada = try await servicoDeEquipesCloudKit.criarWorkspace(para: nova)
                equipes.append(publicada)
                EquipesDoUsuario.salvar(equipes)
                usarEquipe(publicada)
            } catch {
                falhaDeAbertura = "Não foi possível criar a equipe no iCloud: \(error.localizedDescription)"
            }
        }
    }

    private func atualizarQuantidadeDeMembros(equipeID: String, quantidade: Int) {
        guard let indice = equipes.firstIndex(where: { $0.id == equipeID }) else { return }
        equipes[indice].quantidadeDeMembros = quantidade
        EquipesDoUsuario.salvar(equipes)
    }

    private func garantirEspacoParaEquipe(id: String) {
        guard let indice = equipes.firstIndex(where: { $0.id == id }),
              UUID(uuidString: equipes[indice].espacoID ?? "") == nil
        else { return }
        equipes[indice].espacoID = UUID().uuidString
        EquipesDoUsuario.salvar(equipes)
    }

    private func atualizarEspacoDaBiblioteca() {
        guard let biblioteca else { return }
        let espaco: EspacoID
        let equipeParaSincronizar: EquipeDisponivel?
        if contextoDaConta == .equipe,
           let equipe = equipeAtiva,
           let texto = equipe.espacoID,
           let id = UUID(uuidString: texto) {
            espaco = EspacoID(rawValue: id)
            equipeParaSincronizar = equipe.zonaCloudKit == nil ? nil : equipe
        } else {
            espaco = Biblioteca.espacoPessoal()
            equipeParaSincronizar = nil
        }
        Task { await biblioteca.usarEspaco(espaco, equipeCloudKit: equipeParaSincronizar) }
    }

    private func sairDoPerfil() {
        perfil.sair()
        contextoDaConta = .perfil
        voltarParaBiblioteca()
    }

    /// Limpa apenas os dados que pertencem à conta local atual. Preferências
    /// do app e modelos baixados são preservados para que uma nova conta não
    /// precise reconfigurar a aparência nem baixar pesos novamente.
    private func excluirConta() async throws {
        if modelo.gravando {
            await modelo.cancelar()
        }

        try await biblioteca?.excluirDadosDaConta()

        // Todos os stores de dados da conta num caminho só — store novo se
        // registra lá, não aqui.
        LimpezaDeConta.executar()

        perfil.excluirDadosDaConta()
        notificacoes.limpar()
        equipes.removeAll()
        equipeAtivaID = ""
        contextoDaConta = .perfil
        consulta = ""
        conversaAberta.removeAll()
        pastaDaBibliotecaSelecionada = nil
        secaoDaBiblioteca = .todos
        focoNaGravacao = false
        telaSelecionada = .biblioteca
    }

    /// A raiz do app: biblioteca, em "Todas", sem conversa aberta e fora da
    /// captura. Em qualquer outro lugar o chevron aparece.
    private var naTelaInicial: Bool {
        conversaAberta.isEmpty
            && !focoNaGravacao
            && telaSelecionada == .biblioteca
            && secaoDaBiblioteca == .todos
    }

    /// Um passo por vez, e sempre em direção à tela inicial: fecha a conversa,
    /// sai da captura, volta para a biblioteca. Antes, de Equipe o botão ia
    /// para Perfil — hierarquia que fazia o mesmo botão significar coisas
    /// diferentes conforme a tela.
    private func voltar() {
        if !conversaAberta.isEmpty {
            conversaAberta.removeLast()
            return
        }
        if focoNaGravacao {
            withAnimation(.snappy(duration: 0.18)) { focoNaGravacao = false }
            return
        }
        voltarParaBiblioteca()
    }

    /// Selo que segue a pessoa por todas as telas enquanto a gravação continua
    /// rodando fora da tela de captura. Sem ele, sair da captura escondia a
    /// gravação inteira e o microfone seguia ligado sem sinal na janela.
    @ViewBuilder
    private var seloDeGravacaoEmAndamento: some View {
        if modelo.gravando && !focoNaGravacao {
            HStack(spacing: PapagaioTema.Espaco.curto) {
                // O corpo do selo continua sendo o atalho de volta: é o gesto
                // mais provável de quem vê "Gravando" em outra tela.
                Button {
                    voltarParaGravacao()
                } label: {
                    HStack(spacing: PapagaioTema.Espaco.curto) {
                        Circle()
                            .fill(modelo.pausado ? PapagaioTema.aviso : PapagaioTema.perigo)
                            .frame(width: 9, height: 9)

                        Text(modelo.pausado ? "Pausado" : "Gravando")
                            .font(.callout.weight(.semibold))

                        Text(modelo.tempoDeGravacao.comoCronometro)
                            .font(.system(.callout, design: .monospaced))
                            .monospacedDigit()
                    }
                    .foregroundStyle(PapagaioTema.texto)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Voltar para a gravação em andamento")

                Divider().frame(height: 18)

                // Pausar e cancelar sem precisar voltar: quem está no meio de
                // outra tarefa quer resolver ali, não navegar até a captura.
                BotaoDoSelo(
                    simbolo: modelo.pausado ? "play.fill" : "pause.fill",
                    ajuda: modelo.pausado ? "Continuar gravação" : "Pausar gravação"
                ) {
                    Task {
                        if modelo.pausado {
                            await aoContinuarGravacao()
                        } else {
                            await aoPausarGravacao()
                        }
                    }
                }

                BotaoDoSelo(simbolo: "stop.fill", ajuda: "Finalizar gravação") {
                    Task { await aoAlternarGravacao() }
                }

                BotaoDoSelo(simbolo: "xmark", ajuda: "Cancelar gravação", perigo: true) {
                    confirmandoCancelamentoDaGravacao = true
                }
            }
            .padding(.horizontal, PapagaioTema.Espaco.largo)
            .frame(height: PapagaioTema.Altura.padrao)
            .background(PapagaioTema.superficie, in: Capsule())
            .overlay { Capsule().stroke(PapagaioTema.borda, lineWidth: 1) }
            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
            .padding(PapagaioTema.Espaco.secao)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
            .confirmationDialog(
                "Cancelar a gravação?",
                isPresented: $confirmandoCancelamentoDaGravacao,
                titleVisibility: .visible
            ) {
                Button("Cancelar gravação", role: .destructive) {
                    Task { await aoCancelarGravacao() }
                }
                Button("Continuar gravando", role: .cancel) {}
            } message: {
                Text("O áudio capturado até agora é descartado.")
            }
        }
    }

    /// Traz a pessoa de volta à tela de captura, de onde quer que ela esteja.
    private func voltarParaGravacao() {
        conversaAberta.removeAll()
        telaSelecionada = .biblioteca
        secaoDaBiblioteca = .todos
        withAnimation(.snappy(duration: 0.18)) { focoNaGravacao = true }
    }

    /// Finalizar a partir do selo: encerra a captura e desliga o foco, para a
    /// pessoa cair na biblioteca já com a conversa nova entrando na fila.
    private func aoAlternarGravacao() async {
        await modelo.alternarGravacao()
        withAnimation(.snappy(duration: 0.18)) {
            focoNaGravacao = modelo.gravando
        }
    }

    private func aoPausarGravacao() async { await modelo.pausar() }
    private func aoContinuarGravacao() async { await modelo.continuar() }

    private func aoCancelarGravacao() async {
        await modelo.cancelar()
        focoNaGravacao = false
    }

    private func voltarParaBiblioteca() {
        telaSelecionada = .biblioteca
        secaoDaBiblioteca = .todos
    }

    /// Toda mudança de origem dos pesos passa por aqui. Antes, voltar para a
    /// pasta do app deixava a `Biblioteca` apontando para a pasta externa.
    private func escolherPastaDeModelos(_ url: URL) {
        modelos?.escolher(url)
        sincronizarPastaDeModelos()
    }

    private func usarPastaDoApp() {
        modelos?.usarOContainer()
        sincronizarPastaDeModelos()
    }

    private func sincronizarPastaDeModelos() {
        guard let modelos else { return }
        biblioteca?.pastaDeModelos = modelos.pasta
    }
}

#Preview {
    ContentView(gravador: GravadorViewModel())
}
