import PapagaioCore
import SwiftUI
import UniformTypeIdentifiers

/// Superfície do Passo 10: ouvir a gravação e navegar por trecho.
///
/// Clicar num trecho salta o áudio para o `start` dele; o trecho que está
/// tocando fica destacado e a lista rola sozinha até ele.
struct ArquivoDetalheView: View {
    private enum Secao: String, CaseIterable, Identifiable {
        case resumo = "Resumo"
        case transcricao = "Transcrição"
        case audio = "Áudio"
        case proximosPassos = "Próximos passos"

        var id: Self { self }
        var simbolo: String {
            switch self {
            case .resumo: "text.alignleft"
            case .transcricao: "text.quote"
            case .audio: "waveform"
            case .proximosPassos: "checklist"
            }
        }
    }

    let arquivo: Arquivo
    let audio: URL
    /// Texto de status vindo da `Biblioteca` — "transcrevendo…", um erro, ou
    /// "transcrito e resumido".
    let estado: String

    @State private var reprodutor: ReprodutorDeArquivo?
    @State private var secaoSelecionada: Secao = .resumo
    @State private var mostrandoPlayer = false
    @State private var tempoEmEdicao: TimeInterval?
    @State private var mostrandoExportador = false
    @State private var erroDeExportacao: String?
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento

    private var titulo: String { arquivo.resumo?.titulo ?? arquivo.titulo }
    private var trechos: [Trecho] { arquivo.trechos }
    private var exibindoEstadoVazio: Bool {
        switch secaoSelecionada {
        case .resumo:
            arquivo.resumo == nil
        case .transcricao:
            trechos.isEmpty
        case .audio:
            true
        case .proximosPassos:
            arquivo.resumo?.proximosPassos.isEmpty ?? true
        }
    }
    private var animacaoDeInterface: Animation? {
        reduzirMovimento ? nil : .easeInOut(duration: 0.2)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(titulo).font(.title2.bold())
                    Text(estado).font(.caption).foregroundStyle(.secondary)
                }

                seletorDeSecao

                GeometryReader { _ in
                    if exibindoEstadoVazio {
                        conteudoDaSecao
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            conteudoDaSecao
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                                .padding(.bottom, mostrandoPlayer ? 88 : 0)
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if mostrandoPlayer, let reprodutor {
                barraFlutuante(reprodutor)
                    .padding(.bottom, 18)
                    .transition(
                        reduzirMovimento
                            ? .opacity
                            : .move(edge: .bottom).combined(with: .opacity)
                    )
            }
        }
        .frame(minWidth: 520, minHeight: 420, alignment: .topLeading)
        .navigationTitle(titulo)
        .toolbar {
            ToolbarItem {
                Button("Exportar Markdown…", systemImage: "square.and.arrow.up") {
                    mostrandoExportador = true
                }
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

    private var seletorDeSecao: some View {
        HStack(spacing: 0) {
            ForEach(Secao.allCases) { secao in
                Button {
                    withAnimation(animacaoDeInterface) {
                        secaoSelecionada = secao
                        if secao == .audio { mostrandoPlayer = true }
                    }
                } label: {
                    VStack(spacing: 7) {
                        Label(secao.rawValue, systemImage: secao.simbolo)
                            .labelStyle(.titleAndIcon)
                            .font(.callout.weight(secaoSelecionada == secao ? .semibold : .regular))
                            .foregroundStyle(secaoSelecionada == secao ? Color.accentColor : .secondary)
                            .frame(maxWidth: .infinity)
                        Rectangle()
                            .fill(secaoSelecionada == secao ? Color.accentColor : .clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(secaoSelecionada == secao ? .isSelected : [])
            }
        }
        .padding(.top, 4)
        .overlay(alignment: .bottom) {
            Rectangle().fill(.quaternary).frame(height: 1)
        }
    }

    @ViewBuilder
    private var conteudoDaSecao: some View {
        switch secaoSelecionada {
        case .resumo:
            resumo
        case .transcricao:
            transcricao
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

                if !resumo.temas.isEmpty {
                    secao("Temas") {
                        ForEach(Array(resumo.temas.enumerated()), id: \.offset) { _, tema in
                            VStack(alignment: .leading, spacing: 1) {
                                Text(tema.titulo).font(.callout.weight(.medium))
                                Text(tema.detalhe).font(.callout).foregroundStyle(.secondary)
                            }
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
        } else {
            ContentUnavailableView(
                "Resumo indisponível",
                systemImage: "text.alignleft",
                description: Text("O resumo aparecerá depois do processamento.")
            )
        }
    }

    @ViewBuilder
    private var proximosPassos: some View {
        if let resumo = arquivo.resumo, !resumo.proximosPassos.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Próximos passos").font(.headline)
                ForEach(Array(resumo.proximosPassos.enumerated()), id: \.offset) { _, passo in
                    Label {
                        Text(
                            passo.responsavel.map { "\(passo.descricao) (\($0))" }
                                ?? passo.descricao
                        )
                    } icon: {
                        Image(systemName: "checkmark.circle")
                    }
                    .font(.callout)
                }
            }
        } else {
            ContentUnavailableView(
                "Sem próximos passos",
                systemImage: "checklist",
                description: Text("As ações identificadas no resumo aparecerão aqui.")
            )
        }
    }

    private func secao<Conteudo: View>(
        _ titulo: String, @ViewBuilder _ conteudo: () -> Conteudo
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titulo).font(.headline)
            conteudo()
        }
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
            Rectangle().frame(width: 3).foregroundStyle(.quaternary)
            VStack(alignment: .leading, spacing: 2) {
                Text(citacao.texto).font(.callout).italic()
                if let ancora {
                    Button(tempoCurto(ancora)) {
                        Task { await reprodutor?.saltar(paraSegundo: ancora) }
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                }
            }
        }
    }

    // MARK: - Transporte

    private var secaoDeAudio: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform")
                .font(.system(size: 40, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)

            Text("Áudio")
                .font(.title2.bold())

            Text(
                "Use a barra fixa abaixo para ouvir a gravação. Na aba Transcrição, selecione um trecho para iniciar a reprodução daquele ponto."
            )
            .font(.title3)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 720)
        }
        .padding(24)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Áudio. Use a barra fixa abaixo para ouvir a gravação. Na aba Transcrição, selecione um trecho para iniciar a reprodução daquele ponto."
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

    private func posicaoDoPlayer(_ reprodutor: ReprodutorDeArquivo) -> Binding<TimeInterval> {
        Binding(
            get: { tempoEmEdicao ?? reprodutor.tempo },
            set: { tempoEmEdicao = $0 }
        )
    }

    private func concluirEdicaoDaPosicao(_ reprodutor: ReprodutorDeArquivo) {
        guard let destino = tempoEmEdicao else { return }
        Task { @MainActor in
            await reprodutor.saltar(paraSegundo: destino)
            tempoEmEdicao = nil
        }
    }

    private func barraFlutuante(_ reprodutor: ReprodutorDeArquivo) -> some View {
        HStack(spacing: 12) {
            Button {
                reprodutor.alternar()
            } label: {
                Image(systemName: reprodutor.tocando ? "pause.fill" : "play.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.glassProminent)
            .tint(.accentColor)
            .accessibilityLabel(reprodutor.tocando ? "Pausar" : "Tocar")

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(titulo)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text("\(tempoCurto(reprodutor.tempo)) / \(tempoCurto(reprodutor.duracao))")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(
                    value: posicaoDoPlayer(reprodutor),
                    in: 0...max(reprodutor.duracao, 0.1),
                    onEditingChanged: { editando in
                        if editando {
                            tempoEmEdicao = reprodutor.tempo
                        } else {
                            concluirEdicaoDaPosicao(reprodutor)
                        }
                    }
                )
                .accessibilityLabel("Posição do áudio")
                .accessibilityValue("\(tempoLongo(reprodutor.tempo)) de \(tempoLongo(reprodutor.duracao))")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: 680)
        .glassEffect(.regular, in: Capsule())
        .padding(.horizontal, 24)
    }

    // MARK: - Transcrição

    @ViewBuilder
    private var transcricao: some View {
        if trechos.isEmpty {
            ContentUnavailableView(
                "Transcrição indisponível",
                systemImage: "text.quote",
                description: Text("A transcrição aparecerá depois do processamento.")
            )
        } else if let reprodutor {
            ScrollViewReader { rolagem in
                LazyVStack(alignment: .leading, spacing: 0) {
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

    private func linha(_ trecho: Trecho, ativo: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(tempoCurto(trecho.start))
                .font(.system(.caption, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(ativo ? Color.accentColor : .secondary)
                .frame(width: 48, alignment: .trailing)

            VStack(alignment: .leading, spacing: 2) {
                if let speaker = trecho.speaker {
                    Text(speaker == Speaker.eu ? "Eu" : "Interlocutor")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Text(trecho.texto)
                    .fontWeight(ativo ? .medium : .regular)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ativo ? Color.accentColor.opacity(0.12) : Color.clear,
            in: RoundedRectangle(cornerRadius: 6)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(tempoLongo(trecho.start)). \(trecho.texto)")
        .accessibilityAddTraits(ativo ? [.isSelected] : [])
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
