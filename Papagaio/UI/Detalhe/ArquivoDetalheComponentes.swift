import PapagaioCore
import SwiftUI

/// Seções reais disponíveis para uma conversa. Mantê-las fora da view de
/// composição permite reutilizar a barra de navegação sem criar telas que o
/// produto ainda não oferece.
enum SecaoDoDetalhe: String, CaseIterable, Identifiable {
    case resumo = "Resumo"
    case transcricao = "Transcrição"
    case notas = "Notas"
    case midia = "Mídia"
    case tarefas = "Tarefas"

    var id: Self { self }

    var simbolo: String {
        switch self {
        case .resumo: "text.alignleft"
        case .transcricao: "text.quote"
        case .notas: "note.text"
        case .midia: "photo.on.rectangle"
        case .tarefas: "checklist"
        }
    }
}

/// Navegação horizontal entre os conteúdos que já existem no domínio de uma
/// conversa. A mudança de estado fica no container para preservar a regra de
/// abrir o player ao entrar na aba de áudio.
struct BarraDeSecoesDaConversa: View {
    let secaoSelecionada: SecaoDoDetalhe
    let aoSelecionar: (SecaoDoDetalhe) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(SecaoDoDetalhe.allCases) { secao in
                let estaSelecionada = secaoSelecionada == secao

                Button {
                    aoSelecionar(secao)
                } label: {
                    VStack(spacing: 9) {
                        Label(secao.rawValue, systemImage: secao.simbolo)
                            .labelStyle(.titleAndIcon)
                            .font(.callout.weight(estaSelecionada ? .semibold : .regular))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .foregroundStyle(
                                estaSelecionada
                                    ? PapagaioTema.destaqueEscuro
                                    : PapagaioTema.textoSecundario
                            )
                            .frame(maxWidth: .infinity)

                        Rectangle()
                            .fill(estaSelecionada ? PapagaioTema.destaque : .clear)
                            .frame(height: 3)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(estaSelecionada ? .isSelected : [])
            }
        }
        .padding(.top, 4)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PapagaioTema.borda.opacity(0.72))
                .frame(height: 1)
        }
    }
}

/// Linha interativa da transcrição. A ação de tocar pertence ao container;
/// assim a célula continua puramente visual e pode ser usada dentro de um
/// `Button` sem duplicar lógica de AVFoundation.
struct LinhaDeTranscricao: View {
    let trecho: Trecho
    let ativo: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(tempoCurto(trecho.start))
                .font(.system(.caption, design: .monospaced).weight(.medium))
                .monospacedDigit()
                .foregroundStyle(ativo ? PapagaioTema.destaqueEscuro : PapagaioTema.textoSecundario)
                .frame(width: 52, alignment: .trailing)

            VStack(alignment: .leading, spacing: 4) {
                if let speaker = trecho.speaker {
                    Text(speaker == Speaker.eu ? "Eu" : "Interlocutor")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PapagaioTema.textoSecundario)
                }

                Text(trecho.texto)
                    .font(.body)
                    .fontWeight(ativo ? .medium : .regular)
                    .foregroundStyle(PapagaioTema.texto)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ativo ? PapagaioTema.destaqueSuave.opacity(0.76) : PapagaioTema.superficie,
            in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
        )
        .overlay(alignment: .leading) {
            Capsule()
                .fill(ativo ? PapagaioTema.destaque : .clear)
                .frame(width: 4)
                .padding(.vertical, 10)
        }
        .overlay {
            RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
                .stroke(ativo ? PapagaioTema.borda : PapagaioTema.borda.opacity(0.58), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(tempoLongo(trecho.start)). \(trecho.texto)")
        .accessibilityAddTraits(ativo ? [.isSelected] : [])
    }

    private func tempoCurto(_ segundos: TimeInterval) -> String {
        let inteiros = Int(max(0, segundos))
        return String(format: "%d:%02d", inteiros / 60, inteiros % 60)
    }

    private func tempoLongo(_ segundos: TimeInterval) -> String {
        let inteiros = Int(max(0, segundos))
        let minutos = inteiros / 60
        let resto = inteiros % 60
        return minutos > 0 ? "\(minutos) min \(resto) s" : "\(resto) s"
    }
}

/// Player compacto e fixado na parte inferior. Ele só expõe as funções de uma
/// conversa: tocar/pausar e navegar pela posição; não simula recursos de um
/// app de música que não pertencem ao produto.
struct BarraDeAudioDaConversa: View {
    let titulo: String
    let data: Date
    let reprodutor: ReprodutorDeArquivo
    @Binding var tempoEmEdicao: TimeInterval?
    let aoConcluirEdicao: () -> Void

    var body: some View {
        HStack(spacing: 24) {
            HStack(spacing: 14) {
                Image(systemName: "mic")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(PapagaioTema.destaqueEscuro)
                    .frame(width: 48, height: 48)
                    .background(PapagaioTema.destaqueSuave, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(titulo)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(PapagaioTema.texto)
                        .lineLimit(1)
                    Text(data.formatted(.dateTime.day().month(.wide).year()))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(PapagaioTema.textoSecundario)
                        .lineLimit(1)
                }
                .frame(width: 230, alignment: .leading)
            }

            HStack(spacing: 14) {
                BotaoCircularDoPlayer(simbolo: "gobackward.10", tamanho: 18, destaque: false) {
                    Task { await reprodutor.voltar(10) }
                }
                .help("Voltar 10 segundos")

                BotaoCircularDoPlayer(
                    simbolo: reprodutor.tocando ? "pause.fill" : "play.fill",
                    tamanho: 20,
                    destaque: true
                ) {
                    reprodutor.alternar()
                }
                .help(reprodutor.tocando ? "Pausar" : "Tocar")
                .accessibilityLabel(reprodutor.tocando ? "Pausar" : "Tocar")

                BotaoCircularDoPlayer(simbolo: "goforward.10", tamanho: 18, destaque: false) {
                    Task { await reprodutor.avancar(10) }
                }
                .help("Avançar 10 segundos")
            }

            HStack(spacing: 12) {
                Text(tempoCurto(posicaoAtual))
                    .font(.system(.caption, design: .monospaced).weight(.medium))
                    .foregroundStyle(PapagaioTema.texto)
                    .monospacedDigit()
                    .frame(width: 48, alignment: .trailing)

                Slider(
                    value: posicao,
                    in: 0...max(reprodutor.duracao, 0.1),
                    onEditingChanged: { editando in
                        if editando {
                            tempoEmEdicao = reprodutor.tempo
                        } else {
                            aoConcluirEdicao()
                        }
                    }
                )
                .tint(PapagaioTema.destaque)
                .accessibilityLabel("Posição do áudio")
                .accessibilityValue("\(tempoLongo(posicaoAtual)) de \(tempoLongo(reprodutor.duracao))")

                Text(tempoCurto(reprodutor.duracao))
                    .font(.system(.caption, design: .monospaced).weight(.medium))
                    .foregroundStyle(PapagaioTema.texto)
                    .monospacedDigit()
                    .frame(width: 48, alignment: .leading)
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 12) {
                Image(systemName: reprodutor.volume == 0 ? "speaker.slash" : "speaker.wave.2")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(PapagaioTema.textoSecundario)

                Slider(value: volume, in: 0...1)
                    .tint(PapagaioTema.destaqueEscuro)
                    .frame(width: 112)
                    .accessibilityLabel("Volume")

                Button(textoDaVelocidade) {
                    alternarVelocidade()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(PapagaioTema.texto)
                .buttonStyle(.plain)
                .help("Velocidade")
            }
            .frame(width: 210, alignment: .trailing)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, minHeight: 88)
        .background(PapagaioTema.superficie)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(PapagaioTema.borda.opacity(0.75))
                .frame(height: 1)
        }
    }

    private var posicaoAtual: TimeInterval {
        tempoEmEdicao ?? reprodutor.tempo
    }

    private var posicao: Binding<TimeInterval> {
        Binding(
            get: { posicaoAtual },
            set: { tempoEmEdicao = $0 }
        )
    }

    private var volume: Binding<Float> {
        Binding(
            get: { reprodutor.volume },
            set: { reprodutor.volume = $0 }
        )
    }

    private var textoDaVelocidade: String {
        String(format: "%.1fx", reprodutor.velocidade)
    }

    private func alternarVelocidade() {
        let opcoes: [Float] = [0.75, 1, 1.25, 1.5, 2]
        let atual = reprodutor.velocidade
        let proxima = opcoes.first { $0 > atual + 0.01 } ?? opcoes[0]
        reprodutor.velocidade = proxima
    }

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

private struct BotaoCircularDoPlayer: View {
    let simbolo: String
    let tamanho: CGFloat
    let destaque: Bool
    let acao: () -> Void

    var body: some View {
        Button(action: acao) {
            Image(systemName: simbolo)
                .font(.system(size: tamanho, weight: .semibold))
                .foregroundStyle(destaque ? .white : PapagaioTema.textoSecundario)
                .frame(width: destaque ? 48 : 34, height: destaque ? 48 : 34)
                .background(destaque ? PapagaioTema.destaqueEscuro : Color.clear, in: Circle())
        }
        .buttonStyle(.plain)
    }
}

struct AnexoDeMidiaDaConversa: Identifiable, Equatable {
    let id: UUID
    let nome: String
    let tamanho: Int64
    let data: Date
    let url: URL

    var tipoVisual: String {
        let ext = url.pathExtension.localizedLowercase
        if ["png", "jpg", "jpeg", "heic", "gif", "tiff"].contains(ext) { return "Imagem" }
        if ["mov", "mp4", "m4v"].contains(ext) { return "Vídeo" }
        if ["pdf"].contains(ext) { return "PDF" }
        if ["mp3", "m4a", "wav", "aiff"].contains(ext) { return "Áudio" }
        return "Arquivo"
    }

    var simbolo: String {
        switch tipoVisual {
        case "Imagem": "photo"
        case "Vídeo": "film"
        case "PDF": "doc.richtext"
        case "Áudio": "waveform"
        default: "doc"
        }
    }
}

struct MidiaDaConversaView: View {
    let anexos: [AnexoDeMidiaDaConversa]
    let aoAdicionar: () -> Void
    let aoAbrir: (AnexoDeMidiaDaConversa) -> Void
    let aoRemover: (AnexoDeMidiaDaConversa) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Arquivos e Mídia")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(PapagaioTema.texto)

                    Text("Fotos de quadros brancos, capturas de tela e documentos da sessão.")
                        .font(.body)
                        .foregroundStyle(PapagaioTema.textoSecundario)
                }

                Spacer()

                HStack(spacing: 8) {
                    Text(anexos.count == 1 ? "1 arquivo" : "\(anexos.count) arquivos")
                    Text(tamanhoTotal)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(PapagaioTema.textoSecundario)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(PapagaioTema.superficieSuave, in: Capsule())
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 260, maximum: 340), spacing: 20, alignment: .top)],
                spacing: 20
            ) {
                Button(action: aoAdicionar) {
                    VStack(spacing: 14) {
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(PapagaioTema.textoSecundario)
                            .frame(width: 54, height: 54)
                            .background(PapagaioTema.superficieSuave, in: Circle())

                        VStack(spacing: 5) {
                            Text("Adicionar")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(PapagaioTema.texto)
                            Text("Clique para escolher")
                                .font(.callout.weight(.medium))
                                .foregroundStyle(PapagaioTema.textoSecundario)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 360)
                    .background(PapagaioTema.superficie.opacity(0.28), in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeCard, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: PapagaioTema.raioDeCard, style: .continuous)
                            .stroke(
                                PapagaioTema.borda,
                                style: StrokeStyle(lineWidth: 2, dash: [7, 6])
                            )
                    }
                }
                .buttonStyle(.plain)
                .help("Adicionar mídia")

                ForEach(anexos) { anexo in
                    CartaoDeAnexoDeMidia(
                        anexo: anexo,
                        aoAbrir: { aoAbrir(anexo) },
                        aoRemover: { aoRemover(anexo) }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tamanhoTotal: String {
        formatoDeBytes(anexos.reduce(0) { $0 + $1.tamanho })
    }
}

private struct CartaoDeAnexoDeMidia: View {
    let anexo: AnexoDeMidiaDaConversa
    let aoAbrir: () -> Void
    let aoRemover: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button(action: aoAbrir) {
                VStack(alignment: .leading, spacing: 18) {
                    Image(systemName: anexo.simbolo)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(PapagaioTema.destaqueEscuro)
                        .frame(width: 60, height: 60)
                        .background(PapagaioTema.destaqueSuave, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 6) {
                        Text(anexo.nome)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(PapagaioTema.texto)
                            .lineLimit(2)

                        HStack(spacing: 10) {
                            Label(anexo.tipoVisual, systemImage: "tag")
                            Label(formatoDeBytes(anexo.tamanho), systemImage: "externaldrive")
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(PapagaioTema.textoSecundario)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 250, alignment: .topLeading)
            }
            .buttonStyle(.plain)
            .help("Abrir \(anexo.nome)")

            HStack {
                Text(anexo.data.formatted(.dateTime.day().month(.abbreviated).year()))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(PapagaioTema.textoSecundario)

                Spacer()

                Button("Remover", systemImage: "trash", role: .destructive, action: aoRemover)
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(PapagaioTema.perigo)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 360, alignment: .topLeading)
        .cartaoPapagaio()
    }
}

private func formatoDeBytes(_ bytes: Int64) -> String {
    guard bytes > 0 else { return "0 KB" }
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useKB, .useMB, .useGB]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: bytes)
}

enum PrioridadeDaTarefa: String, Codable, CaseIterable {
    case alta = "Alta"
    case media = "Média"
    case baixa = "Baixa"

    var cor: Color {
        switch self {
        case .alta: PapagaioTema.perigo
        case .media: PapagaioTema.textoSecundario
        case .baixa: PapagaioTema.sucesso
        }
    }

    var simbolo: String {
        switch self {
        case .alta: "!"
        case .media: "="
        case .baixa: "-"
        }
    }
}

enum StatusDaTarefa: String, Codable {
    case emAndamento
    case concluida
}

enum FiltroDeTarefas: String, CaseIterable, Identifiable {
    case tudo = "Tudo"
    case prioridadeAlta = "Prioridade alta"
    case emAndamento = "Em andamento"
    case concluidas = "Concluídas"

    var id: Self { self }
}

struct TarefaDaConversa: Identifiable, Codable, Equatable {
    let id: UUID
    var titulo: String
    var origem: String
    var prioridade: PrioridadeDaTarefa
    var status: StatusDaTarefa
    var responsavel: String?
    var prazo: Date?

    init(
        id: UUID = UUID(),
        titulo: String,
        origem: String,
        prioridade: PrioridadeDaTarefa,
        status: StatusDaTarefa,
        responsavel: String?,
        prazo: Date?
    ) {
        self.id = id
        self.titulo = titulo
        self.origem = origem
        self.prioridade = prioridade
        self.status = status
        self.responsavel = responsavel
        self.prazo = prazo
    }
}

struct TarefasDaConversaView: View {
    let tarefas: [TarefaDaConversa]
    @Binding var filtro: FiltroDeTarefas
    let aoAdicionar: () -> Void
    let aoAlternarConclusao: (TarefaDaConversa) -> Void

    private var tarefasFiltradas: [TarefaDaConversa] {
        switch filtro {
        case .tudo:
            tarefas
        case .prioridadeAlta:
            tarefas.filter { $0.prioridade == .alta && $0.status != .concluida }
        case .emAndamento:
            tarefas.filter { $0.status == .emAndamento }
        case .concluidas:
            tarefas.filter { $0.status == .concluida }
        }
    }

    private var altas: [TarefaDaConversa] {
        tarefasFiltradas.filter { $0.prioridade == .alta && $0.status != .concluida }
    }

    private var emAndamento: [TarefaDaConversa] {
        tarefasFiltradas.filter { $0.status == .emAndamento && $0.prioridade != .alta }
    }

    private var concluidas: [TarefaDaConversa] {
        tarefasFiltradas.filter { $0.status == .concluida }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(alignment: .center) {
                HStack(spacing: 10) {
                    ForEach(FiltroDeTarefas.allCases) { opcao in
                        Button {
                            withAnimation(.snappy(duration: 0.18)) {
                                filtro = opcao
                            }
                        } label: {
                            Text(opcao.rawValue)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(filtro == opcao ? .white : PapagaioTema.textoSecundario)
                                .padding(.horizontal, 18)
                                .frame(height: 38)
                                .background(
                                    filtro == opcao ? PapagaioTema.destaque : PapagaioTema.superficie,
                                    in: Capsule()
                                )
                                .overlay {
                                    Capsule()
                                        .stroke(filtro == opcao ? Color.clear : PapagaioTema.borda, lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()

                Button(action: aoAdicionar) {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(PapagaioTema.destaque, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Adicionar tarefa")
            }

            if tarefasFiltradas.isEmpty {
                CartaoDeEstadoVazio(
                    simbolo: "checklist",
                    titulo: "Nenhuma tarefa aqui",
                    mensagem: "Use o botão de adicionar para criar uma tarefa nesta conversa."
                )
                .frame(minHeight: 280)
                .cartaoPapagaio()
            } else {
                VStack(alignment: .leading, spacing: 30) {
                    SecaoDeTarefas(
                        titulo: "Prioridade alta",
                        cor: PapagaioTema.perigo,
                        tarefas: altas,
                        aoAlternarConclusao: aoAlternarConclusao
                    )

                    SecaoDeTarefas(
                        titulo: "Em andamento",
                        cor: PapagaioTema.destaque,
                        tarefas: emAndamento,
                        aoAlternarConclusao: aoAlternarConclusao
                    )

                    SecaoDeTarefas(
                        titulo: "Concluídas",
                        cor: PapagaioTema.sucesso,
                        tarefas: concluidas,
                        aoAlternarConclusao: aoAlternarConclusao
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SecaoDeTarefas: View {
    let titulo: String
    let cor: Color
    let tarefas: [TarefaDaConversa]
    let aoAlternarConclusao: (TarefaDaConversa) -> Void

    var body: some View {
        if !tarefas.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 9) {
                    Circle()
                        .fill(cor)
                        .frame(width: 10, height: 10)

                    Text(titulo)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(PapagaioTema.texto)

                    Text("\(tarefas.count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PapagaioTema.textoSecundario)
                        .frame(width: 26, height: 26)
                        .background(PapagaioTema.superficieSuave, in: Circle())
                }
                .padding(.leading, 8)

                VStack(spacing: 10) {
                    ForEach(tarefas) { tarefa in
                        LinhaDeTarefaDaConversa(
                            tarefa: tarefa,
                            aoAlternarConclusao: { aoAlternarConclusao(tarefa) }
                        )
                    }
                }
            }
        }
    }
}

private struct LinhaDeTarefaDaConversa: View {
    let tarefa: TarefaDaConversa
    let aoAlternarConclusao: () -> Void

    private var concluida: Bool { tarefa.status == .concluida }

    var body: some View {
        HStack(spacing: 18) {
            Button(action: aoAlternarConclusao) {
                Image(systemName: concluida ? "checkmark.square.fill" : "square")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(concluida ? Color(red: 0.48, green: 0.62, blue: 0.92) : PapagaioTema.textoSecundario)
            }
            .buttonStyle(.plain)
            .help(concluida ? "Marcar como em andamento" : "Concluir")

            VStack(alignment: .leading, spacing: 4) {
                Text(tarefa.titulo)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(concluida ? PapagaioTema.textoSecundario : PapagaioTema.texto)
                    .strikethrough(concluida, color: PapagaioTema.textoSecundario)

                Text(tarefa.origem)
                    .font(.callout)
                    .foregroundStyle(PapagaioTema.textoSecundario)
                    .lineLimit(1)
            }

            Spacer(minLength: 16)

            SeloDePrioridade(prioridade: tarefa.prioridade)

            if let responsavel = tarefa.responsavel, !responsavel.isEmpty {
                HStack(spacing: 8) {
                    Text(iniciais(de: responsavel))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PapagaioTema.texto)
                        .frame(width: 34, height: 34)
                        .background(PapagaioTema.destaqueSuave, in: Circle())

                    Text(responsavel)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(PapagaioTema.textoSecundario)
                        .lineLimit(1)
                }
                .frame(width: 190, alignment: .leading)
            }

            if let prazo = tarefa.prazo {
                Label(prazo.formatted(.dateTime.day().month().year()), systemImage: concluida ? "checkmark.circle" : "calendar")
                    .font(.callout.weight(.bold))
                    .foregroundStyle(concluida ? PapagaioTema.sucesso : PapagaioTema.perigo)
                    .monospacedDigit()
                    .frame(width: 130, alignment: .trailing)
            }
        }
        .padding(.horizontal, 18)
        .frame(minHeight: 86)
        .background(PapagaioTema.superficie, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(PapagaioTema.borda, lineWidth: 1)
        }
    }
}

private struct SeloDePrioridade: View {
    let prioridade: PrioridadeDaTarefa

    var body: some View {
        Text("\(prioridade.simbolo) \(prioridade.rawValue)")
            .font(.caption.weight(.bold))
            .foregroundStyle(prioridade.cor)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(prioridade.cor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private func iniciais(de nome: String) -> String {
    let partes = nome.split(separator: " ")
    let letras = partes.prefix(2).compactMap(\.first)
    return letras.isEmpty ? "?" : String(letras).uppercased()
}
