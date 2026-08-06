import PapagaioCore
import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Superfície do Passo 10: ouvir a gravação e navegar por trecho.
///
/// Clicar num trecho salta o áudio para o `start` dele; o trecho que está
/// tocando fica destacado e a lista rola sozinha até ele.
struct ArquivoDetalheView: View {
    let arquivo: Arquivo
    let audio: URL
    /// Canal do sistema (`sistema.m4a`) para reprodução em paralelo ao
    /// microfone — `nil` para importado e gravação legada, que têm canal único.
    let audioSecundario: URL?
    /// Texto de status vindo da `Biblioteca` — "transcrevendo…", um erro, ou
    /// "transcrito e resumido".
    let estado: String
    let processando: Bool
    let naFila: Bool
    let responsaveisDisponiveis: [ResponsavelDaTarefa]
    let aoTranscrever: () -> Void
    let aoAtualizarNotas: ([NotaDaConversa]) async -> Void
    let aoNotificarTarefa: (_ titulo: String, _ mensagem: String) -> Void

    @State private var reprodutor: ReprodutorDeArquivo?
    @State private var secaoSelecionada: SecaoDoDetalhe = .resumo
    @State private var mostrandoPlayer = false
    @State private var tempoEmEdicao: TimeInterval?
    @State private var mostrandoExportador = false
    @State private var erroDeExportacao: String?
    @State private var notasEditaveis: [NotaDaConversa] = []
    @State private var textoDasNotas = ""
    @State private var notaLivreCritica = false
    @State private var notaLivreID: UUID?
    @State private var estadoDeSalvamentoDasNotas = "Salvo"
    @State private var tarefaDeSalvamentoDasNotas: Task<Void, Never>?
    @State private var anexosDeMidia: [AnexoDeMidiaDaConversa] = []
    @State private var erroDeMidia: String?
    @State private var tarefasDaConversa: [TarefaDaConversa] = []
    @State private var filtroDeTarefas: FiltroDeTarefas = .tudo
    @State private var mostrandoCriacaoDeTarefa = false
    @State private var tituloDaNovaTarefa = ""
    @State private var responsavelDaNovaTarefa = ""
    @State private var prioridadeDaNovaTarefa: PrioridadeDaTarefa = .media
    @State private var statusDaNovaTarefa: StatusDaTarefa = .emAndamento
    @State private var prazoDaNovaTarefa = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var mostrandoEdicaoDeTarefa = false
    @State private var tarefaEmEdicaoID: UUID?
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    private var titulo: String { arquivo.resumo?.titulo ?? arquivo.titulo }
    private var metadados: MetadadosVisuaisDoArquivo {
        PreferenciasVisuaisDoArquivo.metadados(arquivo.id)
    }
    private var entrevistado: String {
        let valor = listaDePessoas(metadados.entrevistado)
        return valor.isEmpty ? "Não informado" : valor
    }
    private var entrevistadores: String {
        let valor = listaDePessoas(metadados.entrevistadores)
        return valor.isEmpty ? "Não informado" : valor
    }
    private var participantes: Int {
        max(1, metadados.participantes ?? participantesDetectados)
    }
    private var participantesDetectados: Int {
        let speakers = Set(arquivo.trechos.compactMap(\.speaker).filter { !$0.isEmpty })
        return max(1, speakers.count)
    }
    private var trechos: [Trecho] { arquivo.trechos }
    private var notas: [NotaDaConversa] { notasEditaveis }
    private var marcadoresDaConversa: [NotaDaConversa] {
        notasEditaveis.filter { $0.tipo == .marcador }
    }
    private var podeIniciarTranscricao: Bool {
        trechos.isEmpty && !processando && !naFila
    }
    private var exibindoEstadoVazio: Bool {
        switch secaoSelecionada {
        case .resumo:
            arquivo.resumo == nil
        case .transcricao:
            trechos.isEmpty
        case .notas:
            notas.isEmpty
        case .midia:
            false
        case .tarefas:
            false
        }
    }
    private var animacaoDeInterface: Animation? {
        reduzirMovimento ? nil : .easeInOut(duration: 0.2)
    }
    private var deveMostrarPlayer: Bool {
        mostrandoPlayer || secaoSelecionada == .transcricao
    }
    private var pastaDaConversa: URL {
        audio.deletingLastPathComponent()
    }
    private var estiloDoEstado: EstiloDoStatus {
        let texto = estado.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

        if texto.contains("falhou") || texto.contains("erro") {
            return .erro
        }
        if texto.contains("transcrito e resumido") {
            return .sucesso
        }
        if texto.contains("aguardando") || texto.contains("fila") {
            return .aviso
        }
        if texto.contains("transcrevendo") || texto.contains("resumindo") || texto.contains("processando") {
            return .destaque
        }
        return .neutro
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 24) {
                cabecalho

                seletorDeSecao

                GeometryReader { _ in
                    if exibindoEstadoVazio {
                        conteudoDaSecao
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            conteudoDaSecao
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                                .padding(.bottom, deveMostrarPlayer ? 116 : 0)
                        }
                    }
                }
            }
            .larguraDeConteudoPapagaio()
            .padding(.horizontal, PapagaioTema.espacamentoDePagina)
            .padding(.vertical, PapagaioTema.espacamentoDePagina)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if deveMostrarPlayer, let reprodutor {
                barraFlutuante(reprodutor)
                    .transition(
                        reduzirMovimento
                            ? .opacity
                            : .move(edge: .bottom).combined(with: .opacity)
                    )
            }
        }
        .background(PapagaioTema.fundo)
        .frame(minWidth: 390, minHeight: 420, alignment: .topLeading)
        .navigationTitle(titulo)
        .toolbar {
            ToolbarItem {
                Button("Exportar Markdown…", systemImage: "square.and.arrow.up") {
                    mostrandoExportador = true
                }
                .tint(PapagaioTema.destaqueEscuro)
                .disabled(arquivo.resumo == nil)
                .accessibilityHint(
                    arquivo.resumo == nil
                        ? "Disponível depois que o resumo estiver pronto."
                        : "Exporta o resumo e uma cópia do áudio."
                )
            }
        }
        .task {
            sincronizarNotasComArquivo()
            carregarMidias()
            carregarTarefas()
            let novo = ReprodutorDeArquivo(audio: audio, trechos: trechos, secundario: audioSecundario)
            await novo.preparar()
            reprodutor = novo
        }
        .onChange(of: trechos) { _, novos in
            // A transcrição chega minutos depois de a tela abrir. Atualizar em
            // vez de recriar mantém a posição de escuta.
            reprodutor?.trechos = novos
        }
        .onDisappear {
            // Sem isto o observador periódico sobrevive à view — critério de
            // aceite do Passo 10.
            tarefaDeSalvamentoDasNotas?.cancel()
            salvarNotasAgora()
            reprodutor?.encerrar()
            reprodutor = nil
        }
        .fileExporter(
            isPresented: $mostrandoExportador,
            document: DocumentoMarkdown(conteudo: ExportacaoMarkdown.gerar(arquivo: arquivo)),
            contentType: DocumentoMarkdown.tipo,
            defaultFilename: ExportacaoMarkdown.nomeDeArquivo(para: arquivo)
        ) { resultado in
            guard case let .success(url) = resultado else { return }
            copiarAudioAnexo(para: url)
        }
        .alert("Não foi possível exportar o áudio", isPresented: Binding(
            get: { erroDeExportacao != nil },
            set: { if !$0 { erroDeExportacao = nil } }
        )) {
            Button("OK", role: .cancel) { erroDeExportacao = nil }
        } message: {
            Text(erroDeExportacao ?? "")
        }
        .alert("Não foi possível adicionar a mídia", isPresented: Binding(
            get: { erroDeMidia != nil },
            set: { if !$0 { erroDeMidia = nil } }
        )) {
            Button("OK", role: .cancel) { erroDeMidia = nil }
        } message: {
            Text(erroDeMidia ?? "")
        }
        .sheet(isPresented: $mostrandoCriacaoDeTarefa) {
            NovaTarefaDaConversaSheet(
                modo: .criacao,
                titulo: $tituloDaNovaTarefa,
                responsavel: $responsavelDaNovaTarefa,
                prioridade: $prioridadeDaNovaTarefa,
                status: $statusDaNovaTarefa,
                prazo: $prazoDaNovaTarefa,
                responsaveisDisponiveis: responsaveisDisponiveis,
                aoCancelar: cancelarCriacaoDeTarefa,
                aoAdicionar: adicionarTarefa
            )
        }
        .sheet(isPresented: $mostrandoEdicaoDeTarefa) {
            NovaTarefaDaConversaSheet(
                modo: .edicao,
                titulo: $tituloDaNovaTarefa,
                responsavel: $responsavelDaNovaTarefa,
                prioridade: $prioridadeDaNovaTarefa,
                status: $statusDaNovaTarefa,
                prazo: $prazoDaNovaTarefa,
                responsaveisDisponiveis: responsaveisDisponiveis,
                aoCancelar: cancelarEdicaoDeTarefa,
                aoAdicionar: salvarEdicaoDeTarefa
            )
        }
    }

    // MARK: - Navegação por conteúdo

    private var cabecalho: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .bottom, spacing: 20) {
                textoDoCabecalho
                Spacer(minLength: 16)
                seloDoCabecalho
            }

            VStack(alignment: .leading, spacing: 12) {
                textoDoCabecalho
                seloDoCabecalho
            }
        }
    }

    private var textoDoCabecalho: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(titulo)
                .font(.system(size: 30, weight: .bold, design: .default))
                .foregroundStyle(PapagaioTema.texto)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            if !metadados.descricao.isEmpty {
                Text(metadados.descricao)
                    .font(.callout)
                    .foregroundStyle(PapagaioTema.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 180), spacing: 10, alignment: .leading)],
                alignment: .leading,
                spacing: 8
            ) {
                metadadoDoCabecalho("Entrevistado: \(entrevistado)", simbolo: "person")
                metadadoDoCabecalho("Entrevistadores: \(entrevistadores)", simbolo: "person.crop.circle.badge.checkmark")
                if !metadados.formato.isEmpty {
                    metadadoDoCabecalho(metadados.formato, simbolo: metadados.formato == "Presencial" ? "mappin.and.ellipse" : "video")
                }
                metadadoDoCabecalho("\(participantes) participantes", simbolo: "person.2")
                metadadoDoCabecalho(arquivo.criadoEm.formatted(.dateTime.day().month(.wide).year()), simbolo: "calendar")
                metadadoDoCabecalho(tempoCurto(arquivo.duracao), simbolo: "clock")
            }
        }
    }

    private var seloDoCabecalho: some View {
        SeloDeStatus(
            texto: estado,
            simbolo: "waveform",
            estilo: estiloDoEstado
        )
    }

    private func metadadoDoCabecalho(_ texto: String, simbolo: String) -> some View {
        Label(texto, systemImage: simbolo)
            .font(.callout.weight(.medium))
            .foregroundStyle(PapagaioTema.textoSecundario)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var seletorDeSecao: some View {
        BarraDeSecoesDaConversa(secaoSelecionada: secaoSelecionada) { secao in
            withAnimation(animacaoDeInterface) {
                secaoSelecionada = secao
            }
        }
    }

    @ViewBuilder
    private var conteudoDaSecao: some View {
        switch secaoSelecionada {
        case .resumo:
            resumo
        case .transcricao:
            transcricao
        case .notas:
            notasDaConversa
        case .midia:
            midia
        case .tarefas:
            tarefas
        }
    }

    // MARK: - Resumo

    @ViewBuilder
    private var resumo: some View {
        if let resumo = arquivo.resumo {
            VStack(alignment: .leading, spacing: 12) {
                Text(resumo.visaoGeral)
                    .font(.body)
                    .foregroundStyle(PapagaioTema.texto)

                if !resumo.temas.isEmpty {
                    secao("Temas") {
                        ForEach(Array(resumo.temas.enumerated()), id: \.offset) { _, tema in
                            VStack(alignment: .leading, spacing: 1) {
                                Text(tema.titulo)
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(PapagaioTema.texto)
                                Text(tema.detalhe)
                                    .font(.callout)
                                    .foregroundStyle(PapagaioTema.textoSecundario)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                if !resumo.citacoes.isEmpty {
                    secao("Citações") {
                        ForEach(Array(resumo.citacoes.enumerated()), id: \.offset) { _, citacao in
                            citacaoClicavel(citacao)
                        }
                    }
                }

            }
            .padding(24)
            .cartaoPapagaio()
        } else {
            CartaoDeEstadoVazio(
                simbolo: "text.alignleft",
                titulo: "Resumo indisponível",
                mensagem: "O resumo aparecerá depois do processamento."
            )
        }
    }

    private var tarefas: some View {
        TarefasDaConversaView(
            tarefas: tarefasDaConversa,
            filtro: $filtroDeTarefas,
            aoAdicionar: { mostrandoCriacaoDeTarefa = true },
            aoAlternarConclusao: alternarConclusaoDaTarefa,
            aoEditar: iniciarEdicaoDaTarefa,
            aoMover: moverTarefa
        )
    }

    private func secao<Conteudo: View>(
        _ titulo: String, @ViewBuilder _ conteudo: () -> Conteudo
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titulo)
                .font(.headline)
                .foregroundStyle(PapagaioTema.texto)
            conteudo()
        }
        .padding(.top, 8)
    }

    /// A citação tem âncora de tempo — clicar leva o áudio até a origem dela.
    /// O `start` vem do modelo e pode ser inventado (R-14), então só vira botão
    /// quando cai dentro da duração do arquivo.
    @ViewBuilder
    private func citacaoClicavel(_ citacao: Citacao) -> some View {
        let ancora = citacao.start.flatMap { inicio in
            trechos.contains { inicio >= $0.start && inicio <= $0.end } ? inicio : nil
        }
        HStack(alignment: .top, spacing: 8) {
            Rectangle()
                .frame(width: 3)
                .foregroundStyle(PapagaioTema.destaque)
            VStack(alignment: .leading, spacing: 2) {
                Text(citacao.texto)
                    .font(.callout)
                    .italic()
                    .foregroundStyle(PapagaioTema.texto)
                if let ancora {
                    Button(tempoCurto(ancora)) {
                        Task { await reprodutor?.saltar(paraSegundo: ancora) }
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                    .tint(PapagaioTema.destaqueEscuro)
                }
            }
        }
        .padding(12)
        .background(PapagaioTema.destaqueSuave.opacity(0.42), in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))
    }

    // MARK: - Mídia

    private var midia: some View {
        MidiaDaConversaView(
            anexos: anexosDeMidia,
            aoAdicionar: selecionarMidias,
            aoAbrir: abrirMidia,
            aoRemover: removerMidia
        )
    }

    private func carregarMidias() {
        anexosDeMidia = MidiasDaConversa.carregar(arquivo.id)
    }

    private func selecionarMidias() {
        let painel = NSOpenPanel()
        painel.title = "Adicionar mídia"
        painel.prompt = "Adicionar"
        painel.message = "Escolha fotos, vídeos, áudios, PDFs ou outros arquivos para salvar nesta conversa."
        painel.canChooseFiles = true
        painel.canChooseDirectories = false
        painel.allowsMultipleSelection = true
        painel.resolvesAliases = true

        guard painel.runModal() == .OK else { return }

        for url in painel.urls {
            adicionarMidia(url)
        }
    }

    private func adicionarMidia(_ url: URL) {
        let acessando = url.startAccessingSecurityScopedResource()
        defer {
            if acessando { url.stopAccessingSecurityScopedResource() }
        }

        do {
            let destino = try MidiasDaConversa.copiar(url, para: pastaDaConversa)
            let anexo = try MidiasDaConversa.anexo(para: destino)
            var atualizados = anexosDeMidia.filter { $0.url != anexo.url }
            atualizados.append(anexo)
            atualizados.sort { $0.data > $1.data }
            try MidiasDaConversa.salvar(atualizados, para: arquivo.id)
            anexosDeMidia = atualizados
        } catch {
            erroDeMidia = mensagemAmigavelParaArquivo(error)
        }
    }

    private func abrirMidia(_ anexo: AnexoDeMidiaDaConversa) {
        NSWorkspace.shared.open(anexo.url)
    }

    private func removerMidia(_ anexo: AnexoDeMidiaDaConversa) {
        let atualizados = anexosDeMidia.filter { $0.id != anexo.id }
        do {
            try? MidiasDaConversa.apagarArquivoSalvo(anexo, pastaDaConversa: pastaDaConversa)
            try MidiasDaConversa.salvar(atualizados, para: arquivo.id)
            anexosDeMidia = atualizados
        } catch {
            erroDeMidia = "Não foi possível remover esse arquivo: \(error.localizedDescription)"
        }
    }

    // MARK: - Tarefas

    private func carregarTarefas() {
        let carregadas = TarefasDaConversa.carregar(
            arquivo.id,
            base: arquivo.resumo?.proximosPassos ?? [],
            tituloDaConversa: titulo,
            dataDaConversa: arquivo.criadoEm
        )
        let ajustadas = carregadas.map { tarefaAjustadaPeloPrazo($0) }
        tarefasDaConversa = ajustadas
        if ajustadas != carregadas {
            salvarTarefas()
        }
    }

    private func adicionarTarefa() {
        let tituloLimpo = tituloDaNovaTarefa.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tituloLimpo.isEmpty else { return }

        let tarefa = tarefaAjustadaPeloPrazo(
            TarefaDaConversa(
                titulo: tituloLimpo,
                origem: titulo,
                prioridade: prioridadeDaNovaTarefa,
                status: statusDaNovaTarefa,
                responsavel: responsavelLimpo,
                prazo: prazoDaNovaTarefa
            )
        )
        tarefasDaConversa.append(tarefa)
        salvarTarefas()
        notificarPrazoSeNecessario(tarefa)
        limparNovaTarefa()
        mostrandoCriacaoDeTarefa = false
    }

    private func cancelarCriacaoDeTarefa() {
        limparNovaTarefa()
        mostrandoCriacaoDeTarefa = false
    }

    private func iniciarEdicaoDaTarefa(_ tarefa: TarefaDaConversa) {
        tarefaEmEdicaoID = tarefa.id
        tituloDaNovaTarefa = tarefa.titulo
        responsavelDaNovaTarefa = tarefa.responsavel ?? ""
        prioridadeDaNovaTarefa = tarefa.prioridade
        statusDaNovaTarefa = tarefa.status
        prazoDaNovaTarefa = tarefa.prazo ?? Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        mostrandoEdicaoDeTarefa = true
    }

    private func salvarEdicaoDeTarefa() {
        let tituloLimpo = tituloDaNovaTarefa.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tituloLimpo.isEmpty,
              let tarefaEmEdicaoID,
              let indice = tarefasDaConversa.firstIndex(where: { $0.id == tarefaEmEdicaoID })
        else { return }

        var tarefa = tarefasDaConversa[indice]
        tarefa.titulo = tituloLimpo
        tarefa.responsavel = responsavelLimpo
        tarefa.prioridade = prioridadeDaNovaTarefa
        tarefa.status = statusDaNovaTarefa
        tarefa.prazo = prazoDaNovaTarefa
        tarefa = tarefaAjustadaPeloPrazo(tarefa)
        tarefasDaConversa[indice] = tarefa
        salvarTarefas()
        notificarPrazoSeNecessario(tarefa)
        cancelarEdicaoDeTarefa()
    }

    private func cancelarEdicaoDeTarefa() {
        tarefaEmEdicaoID = nil
        limparNovaTarefa()
        mostrandoEdicaoDeTarefa = false
    }

    private func limparNovaTarefa() {
        tituloDaNovaTarefa = ""
        responsavelDaNovaTarefa = ""
        prioridadeDaNovaTarefa = .media
        statusDaNovaTarefa = .emAndamento
        prazoDaNovaTarefa = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    }

    private var responsavelLimpo: String? {
        let valor = responsavelDaNovaTarefa.trimmingCharacters(in: .whitespacesAndNewlines)
        return valor.isEmpty ? nil : valor
    }

    private func alternarConclusaoDaTarefa(_ tarefa: TarefaDaConversa) {
        guard let indice = tarefasDaConversa.firstIndex(where: { $0.id == tarefa.id }) else { return }
        tarefasDaConversa[indice].status = tarefasDaConversa[indice].status == .concluida ? .emAndamento : .concluida
        salvarTarefas()
    }

    private func moverTarefa(_ id: UUID, para destino: DestinoDeTarefa) {
        guard let indice = tarefasDaConversa.firstIndex(where: { $0.id == id }) else { return }
        if let prioridade = destino.prioridade {
            tarefasDaConversa[indice].prioridade = prioridade
        }
        tarefasDaConversa[indice].status = destino.status
        tarefasDaConversa[indice] = tarefaAjustadaPeloPrazo(tarefasDaConversa[indice])
        salvarTarefas()
        notificarPrazoSeNecessario(tarefasDaConversa[indice])
    }

    private func salvarTarefas() {
        TarefasDaConversa.salvar(tarefasDaConversa, para: arquivo.id)
    }

    private func tarefaAjustadaPeloPrazo(_ tarefa: TarefaDaConversa) -> TarefaDaConversa {
        var ajustada = tarefa
        guard ajustada.status != .concluida, prazoEstaPerto(ajustada.prazo) else { return ajustada }
        ajustada.prioridade = .alta
        return ajustada
    }

    private func prazoEstaPerto(_ prazo: Date?) -> Bool {
        guard let prazo else { return false }
        let calendario = Calendar.current
        let hoje = calendario.startOfDay(for: Date())
        let diaDoPrazo = calendario.startOfDay(for: prazo)
        let dias = calendario.dateComponents([.day], from: hoje, to: diaDoPrazo).day ?? Int.max
        return dias <= 2
    }

    private func notificarPrazoSeNecessario(_ tarefa: TarefaDaConversa) {
        guard tarefa.status != .concluida, prazoEstaPerto(tarefa.prazo) else { return }
        let data = tarefa.prazo?.formatted(.dateTime.day().month().year()) ?? "em breve"
        aoNotificarTarefa(
            "Prazo perto",
            "\(tarefa.titulo) vence \(data) e foi marcada como prioridade alta."
        )
    }

    private func revelarPlayer() {
        guard !mostrandoPlayer else { return }
        withAnimation(animacaoDeInterface) {
            mostrandoPlayer = true
        }
    }

    private func tocar(_ trecho: Trecho, no reprodutor: ReprodutorDeArquivo) {
        tempoEmEdicao = nil
        revelarPlayer()
        Task { @MainActor in
            await reprodutor.tocar(aPartirDe: trecho)
        }
    }

    private func tocar(_ nota: NotaDaConversa) {
        guard let reprodutor else { return }
        let inicio = min(max(0, nota.start), reprodutor.duracao)
        revelarPlayer()
        Task { @MainActor in
            await reprodutor.saltar(paraSegundo: inicio)
            reprodutor.tocar()
        }
    }

    private func concluirEdicaoDaPosicao(_ reprodutor: ReprodutorDeArquivo) {
        guard let destino = tempoEmEdicao else { return }
        Task { @MainActor in
            await reprodutor.saltar(paraSegundo: destino)
            tempoEmEdicao = nil
        }
    }

    private func barraFlutuante(_ reprodutor: ReprodutorDeArquivo) -> some View {
        BarraDeAudioDaConversa(
            titulo: titulo,
            data: arquivo.criadoEm,
            reprodutor: reprodutor,
            tempoEmEdicao: $tempoEmEdicao,
            aoConcluirEdicao: { concluirEdicaoDaPosicao(reprodutor) }
        )
    }

    // MARK: - Transcrição

    @ViewBuilder
    private var notasDaConversa: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                EditorDeNotasDaConversa(
                    texto: $textoDasNotas,
                    notaCritica: $notaLivreCritica,
                    estadoDeSalvamento: estadoDeSalvamentoDasNotas,
                    aoInserirMarcador: inserirMarcadorNasNotas,
                    aoMarcarComoCritico: alternarCriticidadeDaNotaLivre,
                    aoAplicarFormato: aplicarFormatoNasNotas
                )
                .onChange(of: textoDasNotas) { _, _ in
                    agendarSalvamentoDasNotas()
                }

                if !marcadoresDaConversa.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Marcadores da conversa")
                            .font(.headline)
                            .foregroundStyle(PapagaioTema.texto)

                        ListaDeNotasDaConversa(notas: marcadoresDaConversa, aoSelecionar: tocar)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func sincronizarNotasComArquivo() {
        let notasDoArquivo = arquivo.notas
        let marcadores = notasDoArquivo.filter { $0.tipo == .marcador }
        let notaLivre = notasDoArquivo.first { $0.tipo == .nota && $0.start == 0 }
        let anotacoesDaGravacao = notasDoArquivo
            .filter { $0.tipo == .nota && $0.start > 0 }
            .sorted { $0.start < $1.start }

        var textoInicial = notaLivre?.texto ?? ""
        var migrouAnotacoesDaGravacao = false

        if !anotacoesDaGravacao.isEmpty {
            let linhas = anotacoesDaGravacao.map { linhaDeNotaGravada($0) }
            let novasLinhas = linhas.filter { !textoInicial.contains($0) }
            if !novasLinhas.isEmpty {
                let separador = textoInicial.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : "\n"
                textoInicial += "\(separador)\(novasLinhas.joined(separator: "\n"))"
                migrouAnotacoesDaGravacao = true
            }
        }

        textoDasNotas = textoInicial
        notaLivreCritica = notaLivre?.critica ?? anotacoesDaGravacao.contains { $0.critica }
        notaLivreID = notaLivre?.id

        notasEditaveis = marcadores

        if !textoInicial.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            notasEditaveis.insert(
                NotaDaConversa(
                    id: notaLivre?.id ?? UUID(),
                    texto: textoInicial,
                    start: 0,
                    critica: notaLivreCritica,
                    tipo: .nota
                ),
                at: 0
            )
            notaLivreID = notasEditaveis.first { $0.tipo == .nota && $0.start == 0 }?.id
        }

        if migrouAnotacoesDaGravacao {
            salvarNotasAgora()
        }
    }

    private func linhaDeNotaGravada(_ nota: NotaDaConversa) -> String {
        "[\(tempoCurto(nota.start))] \(nota.texto)"
    }

    private func agendarSalvamentoDasNotas() {
        tarefaDeSalvamentoDasNotas?.cancel()
        estadoDeSalvamentoDasNotas = "Salvando..."
        tarefaDeSalvamentoDasNotas = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 650_000_000)
            guard !Task.isCancelled else { return }
            salvarNotasAgora()
        }
    }

    private func salvarNotasAgora() {
        let atualizadas = notasAtualizadasComTextoLivre()
        notaLivreID = atualizadas.first(where: { $0.tipo == .nota && $0.start == 0 })?.id
        notasEditaveis = atualizadas
        estadoDeSalvamentoDasNotas = "Salvando..."

        Task { @MainActor in
            await aoAtualizarNotas(atualizadas)
            estadoDeSalvamentoDasNotas = "Salvo"
        }
    }

    private func notasAtualizadasComTextoLivre() -> [NotaDaConversa] {
        var atualizadas = notasEditaveis.filter { !($0.tipo == .nota && $0.start == 0) }
        let textoLimpo = textoDasNotas.trimmingCharacters(in: .whitespacesAndNewlines)

        if !textoLimpo.isEmpty {
            atualizadas.insert(
                NotaDaConversa(
                    id: notaLivreID ?? UUID(),
                    texto: textoDasNotas,
                    start: 0,
                    critica: notaLivreCritica,
                    tipo: .nota
                ),
                at: 0
            )
        }

        return atualizadas.sorted {
            if $0.start == $1.start { return $0.id.uuidString < $1.id.uuidString }
            return $0.start < $1.start
        }
    }

    private func inserirMarcadorNasNotas() {
        let instante = min(max(0, reprodutor?.tempo ?? 0), max(arquivo.duracao, 0))
        let marcador = NotaDaConversa(
            texto: "Marcador em \(tempoCurto(instante))",
            start: instante,
            critica: notaLivreCritica,
            tipo: .marcador
        )
        notasEditaveis.append(marcador)
        salvarNotasAgora()
    }

    private func alternarCriticidadeDaNotaLivre() {
        notaLivreCritica.toggle()
        salvarNotasAgora()
    }

    private func aplicarFormatoNasNotas(_ formato: FormatoDeNota) {
        switch formato {
        case .negrito:
            acrescentarAoEditor("**texto em destaque**")
        case .italico:
            acrescentarAoEditor("_observação_")
        case .lista:
            acrescentarAoEditor("- item da conversa")
        case .imagem:
            acrescentarAoEditor("![descrição da imagem](arquivo)")
        case .anexo:
            acrescentarAoEditor("[anexo](arquivo)")
        case .link:
            acrescentarAoEditor("[link](https://)")
        }
    }

    private func acrescentarAoEditor(_ texto: String) {
        let separador = textoDasNotas.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : "\n"
        textoDasNotas += "\(separador)\(texto)"
    }

    private func mensagemAmigavelParaArquivo(_ error: Error) -> String {
        let nsError = error as NSError
        let texto = "\(nsError.localizedDescription) \(nsError.localizedFailureReason ?? "")"
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

        if texto.contains("iphone") || texto.contains("locked") || texto.contains("bloqueado") {
            return "Você precisa desbloquear seu iPhone antes de importar esse arquivo."
        }
        if nsError.domain == NSCocoaErrorDomain && [257, 260, 513].contains(nsError.code) {
            return "Não consegui acessar esse arquivo. Se ele estiver no iPhone, desbloqueie o aparelho e tente importar de novo."
        }
        return "Não foi possível guardar esse arquivo: \(error.localizedDescription)"
    }

    @ViewBuilder
    private var transcricao: some View {
        if trechos.isEmpty {
            if podeIniciarTranscricao {
                transcricaoPendente
            } else {
                CartaoDeEstadoVazio(
                    simbolo: "text.quote",
                    titulo: "Transcrição em preparação",
                    mensagem: "A transcrição aparecerá depois do processamento."
                )
            }
        } else if let reprodutor {
            ScrollViewReader { rolagem in
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(trechos.enumerated()), id: \.element.id) { indice, trecho in
                        Button {
                            tocar(trecho, no: reprodutor)
                        } label: {
                            linha(trecho, ativo: indice == reprodutor.indiceAtivo)
                        }
                        .buttonStyle(.plain)
                        .id(trecho.id)
                        .accessibilityHint(
                            "Inicia a reprodução a partir de \(tempoLongo(trecho.start))."
                        )
                    }
                }
                .onChange(of: reprodutor.indiceAtivo) { _, novo in
                    guard let novo, novo < trechos.count else { return }
                    withAnimation(animacaoDeInterface) {
                        rolagem.scrollTo(trechos[novo].id, anchor: .center)
                    }
                }
            }
        }
    }

    private var transcricaoPendente: some View {
        VStack(spacing: 14) {
            Image(systemName: "text.quote")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(PapagaioTema.destaqueEscuro)
                .frame(width: 64, height: 64)
                .background(PapagaioTema.destaqueSuave, in: Circle())

            Text("Pronto para transcrever")
                .font(.title3.weight(.semibold))
                .foregroundStyle(PapagaioTema.texto)

            Text("Inicie a transcrição quando quiser. O resumo será gerado em seguida, respeitando a fila de processamento.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(PapagaioTema.textoSecundario)
                .frame(maxWidth: 420)

            Button("Transcrever", systemImage: "text.badge.plus", action: aoTranscrever)
                .buttonStyle(BotaoPrincipalPapagaio())
                .accessibilityHint("Adiciona esta conversa à fila. O resumo será feito após a transcrição.")
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }

    private func linha(_ trecho: Trecho, ativo: Bool) -> some View {
        LinhaDeTranscricao(trecho: trecho, ativo: ativo)
    }

    // MARK: - Exportação

    /// O painel do sistema já grava o `.md`. Depois copiamos o áudio para a
    /// mesma pasta com o nome-base do Markdown, preservando a extensão — sem
    /// sobrescrever uma exportação anterior que também se chamava `gravacao.m4a`.
    /// Quando a gravação tem dois canais, o `sistema.m4a` vai junto.
    private func copiarAudioAnexo(para markdown: URL) {
        let pasta = markdown.deletingLastPathComponent()
        let base = markdown.deletingPathExtension().lastPathComponent
        let acessou = pasta.startAccessingSecurityScopedResource()
        defer {
            if acessou { pasta.stopAccessingSecurityScopedResource() }
        }

        let principal = pasta
            .appendingPathComponent(base)
            .appendingPathExtension(audio.pathExtension.isEmpty ? "m4a" : audio.pathExtension)
        do {
            try FileManager.default.copyItem(at: audio, to: principal)
            if let secundario = audioSecundario,
               let extensaoSecundaria = secundario.pathExtension.isEmpty
                   ? nil : secundario.pathExtension {
                let canalSecundario = pasta
                    .appendingPathComponent("\(base).sistema")
                    .appendingPathExtension(extensaoSecundaria)
                try FileManager.default.copyItem(at: secundario, to: canalSecundario)
            }
        } catch {
            erroDeExportacao = error.localizedDescription
        }
    }

    // MARK: - Formatação

    private func tempoCurto(_ segundos: TimeInterval) -> String {
        guard segundos.isFinite, segundos >= 0 else { return "0:00" }
        let inteiros = Int(segundos)
        return String(format: "%d:%02d", inteiros / 60, inteiros % 60)
    }

    private func tempoLongo(_ segundos: TimeInterval) -> String {
        let inteiros = Int(max(0, segundos))
        let minutos = inteiros / 60
        let resto = inteiros % 60
        return minutos > 0 ? "\(minutos) min \(resto) s" : "\(resto) s"
    }

    private func listaDePessoas(_ texto: String) -> String {
        texto
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}

private enum MidiasDaConversa {
    private struct Registro: Codable {
        let id: UUID
        let nome: String
        let tamanho: Int64
        let data: Date
        let bookmark: Data
    }

    static func carregar(_ arquivoID: ArquivoID) -> [AnexoDeMidiaDaConversa] {
        guard let dados = UserDefaults.standard.data(forKey: chave(arquivoID)),
              let registros = try? JSONDecoder().decode([Registro].self, from: dados)
        else { return [] }

        return registros.compactMap { registro in
            var obsoleto = false
            guard let url = try? URL(
                resolvingBookmarkData: registro.bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &obsoleto
            ) else { return nil }

            return AnexoDeMidiaDaConversa(
                id: registro.id,
                nome: registro.nome,
                tamanho: registro.tamanho,
                data: registro.data,
                url: url
            )
        }
    }

    static func anexo(para url: URL) throws -> AnexoDeMidiaDaConversa {
        let valores = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        return AnexoDeMidiaDaConversa(
            id: UUID(),
            nome: url.lastPathComponent,
            tamanho: Int64(valores.fileSize ?? 0),
            data: valores.contentModificationDate ?? Date(),
            url: url
        )
    }

    static func copiar(_ origem: URL, para pastaDaConversa: URL) throws -> URL {
        let pastaDeMidia = pastaDaConversa.appendingPathComponent("Midia", isDirectory: true)
        try FileManager.default.createDirectory(at: pastaDeMidia, withIntermediateDirectories: true)

        let nomeUnico = nomeDisponivel(para: origem.lastPathComponent, em: pastaDeMidia)
        let destino = pastaDeMidia.appendingPathComponent(nomeUnico)
        try FileManager.default.copyItem(at: origem, to: destino)
        return destino
    }

    static func apagarArquivoSalvo(_ anexo: AnexoDeMidiaDaConversa, pastaDaConversa: URL) throws {
        let pastaDeMidia = pastaDaConversa.appendingPathComponent("Midia", isDirectory: true)
        let caminhoPadronizado = anexo.url.standardizedFileURL.path
        guard caminhoPadronizado.hasPrefix(pastaDeMidia.standardizedFileURL.path) else { return }
        if FileManager.default.fileExists(atPath: anexo.url.path) {
            try FileManager.default.removeItem(at: anexo.url)
        }
    }

    static func salvar(_ anexos: [AnexoDeMidiaDaConversa], para arquivoID: ArquivoID) throws {
        let registros = try anexos.map { anexo in
            let bookmark = try anexo.url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            return Registro(
                id: anexo.id,
                nome: anexo.nome,
                tamanho: anexo.tamanho,
                data: anexo.data,
                bookmark: bookmark
            )
        }
        let dados = try JSONEncoder().encode(registros)
        UserDefaults.standard.set(dados, forKey: chave(arquivoID))
    }

    private static func chave(_ arquivoID: ArquivoID) -> String {
        "midiasDaConversa.\(arquivoID.rawValue.uuidString)"
    }

    private static func nomeDisponivel(para nomeOriginal: String, em pasta: URL) -> String {
        let original = nomeOriginal.isEmpty ? "arquivo" : nomeOriginal
        let base = (original as NSString).deletingPathExtension
        let ext = (original as NSString).pathExtension
        var candidato = original
        var indice = 2

        while FileManager.default.fileExists(atPath: pasta.appendingPathComponent(candidato).path) {
            candidato = ext.isEmpty ? "\(base) \(indice)" : "\(base) \(indice).\(ext)"
            indice += 1
        }

        return candidato
    }
}

private enum TarefasDaConversa {
    static func carregar(
        _ arquivoID: ArquivoID,
        base proximosPassos: [ProximoPasso],
        tituloDaConversa: String,
        dataDaConversa: Date
    ) -> [TarefaDaConversa] {
        if let dados = UserDefaults.standard.data(forKey: chave(arquivoID)),
           let tarefas = try? JSONDecoder().decode([TarefaDaConversa].self, from: dados) {
            return tarefas
        }

        let tarefas = proximosPassos.enumerated().map { indice, passo in
            TarefaDaConversa(
                titulo: passo.descricao,
                origem: tituloDaConversa,
                prioridade: indice < 2 ? .alta : .media,
                status: .emAndamento,
                responsavel: passo.responsavel,
                prazo: Calendar.current.date(byAdding: .day, value: 7 + indice, to: dataDaConversa)
            )
        }
        salvar(tarefas, para: arquivoID)
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
