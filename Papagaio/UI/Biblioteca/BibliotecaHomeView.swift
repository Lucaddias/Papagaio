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
    @Binding var mostrandoImportador: Bool
    let processamentoAutomatico: Bool
    let aoAlternarGravacao: () async -> Void
    let aoEscolherPastaDeModelos: (URL) -> Void
    let aoUsarPastaDoApp: () -> Void

    @State private var arquivoSelecionadoNaLixeira: Arquivo?
    @State private var arquivoParaExclusaoDefinitiva: Arquivo?

    private var arquivosFiltrados: [Arquivo] {
        guard let biblioteca else { return [] }
        let fonte = secaoSelecionada == .todos
            ? biblioteca.arquivos
            : biblioteca.arquivosNaLixeira
        let termo = consulta.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !termo.isEmpty else { return fonte }
        return fonte.filter { arquivo in
            let titulo = arquivo.resumo?.titulo ?? arquivo.titulo
            return titulo.localizedCaseInsensitiveContains(termo)
                || (secaoSelecionada == .todos
                    && biblioteca.estado(de: arquivo).localizedCaseInsensitiveContains(termo))
        }
    }

    private var subtitulo: String {
        switch secaoSelecionada {
        case .todos:
            "Gerencie suas transcrições e insights de entrevistas."
        case .lixeira:
            "Recupere um arquivo ou apague-o definitivamente."
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

    private var apresentandoAcoesDaLixeira: Binding<Bool> {
        Binding(
            get: { arquivoSelecionadoNaLixeira != nil },
            set: { apresentando in
                if !apresentando { arquivoSelecionadoNaLixeira = nil }
            }
        )
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                CabecalhoDePagina(
                    titulo: tituloDaPagina,
                    subtitulo: subtitulo
                ) {
                    if let biblioteca, biblioteca.processando {
                        SeloDeStatus(
                            texto: "Processamento em andamento",
                            simbolo: "waveform",
                            estilo: .destaque
                        )
                    }
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
                        processamentoAutomatico: processamentoAutomatico,
                        aoFinalizar: aoAlternarGravacao
                    )

                    PainelDeNotasDuranteGravacao(gravador: gravador)
                }

                if !gravador.avisos.isEmpty {
                    AvisosDaGravacao(avisos: gravador.avisos)
                }

                if let falhaDaGravacao {
                    FalhaDaGravacao(mensagem: falhaDaGravacao)
                }

                gradeDeConversas
            }
            .larguraDeConteudoPapagaio()
            .padding(.horizontal, PapagaioTema.espacamentoDePagina)
            .padding(.vertical, PapagaioTema.espacamentoDePagina)
        }
        .background(PapagaioTema.fundo)
        .confirmationDialog(
            "Arquivo na lixeira",
            isPresented: apresentandoAcoesDaLixeira,
            titleVisibility: .visible
        ) {
            if let arquivo = arquivoSelecionadoNaLixeira {
                Button("Recuperar arquivo", systemImage: "arrow.uturn.backward") {
                    arquivoSelecionadoNaLixeira = nil
                    recuperar(arquivo)
                }
                Button("Apagar definitivamente…", systemImage: "trash.slash", role: .destructive) {
                    arquivoSelecionadoNaLixeira = nil
                    arquivoParaExclusaoDefinitiva = arquivo
                }
                Button("Cancelar", role: .cancel) {
                    arquivoSelecionadoNaLixeira = nil
                }
            }
        } message: {
            Text("O arquivo pode voltar para Todos os arquivos ou ser removido para sempre.")
        }
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
        .alert("Não foi possível concluir a operação", isPresented: apresentandoErroDaLixeira) {
            Button("OK", role: .cancel) { biblioteca?.dispensarErroDaLixeira() }
        } message: {
            Text(biblioteca?.erroDaLixeira ?? "")
        }
    }

    @ViewBuilder
    private var gradeDeConversas: some View {
        let colunas = [GridItem(.adaptive(minimum: 270, maximum: 380), spacing: 20, alignment: .top)]

        switch secaoSelecionada {
        case .todos:
            LazyVGrid(columns: colunas, spacing: 20) {
                CartaoNovaConversa(
                    gravando: gravador.gravando,
                    bloqueado: gravador.estado == .processando,
                    prontoParaEntrada: biblioteca != nil,
                    aoAlternarGravacao: aoAlternarGravacao,
                    aoImportar: { mostrandoImportador = true }
                )

                ForEach(arquivosFiltrados) { arquivo in
                    if let biblioteca {
                        CartaoDeConversa(
                            arquivo: arquivo,
                            estado: biblioteca.estado(de: arquivo),
                            processando: biblioteca.estaProcessando(arquivo),
                            naFila: biblioteca.estaNaFila(arquivo),
                            emOperacaoDeLixeira: biblioteca.estaEmOperacaoDeLixeira(arquivo),
                            aoReprocessar: { biblioteca.enfileirarProcessamento(arquivo) },
                            aoMoverParaLixeira: { Task { await biblioteca.moverParaLixeira(arquivo) } }
                        )
                    }
                }
            }

            if biblioteca?.arquivos.isEmpty == false, arquivosFiltrados.isEmpty {
                CartaoDeEstadoVazio(
                    simbolo: "magnifyingglass",
                    titulo: "Nenhuma conversa encontrada",
                    mensagem: "Tente buscar por outro título ou estado de processamento."
                )
                .frame(minHeight: 220)
                .cartaoPapagaio()
            }

            if biblioteca?.arquivos.isEmpty ?? true {
                Text("A primeira conversa aparecerá aqui depois de gravar ou importar um áudio.")
                    .font(.callout)
                    .foregroundStyle(PapagaioTema.textoSecundario)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 2)
            }

        case .lixeira:
            if biblioteca?.arquivosNaLixeira.isEmpty ?? true {
                CartaoDeEstadoVazio(
                    simbolo: "trash",
                    titulo: "A lixeira está vazia",
                    mensagem: "Arquivos movidos da biblioteca aparecerão aqui e poderão ser recuperados."
                )
                .frame(minHeight: 280)
                .cartaoPapagaio()
            } else if arquivosFiltrados.isEmpty {
                CartaoDeEstadoVazio(
                    simbolo: "magnifyingglass",
                    titulo: "Nenhum arquivo encontrado",
                    mensagem: "Tente buscar por outro título na lixeira."
                )
                .frame(minHeight: 220)
                .cartaoPapagaio()
            } else {
                LazyVGrid(columns: colunas, spacing: 20) {
                    ForEach(arquivosFiltrados) { arquivo in
                        if let biblioteca {
                            CartaoDaLixeira(
                                arquivo: arquivo,
                                emOperacao: biblioteca.estaEmOperacaoDeLixeira(arquivo),
                                aoSelecionar: { arquivoSelecionadoNaLixeira = arquivo },
                                aoPedirExclusaoDefinitiva: {
                                    arquivoParaExclusaoDefinitiva = arquivo
                                }
                            )
                        }
                    }
                }
            }
        }
    }
}

private struct CartaoNovaConversa: View {
    let gravando: Bool
    let bloqueado: Bool
    let prontoParaEntrada: Bool
    let aoAlternarGravacao: () async -> Void
    let aoImportar: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: gravando ? "waveform" : "plus")
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(PapagaioTema.destaqueEscuro)
                .frame(width: 64, height: 64)
                .background(PapagaioTema.destaqueSuave, in: Circle())

            VStack(spacing: 5) {
                Text(gravando ? "Gravação em andamento" : "Gerar nova conversa")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(PapagaioTema.texto)
                Text(
                    gravando
                        ? "A captura continua ativa enquanto você usa a biblioteca."
                        : "Grave áudio ou importe um arquivo para transcrever."
                )
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

            if gravando {
                Button("Finalizar gravação", systemImage: "stop.fill") {
                    Task { await aoAlternarGravacao() }
                }
                .buttonStyle(BotaoPrincipalPapagaio())
            } else {
                HStack(spacing: 10) {
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
        .padding(28)
        .frame(maxWidth: .infinity, minHeight: 278)
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
}

private struct CartaoDeConversa: View {
    let arquivo: Arquivo
    let estado: String
    let processando: Bool
    let naFila: Bool
    let emOperacaoDeLixeira: Bool
    let aoReprocessar: () -> Void
    let aoMoverParaLixeira: () -> Void

    private var titulo: String { arquivo.resumo?.titulo ?? arquivo.titulo }

    private var estiloDoStatus: EstiloDoStatus {
        if processando { return .destaque }
        if naFila { return .aviso }
        if estado != "transcrito" && estado != "transcrito e resumido" && estado != "pronto para transcrever" {
            return .erro
        }
        if arquivo.resumo != nil { return .sucesso }
        return .neutro
    }

    private var simboloDoStatus: String {
        if processando { return "waveform" }
        if naFila { return "clock" }
        if estiloDoStatus == .erro { return "exclamationmark.triangle" }
        if arquivo.resumo != nil { return "checkmark.circle" }
        return "text.badge.plus"
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            NavigationLink(value: arquivo.id.rawValue) {
                VStack(alignment: .leading, spacing: 0) {
                    CapaDeConversa(arquivo: arquivo)

                    VStack(alignment: .leading, spacing: 14) {
                        Text(titulo)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(PapagaioTema.texto)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        SeloDeStatus(
                            texto: estado,
                            simbolo: simboloDoStatus,
                            estilo: estiloDoStatus
                        )

                        HStack(spacing: 12) {
                            Label(
                                arquivo.criadoEm.formatted(.dateTime.day().month(.abbreviated).year()),
                                systemImage: "calendar"
                            )
                            Label(tempoCurto(arquivo.duracao), systemImage: "clock")
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(PapagaioTema.textoSecundario)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Conversa \(titulo). \(estado)")

            Menu {
                Button("Processar de novo", systemImage: "arrow.clockwise", action: aoReprocessar)
                    .disabled(processando || naFila || emOperacaoDeLixeira)
                Divider()
                Button(
                    "Mover para lixeira",
                    systemImage: "trash",
                    role: .destructive,
                    action: aoMoverParaLixeira
                )
                .disabled(processando || emOperacaoDeLixeira)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(PapagaioTema.textoSecundario)
                    .frame(width: 36, height: 36)
                    .background(PapagaioTema.superficie.opacity(0.88), in: Circle())
            }
            .menuStyle(.borderlessButton)
            .padding(10)
            .accessibilityLabel("Ações de \(titulo)")
        }
        .frame(maxWidth: .infinity, minHeight: 278, alignment: .top)
        .cartaoPapagaio()
        .overlay {
            if emOperacaoDeLixeira {
                ProgressView("Movendo para a lixeira…")
                    .font(.callout.weight(.medium))
                    .padding(16)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))
            }
        }
        .opacity(emOperacaoDeLixeira ? 0.72 : 1)
    }

    private func tempoCurto(_ segundos: TimeInterval) -> String {
        let inteiros = Int(max(0, segundos))
        return String(format: "%d:%02d", inteiros / 60, inteiros % 60)
    }
}

private struct CapaDeConversa: View {
    let arquivo: Arquivo

    private var matiz: Double {
        let soma = arquivo.id.rawValue.uuidString.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return Double(soma % 20) / 100
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    PapagaioTema.destaqueSuave,
                    PapagaioTema.destaque.opacity(0.40 + matiz)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: "waveform")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(PapagaioTema.destaqueEscuro.opacity(0.62))

            HStack {
                Label("Áudio local", systemImage: "lock.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PapagaioTema.destaqueEscuro)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.white.opacity(0.72), in: Capsule())
                Spacer()
            }
            .padding(14)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: 116)
        .clipShape(RoundedRectangle(cornerRadius: PapagaioTema.raioDeCard, style: .continuous))
        .accessibilityHidden(true)
    }
}

private struct PainelDeGravacao: View {
    let waveform: [Float]
    let tempoDeGravacao: TimeInterval
    let processamentoAutomatico: Bool
    let aoFinalizar: () async -> Void

    var body: some View {
        HStack(spacing: 22) {
            Image(systemName: "mic.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(PapagaioTema.destaqueEscuro)
                .frame(width: 56, height: 56)
                .background(PapagaioTema.destaqueSuave, in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                SeloDeStatus(texto: "GRAVANDO", simbolo: "record.circle", estilo: .erro)
                Text(
                    processamentoAutomatico
                        ? "A conversa será salva e adicionada à fila ao finalizar."
                        : "A conversa será salva. Use Transcrever quando quiser iniciar o processamento."
                )
                    .font(.callout)
                    .foregroundStyle(PapagaioTema.textoSecundario)
                Text(tempoCurto(tempoDeGravacao))
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .foregroundStyle(PapagaioTema.textoSecundario)
                    .monospacedDigit()
            }

            Waveform(amostras: waveform, ativo: true)
                .frame(minWidth: 160, maxWidth: .infinity, minHeight: 48, maxHeight: 48)

            Button("Finalizar", systemImage: "stop.fill") {
                Task { await aoFinalizar() }
            }
            .buttonStyle(BotaoPrincipalPapagaio())
        }
        .padding(18)
        .cartaoPapagaio()
        .accessibilityElement(children: .contain)
    }

    private func tempoCurto(_ segundos: TimeInterval) -> String {
        let total = max(0, Int(segundos))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

private struct AvisosDaGravacao: View {
    let avisos: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(avisos, id: \.self) { aviso in
                Label(aviso, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(PapagaioTema.aviso)
            }
        }
        .padding(16)
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
            .padding(16)
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: modelos.resultado?.bloqueia == true ? "exclamationmark.triangle.fill" : "arrow.down.circle.fill")
                    .font(.title2)
                    .foregroundStyle(modelos.resultado?.bloqueia == true ? PapagaioTema.perigo : PapagaioTema.destaqueEscuro)
                VStack(alignment: .leading, spacing: 3) {
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
                HStack(spacing: 10) {
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
        .padding(20)
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
                RoundedRectangle(cornerRadius: 10, style: .continuous)
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
