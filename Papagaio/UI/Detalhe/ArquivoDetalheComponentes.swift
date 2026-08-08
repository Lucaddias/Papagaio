import PapagaioCore
import AppKit
import QuickLookThumbnailing
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

    /// As abas dividiam a largura inteira da janela: em tela cheia sobravam
    /// ~250pt entre "Resumo" e "Transcrição", e a barra deixava de ler como um
    /// grupo. Agora cada aba tem a largura do seu rótulo e o conjunto fica
    /// ancorado à esquerda, alinhado com o título da página.
    var body: some View {
        HStack(spacing: PapagaioTema.Espaco.secao) {
            ForEach(SecaoDoDetalhe.allCases) { secao in
                let estaSelecionada = secaoSelecionada == secao

                Button {
                    aoSelecionar(secao)
                } label: {
                    VStack(spacing: PapagaioTema.Espaco.curto) {
                        Label(secao.rawValue, systemImage: secao.simbolo)
                            .labelStyle(.titleAndIcon)
                            .font(PapagaioTema.Tipo.apoio.weight(estaSelecionada ? .semibold : .regular))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .foregroundStyle(
                                estaSelecionada
                                    ? PapagaioTema.destaqueEscuro
                                    : PapagaioTema.textoSecundario
                            )

                        Rectangle()
                            .fill(estaSelecionada ? PapagaioTema.destaque : .clear)
                            .frame(height: 3)
                    }
                    // `Rectangle` é guloso: sem fixar o eixo horizontal ele
                    // esticava a aba inteira e as cinco voltavam a se espalhar
                    // pela janela, mesmo com o rótulo já dimensionado.
                    .fixedSize(horizontal: true, vertical: false)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(estaSelecionada ? .isSelected : [])
            }

            Spacer(minLength: 0)
        }
        .padding(.top, PapagaioTema.Espaco.minimo)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PapagaioTema.borda.opacity(0.72))
                .frame(height: 1)
        }
    }
}

/// Linha interativa da transcrição. As ações de tocar pertencem ao container;
/// assim a célula continua puramente visual e pode ser usada dentro de um
/// `Button` sem duplicar lógica de AVFoundation.
struct LinhaDeTranscricao: View {
    let trecho: Trecho
    let ativo: Bool
    /// Palavra destacada dentro do trecho — `nil` quando o trecho está inativo
    /// ou é legado (sem `palavras`).
    let indiceDePalavraAtiva: Int?
    /// Animação do destaque de palavra, vinda do container (respeita o modo de
    /// reduzir movimento).
    let animacao: Animation?
    let aoTocarLinha: () -> Void
    let aoTocarPalavra: (Palavra) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: PapagaioTema.Espaco.medio) {
            Text(trecho.start.comoRelogio)
                .font(.system(.caption, design: .monospaced).weight(.medium))
                .monospacedDigit()
                .foregroundStyle(ativo ? PapagaioTema.destaqueEscuro : PapagaioTema.textoSecundario)
                .frame(width: 52, alignment: .trailing)

            VStack(alignment: .leading, spacing: PapagaioTema.Espaco.minimo) {
                if let speaker = trecho.speaker {
                    Text(speaker == Speaker.eu ? "Eu" : "Interlocutor")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PapagaioTema.textoSecundario)
                }

                corpoDaTranscricao
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, PapagaioTema.Espaco.medio)
        .padding(.horizontal, PapagaioTema.Espaco.largo)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ativo ? PapagaioTema.destaqueSuave.opacity(0.76) : PapagaioTema.superficie,
            in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
        )
        .overlay(alignment: .leading) {
            Capsule()
                .fill(ativo ? PapagaioTema.destaque : .clear)
                .frame(width: 4)
                .padding(.vertical, PapagaioTema.Espaco.curto)
        }
        .overlay {
            RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
                .stroke(ativo ? PapagaioTema.borda : PapagaioTema.borda.opacity(0.58), lineWidth: 1)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            aoTocarLinha()
        }
        // `contain` em vez de `combine`: com palavras clicáveis, juntar tudo
        // num elemento só engoliria os botões do VoiceOver.
        .accessibilityElement(children: .contain)
        .accessibilityAction {
            aoTocarLinha()
        }
        .accessibilityHint("Inicia a reprodução a partir de \(tempoLongo(trecho.start)).")
        .accessibilityAddTraits(ativo ? [.isSelected] : [])
    }

    @ViewBuilder
    private var corpoDaTranscricao: some View {
        if !trecho.palavras.isEmpty {
            LayoutDeFluxo(espacoHorizontal: 1, espacoVertical: 3) {
                ForEach(Array(trecho.palavras.enumerated()), id: \.element.id) { indice, palavra in
                    BotaoDePalavra(
                        palavra: palavra,
                        ativa: indice == indiceDePalavraAtiva,
                        animacao: animacao,
                        acao: { aoTocarPalavra(palavra) }
                    )
                }
            }
        } else {
            // Transcrição legada (salva antes das palavras existirem): cai no
            // parágrafo inteiro, como sempre foi.
            Text(trecho.texto)
                .font(.body)
                .fontWeight(ativo ? .medium : .regular)
                .foregroundStyle(PapagaioTema.texto)
                .multilineTextAlignment(.leading)
        }
    }

    private func tempoLongo(_ segundos: TimeInterval) -> String {
        let inteiros = Int(max(0, segundos))
        let minutos = inteiros / 60
        let resto = inteiros % 60
        return minutos > 0 ? "\(minutos) min \(resto) s" : "\(resto) s"
    }
}

/// Uma palavra clicável do parágrafo corrido. O tap salta o áudio para o
/// timestamp próprio dela; o destaque segue `indiceDePalavraAtiva` do trecho.
private struct BotaoDePalavra: View {
    let palavra: Palavra
    let ativa: Bool
    let animacao: Animation?
    let acao: () -> Void

    var body: some View {
        Button(action: acao) {
            Text(palavra.texto)
                .font(.body)
                // Peso constante: a palavra ativa não pode ocupar mais espaço
                // que as outras. Semiforte alarga o glifo e o parágrafo inteiro
                // se remexe a cada palavra nova — o destaque vive só na cor e
                // no fundo, que não custam largura nenhuma.
                .foregroundStyle(ativa ? PapagaioTema.destaqueEscuro : PapagaioTema.texto)
                .padding(.vertical, 1.5)
                .padding(.horizontal, PapagaioTema.Espaco.minimo)
                .background(
                    ativa ? PapagaioTema.destaqueSuave : Color.clear,
                    in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .animation(animacao, value: ativa)
        .help("Ouvir a partir desta palavra")
        .accessibilityLabel(palavra.texto)
        .accessibilityHint("Salta o áudio para o instante desta palavra.")
        .accessibilityAddTraits(ativa ? [.isSelected] : [])
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
        ViewThatFits(in: .horizontal) {
            HStack(spacing: PapagaioTema.Espaco.secao) {
                blocoDoArquivo
                controlesCentrais
                progresso
                volumeEVelocidade
            }

            VStack(alignment: .leading, spacing: PapagaioTema.Espaco.medio) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: PapagaioTema.Espaco.medio) {
                        blocoDoArquivo
                        Spacer(minLength: 0)
                        controlesCentrais
                    }

                    VStack(alignment: .leading, spacing: PapagaioTema.Espaco.medio) {
                        blocoDoArquivo
                        controlesCentrais
                    }
                }

                progresso

                volumeEVelocidade
            }
        }
        .padding(.horizontal, PapagaioTema.Espaco.secao)
        .padding(.vertical, PapagaioTema.Espaco.largo)
        .frame(maxWidth: .infinity, minHeight: 88)
        .background(PapagaioTema.superficie)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(PapagaioTema.borda.opacity(0.75))
                .frame(height: 1)
        }
    }

    private var blocoDoArquivo: some View {
        HStack(spacing: PapagaioTema.Espaco.medio) {
            Image(systemName: "mic")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(PapagaioTema.destaqueEscuro)
                .frame(width: 48, height: 48)
                .background(PapagaioTema.destaqueSuave, in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))

            VStack(alignment: .leading, spacing: PapagaioTema.Espaco.minimo) {
                Text(titulo)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(PapagaioTema.texto)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(data.formatted(.dateTime.day().month(.wide).year()))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(PapagaioTema.textoSecundario)
            }
            .frame(minWidth: 130, idealWidth: 210, maxWidth: 230, alignment: .leading)
        }
    }

    private var controlesCentrais: some View {
        HStack(spacing: PapagaioTema.Espaco.medio) {
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
    }

    private var progresso: some View {
        HStack(spacing: PapagaioTema.Espaco.medio) {
            Text(posicaoAtual.comoRelogio)
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

            Text(reprodutor.duracao.comoRelogio)
                .font(.system(.caption, design: .monospaced).weight(.medium))
                .foregroundStyle(PapagaioTema.texto)
                .monospacedDigit()
                .frame(width: 48, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
    }

    private var volumeEVelocidade: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: PapagaioTema.Espaco.medio) {
                controlesDeVolumeEVelocidade
            }

            VStack(alignment: .leading, spacing: PapagaioTema.Espaco.curto) {
                controlesDeVolumeEVelocidade
            }
        }
        .frame(minWidth: 140, idealWidth: 190, alignment: .leading)
    }

    private var controlesDeVolumeEVelocidade: some View {
        Group {
            Image(systemName: reprodutor.volume == 0 ? "speaker.slash" : "speaker.wave.2")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(PapagaioTema.textoSecundario)

            Slider(value: volume, in: 0...1)
                .tint(PapagaioTema.destaqueEscuro)
                .frame(minWidth: 92, idealWidth: 120)
                .accessibilityLabel("Volume")

            Menu {
                ForEach([0.75, 1, 1.25, 1.5, 2], id: \.self) { velocidade in
                    Button(String(format: "%.2gx", velocidade)) {
                        reprodutor.definirVelocidade(Float(velocidade))
                    }
                }
            } label: {
                Text(textoDaVelocidade)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PapagaioTema.texto)
                    .padding(.horizontal, PapagaioTema.Espaco.curto)
                    .frame(height: PapagaioTema.Altura.compacta)
                    .background(PapagaioTema.superficieSuave, in: Capsule())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .help("Velocidade")
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
                .foregroundStyle(destaque ? PapagaioTema.textoSobrePrimario : PapagaioTema.textoSecundario)
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

    var extensaoVisual: String {
        let ext = url.pathExtension.uppercased()
        return ext.isEmpty ? tipoVisual.uppercased() : ext
    }
}

struct MidiaDaConversaView: View {
    let anexos: [AnexoDeMidiaDaConversa]
    let aoAdicionar: () -> Void
    let aoAbrir: (AnexoDeMidiaDaConversa) -> Void
    let aoRemover: (AnexoDeMidiaDaConversa) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.secao) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: PapagaioTema.Espaco.curto) {
                    Text("Arquivos e Mídia")
                        .font(PapagaioTema.Tipo.tituloDePagina)
                        .foregroundStyle(PapagaioTema.texto)

                    Text("Fotos, vídeos, áudios, documentos e anexos salvos nesta conversa.")
                        .font(.body)
                        .foregroundStyle(PapagaioTema.textoSecundario)
                }

                Spacer()

                HStack(spacing: PapagaioTema.Espaco.curto) {
                    Text(anexos.count == 1 ? "1 arquivo" : "\(anexos.count) arquivos")
                    Text(tamanhoTotal)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(PapagaioTema.textoSecundario)
                .padding(.horizontal, PapagaioTema.Espaco.medio)
                .frame(height: PapagaioTema.Altura.compacta)
                .background(PapagaioTema.superficieSuave, in: Capsule())
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 270, maximum: 380), spacing: PapagaioTema.Espaco.largo, alignment: .top)],
                spacing: PapagaioTema.Espaco.largo
            ) {
                Button(action: aoAdicionar) {
                    VStack(spacing: PapagaioTema.Espaco.medio) {
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(PapagaioTema.textoSecundario)
                            .frame(width: 54, height: 54)
                            .background(PapagaioTema.superficieSuave, in: Circle())

                        VStack(spacing: PapagaioTema.Espaco.minimo) {
                            Text("Adicionar mídia")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(PapagaioTema.texto)
                            Text("Foto, vídeo, áudio ou arquivo")
                                .font(.callout.weight(.medium))
                                .foregroundStyle(PapagaioTema.textoSecundario)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 318, maxHeight: 318)
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
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.largo) {
            Button(action: aoAbrir) {
                VStack(alignment: .leading, spacing: PapagaioTema.Espaco.medio) {
                    PreviaDoAnexoDeMidia(anexo: anexo)
                        .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: PapagaioTema.Espaco.minimo) {
                        Text(anexo.nome)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(PapagaioTema.texto)
                            .lineLimit(2)
                            .frame(minHeight: 44, alignment: .topLeading)

                        HStack(spacing: PapagaioTema.Espaco.minimo) {
                            SeloDeMidia(texto: anexo.tipoVisual, simbolo: anexo.simbolo)
                            SeloDeMidia(texto: anexo.extensaoVisual, simbolo: "doc.text")
                            SeloDeMidia(texto: formatoDeBytes(anexo.tamanho), simbolo: "externaldrive")
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    }
                    .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .buttonStyle(.plain)
            .help("Abrir \(anexo.nome)")

            Spacer(minLength: 0)

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
        .padding(PapagaioTema.Espaco.largo)
        .frame(maxWidth: .infinity, minHeight: 318, maxHeight: 318, alignment: .topLeading)
        .cartaoPapagaio()
    }
}

private struct PreviaDoAnexoDeMidia: View {
    let anexo: AnexoDeMidiaDaConversa
    @State private var miniatura: NSImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
                .fill(PapagaioTema.superficieSuave)

            if let miniatura {
                Image(nsImage: miniatura)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else if anexo.tipoVisual == "Áudio" {
                PreviaDeAudio()
                    .padding(PapagaioTema.Espaco.largo)
            } else {
                VStack(spacing: PapagaioTema.Espaco.curto) {
                    Image(systemName: anexo.simbolo)
                        .font(.system(size: 34, weight: .semibold))
                    Text(anexo.tipoVisual)
                        .font(.callout.weight(.semibold))
                }
                .foregroundStyle(PapagaioTema.destaqueEscuro)
            }

            VStack {
                HStack {
                    SeloDeTipoDoArquivo(texto: anexo.tipoVisual)
                    Spacer()
                    SeloDeTipoDoArquivo(texto: anexo.extensaoVisual)
                }
                Spacer()
            }
            .padding(PapagaioTema.Espaco.curto)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
                .stroke(PapagaioTema.borda.opacity(0.72), lineWidth: 1)
        }
        .task(id: anexo.url) {
            await carregarMiniatura()
        }
    }

    private func carregarMiniatura() async {
        guard anexo.tipoVisual != "Áudio" else { return }

        let tamanho = CGSize(width: 680, height: 380)
        let escala = NSScreen.main?.backingScaleFactor ?? 2
        let requisicao = QLThumbnailGenerator.Request(
            fileAt: anexo.url,
            size: tamanho,
            scale: escala,
            representationTypes: .thumbnail
        )

        do {
            let representacao = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: requisicao)
            await MainActor.run {
                miniatura = representacao.nsImage
            }
        } catch {
            if anexo.tipoVisual == "Imagem" {
                await MainActor.run {
                    miniatura = NSImage(contentsOf: anexo.url)
                }
            }
        }
    }
}

private struct PreviaDeAudio: View {
    var body: some View {
        HStack(alignment: .center, spacing: PapagaioTema.Espaco.minimo) {
            ForEach(0..<28, id: \.self) { indice in
                Capsule()
                    .fill(PapagaioTema.destaque)
                    .frame(width: 4, height: altura(para: indice))
                    .opacity(indice.isMultiple(of: 3) ? 0.9 : 0.55)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PapagaioTema.destaqueSuave.opacity(0.52), in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))
        .overlay {
            Image(systemName: "waveform")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(PapagaioTema.destaqueEscuro)
                .padding(PapagaioTema.Espaco.medio)
                .background(PapagaioTema.superficie.opacity(0.86), in: Circle())
        }
    }

    private func altura(para indice: Int) -> CGFloat {
        let padrao: [CGFloat] = [18, 32, 48, 28, 62, 38, 54, 24]
        return padrao[indice % padrao.count]
    }
}

private struct SeloDeTipoDoArquivo: View {
    let texto: String

    var body: some View {
        Text(texto)
            .font(.caption.weight(.bold))
            .foregroundStyle(PapagaioTema.texto)
            .padding(.horizontal, PapagaioTema.Espaco.curto)
            .frame(height: PapagaioTema.Altura.compacta)
            .background(PapagaioTema.superficie.opacity(0.88), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(PapagaioTema.borda.opacity(0.7), lineWidth: 1)
            }
    }
}

private struct SeloDeMidia: View {
    let texto: String
    let simbolo: String

    var body: some View {
        Label(texto, systemImage: simbolo)
            .font(.caption.weight(.semibold))
            .foregroundStyle(PapagaioTema.textoSecundario)
            .lineLimit(1)
            .padding(.horizontal, PapagaioTema.Espaco.curto)
            .frame(height: PapagaioTema.Altura.compacta)
            .background(PapagaioTema.superficieSuave, in: Capsule())
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

struct ResponsavelDaTarefa: Identifiable, Hashable {
    var id: String { email.lowercased() }
    let nome: String
    let email: String

    var rotulo: String {
        email.isEmpty ? nome : "\(nome) - \(email)"
    }
}

enum StatusDaTarefa: String, Codable {
    case emAndamento
    case concluida

    var titulo: String {
        switch self {
        case .emAndamento: "Em andamento"
        case .concluida: "Concluída"
        }
    }
}

extension StatusDaTarefa: CaseIterable {}

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
    let aoEditar: (TarefaDaConversa) -> Void
    let aoMover: (UUID, DestinoDeTarefa) -> Void

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
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.secao) {
            HStack(alignment: .center) {
                HStack(spacing: PapagaioTema.Espaco.curto) {
                    ForEach(FiltroDeTarefas.allCases) { opcao in
                        Button {
                            withAnimation(.snappy(duration: 0.18)) {
                                filtro = opcao
                            }
                        } label: {
                            Text(opcao.rawValue)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(filtro == opcao ? PapagaioTema.textoSobrePrimario : PapagaioTema.textoSecundario)
                                .padding(.horizontal, PapagaioTema.Espaco.largo)
                                .frame(height: PapagaioTema.Altura.padrao)
                                .background(
                                    filtro == opcao ? PapagaioTema.preenchimentoPrimario : PapagaioTema.superficie,
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
                        .foregroundStyle(PapagaioTema.textoSobrePrimario)
                        .frame(width: 48, height: 48)
                        .background(PapagaioTema.preenchimentoPrimario, in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))
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
                VStack(alignment: .leading, spacing: PapagaioTema.Espaco.pagina) {
                    secoesVisiveis
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var secoesVisiveis: some View {
        switch filtro {
        case .tudo:
            secaoAlta(tarefas: altas)
            secaoEmAndamento(tarefas: emAndamento)
            secaoConcluidas(tarefas: concluidas)
        case .prioridadeAlta:
            secaoAlta(tarefas: tarefasFiltradas)
        case .emAndamento:
            secaoEmAndamento(tarefas: tarefasFiltradas)
        case .concluidas:
            secaoConcluidas(tarefas: tarefasFiltradas)
        }
    }

    private func secaoAlta(tarefas: [TarefaDaConversa]) -> some View {
        SecaoDeTarefas(
            titulo: "Prioridade alta",
            cor: PapagaioTema.perigo,
            tarefas: tarefas,
            destino: .alta,
            aoAlternarConclusao: aoAlternarConclusao,
            aoEditar: aoEditar,
            aoMover: aoMover
        )
    }

    private func secaoEmAndamento(tarefas: [TarefaDaConversa]) -> some View {
        SecaoDeTarefas(
            titulo: "Em andamento",
            cor: PapagaioTema.destaque,
            tarefas: tarefas,
            destino: .emAndamento,
            aoAlternarConclusao: aoAlternarConclusao,
            aoEditar: aoEditar,
            aoMover: aoMover
        )
    }

    private func secaoConcluidas(tarefas: [TarefaDaConversa]) -> some View {
        SecaoDeTarefas(
            titulo: "Concluídas",
            cor: PapagaioTema.sucesso,
            tarefas: tarefas,
            destino: .concluida,
            aoAlternarConclusao: aoAlternarConclusao,
            aoEditar: aoEditar,
            aoMover: aoMover
        )
    }
}

enum DestinoDeTarefa {
    case alta
    case emAndamento
    case concluida

    var titulo: String {
        switch self {
        case .alta: "Prioridade alta"
        case .emAndamento: "Em andamento"
        case .concluida: "Concluída"
        }
    }

    var prioridade: PrioridadeDaTarefa? {
        switch self {
        case .alta: .alta
        case .emAndamento: .media
        case .concluida: nil
        }
    }

    var status: StatusDaTarefa {
        switch self {
        case .alta, .emAndamento: .emAndamento
        case .concluida: .concluida
        }
    }
}

extension DestinoDeTarefa: CaseIterable, Hashable {}

struct NovaTarefaDaConversaSheet: View {
    enum Modo {
        case criacao
        case edicao

        var titulo: String {
            switch self {
            case .criacao: "Nova tarefa"
            case .edicao: "Editar tarefa"
            }
        }

        var botao: String {
            switch self {
            case .criacao: "Adicionar tarefa"
            case .edicao: "Salvar alterações"
            }
        }

        var simbolo: String {
            switch self {
            case .criacao: "checklist"
            case .edicao: "pencil"
            }
        }
    }

    let modo: Modo
    @Binding var titulo: String
    @Binding var responsavel: String
    @Binding var prioridade: PrioridadeDaTarefa
    @Binding var status: StatusDaTarefa
    @Binding var prazo: Date
    let responsaveisDisponiveis: [ResponsavelDaTarefa]
    let aoCancelar: () -> Void
    let aoAdicionar: () -> Void

    private var podeAdicionar: Bool {
        !titulo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var prazoEstaPerto: Bool {
        let calendario = Calendar.current
        let hoje = calendario.startOfDay(for: Date())
        let diaDoPrazo = calendario.startOfDay(for: prazo)
        let dias = calendario.dateComponents([.day], from: hoje, to: diaDoPrazo).day ?? Int.max
        return dias <= 2
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.secao) {
            HStack(alignment: .top, spacing: PapagaioTema.Espaco.medio) {
                Image(systemName: modo.simbolo)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(PapagaioTema.destaqueEscuro)
                    .frame(width: 44, height: 44)
                    .background(PapagaioTema.destaqueSuave, in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))

                VStack(alignment: .leading, spacing: PapagaioTema.Espaco.minimo) {
                    Text(modo.titulo)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(PapagaioTema.texto)

                    Text("Defina título, responsável, prioridade, status e deadline antes de salvar.")
                        .font(.callout)
                        .foregroundStyle(PapagaioTema.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            VStack(alignment: .leading, spacing: PapagaioTema.Espaco.curto) {
                Text("Título")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PapagaioTema.textoSecundario)

                TextField("Ex.: Revisar pontos da entrevista", text: $titulo)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .padding(.horizontal, PapagaioTema.Espaco.medio)
                    .frame(height: PapagaioTema.Altura.padrao)
                    .background(PapagaioTema.superficie, in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
                            .stroke(PapagaioTema.borda, lineWidth: 1)
                    }
            }

            VStack(alignment: .leading, spacing: PapagaioTema.Espaco.curto) {
                Text("Responsável")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PapagaioTema.textoSecundario)

                VStack(spacing: PapagaioTema.Espaco.curto) {
                    Menu {
                        Button("Sem responsável") {
                            responsavel = ""
                        }

                        ForEach(responsaveisDisponiveis) { pessoa in
                            Button {
                                responsavel = pessoa.rotulo
                            } label: {
                                Text(pessoa.rotulo)
                            }
                        }
                    } label: {
                        HStack(spacing: PapagaioTema.Espaco.curto) {
                            Image(systemName: "person.crop.circle")
                            Text(responsavel.isEmpty ? "Escolher da equipe" : responsavel)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.bold))
                        }
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(PapagaioTema.texto)
                        .padding(.horizontal, PapagaioTema.Espaco.medio)
                        .frame(height: PapagaioTema.Altura.padrao)
                        .background(PapagaioTema.superficie, in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
                                .stroke(PapagaioTema.borda, lineWidth: 1)
                        }
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)

                    TextField("Ou digite nome, e-mail ou login", text: $responsavel)
                        .textFieldStyle(.plain)
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

            VStack(alignment: .leading, spacing: PapagaioTema.Espaco.curto) {
                Text("Prioridade")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PapagaioTema.textoSecundario)

                ControleSegmentadoPapagaio(
                    opcoes: PrioridadeDaTarefa.allCases,
                    selecionado: $prioridade,
                    titulo: { $0.rawValue },
                    simbolo: { _ in nil }
                )
            }

            VStack(alignment: .leading, spacing: PapagaioTema.Espaco.curto) {
                Text("Status")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PapagaioTema.textoSecundario)

                ControleSegmentadoPapagaio(
                    opcoes: StatusDaTarefa.allCases,
                    selecionado: $status,
                    titulo: { $0.titulo },
                    simbolo: { $0 == .concluida ? "checkmark" : "clock" }
                )
            }

            VStack(alignment: .leading, spacing: PapagaioTema.Espaco.curto) {
                Text("Deadline")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PapagaioTema.textoSecundario)

                DatePicker("Data de entrega", selection: $prazo, displayedComponents: [.date])
                    .datePickerStyle(.compact)
                    .labelsHidden()

                if prazoEstaPerto && status != .concluida {
                    Label("Deadline perto: a tarefa será marcada como prioridade alta.", systemImage: "bell.badge")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PapagaioTema.perigo)
                }
            }

            HStack(spacing: PapagaioTema.Espaco.medio) {
                Button("Cancelar", action: aoCancelar)
                    .buttonStyle(BotaoDeContornoPapagaio())

                Spacer()

                Button(modo.botao, systemImage: modo == .criacao ? "plus" : "checkmark") {
                    aoAdicionar()
                }
                .buttonStyle(BotaoPrincipalPapagaio())
                .disabled(!podeAdicionar)
                .keyboardShortcut(.return, modifiers: [.command])
            }
        }
        .padding(PapagaioTema.Espaco.secao)
        .frame(minWidth: 340, idealWidth: 500, maxWidth: 520, alignment: .leading)
        .background(PapagaioTema.fundo)
    }
}

private struct ControleSegmentadoPapagaio<Opcao: Hashable>: View {
    let opcoes: [Opcao]
    @Binding var selecionado: Opcao
    let titulo: (Opcao) -> String
    let simbolo: (Opcao) -> String?

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: PapagaioTema.Espaco.curto) {
                botoes
            }

            VStack(alignment: .leading, spacing: PapagaioTema.Espaco.curto) {
                botoes
            }
        }
    }

    private var botoes: some View {
        Group {
            ForEach(opcoes, id: \.self) { opcao in
                botao(opcao)
            }
        }
    }

    private func botao(_ opcao: Opcao) -> some View {
        let ativo = opcao == selecionado

        return Button {
            withAnimation(.snappy(duration: 0.16)) {
                selecionado = opcao
            }
        } label: {
            HStack(spacing: PapagaioTema.Espaco.minimo) {
                if let simbolo = simbolo(opcao) {
                    Image(systemName: simbolo)
                }
                Text(titulo(opcao))
            }
            .font(.callout.weight(.semibold))
            .foregroundStyle(ativo ? PapagaioTema.textoSobrePrimario : PapagaioTema.textoSecundario)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .frame(maxWidth: .infinity)
            .frame(height: PapagaioTema.Altura.padrao)
            .background(ativo ? PapagaioTema.preenchimentoPrimario : PapagaioTema.superficie, in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
                    .stroke(ativo ? Color.clear : PapagaioTema.borda, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct SecaoDeTarefas: View {
    let titulo: String
    let cor: Color
    let tarefas: [TarefaDaConversa]
    let destino: DestinoDeTarefa
    let aoAlternarConclusao: (TarefaDaConversa) -> Void
    let aoEditar: (TarefaDaConversa) -> Void
    let aoMover: (UUID, DestinoDeTarefa) -> Void
    @State private var recebendoDrop = false

    var body: some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.medio) {
            HStack(spacing: PapagaioTema.Espaco.curto) {
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

                Text("Arraste tarefas para cá")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PapagaioTema.textoSecundario)
            }
            .padding(.leading, PapagaioTema.Espaco.curto)

            VStack(spacing: PapagaioTema.Espaco.curto) {
                if tarefas.isEmpty {
                    Text("Solte uma tarefa aqui para mudar para \(titulo.lowercased()).")
                        .font(.callout)
                        .foregroundStyle(PapagaioTema.textoSecundario)
                        .frame(maxWidth: .infinity, minHeight: 62)
                        .background(PapagaioTema.superficie.opacity(0.45), in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))
                }

                ForEach(tarefas) { tarefa in
                    LinhaDeTarefaDaConversa(
                        tarefa: tarefa,
                        aoAlternarConclusao: { aoAlternarConclusao(tarefa) },
                        aoEditar: { aoEditar(tarefa) }
                    )
                    .draggable(tarefa.id.uuidString)
                }
            }
        }
        .padding(recebendoDrop ? 10 : 0)
        .background(
            recebendoDrop ? cor.opacity(0.08) : Color.clear,
            in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
        )
        .dropDestination(for: String.self) { ids, _ in
            guard let idTexto = ids.first,
                  let id = UUID(uuidString: idTexto)
            else { return false }
            aoMover(id, destino)
            return true
        } isTargeted: { ativo in
            recebendoDrop = ativo
        }
    }
}

private struct LinhaDeTarefaDaConversa: View {
    let tarefa: TarefaDaConversa
    let aoAlternarConclusao: () -> Void
    let aoEditar: () -> Void

    private var concluida: Bool { tarefa.status == .concluida }
    private var dataDoPrazo: String {
        tarefa.prazo?.formatted(.dateTime.day().month().year()) ?? "Sem deadline"
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            conteudoHorizontal
            conteudoCompacto
        }
        .padding(.horizontal, PapagaioTema.Espaco.largo)
        .padding(.vertical, PapagaioTema.Espaco.medio)
        .frame(minHeight: 86)
        .background(PapagaioTema.superficie, in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
                .stroke(PapagaioTema.borda, lineWidth: 1)
        }
    }

    private var conteudoHorizontal: some View {
        HStack(spacing: PapagaioTema.Espaco.medio) {
            botaoConclusao

            tituloDaTarefa
                .frame(minWidth: 220, maxWidth: .infinity, alignment: .leading)

            SeparadorDaLinhaDeTarefa()
            ColunaDaTarefa(rotulo: "Prioridade") {
                SeloDePrioridade(prioridade: tarefa.prioridade)
            }
            .frame(width: 128, alignment: .leading)

            SeparadorDaLinhaDeTarefa()
            ColunaDaTarefa(rotulo: "Responsável") {
                responsavelDaTarefa
            }
            .frame(width: 190, alignment: .leading)

            SeparadorDaLinhaDeTarefa()
            ColunaDaTarefa(rotulo: "Status") {
                SeloDeStatusDaTarefa(status: tarefa.status)
            }
            .frame(width: 124, alignment: .leading)

            SeparadorDaLinhaDeTarefa()
            ColunaDaTarefa(rotulo: "Data") {
                Label(dataDoPrazo, systemImage: concluida ? "checkmark.circle" : "calendar")
                    .font(.callout.weight(.bold))
                    .foregroundStyle(concluida ? PapagaioTema.sucesso : PapagaioTema.perigo)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .frame(width: 136, alignment: .leading)

            botaoEditar
        }
    }

    private var conteudoCompacto: some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.medio) {
            HStack(alignment: .top, spacing: PapagaioTema.Espaco.medio) {
                botaoConclusao
                tituloDaTarefa
                Spacer()
                botaoEditar
            }

            Divider()
                .background(PapagaioTema.borda)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 135), spacing: PapagaioTema.Espaco.medio, alignment: .leading)],
                alignment: .leading,
                spacing: PapagaioTema.Espaco.medio
            ) {
                ColunaDaTarefa(rotulo: "Prioridade") {
                    SeloDePrioridade(prioridade: tarefa.prioridade)
                }
                ColunaDaTarefa(rotulo: "Responsável") {
                    responsavelDaTarefa
                }
                ColunaDaTarefa(rotulo: "Status") {
                    SeloDeStatusDaTarefa(status: tarefa.status)
                }
                ColunaDaTarefa(rotulo: "Data") {
                    Label(dataDoPrazo, systemImage: concluida ? "checkmark.circle" : "calendar")
                        .font(.callout.weight(.bold))
                        .foregroundStyle(concluida ? PapagaioTema.sucesso : PapagaioTema.perigo)
                        .monospacedDigit()
                        .lineLimit(1)
                }
            }
        }
    }

    private var botaoConclusao: some View {
        Button(action: aoAlternarConclusao) {
            Image(systemName: concluida ? "checkmark.square.fill" : "square")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(concluida ? PapagaioTema.sucesso : PapagaioTema.textoSecundario)
        }
        .buttonStyle(.plain)
        .help(concluida ? "Marcar como em andamento" : "Concluir")
    }

    private var botaoEditar: some View {
        Button(action: aoEditar) {
            Image(systemName: "pencil")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(PapagaioTema.textoSecundario)
                .frame(width: 34, height: 34)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Editar tarefa")
    }

    private var tituloDaTarefa: some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.minimo) {
            Text(tarefa.titulo)
                .font(.headline.weight(.semibold))
                .foregroundStyle(concluida ? PapagaioTema.textoSecundario : PapagaioTema.texto)
                .strikethrough(concluida, color: PapagaioTema.textoSecundario)
                .lineLimit(2)

            Text(tarefa.origem)
                .font(.callout)
                .foregroundStyle(PapagaioTema.textoSecundario)
                .lineLimit(1)
        }
    }

    private var responsavelDaTarefa: some View {
        HStack(spacing: PapagaioTema.Espaco.curto) {
            if let responsavel = tarefa.responsavel, !responsavel.isEmpty {
                Text(iniciais(de: responsavel))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PapagaioTema.texto)
                    .frame(width: 30, height: 30)
                    .background(PapagaioTema.destaqueSuave, in: Circle())

                Text(responsavel)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(PapagaioTema.textoSecundario)
                    .lineLimit(1)
            } else {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(PapagaioTema.textoSecundario)
                    .frame(width: 30, height: 30)

                Text("Sem responsável")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(PapagaioTema.textoSecundario)
                    .lineLimit(1)
            }
        }
    }
}

private struct ColunaDaTarefa<Conteudo: View>: View {
    let rotulo: String
    let conteudo: Conteudo

    init(rotulo: String, @ViewBuilder conteudo: () -> Conteudo) {
        self.rotulo = rotulo
        self.conteudo = conteudo()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.minimo) {
            Text(rotulo)
                .font(.caption2.weight(.bold))
                .foregroundStyle(PapagaioTema.textoSecundario)
                .textCase(.uppercase)
            conteudo
        }
    }
}

private struct SeparadorDaLinhaDeTarefa: View {
    var body: some View {
        Rectangle()
            .fill(PapagaioTema.borda.opacity(0.85))
            .frame(width: 1, height: 44)
    }
}

private struct SeloDePrioridade: View {
    let prioridade: PrioridadeDaTarefa

    var body: some View {
        Text(texto)
            .font(.caption.weight(.bold))
            .foregroundStyle(cor)
            .padding(.horizontal, PapagaioTema.Espaco.curto)
            .frame(height: PapagaioTema.Altura.compacta)
            .background(cor.opacity(0.12), in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))
    }

    private var texto: String {
        "\(prioridade.simbolo) \(prioridade.rawValue)"
    }

    private var cor: Color {
        prioridade.cor
    }
}

private struct SeloDeStatusDaTarefa: View {
    let status: StatusDaTarefa

    var body: some View {
        Text(status.titulo)
            .font(.caption.weight(.bold))
            .foregroundStyle(cor)
            .padding(.horizontal, PapagaioTema.Espaco.curto)
            .frame(height: PapagaioTema.Altura.compacta)
            .background(cor.opacity(0.12), in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))
    }

    private var cor: Color {
        switch status {
        case .emAndamento: PapagaioTema.destaque
        case .concluida: PapagaioTema.sucesso
        }
    }
}

private func iniciais(de nome: String) -> String {
    let partes = nome.split(separator: " ")
    let letras = partes.prefix(2).compactMap(\.first)
    return letras.isEmpty ? "?" : String(letras).uppercased()
}
