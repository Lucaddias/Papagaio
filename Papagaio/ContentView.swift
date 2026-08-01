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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                BarraSuperiorPapagaio(
                    consulta: $consulta,
                    perfilConectado: perfil.conectado,
                    perfilVerificando: perfil.verificando,
                    aoEntrar: perfil.entrar,
                    aoSair: perfil.sair
                )

                if let falhaDeAbertura {
                    Label(falhaDeAbertura, systemImage: "xmark.octagon.fill")
                        .font(.callout)
                        .foregroundStyle(PapagaioTema.perigo)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(PapagaioTema.perigo.opacity(0.08))
                }

                BibliotecaHomeView(
                    gravador: modelo,
                    biblioteca: biblioteca,
                    modelos: modelos,
                    consulta: $consulta,
                    mostrandoImportador: $mostrandoImportador,
                    aoAlternarGravacao: { await modelo.alternarGravacao() },
                    aoEscolherPastaDeModelos: escolherPastaDeModelos,
                    aoUsarPastaDoApp: usarPastaDoApp
                )
            }
            .frame(minWidth: 720, minHeight: 560)
            .background(PapagaioTema.fundo)
            .navigationDestination(for: UUID.self) { id in
                if let biblioteca, let arquivo = biblioteca.arquivo(id: id) {
                    ArquivoDetalheView(
                        arquivo: arquivo,
                        audio: biblioteca.audio(de: arquivo),
                        estado: biblioteca.estado(de: arquivo)
                    )
                }
            }
        }
        .preferredColorScheme(.light)
        .task {
            perfil.iniciar()
            await abrir()
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
                await nova.registrar(
                    titulo: titulo,
                    pastaRelativa: pasta,
                    duracao: duracao,
                    notas: notas
                )
            }
            await nova.preparar()
        } catch {
            falhaDeAbertura = "Não foi possível abrir a biblioteca: \(error)"
        }
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
