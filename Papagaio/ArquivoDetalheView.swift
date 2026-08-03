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
    /// Texto de status vindo da `Biblioteca` — "transcrevendo…", um erro, ou
    /// "transcrito e resumido".
    let estado: String
    let processando: Bool
    let naFila: Bool
    let aoTranscrever: () -> Void
    let aoAtualizarNotas: ([NotaDaConversa]) async -> Void

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
    @State private var mostrandoImportadorDeMidia = false
    @State private var erroDeMidia: String?
    @State private var tarefasDaConversa: [TarefaDaConversa] = []
    @State private var filtroDeTarefas: FiltroDeTarefas = .tudo
    @State private var mostrandoCriacaoDeTarefa = false
    @State private var tituloDaNovaTarefa = ""
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    private var titulo: String { arquivo.resumo?.titulo ?? arquivo.titulo }
    private var trechos: [Trecho] { arquivo.trechos }
    private var notas: [NotaDaConversa] { notasEditaveis }
    private var notasTemporizadas: [NotaDaConversa] {
        notasEditaveis.filter { $0.tipo == .marcador || $0.start > 0 }
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
        .frame(minWidth: 520, minHeight: 420, alignment: .topLeading)
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
            let novo = ReprodutorDeArquivo(audio: audio, trechos: trechos)
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
        .fileImporter(
            isPresented: $mostrandoImportadorDeMidia,
            allowedContentTypes: [.image, .pdf, .movie, .audio, .plainText, .data],
            allowsMultipleSelection: true
        ) { resultado in
            guard case let .success(urls) = resultado else { return }
            for url in urls {
                adicionarMidia(url)
            }
        }
        .alert("Não foi possível adicionar a mídia", isPresented: Binding(
            get: { erroDeMidia != nil },
            set: { if !$0 { erroDeMidia = nil } }
        )) {
            Button("OK", role: .cancel) { erroDeMidia = nil }
        } message: {
            Text(erroDeMidia ?? "")
        }
        .alert("Nova tarefa", isPresented: $mostrandoCriacaoDeTarefa) {
            TextField("Título da tarefa", text: $tituloDaNovaTarefa)
            Button("Adicionar") {
                adicionarTarefa()
            }
            Button("Cancelar", role: .cancel) {
                tituloDaNovaTarefa = ""
            }
        } message: {
            Text("A tarefa será adicionada a esta conversa.")
        }
    }

    // MARK: - Navegação por conteúdo

    private var cabecalho: some View {
        HStack(alignment: .bottom, spacing: 20) {
            VStack(alignment: .leading, spacing: 7) {
                Text(titulo)
                    .font(.system(size: 30, weight: .bold, design: .default))
                    .foregroundStyle(PapagaioTema.texto)
                    .lineLimit(2)

                Label(tempoCurto(arquivo.duracao), systemImage: "clock")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(PapagaioTema.textoSecundario)
            }

            Spacer(minLength: 16)

            SeloDeStatus(
                texto: estado,
                simbolo: "waveform",
                estilo: estiloDoEstado
            )
        }
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
            aoAlternarConclusao: alternarConclusaoDaTarefa
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
            aoAdicionar: { mostrandoImportadorDeMidia = true },
            aoAbrir: abrirMidia,
            aoRemover: removerMidia
        )
    }

    private func carregarMidias() {
        anexosDeMidia = MidiasDaConversa.carregar(arquivo.id)
    }

    private func adicionarMidia(_ url: URL) {
        let acessando = url.startAccessingSecurityScopedResource()
        defer {
            if acessando { url.stopAccessingSecurityScopedResource() }
        }

        do {
            let anexo = try MidiasDaConversa.anexo(para: url)
            var atualizados = anexosDeMidia.filter { $0.url != anexo.url }
            atualizados.append(anexo)
            atualizados.sort { $0.data > $1.data }
            try MidiasDaConversa.salvar(atualizados, para: arquivo.id)
            anexosDeMidia = atualizados
        } catch {
            erroDeMidia = "Não foi possível guardar esse arquivo: \(error.localizedDescription)"
        }
    }

    private func abrirMidia(_ anexo: AnexoDeMidiaDaConversa) {
        NSWorkspace.shared.open(anexo.url)
    }

    private func removerMidia(_ anexo: AnexoDeMidiaDaConversa) {
        let atualizados = anexosDeMidia.filter { $0.id != anexo.id }
        do {
            try MidiasDaConversa.salvar(atualizados, para: arquivo.id)
            anexosDeMidia = atualizados
        } catch {
            erroDeMidia = "Não foi possível remover esse arquivo: \(error.localizedDescription)"
        }
    }

    // MARK: - Tarefas

    private func carregarTarefas() {
        tarefasDaConversa = TarefasDaConversa.carregar(
            arquivo.id,
            base: arquivo.resumo?.proximosPassos ?? [],
            tituloDaConversa: titulo,
            dataDaConversa: arquivo.criadoEm
        )
    }

    private func adicionarTarefa() {
        let tituloLimpo = tituloDaNovaTarefa.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tituloLimpo.isEmpty else { return }

        tarefasDaConversa.append(
            TarefaDaConversa(
                titulo: tituloLimpo,
                origem: titulo,
                prioridade: .media,
                status: .emAndamento,
                responsavel: nil,
                prazo: Calendar.current.date(byAdding: .day, value: 7, to: Date())
            )
        )
        salvarTarefas()
        tituloDaNovaTarefa = ""
    }

    private func alternarConclusaoDaTarefa(_ tarefa: TarefaDaConversa) {
        guard let indice = tarefasDaConversa.firstIndex(where: { $0.id == tarefa.id }) else { return }
        tarefasDaConversa[indice].status = tarefasDaConversa[indice].status == .concluida ? .emAndamento : .concluida
        salvarTarefas()
    }

    private func salvarTarefas() {
        TarefasDaConversa.salvar(tarefasDaConversa, para: arquivo.id)
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

            if !notasTemporizadas.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Marcadores da conversa")
                        .font(.headline)
                        .foregroundStyle(PapagaioTema.texto)

                    ListaDeNotasDaConversa(notas: notasTemporizadas, aoSelecionar: tocar)
                }
            }
        }
    }

    private func sincronizarNotasComArquivo() {
        notasEditaveis = arquivo.notas

        if let notaLivre = arquivo.notas.first(where: { $0.tipo == .nota && $0.start == 0 }) {
            textoDasNotas = notaLivre.texto
            notaLivreCritica = notaLivre.critica
            notaLivreID = notaLivre.id
        } else {
            textoDasNotas = ""
            notaLivreCritica = false
            notaLivreID = nil
        }
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

    /// O painel do sistema já grava o `.md`. Depois, copiamos o áudio para a
    /// mesma pasta com o nome-base do Markdown, evitando sobrescrever uma
    /// exportação anterior que também se chamava `gravacao.m4a`.
    private func copiarAudioAnexo(para markdown: URL) {
        let pasta = markdown.deletingLastPathComponent()
        let destino = pasta
            .appendingPathComponent(markdown.deletingPathExtension().lastPathComponent)
            .appendingPathExtension("m4a")
        let acessou = pasta.startAccessingSecurityScopedResource()
        defer {
            if acessou { pasta.stopAccessingSecurityScopedResource() }
        }

        do {
            try FileManager.default.copyItem(at: audio, to: destino)
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
