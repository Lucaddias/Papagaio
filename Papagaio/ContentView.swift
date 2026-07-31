import PapagaioCore
import SwiftUI
import UniformTypeIdentifiers

/// Gravar, importar, e ver a biblioteca com transcrição e resumo de verdade.
struct ContentView: View {
    @State private var modelo = GravadorViewModel()
    @State private var biblioteca: Biblioteca?
    @State private var modelos: ModelosViewModel?
    @State private var perfil = PerfilViewModel()
    @State private var falhaDeAbertura: String?
    @State private var mostrandoImportador = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                cabecalho
                if let falhaDeAbertura {
                    Label(falhaDeAbertura, systemImage: "xmark.octagon")
                        .foregroundStyle(.red)
                }
                if let modelos, !modelos.pronto {
                    BannerDeModelos(modelos: modelos) { escolhida in
                        modelos.escolher(escolhida)
                        biblioteca?.pastaDeModelos = modelos.pasta
                    }
                }
                Divider()
                controles
                Waveform(amostras: modelo.waveform, ativo: modelo.gravando)
                    .frame(height: 72)
                avisos
                Divider()
                lista
            }
            .padding(24)
            .frame(minWidth: 620, minHeight: 520, alignment: .topLeading)
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
        .task {
            perfil.iniciar()
            await abrir()
        }
        .fileImporter(
            isPresented: $mostrandoImportador,
            allowedContentTypes: [.audio, .mpeg4Audio, .mp3, .wav]
        ) { resultado in
            guard case let .success(url) = resultado else { return }
            // Obrigatório sob App Sandbox — é o erro nº 1 de importação.
            guard url.startAccessingSecurityScopedResource() else { return }
            Task {
                defer { url.stopAccessingSecurityScopedResource() }
                await modelo.importar(url)
            }
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

            // A gravação entrega o áudio; a biblioteca salva e processa.
            modelo.aoProduzirAudio = { titulo, pasta, duracao in
                await nova.registrar(titulo: titulo, pastaRelativa: pasta, duracao: duracao)
            }
            await nova.preparar()
        } catch {
            falhaDeAbertura = "Não foi possível abrir a biblioteca: \(error)"
        }
    }

    private var cabecalho: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Papagaio").font(.largeTitle.bold())
                Text(Diagnostico.sandboxAtivo ? "Sandbox ativo" : "SANDBOX INATIVO")
                    .font(.caption)
                    .foregroundStyle(Diagnostico.sandboxAtivo ? Color.secondary : Color.red)
            }
            Spacer()
            if perfil.conectado {
                Menu("Perfil", systemImage: "person.crop.circle.fill") {
                    Text("Conectado com Apple")
                    Button("Sair", role: .destructive) { perfil.sair() }
                }
            } else {
                Button("Entrar com Apple", systemImage: "person.crop.circle") {
                    perfil.entrar()
                }
                .disabled(perfil.verificando)
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

    private var controles: some View {
        HStack(spacing: 16) {
            Button {
                Task { await modelo.alternarGravacao() }
            } label: {
                Image(systemName: modelo.gravando ? "stop.fill" : "circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(modelo.gravando ? Color.primary : Color.red)
                    .frame(width: 52, height: 52)
                    .background(.quaternary, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(modelo.estado == .processando)
            .accessibilityLabel(modelo.gravando ? "Parar gravação" : "Gravar")

            Button("Importar áudio…") { mostrandoImportador = true }
                .disabled(modelo.gravando || modelo.estado == .processando)

            Spacer()

            Text(descricaoDoEstado)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var descricaoDoEstado: String {
        switch modelo.estado {
        case .ocioso: "pronto"
        case .gravando: "gravando…"
        case .processando: "processando…"
        case let .falhou(motivo): "falhou: \(motivo)"
        }
    }

    @ViewBuilder
    private var avisos: some View {
        if !modelo.avisos.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(modelo.avisos, id: \.self) { aviso in
                    Label(aviso, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    @ViewBuilder
    private var lista: some View {
        if let biblioteca {
            if biblioteca.arquivos.isEmpty {
                Text("Nenhuma gravação ainda.")
                    .foregroundStyle(.secondary)
            } else {
                List(biblioteca.arquivos) { arquivo in
                    NavigationLink(value: arquivo.id.rawValue) {
                        LinhaDaBiblioteca(
                            arquivo: arquivo,
                            estado: biblioteca.estado(de: arquivo),
                            processando: biblioteca.estaProcessando(arquivo),
                            naFila: biblioteca.estaNaFila(arquivo)
                        )
                    }
                    .contextMenu {
                        Button("Processar de novo") {
                            biblioteca.enfileirarProcessamento(arquivo)
                        }
                        .disabled(biblioteca.estaProcessando(arquivo) || biblioteca.estaNaFila(arquivo))
                        Button("Apagar", role: .destructive) {
                            Task { await biblioteca.apagar(arquivo) }
                        }
                        .disabled(biblioteca.estaProcessando(arquivo))
                    }
                }
                .listStyle(.inset)
            }
        }
    }
}

/// Uma linha da biblioteca: título, duração e em que pé está o processamento.
private struct LinhaDaBiblioteca: View {
    let arquivo: Arquivo
    let estado: String
    let processando: Bool
    let naFila: Bool

    var body: some View {
        HStack(spacing: 10) {
            if processando {
                ProgressView().controlSize(.small)
                    .accessibilityLabel("Processando")
            } else if naFila {
                Image(systemName: "clock")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Na fila de processamento")
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(arquivo.resumo?.titulo ?? arquivo.titulo)
                Text("\(duracao) · \(estado)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var duracao: String {
        let inteiros = Int(arquivo.duracao)
        return String(format: "%d:%02d", inteiros / 60, inteiros % 60)
    }
}

/// Aviso de que os modelos ainda não estão em disco, com o download do Passo 3.
private struct BannerDeModelos: View {
    @Bindable var modelos: ModelosViewModel
    let aoEscolherPasta: (URL) -> Void

    @State private var escolhendoPasta = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                modelos.resultado?.mensagem ?? "Verificando os modelos…",
                systemImage: modelos.resultado?.bloqueia == true
                    ? "xmark.octagon" : "arrow.down.circle"
            )
            .font(.callout)

            if let progresso = modelos.progresso {
                ProgressView(value: progresso.fracao) {
                    Text(progresso.peso.nomeArquivo).font(.caption)
                } currentValueLabel: {
                    Text("\(gb(progresso.bytesRecebidos)) de \(gb(progresso.bytesTotais))")
                        .font(.caption)
                        .monospacedDigit()
                }
            }

            if let erro = modelos.erro {
                Text(erro).font(.caption).foregroundStyle(.red)
            }

            if modelos.resultado?.bloqueia == false, !modelos.faltando.isEmpty {
                HStack(spacing: 12) {
                    if modelos.baixando {
                        Button("Cancelar") { modelos.cancelar() }
                        Text("O download continua de onde parou se cair a conexão.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        if modelos.pastaEscolhida == nil {
                            Button("Baixar modelos (\(gb(totalFaltando)))") { modelos.baixar() }
                                .buttonStyle(.borderedProminent)
                        }
                        Button("Escolher pasta com os modelos…") { escolhendoPasta = true }
                        if modelos.pastaEscolhida != nil {
                            Button("Usar a pasta do app") { modelos.usarOContainer() }
                        }
                    }
                }

                if let escolhida = modelos.pastaEscolhida {
                    Text("Pasta atual: \(escolhida.path)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                } else {
                    Text("Se você já tem os GGUF no disco, aponte a pasta em vez de baixar.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
        .fileImporter(
            isPresented: $escolhendoPasta,
            allowedContentTypes: [.folder]
        ) { resultado in
            guard case let .success(url) = resultado else { return }
            // Obrigatório sob App Sandbox antes de gravar o bookmark.
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            aoEscolherPasta(url)
        }
    }

    private var totalFaltando: Int64 {
        modelos.faltando.reduce(0) { $0 + $1.bytes }
    }

    private func gb(_ bytes: Int64) -> String {
        String(format: "%.1f GB", Double(bytes) / 1_073_741_824)
    }
}

/// Waveform ao vivo, alimentada pelo RMS do tap do microfone.
struct Waveform: View {
    let amostras: [Float]
    let ativo: Bool

    var body: some View {
        GeometryReader { geometria in
            let largura = geometria.size.width
            let altura = geometria.size.height
            let passo = amostras.isEmpty ? 0 : largura / CGFloat(amostras.count)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8).fill(.quaternary)

                Path { caminho in
                    for (indice, amostra) in amostras.enumerated() {
                        let x = CGFloat(indice) * passo
                        let alturaBarra = max(2, CGFloat(amostra) * altura * 0.9)
                        caminho.addRect(
                            CGRect(
                                x: x,
                                y: (altura - alturaBarra) / 2,
                                width: max(1, passo * 0.6),
                                height: alturaBarra
                            )
                        )
                    }
                }
                .fill(ativo ? Color.red.opacity(0.8) : Color.secondary.opacity(0.5))
            }
        }
        .accessibilityHidden(true)
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
