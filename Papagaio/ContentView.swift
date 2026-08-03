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
    @State private var falhaDeAbertura: String?
    @State private var mostrandoImportador = false
    @State private var consulta = ""
    @State private var secaoDaBiblioteca: SecaoDaBiblioteca = .todos
    @State private var telaSelecionada: TelaPrincipal = .biblioteca
    @State private var pastaDaBibliotecaSelecionada: String?
    @AppStorage("processamentoAutomatico") private var processamentoAutomatico = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
                        aoEscolherPastaDeModelos: escolherPastaDeModelos,
                        aoUsarPastaDoApp: usarPastaDoApp
                    )
                case .tarefas:
                    TarefasView()
                case .configuracoes:
                    ConfiguracoesView(
                        processamentoAutomatico: $processamentoAutomatico
                    )
                }
            }
            .frame(minWidth: 720, minHeight: 560)
            .background(PapagaioTema.fundo)
            .toolbar {
                BarraSuperiorPapagaio(
                    consulta: $consulta,
                    exibindoBotaoVoltar: telaSelecionada != .biblioteca || secaoDaBiblioteca == .lixeira,
                    perfilConectado: perfil.conectado,
                    perfilVerificando: perfil.verificando,
                    gravando: modelo.gravando,
                    processandoBiblioteca: biblioteca?.processando ?? false,
                    quantidadeDeAvisos: modelo.avisos.count,
                    aoEntrar: perfil.entrar,
                    aoSair: perfil.sair,
                    aoVoltar: voltarParaBiblioteca,
                    aoAbrirBiblioteca: voltarParaBiblioteca,
                    aoAbrirTarefas: abrirTarefas,
                    aoAbrirConfiguracoes: { telaSelecionada = .configuracoes },
                    aoAbrirLixeira: abrirLixeira
                )
            }
            .navigationDestination(for: UUID.self) { id in
                if let biblioteca, let arquivo = biblioteca.arquivo(id: id) {
                    ArquivoDetalheView(
                        arquivo: arquivo,
                        audio: biblioteca.audio(de: arquivo),
                        estado: biblioteca.estado(de: arquivo),
                        processando: biblioteca.estaProcessando(arquivo),
                        naFila: biblioteca.estaNaFila(arquivo),
                        aoTranscrever: { biblioteca.enfileirarProcessamento(arquivo) },
                        aoAtualizarNotas: { notas in
                            await biblioteca.atualizarNotas(notas, de: arquivo)
                        }
                    )
                }
            }
        }
        .preferredColorScheme(.light)
        .task {
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
                ), let pastaDaBibliotecaSelecionada {
                    PreferenciasVisuaisDoArquivo.definirPasta(
                        pastaDaBibliotecaSelecionada,
                        para: arquivo.id
                    )
                }
            }
            await nova.preparar()
        } catch {
            falhaDeAbertura = "Não foi possível abrir a biblioteca: \(error)"
        }
    }

    private func abrirLixeira() {
        telaSelecionada = .biblioteca
        secaoDaBiblioteca = .lixeira
    }

    private func abrirTarefas() {
        telaSelecionada = .tarefas
        secaoDaBiblioteca = .todos
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

private enum TelaPrincipal {
    case biblioteca
    case tarefas
    case configuracoes
}

private struct TarefasView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tarefas")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(PapagaioTema.texto)
            Text("As tarefas geradas a partir das conversas aparecerão aqui.")
                .font(.title3)
                .foregroundStyle(PapagaioTema.textoSecundario)

            CartaoDeEstadoVazio(
                simbolo: "list.clipboard",
                titulo: "Nenhuma tarefa ainda",
                mensagem: "Quando uma conversa tiver próximos passos ou ações pendentes, elas ficarão reunidas nesta página."
            )
            .frame(maxWidth: .infinity, minHeight: 300)
            .cartaoPapagaio()
            .padding(.top, 22)
        }
        .larguraDeConteudoPapagaio()
        .padding(.horizontal, PapagaioTema.espacamentoDePagina)
        .padding(.vertical, PapagaioTema.espacamentoDePagina)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(PapagaioTema.fundo)
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
