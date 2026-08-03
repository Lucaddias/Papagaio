import PapagaioCore
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

    @State private var reprodutor: ReprodutorDeArquivo?
    @State private var secaoSelecionada: SecaoDoDetalhe = .resumo
    @State private var mostrandoPlayer = false
    @State private var tempoEmEdicao: TimeInterval?
    @State private var mostrandoExportador = false
    @State private var erroDeExportacao: String?
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    private var titulo: String { arquivo.resumo?.titulo ?? arquivo.titulo }
    private var trechos: [Trecho] { arquivo.trechos }
    private var notas: [NotaDaConversa] { arquivo.notas }
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
        case .audio:
            true
        case .proximosPassos:
            arquivo.resumo?.proximosPassos.isEmpty ?? true
        }
    }
    private var animacaoDeInterface: Animation? {
        reduzirMovimento ? nil : .easeInOut(duration: 0.2)
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
                                .padding(.bottom, mostrandoPlayer ? 104 : 0)
                        }
                    }
                }
            }
            .larguraDeConteudoPapagaio()
            .padding(.horizontal, PapagaioTema.espacamentoDePagina)
            .padding(.vertical, PapagaioTema.espacamentoDePagina)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if mostrandoPlayer, let reprodutor {
                barraFlutuante(reprodutor)
                    .padding(.bottom, 20)
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
                if secao == .audio { mostrandoPlayer = true }
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
        case .audio:
            secaoDeAudio
        case .proximosPassos:
            proximosPassos
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

    @ViewBuilder
    private var proximosPassos: some View {
        if let resumo = arquivo.resumo, !resumo.proximosPassos.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Próximos passos")
                    .font(.headline)
                    .foregroundStyle(PapagaioTema.texto)
                ForEach(Array(resumo.proximosPassos.enumerated()), id: \.offset) { _, passo in
                    Label {
                        Text(
                            passo.responsavel.map { "\(passo.descricao) (\($0))" }
                                ?? passo.descricao
                        )
                    } icon: {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(PapagaioTema.destaqueEscuro)
                    }
                    .font(.callout)
                    .foregroundStyle(PapagaioTema.texto)
                    .padding(.vertical, 4)
                }
            }
            .padding(24)
            .cartaoPapagaio()
        } else {
            CartaoDeEstadoVazio(
                simbolo: "checklist",
                titulo: "Sem próximos passos",
                mensagem: "As ações identificadas no resumo aparecerão aqui."
            )
        }
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

    // MARK: - Transporte

    private var secaoDeAudio: some View {
        OrientacaoDeAudio()
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
            reprodutor: reprodutor,
            tempoEmEdicao: $tempoEmEdicao,
            aoConcluirEdicao: { concluirEdicaoDaPosicao(reprodutor) }
        )
    }

    // MARK: - Transcrição

    @ViewBuilder
    private var notasDaConversa: some View {
        if notas.isEmpty {
            CartaoDeEstadoVazio(
                simbolo: "note.text",
                titulo: "Sem notas nesta conversa",
                mensagem: "As observações registradas durante a gravação aparecerão aqui."
            )
        } else {
            ListaDeNotasDaConversa(notas: notas, aoSelecionar: tocar)
        }
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
