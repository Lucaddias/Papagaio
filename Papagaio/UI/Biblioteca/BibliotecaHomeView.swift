import PapagaioCore
import SwiftUI
import UniformTypeIdentifiers

/// Camada visual da biblioteca. Recebe estado e ações do coordenador raiz, sem
/// criar view models nem assumir responsabilidade pelo pipeline.
struct BibliotecaHomeView: View {
    let gravador: GravadorViewModel
    let biblioteca: Biblioteca?
    let modelos: ModelosViewModel?
    @Binding var consulta: String
    @Binding var secaoSelecionada: SecaoDaBiblioteca
    @Binding var pastaSelecionada: String?
    @Binding var mostrandoImportador: Bool
    let processamentoAutomatico: Bool
    let aoAlternarGravacao: () async -> Void
    let aoPausarGravacao: () async -> Void
    let aoContinuarGravacao: () async -> Void
    let aoCancelarGravacao: () async -> Void
    let aoEscolherPastaDeModelos: (URL) -> Void
    let aoUsarPastaDoApp: () -> Void

    @State private var arquivoParaExclusaoDefinitiva: Arquivo?
    @State private var confirmandoEsvaziarLixeira = false
    @State private var menuAberto: ArquivoID?
    @State private var filtroSelecionado: FiltroDaBiblioteca = .todas
    @State private var atalhoSelecionado: AtalhoDaBiblioteca?
    @State private var atalhoVisualSelecionado: AtalhoDaBiblioteca?
    @State private var versaoDasPreferenciasVisuais = 0
    @State private var criandoPasta = false
    @State private var novaPasta = ""

    private var arquivosFiltrados: [Arquivo] {
        guard let biblioteca else { return [] }
        _ = versaoDasPreferenciasVisuais
        let fonte: [Arquivo]
        switch secaoSelecionada {
        case .todos:
            let recentes = biblioteca.arquivos.sorted { $0.criadoEm > $1.criadoEm }
            if let pastaSelecionada {
                fonte = recentes.filter { PreferenciasVisuaisDoArquivo.pasta($0.id) == pastaSelecionada }
            } else if filtroSelecionado == .pastas {
                fonte = []
            } else if atalhoSelecionado == .favoritos {
                fonte = recentes.filter { PreferenciasVisuaisDoArquivo.favorito($0.id) }
            } else {
                fonte = recentes
            }
        case .lixeira:
            fonte = biblioteca.arquivosNaLixeira
        }
        let termo = consulta.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !termo.isEmpty else { return fonte }
        return fonte.filter { arquivo in
            let titulo = arquivo.resumo?.titulo ?? arquivo.titulo
            return titulo.localizedCaseInsensitiveContains(termo)
                || (secaoSelecionada == .todos
                    && biblioteca.estado(de: arquivo).descricao.localizedCaseInsensitiveContains(termo))
        }
    }

    private var subtitulo: String {
        switch secaoSelecionada {
        case .todos:
            "Gerencie suas transcrições e insights de entrevistas."
        case .lixeira:
            "Gerencie conversas excluídas. Itens na lixeira serão removidos permanentemente após 30 dias."
        }
    }

    private var tituloDaPagina: String {
        switch secaoSelecionada {
        case .todos:
            "Biblioteca de Conversas"
        case .lixeira:
            "Lixeira"
        }
    }

    private var falhaDaGravacao: String? {
        guard case let .falhou(motivo) = gravador.estado else { return nil }
        return motivo
    }

    private var pastasCriadas: [String] {
        _ = versaoDasPreferenciasVisuais
        return PreferenciasVisuaisDoArquivo.pastas()
    }

    private var informacoesDasPastas: [InformacaoDaPasta] {
        guard let biblioteca else { return [] }
        _ = versaoDasPreferenciasVisuais
        return pastasCriadas.map { pasta in
            let arquivos = biblioteca.arquivos.filter {
                PreferenciasVisuaisDoArquivo.pasta($0.id) == pasta
            }
            return InformacaoDaPasta(
                nome: pasta,
                quantidade: arquivos.count,
                duracaoTotal: arquivos.reduce(0) { $0 + $1.duracao },
                ultimoArquivo: arquivos.map(\.criadoEm).max()
            )
        }
    }

    private var tarefasNaLixeira: [TarefaNaLixeira] {
        _ = versaoDasPreferenciasVisuais
        let termo = consulta.trimmingCharacters(in: .whitespacesAndNewlines)
        let tarefas = LixeiraDeTarefas.itens()
        guard !termo.isEmpty else { return tarefas }
        return tarefas.filter {
            $0.tarefa.titulo.localizedCaseInsensitiveContains(termo)
                || $0.conversaTitulo.localizedCaseInsensitiveContains(termo)
                || ($0.tarefa.responsavel?.localizedCaseInsensitiveContains(termo) ?? false)
        }
    }

    private var apresentandoConfirmacaoDeExclusao: Binding<Bool> {
        Binding(
            get: { arquivoParaExclusaoDefinitiva != nil },
            set: { apresentando in
                if !apresentando { arquivoParaExclusaoDefinitiva = nil }
            }
        )
    }

    private var apresentandoErroDaLixeira: Binding<Bool> {
        Binding(
            get: { biblioteca?.erroDaLixeira != nil },
            set: { apresentando in
                if !apresentando { biblioteca?.dispensarErroDaLixeira() }
            }
        )
    }

    private func recuperar(_ arquivo: Arquivo) {
        guard let biblioteca else { return }
        Task { @MainActor in
            if await biblioteca.restaurarDaLixeira(arquivo) {
                secaoSelecionada = .todos
            }
        }
    }

    private func apagarDefinitivamente(_ arquivo: Arquivo) {
        guard let biblioteca else { return }
        Task { @MainActor in
            await biblioteca.apagarDefinitivamente(arquivo)
        }
    }

    private func limparAtalhoVisual() {
        guard atalhoVisualSelecionado != nil else { return }
        withAnimation(.snappy(duration: 0.16)) {
            atalhoVisualSelecionado = nil
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PapagaioTema.Espaco.secao) {
                CabecalhoDePagina(
                    titulo: tituloDaPagina,
                    subtitulo: subtitulo
                ) {
                    HStack(spacing: PapagaioTema.Espaco.largo) {
                        if secaoSelecionada == .todos {
                            AtalhosDaBiblioteca(
                                selecionado: $atalhoVisualSelecionado,
                                aoSelecionarRecentes: {
                                    withAnimation(.snappy(duration: 0.18)) {
                                        filtroSelecionado = .todas
                                        pastaSelecionada = nil
                                        atalhoSelecionado = .recentes
                                        atalhoVisualSelecionado = .recentes
                                    }
                                },
                                aoSelecionarFavoritos: {
                                    withAnimation(.snappy(duration: 0.18)) {
                                        filtroSelecionado = .todas
                                        pastaSelecionada = nil
                                        atalhoSelecionado = .favoritos
                                        atalhoVisualSelecionado = .favoritos
                                    }
                                }
                            )
                        } else if let biblioteca {
                            AcoesDaLixeira(
                                temArquivos: !biblioteca.arquivosNaLixeira.isEmpty || !LixeiraDeTarefas.itens().isEmpty,
                                aoRestaurarTudo: {
                                    Task { await biblioteca.restaurarTudoDaLixeira() }
                                    LixeiraDeTarefas.restaurarTudo(arquivos: biblioteca.arquivos + biblioteca.arquivosNaLixeira)
                                    atualizarPreferenciasVisuais()
                                },
                                aoEsvaziar: {
                                    confirmandoEsvaziarLixeira = true
                                }
                            )
                        }

                        if let biblioteca, biblioteca.processando {
                            SeloDeStatus(
                                texto: "Processamento em andamento",
                                simbolo: "waveform",
                                estilo: .destaque
                            )
                        }
                    }
                }

                if secaoSelecionada == .todos {
                    FiltroDeConversas(
                        selecionado: $filtroSelecionado,
                        pastaSelecionada: $pastaSelecionada,
                        atalhoSelecionado: $atalhoSelecionado,
                        aoLimparAtalhoVisual: limparAtalhoVisual
                    )
                }

                if secaoSelecionada == .todos, filtroSelecionado == .pastas, pastaSelecionada == nil {
                    GradeDePastas(
                        pastas: informacoesDasPastas,
                        selecionada: $pastaSelecionada,
                        aoCriarPasta: abrirCriacaoDePasta
                    )
                    .simultaneousGesture(TapGesture().onEnded { limparAtalhoVisual() })
                }

                if let modelos, !modelos.pronto {
                    CartaoDeModelos(
                        modelos: modelos,
                        aoEscolherPasta: aoEscolherPastaDeModelos,
                        aoUsarPastaDoApp: aoUsarPastaDoApp
                    )
                }

                if gravador.gravando {
                    PainelDeGravacao(
                        waveform: gravador.waveform,
                        tempoDeGravacao: gravador.tempoDeGravacao,
                        pausado: gravador.pausado,
                        aoPausar: aoPausarGravacao,
                        aoContinuar: aoContinuarGravacao,
                        aoFinalizar: aoAlternarGravacao,
                        aoCancelar: aoCancelarGravacao
                    )

                    PainelDeNotasDuranteGravacao(gravador: gravador)
                }

                if !gravador.avisos.isEmpty {
                    AvisosDaGravacao(avisos: gravador.avisos)
                }

                if let falhaDaGravacao {
                    FalhaDaGravacao(mensagem: falhaDaGravacao)
                }

                if !gravador.gravando {
                    gradeDeConversas
                        .simultaneousGesture(TapGesture().onEnded { limparAtalhoVisual() })
                }
            }
            .larguraDeConteudoPapagaio()
            .padding(.horizontal, PapagaioTema.espacamentoDePagina)
            .padding(.vertical, PapagaioTema.espacamentoDePagina)
            .contentShape(Rectangle())
            .simultaneousGesture(TapGesture().onEnded {
                fecharMenu()
            })
        }
        .background(PapagaioTema.fundo)
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded {
            fecharMenu()
        })
        .confirmationDialog(
            "Apagar definitivamente?",
            isPresented: apresentandoConfirmacaoDeExclusao,
            titleVisibility: .visible
        ) {
            if let arquivo = arquivoParaExclusaoDefinitiva {
                Button("Apagar definitivamente", role: .destructive) {
                    arquivoParaExclusaoDefinitiva = nil
                    apagarDefinitivamente(arquivo)
                }
                Button("Cancelar", role: .cancel) {
                    arquivoParaExclusaoDefinitiva = nil
                }
            }
        } message: {
            Text("Essa ação remove o áudio, a transcrição e o resumo do Mac e não pode ser desfeita.")
        }
        .confirmationDialog(
            "Esvaziar lixeira?",
            isPresented: $confirmandoEsvaziarLixeira,
            titleVisibility: .visible
        ) {
            if let biblioteca {
                Button("Esvaziar lixeira", role: .destructive) {
                    Task { await biblioteca.esvaziarLixeira() }
                    LixeiraDeTarefas.esvaziar()
                    atualizarPreferenciasVisuais()
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Essa ação remove permanentemente todos os arquivos da lixeira e não pode ser desfeita.")
        }
        .alert("Não foi possível concluir a operação", isPresented: apresentandoErroDaLixeira) {
            Button("OK", role: .cancel) { biblioteca?.dispensarErroDaLixeira() }
        } message: {
            Text(biblioteca?.erroDaLixeira ?? "")
        }
        .alert("Criar pasta", isPresented: $criandoPasta) {
            TextField("Nome da pasta", text: $novaPasta)
            Button("Criar") {
                let nome = novaPasta.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !nome.isEmpty else { return }
                PreferenciasVisuaisDoArquivo.criarPasta(nome)
                filtroSelecionado = .pastas
                atalhoSelecionado = nil
                atalhoVisualSelecionado = nil
                pastaSelecionada = nome
                novaPasta = ""
                atualizarPreferenciasVisuais()
            }
            Button("Cancelar", role: .cancel) {
                novaPasta = ""
            }
        } message: {
            Text("A pasta ficará disponível para organizar conversas.")
        }
    }

    @ViewBuilder
    private var gradeDeConversas: some View {
        let colunas = [GridItem(.adaptive(minimum: 270, maximum: 380), spacing: PapagaioTema.Espaco.largo, alignment: .top)]
        let colunasDaLixeira = [GridItem(.adaptive(minimum: 270, maximum: 430), spacing: PapagaioTema.Espaco.secao, alignment: .top)]

        switch secaoSelecionada {
        case .todos:
            LazyVGrid(columns: colunas, spacing: PapagaioTema.Espaco.largo) {
                if !gravador.gravando && (filtroSelecionado != .pastas || pastaSelecionada != nil) {
                    CartaoNovaConversa(
                        gravando: gravador.gravando,
                        bloqueado: gravador.estado == .processando,
                        prontoParaEntrada: biblioteca != nil,
                        aoAlternarGravacao: aoAlternarGravacao,
                        aoImportar: { mostrandoImportador = true }
                    )
                }

                ForEach(arquivosFiltrados) { arquivo in
                    if let biblioteca {
                        CartaoDeConversa(
                            arquivo: arquivo,
                            estado: biblioteca.estado(de: arquivo),
                            processando: biblioteca.estaProcessando(arquivo),
                            naFila: biblioteca.estaNaFila(arquivo),
                            emOperacaoDeLixeira: biblioteca.estaEmOperacaoDeLixeira(arquivo),
                            aoReprocessar: { biblioteca.enfileirarProcessamento(arquivo) },
                            aoRenomear: { novoTitulo in Task { await biblioteca.renomear(arquivo, para: novoTitulo) } },
                            aoAtualizarMetadados: { titulo, data, duracao in
                                Task { await biblioteca.atualizarMetadados(arquivo, titulo: titulo, criadoEm: data, duracao: duracao) }
                            },
                            aoDuplicar: {
                                Task {
                                    if let copia = await biblioteca.duplicar(arquivo) {
                                        PreferenciasVisuaisDoArquivo.copiar(de: arquivo.id, para: copia.id)
                                        await MainActor.run {
                                            atualizarPreferenciasVisuais()
                                        }
                                    }
                                }
                            },
                            urlDeAudio: biblioteca.audio(de: arquivo),
                            menuAberto: menuAberto == arquivo.id,
                            aoAlternarMenu: { alternarMenu(de: arquivo) },
                            aoFecharMenu: { fecharMenu() },
                            aoAlterarPreferenciasVisuais: atualizarPreferenciasVisuais,
                            aoMoverParaLixeira: { Task { await biblioteca.moverParaLixeira(arquivo) } }
                        )
                    }
                }
            }

            if !gravador.gravando,
               filtroSelecionado != .pastas || pastaSelecionada != nil,
               biblioteca?.arquivos.isEmpty == false,
               arquivosFiltrados.isEmpty {
                CartaoDeEstadoVazio(
                    simbolo: simboloDoVazio,
                    titulo: tituloDoVazio,
                    mensagem: mensagemDoVazio
                )
                .frame(minHeight: 220)
                .cartaoPapagaio()
            }

            if !gravador.gravando,
               (filtroSelecionado != .pastas || pastaSelecionada != nil),
               biblioteca?.arquivos.isEmpty ?? true {
                Text("A primeira conversa aparecerá aqui depois de gravar ou importar um áudio.")
                    .font(.callout)
                    .foregroundStyle(PapagaioTema.textoSecundario)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, PapagaioTema.Espaco.minimo)
            }

        case .lixeira:
            if (biblioteca?.arquivosNaLixeira.isEmpty ?? true) && tarefasNaLixeira.isEmpty {
                CartaoDeEstadoVazio(
                    simbolo: "trash",
                    titulo: "A lixeira está vazia",
                    mensagem: "Arquivos movidos da biblioteca aparecerão aqui e poderão ser recuperados."
                )
                .frame(minHeight: 280)
                .cartaoPapagaio()
            } else if arquivosFiltrados.isEmpty && tarefasNaLixeira.isEmpty {
                CartaoDeEstadoVazio(
                    simbolo: "magnifyingglass",
                    titulo: "Nenhum arquivo encontrado",
                    mensagem: "Tente buscar por outro título na lixeira."
                )
                .frame(minHeight: 220)
                .cartaoPapagaio()
            } else {
                LazyVGrid(columns: colunasDaLixeira, spacing: PapagaioTema.Espaco.secao) {
                    ForEach(arquivosFiltrados) { arquivo in
                        if let biblioteca {
                            CartaoDaLixeira(
                                arquivo: arquivo,
                                emOperacao: biblioteca.estaEmOperacaoDeLixeira(arquivo),
                                aoRestaurar: { recuperar(arquivo) },
                                aoPedirExclusaoDefinitiva: {
                                    arquivoParaExclusaoDefinitiva = arquivo
                                }
                            )
                        }
                    }

                    ForEach(tarefasNaLixeira) { item in
                        if let biblioteca {
                            CartaoDaTarefaNaLixeira(
                                item: item,
                                aoRestaurar: {
                                    LixeiraDeTarefas.restaurar(item, arquivos: biblioteca.arquivos + biblioteca.arquivosNaLixeira)
                                    atualizarPreferenciasVisuais()
                                },
                                aoApagarDefinitivamente: {
                                    LixeiraDeTarefas.remover(item)
                                    atualizarPreferenciasVisuais()
                                }
                            )
                        }
                    }
                }
            }
        }
    }

    private func alternarMenu(de arquivo: Arquivo) {
        let proximo: ArquivoID? = menuAberto == arquivo.id ? nil : arquivo.id
        DispatchQueue.main.async {
            withAnimation(.snappy(duration: 0.18)) {
                menuAberto = proximo
            }
        }
    }

    private func fecharMenu() {
        withAnimation(.snappy(duration: 0.14)) { menuAberto = nil }
    }

    private func atualizarPreferenciasVisuais() {
        versaoDasPreferenciasVisuais += 1
    }

    private func abrirCriacaoDePasta() {
        novaPasta = ""
        criandoPasta = true
    }

    private var simboloDoVazio: String {
        if pastaSelecionada != nil { return "folder" }
        if atalhoSelecionado == .favoritos { return "star" }
        return "magnifyingglass"
    }

    private var tituloDoVazio: String {
        if let pastaSelecionada { return "A pasta \(pastaSelecionada) está vazia" }
        if atalhoSelecionado == .favoritos { return "Nenhum favorito ainda" }
        return "Nenhuma conversa encontrada"
    }

    private var mensagemDoVazio: String {
        if pastaSelecionada != nil {
            return "Use Mover para pasta no menu de um card para organizar conversas aqui."
        }
        if atalhoSelecionado == .favoritos {
            return "Favorite uma conversa pelo botão de estrela para ela aparecer aqui."
        }
        return "Tente buscar por outro título ou estado de processamento."
    }
}

private enum FiltroDaBiblioteca: String, CaseIterable, Identifiable {
    case todas = "Todas"
    case pastas = "Pastas"

    var id: Self { self }

    var simbolo: String {
        switch self {
        case .todas: "tray.full"
        case .pastas: "folder"
        }
    }
}

private struct FiltroDeConversas: View {
    @Binding var selecionado: FiltroDaBiblioteca
    @Binding var pastaSelecionada: String?
    @Binding var atalhoSelecionado: AtalhoDaBiblioteca?
    let aoLimparAtalhoVisual: () -> Void

    var body: some View {
        HStack(spacing: PapagaioTema.Espaco.largo) {
            ForEach(FiltroDaBiblioteca.allCases) { filtro in
                Button {
                    withAnimation(.snappy(duration: 0.18)) {
                        selecionado = filtro
                        pastaSelecionada = nil
                        atalhoSelecionado = nil
                        aoLimparAtalhoVisual()
                    }
                } label: {
                    Label(filtro.rawValue, systemImage: filtro.simbolo)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(selecionado == filtro ? PapagaioTema.destaqueEscuro : PapagaioTema.textoSecundario)
                }
                .buttonStyle(.plain)
                .help(filtro.rawValue)
                .accessibilityLabel("Mostrar \(filtro.rawValue.localizedLowercase)")
            }
        }
    }
}

private enum AtalhoDaBiblioteca: String, Identifiable {
    case recentes = "Recentes"
    case favoritos = "Favoritos"

    var id: Self { self }
}

private struct AtalhosDaBiblioteca: View {
    @Binding var selecionado: AtalhoDaBiblioteca?
    let aoSelecionarRecentes: () -> Void
    let aoSelecionarFavoritos: () -> Void

    var body: some View {
        HStack(spacing: PapagaioTema.Espaco.largo) {
            Button(action: aoSelecionarRecentes) {
                BotaoTextualDeAtalhoDaBiblioteca(
                    titulo: "Recentes",
                    simbolo: "clock.arrow.circlepath",
                    selecionado: selecionado == .recentes
                )
            }
            .buttonStyle(.plain)
            .help("Recentes")

            Button(action: aoSelecionarFavoritos) {
                BotaoTextualDeAtalhoDaBiblioteca(
                    titulo: "Favoritos",
                    simbolo: selecionado == .favoritos ? "star.fill" : "star",
                    selecionado: selecionado == .favoritos
                )
            }
            .buttonStyle(.plain)
            .help("Favoritos")
        }
        .accessibilityLabel("Atalhos da biblioteca")
    }
}

private struct BotaoTextualDeAtalhoDaBiblioteca: View {
    let titulo: String
    let simbolo: String
    let selecionado: Bool
    @State private var pairando = false

    var body: some View {
        Label(titulo, systemImage: simbolo)
            .font(.callout.weight(.semibold))
            .foregroundStyle(selecionado || pairando ? PapagaioTema.destaqueEscuro : PapagaioTema.textoSecundario)
            .padding(.horizontal, PapagaioTema.Espaco.largo)
            .frame(height: PapagaioTema.Altura.padrao)
            .background(fundo, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(selecionado ? PapagaioTema.destaque.opacity(0.54) : PapagaioTema.borda.opacity(pairando ? 1 : 0.86), lineWidth: 1)
            }
            .contentShape(Capsule())
            .onHover { pairando = $0 }
            .animation(.easeOut(duration: 0.14), value: pairando)
            .animation(.easeOut(duration: 0.14), value: selecionado)
    }

    private var fundo: Color {
        if selecionado { return PapagaioTema.destaqueSuave.opacity(0.76) }
        if pairando { return PapagaioTema.destaqueSuave.opacity(0.42) }
        return PapagaioTema.superficie
    }
}

private struct InformacaoDaPasta: Identifiable {
    let nome: String
    let quantidade: Int
    let duracaoTotal: TimeInterval
    let ultimoArquivo: Date?

    var id: String { nome }
}

private struct GradeDePastas: View {
    let pastas: [InformacaoDaPasta]
    @Binding var selecionada: String?
    let aoCriarPasta: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.medio) {
            HStack {
                Text("Pastas")
                    .font(.headline)
                    .foregroundStyle(PapagaioTema.texto)

                Spacer()

                Button("Nova pasta", systemImage: "folder.badge.plus", action: aoCriarPasta)
                    .buttonStyle(BotaoDeContornoPapagaio())
            }

            if pastas.isEmpty {
                CartaoDeEstadoVazio(
                    simbolo: "folder",
                    titulo: "Nenhuma pasta ainda",
                    mensagem: "Crie uma pasta para organizar conversas por projeto, cliente ou tema."
                )
                .frame(minHeight: 220)
                .cartaoPapagaio()
            } else {
                let colunas = [GridItem(.adaptive(minimum: 250, maximum: 360), spacing: PapagaioTema.Espaco.largo, alignment: .top)]

                LazyVGrid(columns: colunas, spacing: PapagaioTema.Espaco.largo) {
                    ForEach(pastas) { pasta in
                        CartaoDePasta(
                            pasta: pasta,
                            selecionado: selecionada == pasta.nome
                        ) {
                            withAnimation(.snappy(duration: 0.18)) {
                                selecionada = pasta.nome
                            }
                        }
                    }
                }
            }
        }
        .accessibilityLabel("Pastas da biblioteca")
    }
}

private struct CartaoDePasta: View {
    let pasta: InformacaoDaPasta
    let selecionado: Bool
    let acao: () -> Void

    var body: some View {
        Button(action: acao) {
            VStack(alignment: .leading, spacing: PapagaioTema.Espaco.largo) {
                HStack(alignment: .top, spacing: PapagaioTema.Espaco.medio) {
                    Image(systemName: "folder")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(selecionado ? PapagaioTema.destaqueEscuro : PapagaioTema.textoSecundario)
                        .frame(width: 58, height: 58)
                        .background(
                            selecionado ? PapagaioTema.destaqueSuave : PapagaioTema.superficieSuave,
                            in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
                        )

                    VStack(alignment: .leading, spacing: PapagaioTema.Espaco.minimo) {
                        Text(pasta.nome)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(PapagaioTema.texto)
                            .lineLimit(2)

                        Text("Abrir pasta")
                            .font(.callout.weight(.medium))
                            .foregroundStyle(PapagaioTema.textoSecundario)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: PapagaioTema.Espaco.medio) {
                    Label(textoDaQuantidade, systemImage: "doc.text")
                    Label(pasta.duracaoTotal.comoDuracaoPorExtenso, systemImage: "clock")

                    if let ultimoArquivo = pasta.ultimoArquivo {
                        Label(ultimoArquivo.formatted(.dateTime.day().month(.abbreviated)), systemImage: "calendar")
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(PapagaioTema.textoSecundario)
                .lineLimit(1)
            }
            .padding(PapagaioTema.Espaco.largo)
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
            .background(
                selecionado ? PapagaioTema.destaqueSuave.opacity(0.58) : PapagaioTema.superficie,
                in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeCard, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: PapagaioTema.raioDeCard, style: .continuous)
                    .stroke(selecionado ? PapagaioTema.destaque.opacity(0.55) : PapagaioTema.borda, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .help("Abrir pasta \(pasta.nome)")
    }

    private var textoDaQuantidade: String {
        pasta.quantidade == 1 ? "1 conversa" : "\(pasta.quantidade) conversas"
    }

}
private struct CartaoNovaConversa: View {
    let gravando: Bool
    let bloqueado: Bool
    let prontoParaEntrada: Bool
    let aoAlternarGravacao: () async -> Void
    let aoImportar: () -> Void

    var body: some View {
        VStack(spacing: PapagaioTema.Espaco.largo) {
            Image(systemName: "plus")
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(PapagaioTema.destaqueEscuro)
                .frame(width: 64, height: 64)
                .background(PapagaioTema.destaqueSuave, in: Circle())

            VStack(spacing: PapagaioTema.Espaco.minimo) {
                Text("Gerar nova conversa")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(PapagaioTema.texto)
                Text("Grave áudio ou importe um arquivo para transcrever.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(PapagaioTema.textoSecundario)
            }

            if !prontoParaEntrada {
                SeloDeStatus(
                    texto: "Preparando biblioteca",
                    simbolo: "arrow.triangle.2.circlepath",
                    estilo: .neutro
                )
                .accessibilityLabel("Preparando a biblioteca. Gravar e importar estarão disponíveis em instantes.")
            }

            if bloqueado {
                SeloDeStatus(
                    texto: "Preparando áudio",
                    simbolo: "waveform",
                    estilo: .destaque
                )
            }

            // Em coluna estreita os dois botões lado a lado eram espremidos até
            // o rótulo hifenizar ("Impor-tar"). Empilhar é melhor que quebrar
            // a palavra.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: PapagaioTema.Espaco.curto) {
                    botoes
                }

                VStack(spacing: PapagaioTema.Espaco.curto) {
                    botoes
                }
            }
        }
        .padding(PapagaioTema.Espaco.secao)
        .frame(maxWidth: .infinity, minHeight: 260)
        .background(PapagaioTema.superficie.opacity(0.55), in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeCard, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PapagaioTema.raioDeCard, style: .continuous)
                .stroke(
                    PapagaioTema.borda,
                    style: StrokeStyle(lineWidth: 2, dash: [7, 6])
                )
        }
        .accessibilityElement(children: .contain)
    }

    private var botoes: some View {
        Group {
            Button("Gravar", systemImage: "mic.fill") {
                Task { await aoAlternarGravacao() }
            }
            .buttonStyle(BotaoPrincipalPapagaio())
            .disabled(bloqueado || !prontoParaEntrada)

            Button("Importar", systemImage: "arrow.down.doc") {
                aoImportar()
            }
            .buttonStyle(BotaoDeContornoPapagaio())
            .disabled(bloqueado || !prontoParaEntrada)
        }
    }
}

private struct CartaoDeConversa: View {
    let arquivo: Arquivo
    let estado: EstadoDoArquivo
    let processando: Bool
    let naFila: Bool
    let emOperacaoDeLixeira: Bool
    let aoReprocessar: () -> Void
    let aoRenomear: (String) -> Void
    let aoAtualizarMetadados: (String, Date, TimeInterval) -> Void
    let aoDuplicar: () -> Void
    let urlDeAudio: URL
    let menuAberto: Bool
    let aoAlternarMenu: () -> Void
    let aoFecharMenu: () -> Void
    let aoAlterarPreferenciasVisuais: () -> Void
    let aoMoverParaLixeira: () -> Void

    @State private var editandoInformacoes = false
    @State private var escolhendoPastaDestino = false
    @State private var criandoPastaParaMover = false
    @State private var tituloEditado = ""
    @State private var entrevistadoEditado = ""
    @State private var emailDoEntrevistadoEditado = ""
    @State private var entrevistadoresEditados = ""
    @State private var emailDosEntrevistadoresEditado = ""
    @State private var descricaoEditada = ""
    @State private var formatoEditado = ""
    @State private var participantesEditados = ""
    @State private var dataEditada = Date()
    @State private var duracaoEditada = ""
    @State private var nomeDaPasta = ""
    @State private var favorito: Bool
    @State private var pasta: String?
    @State private var capaURL: URL?
    @State private var metadados: MetadadosVisuaisDoArquivo

    init(
        arquivo: Arquivo,
        estado: EstadoDoArquivo,
        processando: Bool,
        naFila: Bool,
        emOperacaoDeLixeira: Bool,
        aoReprocessar: @escaping () -> Void,
        aoRenomear: @escaping (String) -> Void,
        aoAtualizarMetadados: @escaping (String, Date, TimeInterval) -> Void,
        aoDuplicar: @escaping () -> Void,
        urlDeAudio: URL,
        menuAberto: Bool,
        aoAlternarMenu: @escaping () -> Void,
        aoFecharMenu: @escaping () -> Void,
        aoAlterarPreferenciasVisuais: @escaping () -> Void,
        aoMoverParaLixeira: @escaping () -> Void
    ) {
        self.arquivo = arquivo
        self.estado = estado
        self.processando = processando
        self.naFila = naFila
        self.emOperacaoDeLixeira = emOperacaoDeLixeira
        self.aoReprocessar = aoReprocessar
        self.aoRenomear = aoRenomear
        self.aoAtualizarMetadados = aoAtualizarMetadados
        self.aoDuplicar = aoDuplicar
        self.urlDeAudio = urlDeAudio
        self.menuAberto = menuAberto
        self.aoAlternarMenu = aoAlternarMenu
        self.aoFecharMenu = aoFecharMenu
        self.aoAlterarPreferenciasVisuais = aoAlterarPreferenciasVisuais
        self.aoMoverParaLixeira = aoMoverParaLixeira
        _favorito = State(initialValue: PreferenciasVisuaisDoArquivo.favorito(arquivo.id))
        _pasta = State(initialValue: PreferenciasVisuaisDoArquivo.pasta(arquivo.id))
        _capaURL = State(initialValue: PreferenciasVisuaisDoArquivo.capa(arquivo.id))
        _metadados = State(initialValue: PreferenciasVisuaisDoArquivo.metadados(arquivo.id))
    }

    private var titulo: String { arquivo.resumo?.titulo ?? arquivo.titulo }

    /// Só as pessoas que foram realmente preenchidas.
    ///
    /// Antes o cartão imprimia "Não informado" três vezes e dedicava a maior
    /// área da sua superfície a dados ausentes. Campo vazio agora simplesmente
    /// não ocupa espaço — quem preencheu vê a informação em destaque.
    private var pessoasDoCard: [(simbolo: String, rotulo: String, valor: String)] {
        var itens: [(String, String, String)] = []
        let entrevistado = listaDePessoas(metadados.entrevistado)
        if !entrevistado.isEmpty {
            itens.append(("person", "Entrevistado", entrevistado))
        }
        let entrevistadores = listaDePessoas(metadados.entrevistadores)
        if !entrevistadores.isEmpty {
            itens.append(("person.crop.circle.badge.checkmark", "Entrevistadores", entrevistadores))
        }
        return itens
    }

    private var participantes: Int {
        max(1, metadados.participantes ?? participantesDetectados)
    }

    private var participantesDetectados: Int {
        let speakers = Set(arquivo.trechos.compactMap(\.speaker).filter { !$0.isEmpty })
        return max(1, speakers.count)
    }


    var body: some View {
        NavigationLink(value: arquivo.id.rawValue) {
            VStack(alignment: .leading, spacing: 0) {
                CapaDeConversa(arquivo: arquivo, capaURL: capaURL)

                VStack(alignment: .leading, spacing: PapagaioTema.Espaco.medio) {
                    Text(titulo)
                        .font(PapagaioTema.Tipo.tituloDeCard)
                        .foregroundStyle(PapagaioTema.texto)
                        // Reservar as duas linhas mantém os selos e o rodapé na
                        // mesma altura em todos os cartões da fileira. Sem isso
                        // um título de uma linha desalinhava o cartão inteiro em
                        // relação ao vizinho.
                        .lineLimit(2, reservesSpace: true)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing, PapagaioTema.Espaco.secao)

                    if !metadados.descricao.isEmpty {
                        Text(metadados.descricao)
                            .font(PapagaioTema.Tipo.apoio)
                            .foregroundStyle(PapagaioTema.textoSecundario)
                            .lineLimit(2)
                    }

                    // O selo "Áudio local" saiu: era verdadeiro em 100% dos
                    // cartões, então não distinguia nada — só competia por
                    // espaço com o estado, que é a informação que muda.
                    LayoutDeFluxo(espacoHorizontal: PapagaioTema.Espaco.curto, espacoVertical: PapagaioTema.Espaco.curto) {
                        SeloDeStatus(
                            texto: estado.descricao,
                            simbolo: estado.simbolo,
                            estilo: estado.estilo
                        )

                        if let pasta {
                            SeloDeStatus(texto: pasta, simbolo: "folder", estilo: .neutro)
                        }
                    }

                    if !pessoasDoCard.isEmpty {
                        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.minimo) {
                            ForEach(pessoasDoCard, id: \.rotulo) { pessoa in
                                MetadadoDoCard(
                                    simbolo: pessoa.simbolo,
                                    rotulo: pessoa.rotulo,
                                    valor: pessoa.valor
                                )
                            }
                        }
                    }

                    // Data, duração e participantes existem sempre — viram uma
                    // linha de rodapé em vez de três células de grade com
                    // rótulo em maiúscula competindo com o título.
                    LayoutDeFluxo(espacoHorizontal: PapagaioTema.Espaco.medio, espacoVertical: PapagaioTema.Espaco.minimo) {
                        Label(
                            arquivo.criadoEm.formatted(.dateTime.day().month(.abbreviated).year()),
                            systemImage: "calendar"
                        )
                        Label(arquivo.duracao.comoDuracaoPorExtenso, systemImage: "clock")
                        // Conversa de uma pessoa é o caso comum; dizer "1" em
                        // todo cartão só empurrava o rodapé para uma segunda
                        // linha e desalinhava a fileira.
                        if participantes > 1 {
                            Label("\(participantes)", systemImage: "person.2")
                        }
                        if !metadados.formato.isEmpty {
                            Label(
                                metadados.formato,
                                systemImage: metadados.formato == "Presencial" ? "mappin.and.ellipse" : "video"
                            )
                        }
                    }
                    .font(PapagaioTema.Tipo.legenda)
                    .foregroundStyle(PapagaioTema.textoSecundario)
                    .lineLimit(1)
                }
                .padding(PapagaioTema.Espaco.largo)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Conversa \(titulo). \(estado.descricao)")
        // Sem `minHeight` fixo: os 390pt anteriores deixavam ~80pt de área
        // morta no fim de todo cartão, e mais ainda nos de título curto.
        .frame(maxWidth: .infinity, alignment: .top)
        .cartaoPapagaio()
        .overlay(alignment: .topLeading) {
            botaoDeFavoritoDoCard
        }
        .overlay(alignment: .topTrailing) {
            menuDoCard
        }
        .zIndex(menuAberto ? 10 : 0)
        .onAppear(perform: sincronizarPreferenciasVisuais)
        .onChange(of: arquivo.id.rawValue) { _, _ in
            sincronizarPreferenciasVisuais()
        }
        .sheet(isPresented: $editandoInformacoes) {
            EditorDeInformacoesDoCard(
                modo: .edicao,
                titulo: $tituloEditado,
                entrevistado: $entrevistadoEditado,
                emailDoEntrevistado: $emailDoEntrevistadoEditado,
                entrevistadores: $entrevistadoresEditados,
                emailDosEntrevistadores: $emailDosEntrevistadoresEditado,
                descricao: $descricaoEditada,
                formato: $formatoEditado,
                participantes: $participantesEditados,
                data: $dataEditada,
                duracao: $duracaoEditada,
                aoCancelar: { editandoInformacoes = false },
                aoSalvar: salvarInformacoesDoCard
            )
        }
        .confirmationDialog("Mover para pasta", isPresented: $escolhendoPastaDestino) {
            ForEach(PreferenciasVisuaisDoArquivo.pastas(), id: \.self) { nome in
                Button(nome) {
                    moverParaPasta(nome)
                }
            }

            Button("Criar nova pasta…") {
                nomeDaPasta = ""
                criandoPastaParaMover = true
            }

            if pasta != nil {
                Button("Remover da pasta", role: .destructive) {
                    pasta = nil
                    PreferenciasVisuaisDoArquivo.definirPasta(nil, para: arquivo.id)
                    aoAlterarPreferenciasVisuais()
                }
            }

            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Escolha para qual pasta esta conversa deve ir.")
        }
        .alert("Criar pasta e mover", isPresented: $criandoPastaParaMover) {
            TextField("Nome da pasta", text: $nomeDaPasta)
            Button("Criar e mover") {
                let limpa = nomeDaPasta.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !limpa.isEmpty else { return }
                moverParaPasta(limpa)
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Crie uma pasta nova e esta conversa será movida para ela.")
        }
        .overlay {
            if emOperacaoDeLixeira {
                ProgressView("Movendo para a lixeira…")
                    .font(.callout.weight(.medium))
                    .padding(PapagaioTema.Espaco.largo)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))
            }
        }
        .opacity(emOperacaoDeLixeira ? 0.72 : 1)
    }

    @ViewBuilder
    private var menuDoCard: some View {
        ZStack(alignment: .topTrailing) {
            Button {
                if menuAberto {
                    aoFecharMenu()
                } else {
                    aoAlternarMenu()
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(menuAberto ? PapagaioTema.destaqueEscuro : PapagaioTema.textoSecundario)
                    .frame(width: 36, height: 36)
                    .background(PapagaioTema.superficie.opacity(0.92), in: Circle())
                    .overlay {
                        Circle().stroke(menuAberto ? PapagaioTema.destaque.opacity(0.45) : .clear, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .padding(PapagaioTema.Espaco.curto)
            .accessibilityLabel("Ações de \(titulo)")

            if menuAberto {
                MenuDeArquivoAberto(
                    favorito: favorito,
                    bloqueioDeEdicao: processando || naFila || emOperacaoDeLixeira,
                    bloqueioDeLixeira: emOperacaoDeLixeira,
                    aoEditarImagem: executarMenu(editarImagem),
                    aoRenomear: executarMenu(abrirEditorDeInformacoes),
                    aoMoverParaPasta: executarMenu(abrirMoverParaPasta),
                    aoCompartilhar: executarMenu(compartilhar),
                    aoDuplicar: executarMenu(aoDuplicar),
                    aoFavoritar: executarMenu(alternarFavorito),
                    aoMoverParaLixeira: executarMenu(aoMoverParaLixeira)
                )
                .padding(.top, PapagaioTema.Espaco.pagina)
                .padding(.trailing, PapagaioTema.Espaco.curto)
                .transition(.scale(scale: 0.94, anchor: .topTrailing).combined(with: .opacity))
                .zIndex(2)
            }
        }
    }

    private var botaoDeFavoritoDoCard: some View {
        Button(action: alternarFavorito) {
            Image(systemName: favorito ? "star.fill" : "star")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(favorito ? PapagaioTema.destaqueEscuro : PapagaioTema.textoSecundario)
                .frame(width: 36, height: 36)
                .background(PapagaioTema.superficie.opacity(0.92), in: Circle())
                .overlay {
                    Circle().stroke(favorito ? PapagaioTema.destaque.opacity(0.5) : PapagaioTema.borda.opacity(0.9), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .padding(PapagaioTema.Espaco.curto)
        .help(favorito ? "Desfavoritar" : "Favoritar")
        .accessibilityLabel(favorito ? "Desfavoritar conversa" : "Favoritar conversa")
    }

    private func executarMenu(_ acao: @escaping () -> Void) -> () -> Void {
        {
            aoFecharMenu()
            acao()
        }
    }

    private func abrirEditorDeInformacoes() {
        tituloEditado = titulo
        entrevistadoEditado = metadados.entrevistado
        emailDoEntrevistadoEditado = metadados.emailDoEntrevistado
        entrevistadoresEditados = metadados.entrevistadores
        emailDosEntrevistadoresEditado = metadados.emailDosEntrevistadores
        descricaoEditada = metadados.descricao
        formatoEditado = metadados.formato
        participantesEditados = "\(participantes)"
        dataEditada = arquivo.criadoEm
        duracaoEditada = arquivo.duracao.comoDuracaoPorExtenso
        editandoInformacoes = true
    }

    private func salvarInformacoesDoCard() {
        let tituloLimpo = tituloEditado.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tituloLimpo.isEmpty else { return }

        let participantesLimpos = participantesEditados.trimmingCharacters(in: .whitespacesAndNewlines)
        let quantidade = Int(participantesLimpos).map { max(1, $0) }
        let novosMetadados = MetadadosVisuaisDoArquivo(
            entrevistado: entrevistadoEditado.trimmingCharacters(in: .whitespacesAndNewlines),
            emailDoEntrevistado: emailDoEntrevistadoEditado.trimmingCharacters(in: .whitespacesAndNewlines),
            entrevistadores: entrevistadoresEditados.trimmingCharacters(in: .whitespacesAndNewlines),
            emailDosEntrevistadores: emailDosEntrevistadoresEditado.trimmingCharacters(in: .whitespacesAndNewlines),
            descricao: descricaoEditada.trimmingCharacters(in: .whitespacesAndNewlines),
            formato: formatoEditado.trimmingCharacters(in: .whitespacesAndNewlines),
            participantes: quantidade
        )

        metadados = novosMetadados
        PreferenciasVisuaisDoArquivo.definirMetadados(novosMetadados, para: arquivo.id)
        aoAtualizarMetadados(tituloLimpo, dataEditada, TimeInterval.lendo(duracaoEditada) ?? arquivo.duracao)
        aoAlterarPreferenciasVisuais()
        editandoInformacoes = false
    }

    private func abrirMoverParaPasta() {
        let pastas = PreferenciasVisuaisDoArquivo.pastas()
        if pastas.isEmpty {
            nomeDaPasta = ""
            criandoPastaParaMover = true
        } else {
            escolhendoPastaDestino = true
        }
    }

    private func moverParaPasta(_ nome: String) {
        let limpa = nome.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpa.isEmpty else { return }
        pasta = limpa
        PreferenciasVisuaisDoArquivo.definirPasta(limpa, para: arquivo.id)
        aoAlterarPreferenciasVisuais()
    }

    private func alternarFavorito() {
        withAnimation(.snappy(duration: 0.16)) {
            favorito.toggle()
        }
        PreferenciasVisuaisDoArquivo.definirFavorito(favorito, para: arquivo.id)
        aoAlterarPreferenciasVisuais()
    }

    private func sincronizarPreferenciasVisuais() {
        favorito = PreferenciasVisuaisDoArquivo.favorito(arquivo.id)
        pasta = PreferenciasVisuaisDoArquivo.pasta(arquivo.id)
        capaURL = PreferenciasVisuaisDoArquivo.capa(arquivo.id)
        metadados = PreferenciasVisuaisDoArquivo.metadados(arquivo.id)
    }

    private func editarImagem() {
        #if os(macOS)
        let painel = NSOpenPanel()
        painel.title = "Escolha uma imagem para a capa"
        painel.prompt = "Usar imagem"
        painel.canChooseFiles = true
        painel.canChooseDirectories = false
        painel.allowsMultipleSelection = false
        painel.allowedContentTypes = [.image]

        guard painel.runModal() == .OK,
              let url = painel.url,
              url.startAccessingSecurityScopedResource()
        else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            try PreferenciasVisuaisDoArquivo.definirCapa(url, para: arquivo.id)
            capaURL = PreferenciasVisuaisDoArquivo.capa(arquivo.id)
            aoAlterarPreferenciasVisuais()
        } catch {
            capaURL = url
            aoAlterarPreferenciasVisuais()
        }
        #endif
    }

    private func compartilhar() {
        #if os(macOS)
        let itens: [Any] = FileManager.default.fileExists(atPath: urlDeAudio.path)
            ? [urlDeAudio]
            : [titulo]
        let picker = NSSharingServicePicker(items: itens)
        if let view = NSApp.keyWindow?.contentView {
            picker.show(relativeTo: view.bounds, of: view, preferredEdge: .maxY)
        }
        #endif
    }

    private func listaDePessoas(_ texto: String) -> String {
        texto
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}

private struct MenuDeArquivoAberto: View {
    let favorito: Bool
    let bloqueioDeEdicao: Bool
    let bloqueioDeLixeira: Bool
    let aoEditarImagem: () -> Void
    let aoRenomear: () -> Void
    let aoMoverParaPasta: () -> Void
    let aoCompartilhar: () -> Void
    let aoDuplicar: () -> Void
    let aoFavoritar: () -> Void
    let aoMoverParaLixeira: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ItemDoMenuDeArquivo(simbolo: "pencil.and.outline", titulo: "Editar imagem", acao: aoEditarImagem)
            ItemDoMenuDeArquivo(simbolo: "square.and.pencil", titulo: "Editar informações", acao: aoRenomear)
            ItemDoMenuDeArquivo(simbolo: "folder", titulo: "Mover para pasta", acao: aoMoverParaPasta)
            ItemDoMenuDeArquivo(simbolo: "square.and.arrow.up", titulo: "Compartilhar", acao: aoCompartilhar)
            ItemDoMenuDeArquivo(simbolo: "rectangle.on.rectangle", titulo: "Duplicar", desabilitado: bloqueioDeEdicao, acao: aoDuplicar)
            ItemDoMenuDeArquivo(simbolo: favorito ? "star.fill" : "star", titulo: favorito ? "Desfavoritar" : "Favoritar", acao: aoFavoritar)

            SeparadorPapagaio()
                .padding(.horizontal, PapagaioTema.Espaco.medio)
                .padding(.vertical, PapagaioTema.Espaco.minimo)

            ItemDoMenuDeArquivo(
                simbolo: "trash",
                titulo: "Mover para Lixeira",
                destrutivo: true,
                desabilitado: bloqueioDeLixeira,
                acao: aoMoverParaLixeira
            )
        }
        .frame(width: 214)
        .padding(.vertical, PapagaioTema.Espaco.minimo)
        .background(PapagaioTema.superficie, in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
                .stroke(PapagaioTema.borda, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 12, y: 6)
        .shadow(color: PapagaioTema.destaque.opacity(0.12), radius: 4, y: 1)
    }
}

private struct ItemDoMenuDeArquivo: View {
    let simbolo: String
    let titulo: String
    var destrutivo = false
    var desabilitado = false
    let acao: () -> Void

    var body: some View {
        Button(action: acao) {
            HStack(spacing: PapagaioTema.Espaco.medio) {
                Image(systemName: simbolo)
                    .font(.system(size: 15, weight: .regular))
                    .symbolRenderingMode(.monochrome)
                    .frame(width: 18)

                Text(titulo)
                    .font(.system(size: 14, weight: .regular))
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .foregroundStyle(cor.opacity(desabilitado ? 0.42 : 1))
            .padding(.horizontal, PapagaioTema.Espaco.medio)
            .frame(height: PapagaioTema.Altura.padrao)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(desabilitado)
    }

    private var cor: Color {
        destrutivo ? PapagaioTema.perigo : PapagaioTema.textoSecundario
    }
}

private struct MetadadoDoCard: View {
    let simbolo: String
    let rotulo: String
    let valor: String

    /// O rótulo era `caption2.bold` em MAIÚSCULA e o valor `caption` normal —
    /// ou seja, "ENTREVISTADO" pesava mais na página do que o nome da pessoa.
    /// Aqui o valor é que tem cor e peso de texto; o rótulo só orienta.
    var body: some View {
        Label {
            HStack(spacing: PapagaioTema.Espaco.minimo) {
                Text("\(rotulo):")
                    .font(PapagaioTema.Tipo.legenda)
                    .foregroundStyle(PapagaioTema.textoSecundario.opacity(0.8))

                Text(valor)
                    .font(PapagaioTema.Tipo.legenda.weight(.semibold))
                    .foregroundStyle(PapagaioTema.texto)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        } icon: {
            Image(systemName: simbolo)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PapagaioTema.destaqueEscuro)
        }
    }
}

struct EditorDeInformacoesDoCard: View {
    let modo: Modo
    @Binding var titulo: String
    @Binding var entrevistado: String
    @Binding var emailDoEntrevistado: String
    @Binding var entrevistadores: String
    @Binding var emailDosEntrevistadores: String
    @Binding var descricao: String
    @Binding var formato: String
    @Binding var participantes: String
    @Binding var data: Date
    @Binding var duracao: String
    let aoCancelar: () -> Void
    let aoSalvar: () -> Void

    enum Modo {
        case nova
        case edicao

        var titulo: String {
            switch self {
            case .nova: "Nova Entrevista"
            case .edicao: "Editar informações"
            }
        }

        var subtitulo: String {
            switch self {
            case .nova: "Configure os detalhes da sua nova sessão"
            case .edicao: "Atualize os dados que aparecem no card e no cabeçalho."
            }
        }

        var botao: String {
            switch self {
            case .nova: "Continuar"
            case .edicao: "Salvar informações"
            }
        }
    }

    private var podeSalvar: Bool {
        !titulo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: PapagaioTema.Espaco.medio) {
                VStack(alignment: .leading, spacing: PapagaioTema.Espaco.minimo) {
                    Text(modo.titulo)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(PapagaioTema.texto)
                    Text(modo.subtitulo)
                        .font(.callout)
                        .foregroundStyle(PapagaioTema.textoSecundario)
                }

                Spacer()

                Button(action: aoCancelar) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(PapagaioTema.textoSecundario)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
            }
            .padding(PapagaioTema.Espaco.secao)

            SeparadorPapagaio()

            VStack(alignment: .leading, spacing: PapagaioTema.Espaco.secao) {
                campo("Título da entrevista") {
                    TextField("Ex.: Entrevista com Stakeholders - UX Research", text: $titulo)
                        .textFieldStyle(.plain)
                        .campoPapagaio()
                }

                PessoasDaFichaDaEntrevista(
                    titulo: "Entrevistado(s)",
                    nome: $entrevistado,
                    email: $emailDoEntrevistado,
                    placeholderNome: "Ex.: Ana Silva",
                    placeholderEmail: "ana.silva@email.com"
                )

                PessoasDaFichaDaEntrevista(
                    titulo: "Entrevistador(es)",
                    nome: $entrevistadores,
                    email: $emailDosEntrevistadores,
                    placeholderNome: "Ex.: João Santos",
                    placeholderEmail: "joao.santos@empresa.com"
                )

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: PapagaioTema.Espaco.medio) {
                        participantesEDuracao
                    }

                    VStack(alignment: .leading, spacing: PapagaioTema.Espaco.medio) {
                        participantesEDuracao
                    }
                }

                campo("Formato") {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: PapagaioTema.Espaco.curto) {
                            botoesDeFormato
                        }

                        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.curto) {
                            botoesDeFormato
                        }
                    }
                }

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: PapagaioTema.Espaco.medio) {
                        dataEDescricao
                    }

                    VStack(alignment: .leading, spacing: PapagaioTema.Espaco.medio) {
                        dataEDescricao
                    }
                }
            }
            .padding(PapagaioTema.Espaco.secao)

            SeparadorPapagaio()

            HStack(spacing: PapagaioTema.Espaco.medio) {
                Spacer()

                Button("Cancelar", systemImage: "xmark", action: aoCancelar)
                    .buttonStyle(BotaoDeContornoPapagaio())

                Button(modo.botao, systemImage: "arrow.right", action: aoSalvar)
                    .buttonStyle(BotaoPrincipalPapagaio())
                    .disabled(!podeSalvar)

                Spacer()
            }
            .padding(PapagaioTema.Espaco.secao)
            .background(PapagaioTema.superficieSuave.opacity(0.45))
        }
        .frame(minWidth: 360, idealWidth: 720, maxWidth: 780, alignment: .leading)
        .background(PapagaioTema.fundo, in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))
    }

    private var participantesEDuracao: some View {
        Group {
            campo("Participantes") {
                TextField("Ex.: 12", text: $participantes)
                    .textFieldStyle(.plain)
                    .campoPapagaio()
            }

            campo("Duração") {
                TextField("Ex.: 45 min ou 1h 15min", text: $duracao)
                    .textFieldStyle(.plain)
                    .campoPapagaio()
            }
        }
    }

    private var botoesDeFormato: some View {
        Group {
                        BotaoDeFormatoDaEntrevista(
                            titulo: "Online",
                            simbolo: "video",
                            selecionado: formato == "Online"
                        ) {
                            formato = "Online"
                        }

                        BotaoDeFormatoDaEntrevista(
                            titulo: "Presencial",
                            simbolo: "mappin.and.ellipse",
                            selecionado: formato == "Presencial"
                        ) {
                            formato = "Presencial"
                        }
        }
    }

    private var dataEDescricao: some View {
        Group {
            campo("Data") {
                DatePicker("Data", selection: $data, displayedComponents: [.date])
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .frame(height: PapagaioTema.Altura.padrao)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            campo("Descrição (opcional)") {
                TextField("Adicione uma descrição opcional", text: $descricao)
                    .textFieldStyle(.plain)
                    .campoPapagaio()
            }
        }
    }

    private func campo<Conteudo: View>(_ titulo: String, @ViewBuilder conteudo: () -> Conteudo) -> some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.curto) {
            Text(titulo)
                .font(.caption.weight(.bold))
                .foregroundStyle(PapagaioTema.textoSecundario)
            conteudo()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PessoasDaFichaDaEntrevista: View {
    let titulo: String
    @Binding var nome: String
    @Binding var email: String
    let placeholderNome: String
    let placeholderEmail: String

    private var quantidade: Int {
        max(linhas(nome).count, linhas(email).count, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.medio) {
            Text(titulo)
                .font(.caption.weight(.bold))
                .foregroundStyle(PapagaioTema.destaqueEscuro)
                .textCase(.uppercase)

            ForEach(0..<quantidade, id: \.self) { indice in
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: PapagaioTema.Espaco.medio) {
                        camposDaPessoa(indice)
                    }

                    VStack(alignment: .leading, spacing: PapagaioTema.Espaco.curto) {
                        camposDaPessoa(indice)
                    }
                }
            }

            Button {
                adicionarPessoa()
            } label: {
                Label("Adicionar pessoa", systemImage: "plus.circle")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(PapagaioTema.destaqueEscuro)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func camposDaPessoa(_ indice: Int) -> some View {
        Group {
            campo("Nome") {
                TextField(placeholderNome, text: bindingLinha($nome, indice: indice))
                    .textFieldStyle(.plain)
                    .campoPapagaio()
            }

            campo("E-mail") {
                TextField(placeholderEmail, text: bindingLinha($email, indice: indice))
                    .textFieldStyle(.plain)
                    .campoPapagaio()
            }

            if quantidade > 1 {
                        Button {
                            removerPessoa(indice)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(PapagaioTema.textoSecundario)
                                .frame(width: 36, height: 42)
                        }
                        .buttonStyle(.plain)
                        .help("Remover pessoa")
            }
        }
    }

    private func campo<Conteudo: View>(_ titulo: String, @ViewBuilder conteudo: () -> Conteudo) -> some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.curto) {
            Text(titulo)
                .font(.caption.weight(.bold))
                .foregroundStyle(PapagaioTema.textoSecundario)
            conteudo()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bindingLinha(_ texto: Binding<String>, indice: Int) -> Binding<String> {
        Binding(
            get: { valorDaLinha(texto.wrappedValue, indice: indice) },
            set: { novoValor in
                texto.wrappedValue = definirLinha(texto.wrappedValue, indice: indice, valor: novoValor)
            }
        )
    }

    private func adicionarPessoa() {
        nome = adicionarLinha(nome)
        email = adicionarLinha(email)
    }

    private func removerPessoa(_ indice: Int) {
        nome = removerLinha(nome, indice: indice)
        email = removerLinha(email, indice: indice)
    }

    private func linhas(_ texto: String) -> [String] {
        texto.components(separatedBy: .newlines)
    }

    private func valorDaLinha(_ texto: String, indice: Int) -> String {
        let valores = linhas(texto)
        guard valores.indices.contains(indice) else { return "" }
        return valores[indice]
    }

    private func definirLinha(_ texto: String, indice: Int, valor: String) -> String {
        var valores = linhas(texto)
        while valores.count <= indice { valores.append("") }
        valores[indice] = valor
        return valores.joined(separator: "\n")
    }

    private func adicionarLinha(_ texto: String) -> String {
        texto.isEmpty ? "\n" : texto + "\n"
    }

    private func removerLinha(_ texto: String, indice: Int) -> String {
        var valores = linhas(texto)
        guard valores.indices.contains(indice) else { return texto }
        valores.remove(at: indice)
        return valores.joined(separator: "\n")
    }
}

private struct BotaoDeFormatoDaEntrevista: View {
    let titulo: String
    let simbolo: String
    let selecionado: Bool
    let acao: () -> Void

    var body: some View {
        Button(action: acao) {
            Label(titulo, systemImage: simbolo)
                .font(.callout.weight(.semibold))
                .foregroundStyle(selecionado ? PapagaioTema.textoSobrePrimario : PapagaioTema.textoSecundario)
                .frame(maxWidth: .infinity)
                .frame(height: PapagaioTema.Altura.padrao)
                .background(
                    selecionado ? PapagaioTema.preenchimentoPrimario : PapagaioTema.superficie,
                    in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
                        .stroke(selecionado ? Color.clear : PapagaioTema.borda, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

private extension View {
    func campoPapagaio() -> some View {
        self
            .font(.body)
            .padding(.horizontal, PapagaioTema.Espaco.medio)
            .frame(height: PapagaioTema.Altura.padrao)
            .background(PapagaioTema.superficie, in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
                    .stroke(PapagaioTema.borda, lineWidth: 1)
            }
    }
}

struct MetadadosVisuaisDoArquivo: Codable, Equatable {
    var entrevistado: String = ""
    var emailDoEntrevistado: String = ""
    var entrevistadores: String = ""
    var emailDosEntrevistadores: String = ""
    var descricao: String = ""
    var formato: String = ""
    var participantes: Int?
}

enum PreferenciasVisuaisDoArquivo {
    private static let prefixoFavorito = "arquivoFavorito."
    private static let prefixoPasta = "arquivoPasta."
    private static let prefixoCapa = "arquivoCapa."
    private static let prefixoMetadados = "arquivoMetadados."

    static func favorito(_ id: ArquivoID) -> Bool {
        UserDefaults.standard.bool(forKey: prefixoFavorito + id.rawValue.uuidString)
    }

    static func definirFavorito(_ favorito: Bool, para id: ArquivoID) {
        let chave = prefixoFavorito + id.rawValue.uuidString
        if favorito {
            UserDefaults.standard.set(true, forKey: chave)
        } else {
            UserDefaults.standard.removeObject(forKey: chave)
        }
    }

    static func pasta(_ id: ArquivoID) -> String? {
        UserDefaults.standard.string(forKey: prefixoPasta + id.rawValue.uuidString)
    }

    static func definirPasta(_ pasta: String?, para id: ArquivoID) {
        let chave = prefixoPasta + id.rawValue.uuidString
        if let pasta {
            criarPasta(pasta)
            UserDefaults.standard.set(pasta, forKey: chave)
        } else {
            UserDefaults.standard.removeObject(forKey: chave)
        }
    }

    static func criarPasta(_ pasta: String) {
        let nome = pasta.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nome.isEmpty else { return }
        let chave = "pastasDaBiblioteca"
        var pastas = UserDefaults.standard.stringArray(forKey: chave) ?? []
        guard !pastas.contains(where: { $0.localizedCaseInsensitiveCompare(nome) == .orderedSame }) else { return }
        pastas.append(nome)
        pastas.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        UserDefaults.standard.set(pastas, forKey: chave)
    }

    static func pastas() -> [String] {
        UserDefaults.standard.stringArray(forKey: "pastasDaBiblioteca") ?? []
    }

    static func capa(_ id: ArquivoID) -> URL? {
        let chave = prefixoCapa + id.rawValue.uuidString
        guard let dados = UserDefaults.standard.data(forKey: chave) else { return nil }
        var obsoleto = false
        guard let url = try? URL(
            resolvingBookmarkData: dados,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &obsoleto
        ) else {
            UserDefaults.standard.removeObject(forKey: chave)
            return nil
        }
        if obsoleto { try? definirCapa(url, para: id) }
        return url
    }

    static func definirCapa(_ url: URL, para id: ArquivoID) throws {
        let dados = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(dados, forKey: prefixoCapa + id.rawValue.uuidString)
    }

    static func metadados(_ id: ArquivoID) -> MetadadosVisuaisDoArquivo {
        guard let dados = UserDefaults.standard.data(forKey: prefixoMetadados + id.rawValue.uuidString),
              let metadados = try? JSONDecoder().decode(MetadadosVisuaisDoArquivo.self, from: dados)
        else { return MetadadosVisuaisDoArquivo() }
        return metadados
    }

    static func definirMetadados(_ metadados: MetadadosVisuaisDoArquivo, para id: ArquivoID) {
        guard let dados = try? JSONEncoder().encode(metadados) else { return }
        UserDefaults.standard.set(dados, forKey: prefixoMetadados + id.rawValue.uuidString)
    }

    static func copiar(de origem: ArquivoID, para destino: ArquivoID) {
        definirFavorito(favorito(origem), para: destino)
        definirPasta(pasta(origem), para: destino)

        let chaveOrigem = prefixoCapa + origem.rawValue.uuidString
        let chaveDestino = prefixoCapa + destino.rawValue.uuidString
        if let dados = UserDefaults.standard.data(forKey: chaveOrigem) {
            UserDefaults.standard.set(dados, forKey: chaveDestino)
        } else {
            UserDefaults.standard.removeObject(forKey: chaveDestino)
        }

        let chaveMetadadosOrigem = prefixoMetadados + origem.rawValue.uuidString
        let chaveMetadadosDestino = prefixoMetadados + destino.rawValue.uuidString
        if let dados = UserDefaults.standard.data(forKey: chaveMetadadosOrigem) {
            UserDefaults.standard.set(dados, forKey: chaveMetadadosDestino)
        } else {
            UserDefaults.standard.removeObject(forKey: chaveMetadadosDestino)
        }
    }
}

private struct CapaDeConversa: View {
    let arquivo: Arquivo
    let capaURL: URL?

    private var matiz: Double {
        let soma = arquivo.id.rawValue.uuidString.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return Double(soma % 20) / 100
    }

    private var imagemDaCapa: NSImage? {
        #if os(macOS)
        guard let capaURL else { return nil }
        let acessou = capaURL.startAccessingSecurityScopedResource()
        defer {
            if acessou { capaURL.stopAccessingSecurityScopedResource() }
        }
        return NSImage(contentsOf: capaURL)
        #else
        return nil
        #endif
    }

    var body: some View {
        ZStack {
            if let imagem = imagemDaCapa {
                Image(nsImage: imagem)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [
                        PapagaioTema.destaqueSuave,
                        PapagaioTema.destaque.opacity(0.40 + matiz)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(systemName: "waveform")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(PapagaioTema.destaqueEscuro.opacity(0.62))
            }
        }
        // 88 em vez de 116: a capa é decorativa e idêntica em todos os cartões
        // sem imagem própria, então não merece um terço da altura útil.
        .frame(height: 88)
        .clipShape(RoundedRectangle(cornerRadius: PapagaioTema.raioDeCard, style: .continuous))
        .accessibilityHidden(true)
    }
}

private struct PainelDeGravacao: View {
    let waveform: [Float]
    let tempoDeGravacao: TimeInterval
    let pausado: Bool
    let aoPausar: () async -> Void
    let aoContinuar: () async -> Void
    let aoFinalizar: () async -> Void
    let aoCancelar: () async -> Void

    var body: some View {
        HStack(spacing: PapagaioTema.Espaco.largo) {
            Image(systemName: pausado ? "pause.fill" : "mic.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(PapagaioTema.destaqueEscuro)
                .frame(width: 56, height: 56)
                .background(PapagaioTema.destaqueSuave, in: Circle())

            Text(tempoDeGravacao.comoCronometro)
                .font(.system(.title3, design: .monospaced).weight(.semibold))
                .foregroundStyle(PapagaioTema.texto)
                .monospacedDigit()
                .frame(width: 72, alignment: .leading)

            Waveform(amostras: waveform, ativo: !pausado)
                .frame(minWidth: 160, maxWidth: .infinity, minHeight: 48, maxHeight: 48)

            HStack(spacing: PapagaioTema.Espaco.curto) {
                Button(pausado ? "Continuar" : "Pausar", systemImage: pausado ? "play.fill" : "pause.fill") {
                    Task {
                        if pausado {
                            await aoContinuar()
                        } else {
                            await aoPausar()
                        }
                    }
                }
                .buttonStyle(BotaoDeContornoPapagaio())

                Button("Finalizar", systemImage: "stop.fill") {
                    Task { await aoFinalizar() }
                }
                .buttonStyle(BotaoPrincipalPapagaio())

                Button("Cancelar", systemImage: "xmark") {
                    Task { await aoCancelar() }
                }
                .buttonStyle(BotaoDeContornoPapagaio())
                .foregroundStyle(PapagaioTema.perigo)
            }
        }
        .padding(PapagaioTema.Espaco.largo)
        .cartaoPapagaio()
        .accessibilityElement(children: .contain)
    }

}

private struct AvisosDaGravacao: View {
    let avisos: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.curto) {
            ForEach(avisos, id: \.self) { aviso in
                Label(aviso, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(PapagaioTema.aviso)
            }
        }
        .padding(PapagaioTema.Espaco.largo)
        .background(PapagaioTema.aviso.opacity(0.09), in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
                .stroke(PapagaioTema.aviso.opacity(0.36), lineWidth: 1)
        }
    }
}

/// A falha de captura/importação fazia parte do texto de estado da tela
/// anterior. Mantê-la visível evita transformar um erro operacional em um
/// cartão silencioso depois do redesign.
private struct FalhaDaGravacao: View {
    let mensagem: String

    var body: some View {
        Label(mensagem, systemImage: "xmark.octagon.fill")
            .font(.callout)
            .foregroundStyle(PapagaioTema.perigo)
            .padding(PapagaioTema.Espaco.largo)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                PapagaioTema.perigo.opacity(0.09),
                in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
                    .stroke(PapagaioTema.perigo.opacity(0.32), lineWidth: 1)
            }
            .accessibilityElement(children: .combine)
    }
}

/// Aviso de pesos ausentes, preservando as garantias de sandbox do seletor de
/// pasta. A mudança visual não pode antecipar o fim do acesso security-scoped.
private struct CartaoDeModelos: View {
    let modelos: ModelosViewModel
    let aoEscolherPasta: (URL) -> Void
    let aoUsarPastaDoApp: () -> Void
    @State private var escolhendoPasta = false

    var body: some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.medio) {
            HStack(alignment: .top, spacing: PapagaioTema.Espaco.medio) {
                Image(systemName: modelos.resultado?.bloqueia == true ? "exclamationmark.triangle.fill" : "arrow.down.circle.fill")
                    .font(.title2)
                    .foregroundStyle(modelos.resultado?.bloqueia == true ? PapagaioTema.perigo : PapagaioTema.destaqueEscuro)
                VStack(alignment: .leading, spacing: PapagaioTema.Espaco.minimo) {
                    Text("Modelos locais")
                        .font(.headline)
                        .foregroundStyle(PapagaioTema.texto)
                    Text(modelos.resultado?.mensagem ?? "Verificando os modelos…")
                        .font(.callout)
                        .foregroundStyle(PapagaioTema.textoSecundario)
                }
            }

            if let progresso = modelos.progresso {
                ProgressView(value: progresso.fracao) {
                    Text(progresso.peso.nomeArquivo)
                        .font(.caption.weight(.medium))
                } currentValueLabel: {
                    Text("\(gb(progresso.bytesRecebidos)) de \(gb(progresso.bytesTotais))")
                        .font(.caption.monospacedDigit())
                }
                .tint(PapagaioTema.destaque)
            }

            if let erro = modelos.erro {
                Label(erro, systemImage: "xmark.octagon.fill")
                    .font(.caption)
                    .foregroundStyle(PapagaioTema.perigo)
            }

            if modelos.resultado?.bloqueia == false, !modelos.faltando.isEmpty {
                HStack(spacing: PapagaioTema.Espaco.curto) {
                    if modelos.baixando {
                        Button("Cancelar", action: modelos.cancelar)
                            .buttonStyle(BotaoDeContornoPapagaio())
                        Text("O download continua de onde parou se a conexão cair.")
                            .font(.caption)
                            .foregroundStyle(PapagaioTema.textoSecundario)
                    } else {
                        if modelos.pastaEscolhida == nil {
                            Button("Baixar modelos (\(gb(totalFaltando)))", action: modelos.baixar)
                                .buttonStyle(BotaoPrincipalPapagaio())
                        }
                        Button("Escolher pasta…") { escolhendoPasta = true }
                            .buttonStyle(BotaoDeContornoPapagaio())
                        if modelos.pastaEscolhida != nil {
                            Button("Usar pasta do app", action: aoUsarPastaDoApp)
                                .buttonStyle(BotaoDeContornoPapagaio())
                        }
                    }
                }

                Text(descricaoDaPasta)
                    .font(.caption)
                    .foregroundStyle(PapagaioTema.textoSecundario)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(PapagaioTema.Espaco.largo)
        .cartaoPapagaio()
        .fileImporter(
            isPresented: $escolhendoPasta,
            allowedContentTypes: [.folder]
        ) { resultado in
            guard case let .success(url) = resultado,
                  url.startAccessingSecurityScopedResource()
            else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            aoEscolherPasta(url)
        }
    }

    private var totalFaltando: Int64 {
        modelos.faltando.reduce(0) { $0 + $1.bytes }
    }

    private var descricaoDaPasta: String {
        if let escolhida = modelos.pastaEscolhida {
            return "Pasta ativa: \(escolhida.path)"
        }
        return "Você também pode apontar uma pasta que já tenha os modelos GGUF."
    }

    private func gb(_ bytes: Int64) -> String {
        String(format: "%.1f GB", Double(bytes) / 1_073_741_824)
    }
}

/// Waveform leve: o caminho é o único elemento que recebe atualizações a
/// ~20 Hz durante a captura, evitando efeitos de layout ou animações caras.
struct Waveform: View {
    let amostras: [Float]
    let ativo: Bool

    var body: some View {
        GeometryReader { geometria in
            let largura = geometria.size.width
            let altura = geometria.size.height
            let passo = amostras.isEmpty ? 0 : largura / CGFloat(amostras.count)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
                    .fill(PapagaioTema.superficieSuave)

                Path { caminho in
                    for (indice, amostra) in amostras.enumerated() {
                        let x = CGFloat(indice) * passo
                        let alturaBarra = max(2, CGFloat(amostra) * altura * 0.78)
                        caminho.addRect(
                            CGRect(
                                x: x,
                                y: (altura - alturaBarra) / 2,
                                width: max(1, passo * 0.58),
                                height: alturaBarra
                            )
                        )
                    }
                }
                .fill(ativo ? PapagaioTema.destaque : PapagaioTema.textoSecundario.opacity(0.5))
            }
        }
        .accessibilityHidden(true)
    }
}
