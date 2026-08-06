import AppKit
import PapagaioCore
import SwiftUI
import UniformTypeIdentifiers

/// Coordenador da interface inicial.
///
/// Mantém a identidade dos view models e as integrações de sistema (navegação,
/// importação e Sign in with Apple). A composição visual vive em componentes
/// menores para que o redesign não altere o ciclo de vida do áudio.
struct ContentView: View {
    @State private var modelo = GravadorViewModel()
    @State private var biblioteca: Biblioteca?
    @State private var modelos: ModelosViewModel?
    @State private var perfil = PerfilViewModel()
    @State private var notificacoes = NotificacoesViewModel()
    @State private var equipes = EquipesDoUsuario.carregar()
    @State private var falhaDeAbertura: String?
    @State private var mostrandoImportador = false
    @State private var arquivoParaConfigurar: Arquivo?
    @State private var arquivosAguardandoFicha: Set<ArquivoID> = []
    @State private var tituloDaFicha = ""
    @State private var entrevistadoDaFicha = ""
    @State private var emailDoEntrevistadoDaFicha = ""
    @State private var entrevistadoresDaFicha = ""
    @State private var emailDosEntrevistadoresDaFicha = ""
    @State private var descricaoDaFicha = ""
    @State private var formatoDaFicha = ""
    @State private var participantesDaFicha = "1"
    @State private var dataDaFicha = Date()
    @State private var duracaoDaFicha = ""
    @State private var consulta = ""
    @State private var legendaDaBarra: LegendaDaBarra?
    @State private var secaoDaBiblioteca: SecaoDaBiblioteca = .todos
    @State private var telaSelecionada: TelaPrincipal = .biblioteca
    @State private var pastaDaBibliotecaSelecionada: String?
    @AppStorage("processamentoAutomatico") private var processamentoAutomatico = true
    @AppStorage("contextoDaConta") private var contextoDaContaRaw = ContextoDaConta.perfil.rawValue
    @AppStorage("equipeAtiva") private var equipeAtivaID = EquipeDisponivel.padrao.id

    private var contextoDaConta: ContextoDaConta {
        get { ContextoDaConta(rawValue: contextoDaContaRaw) ?? .perfil }
        nonmutating set { contextoDaContaRaw = newValue.rawValue }
    }

    private var equipeAtiva: EquipeDisponivel {
        equipes.first { $0.id == equipeAtivaID } ?? equipes.first ?? .padrao
    }

    private var responsaveisDaEquipeAtiva: [ResponsavelDaTarefa] {
        MembrosDasEquipes.carregar(equipeID: equipeAtiva.id).map {
            ResponsavelDaTarefa(nome: $0.nome, email: $0.email)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                BarraSuperiorPapagaioView(
                    consulta: $consulta,
                    legendaAtiva: $legendaDaBarra,
                    exibindoBotaoVoltar: telaSelecionada != .biblioteca || secaoDaBiblioteca == .lixeira,
                    bibliotecaSelecionada: telaSelecionada == .biblioteca && secaoDaBiblioteca != .lixeira,
                    tarefasSelecionada: telaSelecionada == .tarefas,
                    configuracoesSelecionada: telaSelecionada == .configuracoes,
                    lixeiraSelecionada: telaSelecionada == .biblioteca && secaoDaBiblioteca == .lixeira,
                    perfilConectado: perfil.conectado,
                    perfilVerificando: perfil.verificando,
                    avatarURL: perfil.avatarURL,
                    contextoDaConta: contextoDaConta,
                    equipeAtiva: equipeAtiva,
                    gravando: modelo.gravando,
                    processandoBiblioteca: biblioteca?.processando ?? false,
                    quantidadeDeAvisos: notificacoes.naoLidas,
                    notificacoes: notificacoes.itens,
                    aoEntrar: perfil.entrar,
                    aoSair: sairDoPerfil,
                    aoMarcarNotificacoesComoLidas: notificacoes.marcarComoLidas,
                    aoLimparNotificacoes: notificacoes.limpar,
                    aoVoltar: voltar,
                    aoAbrirBiblioteca: voltarParaBiblioteca,
                    aoAbrirTarefas: abrirTarefas,
                    aoAbrirConfiguracoes: { telaSelecionada = .configuracoes },
                    aoAbrirLixeira: abrirLixeira,
                    aoUsarPerfil: selecionarPerfilPessoal,
                    aoUsarEquipe: selecionarEquipe,
                    aoGerenciarPerfil: abrirPerfil,
                    aoGerenciarEquipe: abrirEquipe
                )

                if let falhaDeAbertura {
                    Label(falhaDeAbertura, systemImage: "xmark.octagon.fill")
                        .font(.callout)
                        .foregroundStyle(PapagaioTema.perigo)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(PapagaioTema.perigo.opacity(0.08))
                }

                switch telaSelecionada {
                case .biblioteca:
                    BibliotecaHomeView(
                        gravador: modelo,
                        biblioteca: biblioteca,
                        modelos: modelos,
                        consulta: $consulta,
                        secaoSelecionada: $secaoDaBiblioteca,
                        pastaSelecionada: $pastaDaBibliotecaSelecionada,
                        mostrandoImportador: $mostrandoImportador,
                        processamentoAutomatico: processamentoAutomatico,
                        aoAlternarGravacao: { await modelo.alternarGravacao() },
                        aoPausarGravacao: { await modelo.pausar() },
                        aoContinuarGravacao: { await modelo.continuar() },
                        aoCancelarGravacao: { await modelo.cancelar() },
                        aoEscolherPastaDeModelos: escolherPastaDeModelos,
                        aoUsarPastaDoApp: usarPastaDoApp
                    )
                case .tarefas:
                    TarefasView(
                        biblioteca: biblioteca,
                        consulta: consulta
                    )
                case .configuracoes:
                    ConfiguracoesView(
                        processamentoAutomatico: $processamentoAutomatico
                    )
                case .perfil:
                    PerfilPessoalView(
                        perfil: perfil,
                        equipeAtiva: equipeAtiva,
                        equipes: equipes,
                        aoSelecionarEquipe: usarEquipe,
                        aoAdicionarEquipe: adicionarEquipe,
                        aoSair: sairDoPerfil
                    )
                case .equipe:
                    GestaoDeEquipeView(
                        equipeAtiva: equipeAtiva,
                        equipes: equipes,
                        aoSelecionarEquipe: usarEquipe,
                        aoAtualizarQuantidadeDeMembros: atualizarQuantidadeDeMembros
                    )
                }
            }
            .frame(minWidth: 390, minHeight: 520)
            .background(PapagaioTema.fundo)
            .overlay(alignment: .top) {
                LegendaGlobalDaBarra(texto: legendaDaBarra)
                    .padding(.top, 8)
            }
            .navigationDestination(for: UUID.self) { id in
                if let biblioteca, let arquivo = biblioteca.arquivo(id: id) {
                    ArquivoDetalheView(
                        arquivo: arquivo,
                        audio: biblioteca.audio(de: arquivo),
                        audioSecundario: biblioteca.audioSecundario(de: arquivo),
                        estado: biblioteca.estado(de: arquivo),
                        processando: biblioteca.estaProcessando(arquivo),
                        naFila: biblioteca.estaNaFila(arquivo),
                        responsaveisDisponiveis: responsaveisDaEquipeAtiva,
                        aoTranscrever: { biblioteca.enfileirarProcessamento(arquivo) },
                        aoAtualizarNotas: { notas in
                            await biblioteca.atualizarNotas(notas, de: arquivo)
                        },
                        aoNotificarTarefa: { titulo, mensagem in
                            notificacoes.registrar(titulo: titulo, mensagem: mensagem, tipo: .aviso)
                        }
                    )
                }
            }
        }
        .preferredColorScheme(.light)
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
            allowedContentTypes: [.audio, .mpeg4Audio, .mp3, .wav]
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
                titulo: $tituloDaFicha,
                entrevistado: $entrevistadoDaFicha,
                emailDoEntrevistado: $emailDoEntrevistadoDaFicha,
                entrevistadores: $entrevistadoresDaFicha,
                emailDosEntrevistadores: $emailDosEntrevistadoresDaFicha,
                descricao: $descricaoDaFicha,
                formato: $formatoDaFicha,
                participantes: $participantesDaFicha,
                data: $dataDaFicha,
                duracao: $duracaoDaFicha,
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
        } catch {
            falhaDeAbertura = "Não foi possível abrir a biblioteca: \(error)"
        }
    }

    private func abrirFichaDaEntrevista(para arquivo: Arquivo) {
        let metadados = PreferenciasVisuaisDoArquivo.metadados(arquivo.id)
        arquivoParaConfigurar = arquivo
        tituloDaFicha = arquivo.resumo?.titulo ?? arquivo.titulo
        entrevistadoDaFicha = metadados.entrevistado
        emailDoEntrevistadoDaFicha = metadados.emailDoEntrevistado
        entrevistadoresDaFicha = metadados.entrevistadores
        emailDosEntrevistadoresDaFicha = metadados.emailDosEntrevistadores
        descricaoDaFicha = metadados.descricao
        formatoDaFicha = metadados.formato
        participantesDaFicha = "\(max(1, metadados.participantes ?? 1))"
        dataDaFicha = arquivo.criadoEm
        duracaoDaFicha = tempoDaFicha(arquivo.duracao)
    }

    private func salvarFichaDaEntrevista() {
        guard let arquivo = arquivoParaConfigurar,
              let biblioteca
        else { return }

        let tituloLimpo = tituloDaFicha.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tituloLimpo.isEmpty else { return }

        let quantidade = Int(participantesDaFicha.trimmingCharacters(in: .whitespacesAndNewlines)).map { max(1, $0) }
        let metadados = MetadadosVisuaisDoArquivo(
            entrevistado: entrevistadoDaFicha.trimmingCharacters(in: .whitespacesAndNewlines),
            emailDoEntrevistado: emailDoEntrevistadoDaFicha.trimmingCharacters(in: .whitespacesAndNewlines),
            entrevistadores: entrevistadoresDaFicha.trimmingCharacters(in: .whitespacesAndNewlines),
            emailDosEntrevistadores: emailDosEntrevistadoresDaFicha.trimmingCharacters(in: .whitespacesAndNewlines),
            descricao: descricaoDaFicha.trimmingCharacters(in: .whitespacesAndNewlines),
            formato: formatoDaFicha.trimmingCharacters(in: .whitespacesAndNewlines),
            participantes: quantidade
        )
        PreferenciasVisuaisDoArquivo.definirMetadados(metadados, para: arquivo.id)

        let duracao = segundosDaFicha(duracaoDaFicha) ?? arquivo.duracao
        Task {
            await biblioteca.atualizarMetadados(arquivo, titulo: tituloLimpo, criadoEm: dataDaFicha, duracao: duracao)
            await MainActor.run {
                arquivoParaConfigurar = nil
            }
        }
    }

    private func tempoDaFicha(_ segundos: TimeInterval) -> String {
        let total = Int(max(0, segundos).rounded())
        let horas = total / 3600
        let minutos = (total % 3600) / 60
        let segundosRestantes = total % 60
        if horas > 0 { return minutos > 0 ? "\(horas) h \(minutos) min" : "\(horas) h" }
        if minutos > 0 { return segundosRestantes > 0 ? "\(minutos) min \(segundosRestantes) s" : "\(minutos) min" }
        return "\(segundosRestantes) segundos"
    }

    private func segundosDaFicha(_ texto: String) -> TimeInterval? {
        let limpo = texto
            .lowercased()
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpo.isEmpty else { return nil }

        let padroes: [(String, Double)] = [
            (#"([0-9]+(?:\.[0-9]+)?)\s*h"#, 3600),
            (#"([0-9]+(?:\.[0-9]+)?)\s*(?:min|m)"#, 60),
            (#"([0-9]+(?:\.[0-9]+)?)\s*(?:seg|s)"#, 1)
        ]

        var total: Double = 0
        for (padrao, multiplicador) in padroes {
            guard let regex = try? NSRegularExpression(pattern: padrao) else { continue }
            let intervalo = NSRange(limpo.startIndex..<limpo.endIndex, in: limpo)
            regex.enumerateMatches(in: limpo, range: intervalo) { match, _, _ in
                guard let match,
                      let range = Range(match.range(at: 1), in: limpo),
                      let valor = Double(limpo[range])
                else { return }
                total += valor * multiplicador
            }
        }

        if total > 0 { return total }
        return Double(limpo).map { $0 * 60 }
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
    }

    private func selecionarEquipe() {
        usarEquipe(equipeAtiva)
    }

    private func usarEquipe(_ equipe: EquipeDisponivel) {
        contextoDaConta = .equipe
        equipeAtivaID = equipe.id
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
            quantidadeDeMembros: 1
        )
        equipes.append(nova)
        EquipesDoUsuario.salvar(equipes)
        usarEquipe(nova)
    }

    private func atualizarQuantidadeDeMembros(equipeID: String, quantidade: Int) {
        guard let indice = equipes.firstIndex(where: { $0.id == equipeID }) else { return }
        equipes[indice].quantidadeDeMembros = quantidade
        EquipesDoUsuario.salvar(equipes)
    }

    private func sairDoPerfil() {
        perfil.sair()
        contextoDaConta = .perfil
        voltarParaBiblioteca()
    }

    private func voltar() {
        if telaSelecionada == .equipe {
            abrirPerfil()
        } else {
            voltarParaBiblioteca()
        }
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

private struct LegendaGlobalDaBarra: View {
    let texto: LegendaDaBarra?

    var body: some View {
        GeometryReader { geometria in
            Group {
                if let texto {
                    Text(texto.texto)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(PapagaioTema.texto)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: true)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(PapagaioTema.superficie, in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(PapagaioTema.borda.opacity(0.92), lineWidth: 1)
                        }
                        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
                        .position(x: posicaoLimitada(texto.x, largura: geometria.size.width), y: 14)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .animation(.easeOut(duration: 0.12), value: texto)
        .allowsHitTesting(false)
        .zIndex(100)
    }

    private func posicaoLimitada(_ x: CGFloat, largura: CGFloat) -> CGFloat {
        min(max(x, 80), max(80, largura - 80))
    }
}

struct LegendaDaBarra: Equatable {
    let texto: String
    let x: CGFloat
}

private enum TelaPrincipal {
    case biblioteca
    case tarefas
    case configuracoes
    case perfil
    case equipe
}

enum ContextoDaConta: String {
    case perfil
    case equipe

    var titulo: String {
        switch self {
        case .perfil: "Perfil pessoal"
        case .equipe: "Creative Flow Studio"
        }
    }

    var subtitulo: String {
        switch self {
        case .perfil: "Conta pessoal"
        case .equipe: "Equipe selecionada"
        }
    }

    var simbolo: String {
        switch self {
        case .perfil: "person.crop.circle"
        case .equipe: "person.3"
        }
    }
}

struct EquipeDisponivel: Identifiable, Hashable, Codable {
    let id: String
    let nome: String
    let papel: String
    var quantidadeDeMembros: Int

    static let padrao = EquipeDisponivel(
        id: "creative-flow",
        nome: "Creative Flow Studio",
        papel: "Administrador",
        quantidadeDeMembros: 5
    )

    static let todas: [EquipeDisponivel] = [
        .padrao,
        EquipeDisponivel(
            id: "scribeflow",
            nome: "ScribeFlow Research",
            papel: "Transcritor",
            quantidadeDeMembros: 3
        ),
        EquipeDisponivel(
            id: "design-lab",
            nome: "Design Lab",
            papel: "Designer",
            quantidadeDeMembros: 2
        )
    ]
}

private enum EquipesDoUsuario {
    private static let chave = "equipesDoUsuario"

    static func carregar() -> [EquipeDisponivel] {
        guard let dados = UserDefaults.standard.data(forKey: chave),
              let equipes = try? JSONDecoder().decode([EquipeDisponivel].self, from: dados),
              !equipes.isEmpty
        else { return EquipeDisponivel.todas }
        return equipes
    }

    static func salvar(_ equipes: [EquipeDisponivel]) {
        guard let dados = try? JSONEncoder().encode(equipes) else { return }
        UserDefaults.standard.set(dados, forKey: chave)
    }
}

private struct PerfilPessoalView: View {
    @Bindable var perfil: PerfilViewModel
    let equipeAtiva: EquipeDisponivel
    let equipes: [EquipeDisponivel]
    let aoSelecionarEquipe: (EquipeDisponivel) -> Void
    let aoAdicionarEquipe: (String) -> Void
    let aoSair: () -> Void
    @State private var nome: String = ""
    @State private var email: String = ""
    @State private var mostrandoAvisoDeSenha = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 34) {
                Text("Meu Perfil")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(PapagaioTema.texto)

                CartaoDeIdentidadeDoPerfil(
                    nome: nome,
                    email: email,
                    avatarURL: perfil.avatarURL,
                    aoEditarAvatar: escolherAvatar
                )

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 28) {
                        InformacoesPessoaisDoPerfil(
                            nome: $nome,
                            email: $email,
                            aoSalvar: salvarDados
                        )
                        .frame(maxWidth: .infinity)

                        EquipesDoPerfil(
                            equipeAtiva: equipeAtiva,
                            equipes: equipes,
                            aoSelecionar: aoSelecionarEquipe,
                            aoAdicionarEquipe: aoAdicionarEquipe
                        )
                        .frame(width: 330)
                    }

                    VStack(alignment: .leading, spacing: 22) {
                        InformacoesPessoaisDoPerfil(
                            nome: $nome,
                            email: $email,
                            aoSalvar: salvarDados
                        )

                        EquipesDoPerfil(
                            equipeAtiva: equipeAtiva,
                            equipes: equipes,
                            aoSelecionar: aoSelecionarEquipe,
                            aoAdicionarEquipe: aoAdicionarEquipe
                        )
                    }
                }

                SegurancaDoPerfil(
                    aoAlterarSenha: { mostrandoAvisoDeSenha = true },
                    aoSair: aoSair
                )
                .frame(maxWidth: 690)
            }
            .larguraDeConteudoPapagaio()
            .padding(.horizontal, PapagaioTema.espacamentoDePagina)
            .padding(.vertical, PapagaioTema.espacamentoDePagina)
        }
        .background(PapagaioTema.fundo)
        .onAppear {
            nome = perfil.nome
            email = perfil.email
        }
        .alert("Login com Apple", isPresented: $mostrandoAvisoDeSenha) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("A senha é gerenciada pelo seu ID Apple. Para alterar, use os ajustes da sua conta Apple.")
        }
    }

    private func salvarDados() {
        perfil.salvarDados(nome: nome, email: email)
        nome = perfil.nome
        email = perfil.email
    }

    private func escolherAvatar() {
        let painel = NSOpenPanel()
        painel.allowedContentTypes = [.image]
        painel.allowsMultipleSelection = false
        painel.canChooseDirectories = false
        painel.canChooseFiles = true
        painel.title = "Escolher foto do perfil"
        if painel.runModal() == .OK, let url = painel.url {
            perfil.escolherAvatar(url)
        }
    }
}

private struct CartaoDeIdentidadeDoPerfil: View {
    let nome: String
    let email: String
    let avatarURL: URL?
    let aoEditarAvatar: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 42) {
                conteudo
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 20) {
                conteudo
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 26)
        .frame(maxWidth: 990, minHeight: 220, alignment: .leading)
        .cartaoPapagaio()
    }

    private var conteudo: some View {
        Group {
            ZStack(alignment: .bottomTrailing) {
                AvatarDoPerfil(url: avatarURL, tamanho: 132)

                Button(action: aoEditarAvatar) {
                    Image(systemName: "pencil")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(PapagaioTema.destaqueEscuro, in: Circle())
                        .shadow(color: .black.opacity(0.16), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .help("Trocar foto do perfil")
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(nome.isEmpty ? "Meu Perfil" : nome)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(PapagaioTema.texto)

                Text(email.isEmpty ? "email@exemplo.com" : email)
                    .font(.title3)
                    .foregroundStyle(PapagaioTema.textoSecundario)
                    .lineLimit(2)
            }
        }
    }
}

private struct InformacoesPessoaisDoPerfil: View {
    @Binding var nome: String
    @Binding var email: String
    let aoSalvar: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            TituloDeSecaoDoPerfil(simbolo: "person", titulo: "Informações Pessoais")

            SeparadorPapagaio()

            CampoDoPerfil(titulo: "Nome Completo", texto: $nome, placeholder: "Seu nome")
            CampoDoPerfil(titulo: "Email Primário", texto: $email, placeholder: "seu@email.com")

            Button("Salvar alterações", systemImage: "checkmark") {
                aoSalvar()
            }
            .buttonStyle(BotaoDeContornoPapagaio())
        }
        .padding(28)
        .cartaoPapagaio()
    }
}

private struct EquipesDoPerfil: View {
    let equipeAtiva: EquipeDisponivel
    let equipes: [EquipeDisponivel]
    let aoSelecionar: (EquipeDisponivel) -> Void
    let aoAdicionarEquipe: (String) -> Void
    @State private var mostrandoNovaEquipe = false
    @State private var nomeDaNovaEquipe = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Equipes")
                    .font(.title3)
                    .foregroundStyle(PapagaioTema.texto)

                Spacer()

                Button {
                    mostrandoNovaEquipe = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .foregroundStyle(PapagaioTema.destaqueEscuro)
                .background(PapagaioTema.destaqueSuave, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .help("Adicionar nova equipe")
            }

            SeparadorPapagaio()

            VStack(alignment: .leading, spacing: 10) {
                ForEach(equipes) { equipe in
                    Button {
                        aoSelecionar(equipe)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: equipe.id == equipeAtiva.id ? "checkmark.circle.fill" : "person.3")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(equipe.id == equipeAtiva.id ? PapagaioTema.destaqueEscuro : PapagaioTema.textoSecundario)
                                .frame(width: 28, height: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(equipe.nome)
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(PapagaioTema.texto)
                                    .lineLimit(1)

                                Text("\(equipe.papel) • \(equipe.quantidadeDeMembros) membros")
                                    .font(.caption)
                                    .foregroundStyle(PapagaioTema.textoSecundario)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 0)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(10)
                    .background(
                        equipe.id == equipeAtiva.id ? PapagaioTema.destaqueSuave.opacity(0.58) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                }
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, minHeight: 226, alignment: .topLeading)
        .cartaoPapagaio()
        .alert("Nova equipe", isPresented: $mostrandoNovaEquipe) {
            TextField("Nome da equipe", text: $nomeDaNovaEquipe)
            Button("Cancelar", role: .cancel) {
                nomeDaNovaEquipe = ""
            }
            Button("Adicionar") {
                adicionarEquipe()
            }
            .disabled(nomeDaNovaEquipe.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Crie uma equipe para vincular ao seu perfil.")
        }
    }

    private func adicionarEquipe() {
        let nome = nomeDaNovaEquipe.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nome.isEmpty else { return }
        aoAdicionarEquipe(nome)
        nomeDaNovaEquipe = ""
    }
}

private struct SegurancaDoPerfil: View {
    let aoAlterarSenha: () -> Void
    let aoSair: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            TituloDeSecaoDoPerfil(simbolo: "shield", titulo: "Segurança")

            SeparadorPapagaio()

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center) {
                    conteudo
                }

                VStack(alignment: .leading, spacing: 16) {
                    conteudo
                }
            }
        }
        .padding(28)
        .cartaoPapagaio()
    }

    private var conteudo: some View {
        Group {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Senha")
                        .font(.headline)
                        .foregroundStyle(PapagaioTema.texto)
                    Text("Gerenciada pelo ID Apple")
                        .font(.callout)
                        .foregroundStyle(PapagaioTema.textoSecundario)
                }

                Spacer()

                Button("Alterar Senha", action: aoAlterarSenha)
                    .buttonStyle(BotaoDeContornoPapagaio())

                Button("Sair", role: .destructive, action: aoSair)
                    .buttonStyle(BotaoDeContornoPapagaio())
        }
    }
}

private struct TituloDeSecaoDoPerfil: View {
    let simbolo: String
    let titulo: String

    var body: some View {
        Label(titulo, systemImage: simbolo)
            .font(.title3)
            .foregroundStyle(PapagaioTema.texto)
            .labelStyle(.titleAndIcon)
    }
}

private struct CampoDoPerfil: View {
    let titulo: String
    @Binding var texto: String
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titulo)
                .font(.callout.weight(.semibold))
                .foregroundStyle(PapagaioTema.textoSecundario)

            TextField(placeholder, text: $texto)
                .textFieldStyle(.plain)
                .font(.title3)
                .foregroundStyle(PapagaioTema.texto)
                .padding(.horizontal, 18)
                .frame(height: 48)
                .background(PapagaioTema.fundo, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(PapagaioTema.borda, lineWidth: 1)
                }
        }
    }
}

private struct AvatarDoPerfil: View {
    let url: URL?
    let tamanho: CGFloat

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
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(PapagaioTema.textoSecundario.opacity(0.35))
                    .padding(8)
            }
        }
        .frame(width: tamanho, height: tamanho)
        .clipShape(Circle())
        .overlay { Circle().stroke(PapagaioTema.superficie, lineWidth: 5) }
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
    }
}

private enum StatusDaEquipe: String, CaseIterable, Identifiable, Codable {
    case ativo = "Ativo"
    case offline = "Offline"
    case ocupado = "Ocupado"

    var id: Self { self }
    var cor: Color {
        switch self {
        case .ativo: Color(red: 0.109, green: 0.745, blue: 0.369)
        case .offline: PapagaioTema.textoSecundario.opacity(0.55)
        case .ocupado: PapagaioTema.perigo
        }
    }
}

private struct MembroDaEquipe: Identifiable, Equatable, Codable {
    var id = UUID()
    var nome: String
    var email: String
    var cargo: String
    var status: StatusDaEquipe
    var atual: Bool = false

    var iniciais: String {
        let partes = nome.split(separator: " ")
        let letras = partes.prefix(2).compactMap(\.first)
        return letras.isEmpty ? "M" : String(letras).uppercased()
    }
}

private enum MembrosDasEquipes {
    private static func chave(_ equipeID: String) -> String {
        "membrosDaEquipe.\(equipeID)"
    }

    static func carregar(equipeID: String) -> [MembroDaEquipe] {
        if let dados = UserDefaults.standard.data(forKey: chave(equipeID)),
           let membros = try? JSONDecoder().decode([MembroDaEquipe].self, from: dados) {
            return membros
        }

        let membros = membrosPadrao(equipeID: equipeID)
        salvar(membros, equipeID: equipeID)
        return membros
    }

    static func salvar(_ membros: [MembroDaEquipe], equipeID: String) {
        guard let dados = try? JSONEncoder().encode(membros) else { return }
        UserDefaults.standard.set(dados, forKey: chave(equipeID))
    }

    private static func membrosPadrao(equipeID: String) -> [MembroDaEquipe] {
        switch equipeID {
        case "creative-flow":
            [
                MembroDaEquipe(nome: "Ricardo Silva", email: "ricardo.silva@scribeflow.io", cargo: "Administrador", status: .ativo, atual: true),
                MembroDaEquipe(nome: "Beatriz Martins", email: "beatriz.m@scribeflow.io", cargo: "Transcritor", status: .ativo),
                MembroDaEquipe(nome: "Lucas Oliveira", email: "lucas.oliveira@design.com", cargo: "Designer", status: .ocupado),
                MembroDaEquipe(nome: "Fernanda Costa", email: "f.costa@scribeflow.io", cargo: "Transcritor", status: .offline),
                MembroDaEquipe(nome: "João Silva", email: "joao.silva@scribeflow.io", cargo: "Pesquisador", status: .ocupado)
            ]
        case "scribeflow":
            [
                MembroDaEquipe(nome: "Ricardo Silva", email: "ricardo.silva@scribeflow.io", cargo: "Administrador", status: .ativo, atual: true),
                MembroDaEquipe(nome: "Camila Rocha", email: "camila@scribeflow.io", cargo: "Revisora", status: .offline),
                MembroDaEquipe(nome: "Pedro Lima", email: "pedro@scribeflow.io", cargo: "Transcritor", status: .ativo)
            ]
        case "design-lab":
            [
                MembroDaEquipe(nome: "Ricardo Silva", email: "ricardo.silva@design.com", cargo: "Administrador", status: .ativo, atual: true),
                MembroDaEquipe(nome: "Ana Costa", email: "ana@design.com", cargo: "Designer", status: .ativo)
            ]
        default:
            [
                MembroDaEquipe(nome: "Ricardo Silva", email: "ricardo.silva@scribeflow.io", cargo: "Administrador", status: .ativo, atual: true)
            ]
        }
    }
}

private struct GestaoDeEquipeView: View {
    let equipeAtiva: EquipeDisponivel
    let equipes: [EquipeDisponivel]
    let aoSelecionarEquipe: (EquipeDisponivel) -> Void
    let aoAtualizarQuantidadeDeMembros: (String, Int) -> Void
    @State private var membros: [MembroDaEquipe] = []
    @State private var pagina = 0
    @State private var membroEditando: MembroDaEquipe?
    @State private var mostrandoAdicionar = false
    @State private var mostrandoTrocarEquipe = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 36) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .bottom, spacing: 16) {
                        cabecalho
                    }

                    VStack(alignment: .leading, spacing: 18) {
                        cabecalho
                    }
                }

                TabelaDaEquipe(
                    membros: membros,
                    pagina: pagina,
                    aoEditar: { membroEditando = $0 },
                    aoRemover: remover,
                    aoAlternarPagina: alternarPagina
                )
            }
            .larguraDeConteudoPapagaio()
            .padding(.horizontal, PapagaioTema.espacamentoDePagina)
            .padding(.vertical, PapagaioTema.espacamentoDePagina)
        }
        .background(PapagaioTema.fundo)
        .onAppear {
            carregarMembrosDaEquipe()
        }
        .onChange(of: equipeAtiva.id) { _, _ in
            carregarMembrosDaEquipe()
        }
        .sheet(isPresented: $mostrandoAdicionar) {
            EditorDeMembroDaEquipe(
                titulo: "Adicionar membro",
                membro: MembroDaEquipe(nome: "", email: "", cargo: "Transcritor", status: .ativo),
                aoCancelar: { mostrandoAdicionar = false },
                aoSalvar: { novo in
                    membros.append(novo)
                    salvarMembrosDaEquipe()
                    mostrandoAdicionar = false
                }
            )
        }
        .sheet(item: $membroEditando) { membro in
            EditorDeMembroDaEquipe(
                titulo: "Editar membro",
                membro: membro,
                aoCancelar: { membroEditando = nil },
                aoSalvar: { editado in
                    if let indice = membros.firstIndex(where: { $0.id == editado.id }) {
                        membros[indice] = editado
                        salvarMembrosDaEquipe()
                    }
                    membroEditando = nil
                }
            )
        }
        .sheet(isPresented: $mostrandoTrocarEquipe) {
            SeletorDeEquipeView(
                equipeAtiva: equipeAtiva,
                equipes: equipes,
                aoCancelar: { mostrandoTrocarEquipe = false },
                aoSelecionar: { equipe in
                    aoSelecionarEquipe(equipe)
                    mostrandoTrocarEquipe = false
                }
            )
        }
    }

    private var cabecalho: some View {
        Group {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Equipe")
                            .font(.system(size: 42, weight: .bold))
                            .foregroundStyle(PapagaioTema.texto)

                        Text("Gerencie os membros de \(equipeAtiva.nome) e níveis de acesso\nem um ambiente centralizado e colaborativo.")
                            .font(.title3)
                            .lineSpacing(6)
                            .foregroundStyle(PapagaioTema.textoSecundario)
                    }

                    Spacer()

                    Button("Mudar Equipe: \(equipeAtiva.nome)", systemImage: "arrow.triangle.2.circlepath") {
                        mostrandoTrocarEquipe = true
                    }
                    .buttonStyle(BotaoDeContornoPapagaio())

                    Button("Adicionar Membro", systemImage: "person.badge.plus") {
                        mostrandoAdicionar = true
                    }
                    .buttonStyle(BotaoPrincipalPapagaio())
        }
    }

    private func remover(_ membro: MembroDaEquipe) {
        guard !membro.atual else { return }
        membros.removeAll { $0.id == membro.id }
        salvarMembrosDaEquipe()
    }

    private func alternarPagina(_ delta: Int) {
        let ultima = max(0, (membros.count - 1) / TabelaDaEquipe.itensPorPagina)
        pagina = min(max(0, pagina + delta), ultima)
    }

    private func carregarMembrosDaEquipe() {
        membros = MembrosDasEquipes.carregar(equipeID: equipeAtiva.id)
        pagina = 0
        aoAtualizarQuantidadeDeMembros(equipeAtiva.id, membros.count)
    }

    private func salvarMembrosDaEquipe() {
        MembrosDasEquipes.salvar(membros, equipeID: equipeAtiva.id)
        let ultima = max(0, (membros.count - 1) / TabelaDaEquipe.itensPorPagina)
        pagina = min(pagina, ultima)
        aoAtualizarQuantidadeDeMembros(equipeAtiva.id, membros.count)
    }
}

private struct TabelaDaEquipe: View {
    static let itensPorPagina = 4

    let membros: [MembroDaEquipe]
    let pagina: Int
    let aoEditar: (MembroDaEquipe) -> Void
    let aoRemover: (MembroDaEquipe) -> Void
    let aoAlternarPagina: (Int) -> Void

    private var membrosDaPagina: [MembroDaEquipe] {
        let inicio = min(pagina * Self.itensPorPagina, membros.count)
        let fim = min(inicio + Self.itensPorPagina, membros.count)
        return Array(membros[inicio..<fim])
    }

    private var ultimaPagina: Int {
        max(0, (membros.count - 1) / Self.itensPorPagina)
    }

    private var intervaloAtual: String {
        guard !membros.isEmpty else { return "Nenhum membro" }
        let fim = min((pagina + 1) * Self.itensPorPagina, membros.count)
        return "\(fim) de \(membros.count) membros"
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(spacing: 0) {
                HStack {
                    CabecalhoDeColuna("MEMBRO", largura: 300)
                    CabecalhoDeColuna("EMAIL", largura: 330)
                    CabecalhoDeColuna("CARGO", largura: 210)
                    CabecalhoDeColuna("STATUS", largura: 170)
                    CabecalhoDeColuna("AÇÕES", alinhamento: .trailing)
                }
                .padding(.horizontal, 24)
                .frame(height: 64)

                SeparadorPapagaio()

                ForEach(membrosDaPagina) { membro in
                    LinhaDeMembroDaEquipe(
                        membro: membro,
                        aoEditar: { aoEditar(membro) },
                        aoRemover: { aoRemover(membro) }
                    )

                    if membro.id != membrosDaPagina.last?.id {
                        SeparadorPapagaio()
                    }
                }

                SeparadorPapagaio()

                HStack {
                    Text(intervaloAtual)
                        .font(.callout)
                        .foregroundStyle(PapagaioTema.textoSecundario)

                    Spacer()

                    HStack(spacing: 10) {
                        Button {
                            aoAlternarPagina(-1)
                        } label: {
                            Image(systemName: "chevron.left")
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(pagina == 0 ? PapagaioTema.textoSecundario.opacity(0.3) : PapagaioTema.textoSecundario)
                        .disabled(pagina == 0)

                        Button {
                            aoAlternarPagina(1)
                        } label: {
                            Image(systemName: "chevron.right")
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(pagina >= ultimaPagina ? PapagaioTema.textoSecundario.opacity(0.3) : PapagaioTema.texto)
                        .disabled(pagina >= ultimaPagina)
                    }
                }
                .padding(.horizontal, 24)
                .frame(height: 72)
            }
            .frame(minWidth: 1_060)
        }
        .cartaoPapagaio()
    }
}

private struct CabecalhoDeColuna: View {
    let texto: String
    let largura: CGFloat?
    let alinhamento: Alignment

    init(_ texto: String, largura: CGFloat? = nil, alinhamento: Alignment = .leading) {
        self.texto = texto
        self.largura = largura
        self.alinhamento = alinhamento
    }

    var body: some View {
        Text(texto)
            .font(.callout.weight(.bold))
            .foregroundStyle(PapagaioTema.textoSecundario)
            .frame(width: largura, alignment: alinhamento)
            .frame(maxWidth: largura == nil ? .infinity : nil, alignment: alinhamento)
    }
}

private struct LinhaDeMembroDaEquipe: View {
    let membro: MembroDaEquipe
    let aoEditar: () -> Void
    let aoRemover: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 16) {
                AvatarDeMembro(iniciais: membro.iniciais)

                VStack(alignment: .leading, spacing: 3) {
                    Text(membro.nome)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(PapagaioTema.texto)
                    if membro.atual {
                        Text("Você")
                            .font(.callout)
                            .foregroundStyle(PapagaioTema.textoSecundario)
                    }
                }
            }
            .frame(width: 300, alignment: .leading)

            Text(membro.email)
                .font(.title3)
                .foregroundStyle(PapagaioTema.textoSecundario)
                .frame(width: 330, alignment: .leading)

            Text(membro.cargo)
                .font(.callout.weight(.medium))
                .foregroundStyle(PapagaioTema.textoSecundario)
                .padding(.horizontal, 16)
                .frame(height: 32)
                .background(PapagaioTema.destaque.opacity(0.24), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .frame(width: 210, alignment: .leading)

            HStack(spacing: 12) {
                Circle()
                    .fill(membro.status.cor)
                    .frame(width: 10, height: 10)
                Text(membro.status.rawValue)
                    .font(.title3)
                    .foregroundStyle(PapagaioTema.textoSecundario)
            }
            .frame(width: 210, alignment: .leading)

            Spacer()

            if membro.atual {
                Button(action: aoEditar) {
                    Image(systemName: "pencil")
                        .font(.system(size: 21, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(PapagaioTema.textoSecundario)
                .help("Editar")
            } else {
                Menu {
                    Button("Editar", systemImage: "pencil", action: aoEditar)
                    Button("Remover", systemImage: "trash", role: .destructive, action: aoRemover)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 24, weight: .bold))
                        .frame(width: 32, height: 32)
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .foregroundStyle(PapagaioTema.textoSecundario)
                .help("Ações")
            }
        }
        .padding(.horizontal, 30)
        .frame(height: 96)
    }
}

private struct AvatarDeMembro: View {
    let iniciais: String

    var body: some View {
        Text(iniciais)
            .font(.callout.weight(.bold))
            .foregroundStyle(PapagaioTema.texto)
            .frame(width: 50, height: 50)
            .background(
                LinearGradient(
                    colors: [PapagaioTema.destaqueSuave, PapagaioTema.superficieSuave],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Circle()
            )
    }
}

private struct EditorDeMembroDaEquipe: View {
    let titulo: String
    @State var membro: MembroDaEquipe
    let aoCancelar: () -> Void
    let aoSalvar: (MembroDaEquipe) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Text(titulo)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(PapagaioTema.texto)
                Spacer()
                Button(action: aoCancelar) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
            }

            CampoDoPerfil(titulo: "Nome", texto: $membro.nome, placeholder: "Nome completo")
            CampoDoPerfil(titulo: "Email", texto: $membro.email, placeholder: "email@empresa.com")

            CampoDoPerfil(titulo: "Cargo", texto: $membro.cargo, placeholder: "Ex.: Pesquisador, Designer, Transcritor")

            Picker("Status", selection: $membro.status) {
                ForEach(StatusDaEquipe.allCases) { status in
                    Text(status.rawValue).tag(status)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Spacer()
                Button("Cancelar", role: .cancel, action: aoCancelar)
                    .buttonStyle(BotaoDeContornoPapagaio())
                Button("Salvar", systemImage: "checkmark") {
                    aoSalvar(membro)
                }
                .buttonStyle(BotaoPrincipalPapagaio())
                .disabled(membro.nome.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || membro.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(28)
        .frame(minWidth: 340, idealWidth: 440, maxWidth: 460)
        .background(PapagaioTema.fundo)
    }
}

private struct SeletorDeEquipeView: View {
    let equipeAtiva: EquipeDisponivel
    let equipes: [EquipeDisponivel]
    let aoCancelar: () -> Void
    let aoSelecionar: (EquipeDisponivel) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Mudar Equipe")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(PapagaioTema.texto)

                Spacer()

                Button(action: aoCancelar) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .help("Fechar")
            }

            Text("Escolha em qual equipe você quer trabalhar agora.")
                .font(.callout)
                .foregroundStyle(PapagaioTema.textoSecundario)

            VStack(spacing: 8) {
                ForEach(equipes) { equipe in
                    Button {
                        aoSelecionar(equipe)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "person.3")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(PapagaioTema.destaqueEscuro)
                                .frame(width: 34, height: 34)
                                .background(PapagaioTema.destaqueSuave, in: Circle())

                            VStack(alignment: .leading, spacing: 3) {
                                Text(equipe.nome)
                                    .font(.headline)
                                    .foregroundStyle(PapagaioTema.texto)
                                Text("\(equipe.papel) • \(equipe.quantidadeDeMembros) membros")
                                    .font(.caption)
                                    .foregroundStyle(PapagaioTema.textoSecundario)
                            }

                            Spacer()

                            if equipe.id == equipeAtiva.id {
                                Image(systemName: "checkmark")
                                    .font(.callout.weight(.bold))
                                    .foregroundStyle(PapagaioTema.destaqueEscuro)
                            }
                        }
                        .padding(12)
                        .background(
                            equipe.id == equipeAtiva.id ? PapagaioTema.destaqueSuave.opacity(0.62) : PapagaioTema.superficie,
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(equipe.id == equipeAtiva.id ? PapagaioTema.destaque.opacity(0.45) : PapagaioTema.borda, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(28)
        .frame(width: 430)
        .background(PapagaioTema.fundo)
    }
}

private struct TarefasView: View {
    let biblioteca: Biblioteca?
    let consulta: String
    @State private var conversasSelecionadas: Set<ArquivoID> = []
    @State private var versaoDasTarefas = 0
    @State private var prioridadeSelecionada: PrioridadeDaTarefa?
    @State private var ordenacao: OrdenacaoDoPainelDeTarefas = .deadline
    @State private var filtroDeDeadline: FiltroDeDeadlineTarefa = .todas
    @State private var exibindoEditor = false
    @State private var tarefaEmEdicao: TarefaGeral?
    @State private var conversaDoEditor: ArquivoID?
    @State private var tituloDoEditor = ""
    @State private var responsavelDoEditor = ""
    @State private var prioridadeDoEditor: PrioridadeDaTarefa = .media
    @State private var statusDoEditor: StatusDaTarefa = .emAndamento
    @State private var prazoDoEditor = Date()

    private var conversas: [Arquivo] {
        biblioteca?.arquivos.sorted { $0.criadoEm > $1.criadoEm } ?? []
    }

    private var tarefasPorConversa: [TarefasDaConversaGeral] {
        _ = versaoDasTarefas
        return conversas.compactMap { arquivo -> TarefasDaConversaGeral? in
            let tarefas = TarefasGeraisStore.carregar(arquivo)
                .sorted(by: ordenarPorDeadline)
            guard !tarefas.isEmpty else { return nil }
            return TarefasDaConversaGeral(
                arquivo: arquivo,
                titulo: arquivo.resumo?.titulo ?? arquivo.titulo,
                tarefas: tarefas
            )
        }
    }

    private var conversasVisiveis: [TarefasDaConversaGeral] {
        let termo = consulta.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = tarefasPorConversa
        let filtradasPorSelecao: [TarefasDaConversaGeral]
        if conversasSelecionadas.isEmpty {
            filtradasPorSelecao = base
        } else {
            filtradasPorSelecao = base.filter { conversasSelecionadas.contains($0.id) }
        }

        guard !termo.isEmpty else { return filtradasPorSelecao }
        return filtradasPorSelecao.compactMap { conversa in
            let tarefas = conversa.tarefas.filter {
                conversa.titulo.localizedCaseInsensitiveContains(termo)
                    || $0.titulo.localizedCaseInsensitiveContains(termo)
                    || $0.origem.localizedCaseInsensitiveContains(termo)
                    || ($0.responsavel?.localizedCaseInsensitiveContains(termo) ?? false)
            }
            guard !tarefas.isEmpty else { return nil }
            return TarefasDaConversaGeral(
                arquivo: conversa.arquivo,
                titulo: conversa.titulo,
                tarefas: tarefas
            )
        }
    }

    private var tarefasVisiveis: [TarefaGeral] {
        let tarefas = conversasVisiveis.flatMap { conversa in
            conversa.tarefas.map {
                TarefaGeral(conversa: conversa, tarefa: $0)
            }
        }

        let porPrioridade = prioridadeSelecionada.map { prioridade in
            tarefas.filter { $0.tarefa.prioridade == prioridade }
        } ?? tarefas

        let filtradas = porPrioridade.filter { tarefa in
            filtroDeDeadline.inclui(tarefa.tarefa.prazo)
        }

        return filtradas.sorted { primeira, segunda in
            switch ordenacao {
            case .deadline:
                return ordenarPorDeadline(primeira.tarefa, segunda.tarefa)
            case .prioridade:
                let prioridadeA = prioridadeOrdenacao(primeira.tarefa.prioridade)
                let prioridadeB = prioridadeOrdenacao(segunda.tarefa.prioridade)
                if prioridadeA != prioridadeB { return prioridadeA < prioridadeB }
                return ordenarPorDeadline(primeira.tarefa, segunda.tarefa)
            }
        }
    }

    private var tarefasDePrioridadeAlta: [TarefaGeral] {
        tarefasVisiveis.filter { $0.tarefa.prioridade == .alta && $0.tarefa.status != .concluida }
    }

    private var tarefasEmAndamento: [TarefaGeral] {
        tarefasVisiveis.filter { $0.tarefa.status == .emAndamento && $0.tarefa.prioridade != .alta }
    }

    private var tarefasConcluidas: [TarefaGeral] {
        tarefasVisiveis.filter { $0.tarefa.status == .concluida }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Painel de Tarefas")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(PapagaioTema.texto)

                    Text("Gerencie as ações geradas a partir das suas conversas.")
                        .font(.title3)
                        .foregroundStyle(PapagaioTema.textoSecundario)
                }

                if tarefasPorConversa.isEmpty {
                    CartaoDeEstadoVazio(
                        simbolo: "list.clipboard",
                        titulo: "Nenhuma tarefa ainda",
                        mensagem: "Quando uma conversa tiver próximos passos ou tarefas criadas, elas ficarão reunidas nesta página."
                    )
                    .frame(maxWidth: .infinity, minHeight: 300)
                    .cartaoPapagaio()
                } else {
                    seletorDeConversas
                    kanbanDeTarefas
                }
            }
            .larguraDeConteudoPapagaio()
            .padding(.horizontal, PapagaioTema.espacamentoDePagina)
            .padding(.vertical, PapagaioTema.espacamentoDePagina)
        }
        .background(PapagaioTema.fundo)
        .overlay(alignment: .bottomTrailing) {
            Button(action: abrirCriacaoDeTarefa) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(PapagaioTema.destaqueEscuro, in: Circle())
                    .shadow(color: PapagaioTema.destaque.opacity(0.28), radius: 18, y: 10)
            }
            .buttonStyle(.plain)
            .padding(30)
            .help("Adicionar tarefa")
            .disabled(conversas.isEmpty)
        }
        .sheet(isPresented: $exibindoEditor) {
            EditorDeTarefaGeralSheet(
                modo: tarefaEmEdicao == nil ? .criacao : .edicao,
                conversas: conversas,
                conversaSelecionada: $conversaDoEditor,
                titulo: $tituloDoEditor,
                responsavel: $responsavelDoEditor,
                prioridade: $prioridadeDoEditor,
                status: $statusDoEditor,
                prazo: $prazoDoEditor,
                aoCancelar: { exibindoEditor = false },
                aoSalvar: salvarTarefaDoEditor
            )
        }
    }

    private var seletorDeConversas: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Todas as conversas")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(PapagaioTema.textoSecundario)

                if !conversasSelecionadas.isEmpty {
                    Button("Limpar seleção") {
                        withAnimation(.snappy(duration: 0.18)) {
                            conversasSelecionadas.removeAll()
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PapagaioTema.destaqueEscuro)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(tarefasPorConversa) { conversa in
                        CartaoFiltroDeConversaTarefa(
                            conversa: conversa,
                            selecionado: conversasSelecionadas.contains(conversa.id),
                            vencimento: vencimentoMaisProximo(conversa.tarefas)
                        ) {
                            alternarSelecao(conversa.id)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var kanbanDeTarefas: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Label(tituloDoKanban, systemImage: "bubble.left.and.text.bubble.right")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(PapagaioTema.texto)

                Text("\(tarefasVisiveis.count) \(tarefasVisiveis.count == 1 ? "Tarefa" : "Tarefas")")
                    .font(.callout.weight(.bold))
                    .foregroundStyle(PapagaioTema.textoSecundario)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(PapagaioTema.superficieSuave, in: Capsule())

                Spacer()

                Menu {
                    Button("Todas") { prioridadeSelecionada = nil }
                    ForEach(PrioridadeDaTarefa.allCases, id: \.self) { prioridade in
                        Button(prioridade.rawValue) { prioridadeSelecionada = prioridade }
                    }
                } label: {
                    Label(prioridadeSelecionada?.rawValue ?? "Prioridade", systemImage: "line.3.horizontal.decrease")
                }
                .buttonStyle(BotaoDeFiltroDeTarefaGeral(ativo: prioridadeSelecionada != nil))

                Menu {
                    Button("Todas") { filtroDeDeadline = .todas }
                    Divider()
                    ForEach(FiltroDeDeadlineTarefa.allCases.filter { $0 != .todas }, id: \.self) { filtro in
                        Button(filtro.titulo) { filtroDeDeadline = filtro }
                    }
                } label: {
                    Label(filtroDeDeadline.titulo, systemImage: filtroDeDeadline.simbolo)
                }
                .buttonStyle(BotaoDeFiltroDeTarefaGeral(ativo: filtroDeDeadline != .todas))

            }

            if tarefasVisiveis.isEmpty {
                CartaoDeEstadoVazio(
                    simbolo: "magnifyingglass",
                    titulo: "Nenhuma tarefa encontrada",
                    mensagem: "Tente limpar a seleção ou buscar por outra conversa."
                )
                .frame(maxWidth: .infinity, minHeight: 240)
                .cartaoPapagaio()
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 20) {
                        coluna(titulo: "Prioridade alta", cor: PapagaioTema.perigo, tarefas: tarefasDePrioridadeAlta)
                        coluna(titulo: "Em andamento", cor: PapagaioTema.destaque, tarefas: tarefasEmAndamento)
                        coluna(titulo: "Concluídas", cor: PapagaioTema.textoSecundario, tarefas: tarefasConcluidas)
                    }

                    VStack(alignment: .leading, spacing: 18) {
                        coluna(titulo: "Prioridade alta", cor: PapagaioTema.perigo, tarefas: tarefasDePrioridadeAlta)
                        coluna(titulo: "Em andamento", cor: PapagaioTema.destaque, tarefas: tarefasEmAndamento)
                        coluna(titulo: "Concluídas", cor: PapagaioTema.textoSecundario, tarefas: tarefasConcluidas)
                    }
                }
            }
        }
    }

    private var tituloDoKanban: String {
        if conversasSelecionadas.count == 1,
           let selecionada = conversasVisiveis.first {
            return selecionada.titulo
        }
        return conversasSelecionadas.isEmpty ? "Todas as tarefas" : "\(conversasSelecionadas.count) conversas selecionadas"
    }

    private func coluna(titulo: String, cor: Color, tarefas: [TarefaGeral]) -> some View {
        ColunaDeTarefasGerais(
            titulo: titulo,
            cor: cor,
            tarefas: tarefas,
            aoEditar: abrirEdicao,
            aoAlternarConclusao: alternarConclusao,
            aoExcluir: excluirTarefa,
            aoMover: moverTarefa
        )
            .frame(maxWidth: .infinity, alignment: .top)
    }

    private func alternarSelecao(_ id: ArquivoID) {
        withAnimation(.snappy(duration: 0.18)) {
            if conversasSelecionadas.contains(id) {
                conversasSelecionadas.remove(id)
            } else {
                conversasSelecionadas.insert(id)
            }
        }
    }

    private func vencimentoMaisProximo(_ tarefas: [TarefaDaConversa]) -> Date? {
        tarefas
            .filter { $0.status != .concluida }
            .compactMap(\.prazo)
            .min()
    }

    private func abrirCriacaoDeTarefa() {
        tarefaEmEdicao = nil
        conversaDoEditor = conversasSelecionadas.first ?? conversas.first?.id
        tituloDoEditor = ""
        responsavelDoEditor = ""
        prioridadeDoEditor = .media
        statusDoEditor = .emAndamento
        prazoDoEditor = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        exibindoEditor = true
    }

    private func abrirEdicao(_ tarefa: TarefaGeral) {
        tarefaEmEdicao = tarefa
        conversaDoEditor = tarefa.conversa.id
        tituloDoEditor = tarefa.tarefa.titulo
        responsavelDoEditor = tarefa.tarefa.responsavel ?? ""
        prioridadeDoEditor = tarefa.tarefa.prioridade
        statusDoEditor = tarefa.tarefa.status
        prazoDoEditor = tarefa.tarefa.prazo ?? Date()
        exibindoEditor = true
    }

    private func salvarTarefaDoEditor() {
        guard let conversaID = conversaDoEditor,
              let arquivo = conversas.first(where: { $0.id == conversaID })
        else { return }

        let titulo = tituloDoEditor.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !titulo.isEmpty else { return }

        var tarefas = TarefasGeraisStore.carregar(arquivo)
        let tarefaAtualizada = TarefaDaConversa(
            id: tarefaEmEdicao?.tarefa.id ?? UUID(),
            titulo: titulo,
            origem: arquivo.resumo?.titulo ?? arquivo.titulo,
            prioridade: prioridadeDoEditor,
            status: statusDoEditor,
            responsavel: responsavelDoEditor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : responsavelDoEditor,
            prazo: prazoDoEditor
        )

        if let tarefaEmEdicao,
           let indice = tarefas.firstIndex(where: { $0.id == tarefaEmEdicao.tarefa.id }) {
            tarefas[indice] = tarefaAtualizada
        } else {
            tarefas.append(tarefaAtualizada)
        }

        TarefasGeraisStore.salvar(tarefas, para: conversaID)
        versaoDasTarefas += 1
        exibindoEditor = false
    }

    private func alternarConclusao(_ tarefa: TarefaGeral) {
        atualizar(tarefa) { editada in
            editada.status = editada.status == .concluida ? .emAndamento : .concluida
        }
    }

    private func moverTarefa(_ id: String, para destino: DestinoDeTarefa) {
        guard let tarefa = tarefasVisiveis.first(where: { $0.id == id }) else { return }
        atualizar(tarefa) { editada in
            editada.status = destino.status
            if let prioridade = destino.prioridade {
                editada.prioridade = prioridade
            }
        }
    }

    private func excluirTarefa(_ tarefa: TarefaGeral) {
        guard let arquivo = conversas.first(where: { $0.id == tarefa.conversa.id }) else { return }
        let tarefas = TarefasGeraisStore.carregar(arquivo).filter { $0.id != tarefa.tarefa.id }
        TarefasGeraisStore.salvar(tarefas, para: tarefa.conversa.id)
        LixeiraDeTarefas.mover(
            tarefa.tarefa,
            arquivoID: tarefa.conversa.id,
            conversaTitulo: tarefa.conversa.titulo
        )
        versaoDasTarefas += 1
    }

    private func atualizar(_ tarefa: TarefaGeral, alteracao: (inout TarefaDaConversa) -> Void) {
        guard let arquivo = conversas.first(where: { $0.id == tarefa.conversa.id }) else { return }
        var tarefas = TarefasGeraisStore.carregar(arquivo)
        guard let indice = tarefas.firstIndex(where: { $0.id == tarefa.tarefa.id }) else { return }
        alteracao(&tarefas[indice])
        TarefasGeraisStore.salvar(tarefas, para: tarefa.conversa.id)
        versaoDasTarefas += 1
    }

    private func ordenarPorDeadline(_ primeira: TarefaDaConversa, _ segunda: TarefaDaConversa) -> Bool {
        switch (primeira.prazo, segunda.prazo) {
        case let (a?, b?):
            if a != b { return a < b }
            if primeira.prioridade != segunda.prioridade {
                return prioridadeOrdenacao(primeira.prioridade) < prioridadeOrdenacao(segunda.prioridade)
            }
            return primeira.titulo.localizedCaseInsensitiveCompare(segunda.titulo) == .orderedAscending
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            return primeira.titulo.localizedCaseInsensitiveCompare(segunda.titulo) == .orderedAscending
        }
    }

    private func prioridadeOrdenacao(_ prioridade: PrioridadeDaTarefa) -> Int {
        switch prioridade {
        case .alta: 0
        case .media: 1
        case .baixa: 2
        }
    }
}

private struct TarefasDaConversaGeral: Identifiable {
    let arquivo: Arquivo
    let titulo: String
    let tarefas: [TarefaDaConversa]

    var id: ArquivoID { arquivo.id }
}

private struct TarefaGeral: Identifiable {
    let conversa: TarefasDaConversaGeral
    let tarefa: TarefaDaConversa

    var id: String { "\(conversa.id.rawValue.uuidString)-\(tarefa.id.uuidString)" }
}

private struct CartaoFiltroDeConversaTarefa: View {
    let conversa: TarefasDaConversaGeral
    let selecionado: Bool
    let vencimento: Date?
    let acao: () -> Void

    var body: some View {
        Button(action: acao) {
            HStack(spacing: 14) {
                Image(systemName: simbolo)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(selecionado ? PapagaioTema.destaqueEscuro : PapagaioTema.textoSecundario)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text(conversa.titulo)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(selecionado ? PapagaioTema.destaqueEscuro : PapagaioTema.texto)
                        .lineLimit(1)

                    VStack(alignment: .leading, spacing: 4) {
                        Label("\(conversa.tarefas.count) \(conversa.tarefas.count == 1 ? "Tarefa" : "Tarefas")", systemImage: "checklist")

                        if let vencimento {
                            Label(rotuloDoVencimento(vencimento), systemImage: "calendar")
                        } else {
                            Label("Sem data", systemImage: "calendar.badge.clock")
                        }
                    }
                    .font(.callout.weight(.medium))
                    .foregroundStyle(PapagaioTema.textoSecundario)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .frame(width: 254, height: 82)
            .background(selecionado ? PapagaioTema.destaqueSuave.opacity(0.82) : PapagaioTema.superficie, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(selecionado ? PapagaioTema.destaque : PapagaioTema.borda, lineWidth: selecionado ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(selecionado ? "Desmarcar \(conversa.titulo)" : "Marcar \(conversa.titulo)")
    }

    private var simbolo: String {
        selecionado ? "bubble.left.and.text.bubble.right.fill" : "bubble.left"
    }

    private func rotuloDoVencimento(_ data: Date) -> String {
        if Calendar.current.isDateInToday(data) { return "Hoje" }
        if Calendar.current.isDateInTomorrow(data) { return "Amanhã" }
        return data.formatted(.dateTime.day().month(.abbreviated))
    }
}

private struct ColunaDeTarefasGerais: View {
    let titulo: String
    let cor: Color
    let tarefas: [TarefaGeral]
    let aoEditar: (TarefaGeral) -> Void
    let aoAlternarConclusao: (TarefaGeral) -> Void
    let aoExcluir: (TarefaGeral) -> Void
    let aoMover: (String, DestinoDeTarefa) -> Void
    @State private var recebendoDrop = false

    private var destino: DestinoDeTarefa {
        if titulo.localizedCaseInsensitiveContains("alta") { return .alta }
        if titulo.localizedCaseInsensitiveContains("conclu") { return .concluida }
        return .emAndamento
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Circle()
                    .fill(cor)
                    .frame(width: 9, height: 9)

                Text(titulo)
                    .font(.callout.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(PapagaioTema.textoSecundario)

                Text("\(tarefas.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PapagaioTema.textoSecundario)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(PapagaioTema.superficieSuave, in: Capsule())
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
            .background(PapagaioTema.superficie.opacity(0.48), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(spacing: 12) {
                if tarefas.isEmpty {
                    Text("Solte uma tarefa aqui.")
                        .font(.callout)
                        .foregroundStyle(PapagaioTema.textoSecundario)
                        .frame(maxWidth: .infinity, minHeight: 72)
                        .background(PapagaioTema.superficie.opacity(0.45), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    ForEach(tarefas) { tarefa in
                        CartaoDeTarefaGeral(
                            tarefa: tarefa,
                            aoEditar: { aoEditar(tarefa) },
                            aoAlternarConclusao: { aoAlternarConclusao(tarefa) },
                            aoExcluir: { aoExcluir(tarefa) }
                        )
                        .draggable(tarefa.id)
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 320, alignment: .top)
        }
        .frame(maxWidth: .infinity, minHeight: 390, alignment: .top)
        .padding(recebendoDrop ? 10 : 0)
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .background(
            recebendoDrop ? cor.opacity(0.08) : Color.clear,
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .dropDestination(for: String.self) { ids, _ in
            guard let id = ids.first else { return false }
            aoMover(id, destino)
            return true
        } isTargeted: { ativo in
            recebendoDrop = ativo
        }
    }
}

private struct CartaoDeTarefaGeral: View {
    let tarefa: TarefaGeral
    let aoEditar: () -> Void
    let aoAlternarConclusao: () -> Void
    let aoExcluir: () -> Void

    private var concluida: Bool { tarefa.tarefa.status == .concluida }
    private var progresso: Double {
        concluida ? 1 : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SeloPrioridadeGeral(prioridade: tarefa.tarefa.prioridade)
                Spacer()
                SeloStatusGeral(status: tarefa.tarefa.status)
                Menu {
                    Button("Editar", systemImage: "pencil", action: aoEditar)
                    Button(concluida ? "Marcar em andamento" : "Marcar concluída", systemImage: concluida ? "clock" : "checkmark", action: aoAlternarConclusao)
                    Button("Excluir", systemImage: "trash", role: .destructive, action: aoExcluir)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(PapagaioTema.textoSecundario)
                        .frame(width: 30, height: 30)
                        .contentShape(Circle())
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .help("Ações da tarefa")
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(tarefa.tarefa.titulo)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(concluida ? PapagaioTema.textoSecundario : PapagaioTema.texto)
                    .strikethrough(concluida, color: PapagaioTema.textoSecundario)
                    .lineLimit(2)

                Text(tarefa.conversa.titulo)
                    .font(.callout)
                    .foregroundStyle(PapagaioTema.textoSecundario)
                    .lineLimit(1)
            }

            HStack(spacing: 10) {
                avatarResponsavel
                Spacer(minLength: 0)
                Label(rotuloDoPrazo, systemImage: concluida ? "checkmark.circle" : "calendar")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(corDoPrazo)
                    .lineLimit(1)
            }

            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: progresso)
                    .progressViewStyle(.linear)
                    .tint(concluida ? PapagaioTema.sucesso : PapagaioTema.destaqueEscuro)

                Text(concluida ? "100% Concluído" : "Em andamento")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(concluida ? PapagaioTema.sucesso : PapagaioTema.destaqueEscuro)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 142, alignment: .topLeading)
        .background(PapagaioTema.superficie, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(PapagaioTema.borda, lineWidth: 1)
        }
        .shadow(color: PapagaioTema.destaque.opacity(0.08), radius: 10, y: 6)
    }

    private var avatarResponsavel: some View {
        HStack(spacing: 8) {
            Text(iniciais(de: tarefa.tarefa.responsavel ?? "?"))
                .font(.caption.weight(.bold))
                .foregroundStyle(PapagaioTema.texto)
                .frame(width: 30, height: 30)
                .background(PapagaioTema.destaqueSuave, in: Circle())

            Text(tarefa.tarefa.responsavel?.isEmpty == false ? tarefa.tarefa.responsavel! : "Sem responsável")
                .font(.caption.weight(.semibold))
                .foregroundStyle(PapagaioTema.textoSecundario)
                .lineLimit(1)
        }
    }

    private var rotuloDoPrazo: String {
        guard let prazo = tarefa.tarefa.prazo else { return "Sem deadline" }
        if Calendar.current.isDateInToday(prazo) { return "Hoje" }
        if Calendar.current.isDateInTomorrow(prazo) { return "Amanhã" }
        return prazo.formatted(.dateTime.day().month().year())
    }

    private var corDoPrazo: Color {
        guard let prazo = tarefa.tarefa.prazo, !concluida else { return PapagaioTema.textoSecundario }
        if prazo <= Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date() {
            return PapagaioTema.perigo
        }
        return PapagaioTema.textoSecundario
    }

    private func iniciais(de nome: String) -> String {
        let partes = nome.split(separator: " ")
        let letras = partes.prefix(2).compactMap(\.first)
        return letras.isEmpty ? "?" : String(letras).uppercased()
    }
}

private struct SeloPrioridadeGeral: View {
    let prioridade: PrioridadeDaTarefa

    var body: some View {
        Text("\(prioridade.simbolo) \(prioridade.rawValue)")
            .font(.caption.weight(.bold))
            .foregroundStyle(prioridade.cor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(prioridade.cor.opacity(0.14), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

private struct SeloStatusGeral: View {
    let status: StatusDaTarefa

    var body: some View {
        Text(status == .concluida ? "Pronto" : "Ativo")
            .font(.caption.weight(.bold))
            .foregroundStyle(status == .concluida ? PapagaioTema.sucesso : PapagaioTema.destaqueEscuro)
            .textCase(.uppercase)
    }
}

private enum OrdenacaoDoPainelDeTarefas {
    case deadline
    case prioridade

    var titulo: String {
        switch self {
        case .deadline: "Data limite"
        case .prioridade: "Prioridade"
        }
    }

    var simbolo: String {
        switch self {
        case .deadline: "calendar"
        case .prioridade: "line.3.horizontal.decrease"
        }
    }
}

private enum FiltroDeDeadlineTarefa: CaseIterable, Hashable {
    case todas
    case atrasadas
    case hoje
    case proximosSeteDias
    case semData

    var titulo: String {
        switch self {
        case .todas: "Data limite"
        case .atrasadas: "Atrasadas"
        case .hoje: "Hoje"
        case .proximosSeteDias: "Próximos 7 dias"
        case .semData: "Sem data"
        }
    }

    var simbolo: String {
        switch self {
        case .todas, .proximosSeteDias: "calendar"
        case .atrasadas: "calendar.badge.exclamationmark"
        case .hoje: "calendar.circle"
        case .semData: "calendar.badge.clock"
        }
    }

    func inclui(_ prazo: Date?) -> Bool {
        let calendario = Calendar.current
        let hoje = calendario.startOfDay(for: Date())

        switch self {
        case .todas:
            return true
        case .semData:
            return prazo == nil
        case .atrasadas:
            guard let prazo else { return false }
            return calendario.startOfDay(for: prazo) < hoje
        case .hoje:
            guard let prazo else { return false }
            return calendario.isDateInToday(prazo)
        case .proximosSeteDias:
            guard let prazo else { return false }
            let dia = calendario.startOfDay(for: prazo)
            let limite = calendario.date(byAdding: .day, value: 7, to: hoje) ?? hoje
            return dia >= hoje && dia <= limite
        }
    }
}

private struct BotaoDeFiltroDeTarefaGeral: ButtonStyle {
    let ativo: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .foregroundStyle(ativo ? PapagaioTema.destaqueEscuro : PapagaioTema.textoSecundario)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(
                ativo ? PapagaioTema.destaqueSuave.opacity(configuration.isPressed ? 0.95 : 0.62) : PapagaioTema.superficie,
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .stroke(PapagaioTema.borda.opacity(0.95), lineWidth: 1)
            }
    }
}

private struct EditorDeTarefaGeralSheet: View {
    enum Modo {
        case criacao
        case edicao
    }

    let modo: Modo
    let conversas: [Arquivo]
    @Binding var conversaSelecionada: ArquivoID?
    @Binding var titulo: String
    @Binding var responsavel: String
    @Binding var prioridade: PrioridadeDaTarefa
    @Binding var status: StatusDaTarefa
    @Binding var prazo: Date
    let aoCancelar: () -> Void
    let aoSalvar: () -> Void

    private var conversaAtual: Arquivo? {
        guard let conversaSelecionada else { return nil }
        return conversas.first { $0.id == conversaSelecionada }
    }

    private var podeSalvar: Bool {
        conversaSelecionada != nil && !titulo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: modo == .criacao ? "plus.circle" : "pencil")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(PapagaioTema.destaqueEscuro)
                    .frame(width: 46, height: 46)
                    .background(PapagaioTema.destaqueSuave, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(modo == .criacao ? "Nova tarefa" : "Editar tarefa")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(PapagaioTema.texto)
                    Text("Escolha a conversa, prioridade, responsável, status e data limite.")
                        .font(.callout)
                        .foregroundStyle(PapagaioTema.textoSecundario)
                }

                Spacer()
            }

            campo("Conversa") {
                Menu {
                    ForEach(conversas) { conversa in
                        Button(conversa.resumo?.titulo ?? conversa.titulo) {
                            conversaSelecionada = conversa.id
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "bubble.left")
                        Text(conversaAtual.map { $0.resumo?.titulo ?? $0.titulo } ?? "Escolher conversa")
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.bold))
                    }
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(PapagaioTema.texto)
                    .padding(.horizontal, 12)
                    .frame(height: 42)
                    .background(PapagaioTema.superficie, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(PapagaioTema.borda, lineWidth: 1)
                    }
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
            }

            campo("Título") {
                TextField("Ex.: Revisar documentação", text: $titulo)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .padding(.horizontal, 12)
                    .frame(height: 42)
                    .background(PapagaioTema.superficie, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(PapagaioTema.borda, lineWidth: 1)
                    }
            }

            campo("Responsável") {
                TextField("Nome, e-mail ou login", text: $responsavel)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .padding(.horizontal, 12)
                    .frame(height: 42)
                    .background(PapagaioTema.superficie, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(PapagaioTema.borda, lineWidth: 1)
                    }
            }

            campo("Prioridade") {
                ControleSegmentadoTarefaGeral(
                    opcoes: PrioridadeDaTarefa.allCases,
                    selecionado: $prioridade,
                    titulo: { $0.rawValue },
                    simbolo: { _ in nil }
                )
            }

            campo("Status") {
                ControleSegmentadoTarefaGeral(
                    opcoes: StatusDaTarefa.allCases,
                    selecionado: $status,
                    titulo: { $0.titulo },
                    simbolo: { $0 == .concluida ? "checkmark" : "clock" }
                )
            }

            campo("Data limite") {
                DatePicker("Data limite", selection: $prazo, displayedComponents: [.date])
                    .datePickerStyle(.compact)
                    .labelsHidden()
            }

            HStack(spacing: 12) {
                Button("Cancelar", action: aoCancelar)
                    .buttonStyle(BotaoDeContornoPapagaio())

                Spacer()

                Button(modo == .criacao ? "Adicionar tarefa" : "Salvar alterações", systemImage: modo == .criacao ? "plus" : "checkmark") {
                    aoSalvar()
                }
                .buttonStyle(BotaoPrincipalPapagaio())
                .disabled(!podeSalvar)
            }
        }
        .padding(24)
        .frame(width: 540, alignment: .leading)
        .background(PapagaioTema.fundo)
    }

    private func campo<Conteudo: View>(_ titulo: String, @ViewBuilder conteudo: () -> Conteudo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titulo)
                .font(.caption.weight(.bold))
                .foregroundStyle(PapagaioTema.textoSecundario)
            conteudo()
        }
    }
}

private struct ControleSegmentadoTarefaGeral<Opcao: Hashable>: View {
    let opcoes: [Opcao]
    @Binding var selecionado: Opcao
    let titulo: (Opcao) -> String
    let simbolo: (Opcao) -> String?

    var body: some View {
        HStack(spacing: 8) {
            ForEach(opcoes, id: \.self) { opcao in
                let ativo = opcao == selecionado

                Button {
                    withAnimation(.snappy(duration: 0.16)) {
                        selecionado = opcao
                    }
                } label: {
                    HStack(spacing: 6) {
                        if let simbolo = simbolo(opcao) {
                            Image(systemName: simbolo)
                        }
                        Text(titulo(opcao))
                    }
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(ativo ? .white : PapagaioTema.textoSecundario)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(ativo ? PapagaioTema.destaque : PapagaioTema.superficie, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(ativo ? Color.clear : PapagaioTema.borda, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

enum TarefasGeraisStore {
    static func carregar(_ arquivo: Arquivo) -> [TarefaDaConversa] {
        if let dados = UserDefaults.standard.data(forKey: chave(arquivo.id)),
           let tarefas = try? JSONDecoder().decode([TarefaDaConversa].self, from: dados) {
            return tarefas
        }

        let titulo = arquivo.resumo?.titulo ?? arquivo.titulo
        let tarefas = (arquivo.resumo?.proximosPassos ?? []).enumerated().map { indice, passo in
            TarefaDaConversa(
                titulo: passo.descricao,
                origem: titulo,
                prioridade: indice < 2 ? .alta : .media,
                status: .emAndamento,
                responsavel: passo.responsavel,
                prazo: Calendar.current.date(byAdding: .day, value: 7 + indice, to: arquivo.criadoEm)
            )
        }

        if !tarefas.isEmpty {
            salvar(tarefas, para: arquivo.id)
        }

        return tarefas
    }

    static func salvar(_ tarefas: [TarefaDaConversa], para arquivoID: ArquivoID) {
        guard let dados = try? JSONEncoder().encode(tarefas) else { return }
        UserDefaults.standard.set(dados, forKey: chave(arquivoID))
    }

    private static func chave(_ arquivoID: ArquivoID) -> String {
        "tarefasDaConversa.\(arquivoID.rawValue.uuidString)"
    }
}

enum Diagnostico {
    /// Sob App Sandbox o home do processo é redirecionado para
    /// `~/Library/Containers/<bundle-id>/Data`.
    static var sandboxAtivo: Bool {
        NSHomeDirectory().contains("/Library/Containers/")
    }
}
#Preview {
    ContentView()
}
