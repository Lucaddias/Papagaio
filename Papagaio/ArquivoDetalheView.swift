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

    @State private var reprodutor: ReprodutorDeArquivo?
    @State private var mostrandoExportador = false
    @State private var erroDeExportacao: String?

    private var titulo: String { arquivo.resumo?.titulo ?? arquivo.titulo }
    private var trechos: [Trecho] { arquivo.trechos }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(titulo).font(.title2.bold())
                    Text(estado).font(.caption).foregroundStyle(.secondary)
                }

                controles
                Divider()
                resumo
                transcricao
            }
            .padding(24)
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

                if !resumo.proximosPassos.isEmpty {
                    secao("Próximos passos") {
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
                }
            }
            Divider()
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

    @ViewBuilder
    private var controles: some View {
        if let reprodutor {
            HStack(spacing: 16) {
                Button {
                    reprodutor.alternar()
                } label: {
                    Image(systemName: reprodutor.tocando ? "pause.fill" : "play.fill")
                        .font(.system(size: 18))
                        .frame(width: 44, height: 44)
                        .background(.quaternary, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(reprodutor.tocando ? "Pausar" : "Tocar")

                Slider(
                    value: Binding(
                        get: { reprodutor.tempo },
                        set: { novo in Task { await reprodutor.saltar(paraSegundo: novo) } }
                    ),
                    in: 0...max(reprodutor.duracao, 0.1)
                )
                .accessibilityLabel("Posição")

                Text("\(tempoCurto(reprodutor.tempo)) / \(tempoCurto(reprodutor.duracao))")
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        } else {
            ProgressView().controlSize(.small)
        }
    }

    // MARK: - Transcrição

    @ViewBuilder
    private var transcricao: some View {
        if trechos.isEmpty {
            Text("Sem transcrição ainda.")
                .foregroundStyle(.secondary)
        } else if let reprodutor {
            ScrollViewReader { rolagem in
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(trechos.enumerated()), id: \.element.id) { indice, trecho in
                        linha(trecho, ativo: indice == reprodutor.indiceAtivo)
                            .id(trecho.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                Task { await reprodutor.saltar(para: trecho) }
                            }
                    }
                }
                .onChange(of: reprodutor.indiceAtivo) { _, novo in
                    guard let novo, novo < trechos.count else { return }
                    withAnimation { rolagem.scrollTo(trechos[novo].id, anchor: .center) }
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
