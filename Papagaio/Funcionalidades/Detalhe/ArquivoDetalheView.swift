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
    /// Canal do sistema (`sistema.caf`) para reprodução em paralelo ao
    /// microfone — `nil` para importado e gravação legada, que têm canal único.
    let audioSecundario: URL?
    /// Veio de um arquivo escolhido pela pessoa, em vez de uma gravação feita
    /// dentro do app.
    let importado: Bool
    /// Texto de status vindo da `Biblioteca` — "transcrevendo…", um erro, ou
    /// "transcrito e resumido".
    let estado: EstadoDoArquivo
    let processando: Bool
    let naFila: Bool
    let responsaveisDisponiveis: [ResponsavelDaTarefa]
    let aoTranscrever: () -> Void
    let aoAtualizarNotas: ([NotaDaConversa]) async -> Void
    let aoNotificarTarefa: (_ titulo: String, _ mensagem: String) -> Void
    let aoAtualizarMetadados: (String, Date, TimeInterval) -> Void
    /// Salva a transcrição corrigida à mão.
    let aoAtualizarTranscricao: ([Trecho]) async -> Void
    /// Refina com o Whisper local o trecho ditado numa nota.
    let aoDitar: (URL) async throws -> String

    @State private var reprodutor: ReprodutorDeArquivo?
    @State private var secaoSelecionada: SecaoDoDetalhe = .resumo
    @State private var mostrandoPlayer = false
    @State private var tempoEmEdicao: TimeInterval?
    @State private var mostrandoExportador = false
    @State private var notasEditaveis: [NotaDaConversa] = []
    @State private var estadoDeSalvamentoDasNotas = "Salvo"
    @State private var tarefaDeSalvamentoDasNotas: Task<Void, Never>?
    @State private var anexosDeMidia: [AnexoDeMidiaDaConversa] = []
    @State private var anexosDaGravacao: [AnexoDeMidiaDaConversa] = []
    @State private var erroDeMidia: String?
    @State private var midiasNaLixeiraDaConversa: [MidiaNaLixeira] = []
    @State private var tarefasDaConversa: [TarefaDaConversa] = []
    @State private var filtroDeTarefas: FiltroDeTarefas = .tudo
    @State private var mostrandoCriacaoDeTarefa = false
    @State private var tituloDaNovaTarefa = ""
    @State private var responsavelDaNovaTarefa = ""
    @State private var prioridadeDaNovaTarefa: PrioridadeDaTarefa = .media
    @State private var statusDaNovaTarefa: StatusDaTarefa = .naoIniciado
    @State private var prazoDaNovaTarefa = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var mostrandoEdicaoDeTarefa = false
    @State private var tarefaEmEdicaoID: UUID?
    @State private var editandoInformacoes = false
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
    /// Recarrega a ficha depois de salvar: os metadados vêm de `UserDefaults`,
    /// que não notifica a view sozinho.
    @State private var versaoDaFicha = 0
    @State private var ditado = DitadoDeNota()
    /// O picker não retém o delegate; sem esta referência "Salvar em…" some.
    @State private var delegadoDeCompartilhamento: OpcoesDeCompartilhamento?
    @State private var trechoEmEdicao: UUID?
    @State private var textoDoTrechoEmEdicao = ""
    @State private var falaEmEdicao: UUID?
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento
    @Environment(\.dismiss) private var fechar

    private var titulo: String { arquivo.resumo?.titulo ?? arquivo.titulo }
    @State private var pairandoNoTitulo = false
    @State private var legendaDaBarra: LegendaDaBarra?
    @State private var mostrandoFicha = false
    @State private var pairandoNaFicha = false
    @State private var entrevistadoDaFicha = ""
    @State private var entrevistadoresDaFicha = ""
    @State private var formatoDaFicha = ""
    private var metadados: MetadadosVisuaisDoArquivo {
        _ = versaoDaFicha
        return PreferenciasVisuaisDoArquivo.metadados(arquivo.id)
    }
    /// Vazio quando não foi preenchido; o cabeçalho assinala isso em vez de
    /// esconder a linha, para o campo não parecer inexistente.
    private var entrevistado: String {
        listaDePessoas(metadados.entrevistado)
    }
    private var entrevistadores: String {
        listaDePessoas(metadados.entrevistadores)
    }
    private var participantes: Int {
        max(1, metadados.participantes ?? participantesDetectados)
    }
    private var participantesDetectados: Int {
        let speakers = Set(arquivo.trechos.compactMap(\.speaker).filter { !$0.isEmpty })
        return max(1, speakers.count)
    }
    private var trechos: [Trecho] { arquivo.trechos }
    /// A conversa em falas por falante acústico — `nil` sem diarização, quando
    /// a transcrição continua em blocos de trecho.
    private var falas: [FalaDeFalante]? { FalasDaConversa.agrupar(trechos) }
    private var notas: [NotaDaConversa] { notasEditaveis }
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
            // O painel tem estado vazio próprio, com as ações de criar nota.
            false
        case .midia:
            false
        case .tarefas:
            false
        }
    }
    private var animacaoDeInterface: Animation? {
        reduzirMovimento ? nil : .easeInOut(duration: 0.2)
    }
    /// O player também aparece nas Notas: sem ele, num arquivo importado, ⌘N e
    /// ⌘K criariam tudo em 0:00 — a âncora de tempo, que é o valor da nota,
    /// deixaria de existir.
    private var deveMostrarPlayer: Bool {
        mostrandoPlayer || secaoSelecionada == .transcricao || secaoSelecionada == .notas
    }
    private var pastaDaConversa: URL {
        audio.deletingLastPathComponent()
    }
    /// Pergunta ao próprio player se ele conseguiu abrir o arquivo, em vez de
    /// checar um caminho na mão.
    ///
    /// Checar `audio.path` dava falso negativo: um áudio que está na aba Mídia
    /// mas não no nome canônico da conversa fazia a barra dizer "removido"
    /// mesmo com o arquivo visível ali. Duração zero depois de `preparar()` é
    /// o único sinal confiável de que o `AVAudioPlayer` não abriu nada.
    private var audioIndisponivel: Bool {
        guard let reprodutor else { return false }
        return reprodutor.duracao <= 0
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: PapagaioTema.Espaco.secao) {
                barraDeAcoes

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
                        // Barra de rolagem escondida nesta tela.
                        //
                        // Quem usa "Mostrar barras de rolagem: sempre" nos
                        // Ajustes do Sistema recebe uma barra opaca desenhada
                        // por cima do conteúdo — e aqui ela caía sobre os
                        // botões das notas, escondendo o lápis e a lixeira e
                        // roubando o clique deles. Como cada aba tem começo e
                        // fim visíveis, a barra não estava informando nada que
                        // a tela já não dissesse.
                        .scrollIndicators(.hidden)
                    }
                }
            }
            .larguraDeConteudoPapagaio()
            .padding(.horizontal, PapagaioTema.espacamentoDePagina)
            .padding(.vertical, PapagaioTema.espacamentoDePagina)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if deveMostrarPlayer, audioIndisponivel {
                avisoDeAudioRemovido
                    .transition(.opacity)
            } else if deveMostrarPlayer, let reprodutor {
                barraFlutuante(reprodutor)
                    .transition(
                        reduzirMovimento
                            ? .opacity
                            : .move(edge: .bottom).combined(with: .opacity)
                    )
            }
        }
        // `ignoresSafeArea` porque a janela está sem barra de título: sem
        // isto o topo ficava transparente e mostrava o papel de parede,
        // que era a faixa estranha acima do título.
        // Anuncia o espaço do player para quem posiciona o selo de gravação.
        // 116 é a altura da barra flutuante mais o respiro dela; zero quando o
        // player não está na tela, e aí o selo volta para o canto de baixo.
        .alturaDoPlayerPapagaio(deveMostrarPlayer ? 116 : 0)
        .overlay { LegendaGlobalDaBarra(texto: legendaDaBarra) }
        .background(PapagaioTema.fundo.ignoresSafeArea())
        // Piso baixo de propósito: acima disso o conteúdo era desenhado mais
        // largo que a janela e ficava cortado à direita em vez de se reorganizar.
        .frame(minWidth: 320, minHeight: 360, alignment: .topLeading)
        // Sem título na barra de navegação: o mesmo texto já aparece logo
        // abaixo como H1, e ver a frase duas vezes em 40pt de distância não
        // acrescenta nada. A janela continua identificada pelo H1 da página.
        .navigationTitle("")
        // O chevron do `NavigationStack` é desenhado pelo macOS e não aceita a
        // paleta do app — ficava um botão cinza do sistema convivendo com o
        // nosso, coral e com borda. Escondido, sobra só o da barra superior,
        // que já sabe desempilhar a conversa.
        .navigationBarBackButtonHidden(true)
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
            // Mesmo conteúdo do Compartilhar do cartão: resumo, transcrição,
            // notas, mídia e tarefas num documento só. O áudio não vai junto —
            // fica na aba Mídia, de onde pode ser aberto ou apagado.
            document: DocumentoMarkdown(conteudo: DossieDaConversa.gerar(arquivo: arquivo)),
            contentType: DocumentoMarkdown.tipo,
            defaultFilename: DossieDaConversa.nomeDeArquivo(para: arquivo)
        ) { _ in }
        .alert("Não foi possível adicionar a mídia", isPresented: Binding(
            get: { erroDeMidia != nil },
            set: { if !$0 { erroDeMidia = nil } }
        )) {
            Button("OK", role: .cancel) { erroDeMidia = nil }
        } message: {
            Text(erroDeMidia ?? "")
        }
        .sheet(isPresented: Binding(
            get: { trechoEmEdicao != nil || falaEmEdicao != nil },
            set: { if !$0 { cancelarEdicaoDoTrecho(); cancelarEdicaoDaFala() } }
        )) {
            folhaDeCorrecaoDoTrecho
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
                aoSalvar: salvarInformacoesDaConversa
            )
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

    /// A ficha troca de lugar com o selo de estado.
    ///
    /// Quem participou, quando e por quanto tempo é o que se consulta durante
    /// a leitura; "transcrito e resumido" é status de processamento, que
    /// interessa uma vez e depois vira paisagem. O ponto mais nobre da tela,
    /// ao lado do título, cabe ao primeiro.
    private var cabecalho: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .bottom, spacing: PapagaioTema.Espaco.largo) {
                textoDoCabecalho
                Spacer(minLength: 16)
                botaoDeFicha
            }

            VStack(alignment: .leading, spacing: PapagaioTema.Espaco.medio) {
                textoDoCabecalho
                botaoDeFicha
            }
        }
    }

    /// Ações da conversa dentro da página, e não numa `toolbar`.
    ///
    /// A toolbar do macOS desenha a própria faixa no topo da janela, com
    /// material translúcido — era aquela tira que insistia em aparecer, ainda
    /// mais visível em tela cheia. Como linha da página, ela é do mesmo fundo
    /// de tudo o mais, e a tela vira uma superfície só. O recuo à esquerda
    /// abre espaço para os semáforos da janela, que sem barra de título
    /// passam a flutuar sobre o conteúdo.
    private var barraDeAcoes: some View {
        HStack(spacing: PapagaioTema.Espaco.curto) {
            BotaoCircularPapagaio(
                simbolo: "chevron.backward",
                ajuda: "Voltar para a biblioteca",
                legendaAtiva: $legendaDaBarra
            ) {
                fechar()
            }

            Spacer(minLength: PapagaioTema.Espaco.curto)

            BotaoCircularPapagaio(
                simbolo: "square.and.arrow.up",
                ajuda: arquivo.resumo == nil
                    ? "Disponível depois que o resumo estiver pronto"
                    : "Compartilhar conversa",
                legendaAtiva: $legendaDaBarra
            ) {
                compartilhar()
            }
            .disabled(arquivo.resumo == nil)
        }
    }

    private var textoDoCabecalho: some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.curto) {
            // O título abre a ficha completa — é de lá que saem título e
            // descrição, que não cabem num popover de campo isolado.
            Button {
                abrirEditorDeInformacoes()
            } label: {
                // O chevron é o único indício de que o título abre alguma
                // coisa. Sem ele, um título grande em negrito parece só um
                // título, e a ficha ficava escondida atrás de um clique que
                // ninguém adivinha. Alinhado pela linha de base do texto para
                // não flutuar quando o título quebra em duas ou três linhas.
                HStack(alignment: .firstTextBaseline, spacing: PapagaioTema.Espaco.curto) {
                    Text(titulo)
                        .font(PapagaioTema.Tipo.tituloDePagina)
                        .minimumScaleFactor(0.6)
                        .foregroundStyle(PapagaioTema.texto)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(
                            pairandoNoTitulo
                                ? PapagaioTema.destaqueEscuro
                                : PapagaioTema.textoSecundario
                        )
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Editar título e descrição")
            .onHover { pairandoNoTitulo = $0 }
            .animation(.easeOut(duration: 0.14), value: pairandoNoTitulo)

            if !metadados.descricao.isEmpty {
                Text(metadados.descricao)
                    .font(PapagaioTema.Tipo.apoio)
                    .foregroundStyle(PapagaioTema.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }

        }
    }

    /// Ficha na ponta direita da linha das abas — só leitura.
    ///
    /// Editar acontece no formulário (pelo título ou pelo menu do cartão), que
    /// é onde a pessoa preenche isso de qualquer jeito. Deixar cada campo
    /// clicável aqui duplicava o mesmo caminho em dois lugares.
    /// A ficha virou botão.
    ///
    /// Em linha, ela ocupava a largura toda ao lado das abas e ainda assim só
    /// dava para ler — editar exigia abrir o editor completo pelo título. Como
    /// popover, ela some quando não interessa e vira formulário quando
    /// interessa, com o que faz sentido mudar já editável ali mesmo.
    private var botaoDeFicha: some View {
        Button {
            entrevistadoDaFicha = metadados.entrevistado
            entrevistadoresDaFicha = metadados.entrevistadores
            formatoDaFicha = metadados.formato
            mostrandoFicha = true
        } label: {
            // `person.text.rectangle` em vez de `info.circle`: o conteúdo é a
            // ficha de quem participou, não um aviso genérico. E o "i" já é o
            // símbolo da ajuda em outras abas — dois significados para o mesmo
            // desenho confundia.
            // Pastilha, e não aba: fora da barra de seções, o filete de 3pt
            // não teria com o que se alinhar. Mesma forma dos filtros da
            // biblioteca, que é a linguagem do app para "isto se clica".
            Label("Ficha", systemImage: "person.text.rectangle")
                .labelStyle(.titleAndIcon)
                .font(PapagaioTema.Tipo.apoio.weight(.semibold))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(
                    mostrandoFicha || pairandoNaFicha
                        ? PapagaioTema.destaqueEscuro
                        : PapagaioTema.textoSecundario
                )
                .padding(.horizontal, PapagaioTema.Espaco.medio)
                .frame(height: PapagaioTema.Altura.compacta)
                .background(
                    mostrandoFicha ? PapagaioTema.destaque.opacity(0.14) : .clear,
                    in: Capsule()
                )
                .overlay {
                    Capsule().stroke(
                        mostrandoFicha || pairandoNaFicha
                            ? PapagaioTema.destaque.opacity(0.58)
                            : PapagaioTema.borda.opacity(0.76),
                        lineWidth: 1
                    )
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("Ficha da conversa")
        .accessibilityLabel("Ficha da conversa")
        .onHover { pairandoNaFicha = $0 }
        .animation(.easeOut(duration: 0.14), value: pairandoNaFicha)
        .popover(isPresented: $mostrandoFicha, arrowEdge: .bottom) {
            fichaEmPopover
        }
    }

    /// A ficha só mostra. Quem edita é o formulário, no clique do título.
    ///
    /// Ter os dois caminhos de edição — o formulário completo e um modo de
    /// edição aqui dentro — significava manter duas telas fazendo a mesma
    /// coisa, com regras que precisavam concordar. E o popover crescia de 280
    /// para 460pt no clique do "Editar", o que fazia a tela pular. Como espelho
    /// do formulário, ele fica sempre do mesmo tamanho e sempre igual.
    private var fichaEmPopover: some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.largo) {
            // Rótulo concordando em gênero e número com quem está na lista:
            // "Entrevistado: Ana, João" lia errado duas vezes — como se fosse
            // uma pessoa só, e como se essa pessoa fosse homem.
            linhaDaFicha(
                rotuloDeEntrevistadores(nomesDePessoas(entrevistadoresDaFicha)),
                valor: entrevistadoresDaFicha,
                simbolo: "person.crop.circle.badge.checkmark"
            )
            linhaDaFicha(
                rotuloDeEntrevistados(nomesDePessoas(entrevistadoDaFicha)),
                valor: entrevistadoDaFicha,
                simbolo: "person"
            )
            linhaDaFicha(
                "Modalidade",
                valor: formatoDaFicha,
                simbolo: simboloDaModalidade(formatoDaFicha)
            )

            Divider()

            // Estes três são consequência, não escolha: participantes sai dos
            // nomes acima, data e duração vêm do próprio áudio.
            VStack(alignment: .leading, spacing: PapagaioTema.Espaco.curto) {
                dadoDaFicha(textoDeParticipantes, simbolo: participantesDaFicha > 1 ? "person.2" : "person")
                dadoDaFicha(
                    DataDigitada.textoComHora(de: arquivo.criadoEm),
                    simbolo: "calendar"
                )
                dadoDaFicha(arquivo.duracao.comoDuracaoPorExtenso, simbolo: "clock")
            }
        }
        .padding(PapagaioTema.Espaco.largo)
        .frame(width: 300)
    }

    /// Contado a partir dos nomes salvos, e não de um campo próprio: o número
    /// é consequência de quem foi preenchido no formulário.
    private var participantesDaFicha: Int {
        nomesInformados(entrevistadoDaFicha) + nomesInformados(entrevistadoresDaFicha)
    }

    /// Ninguém preenchido é **zero**, não um.
    ///
    /// O piso em 1 vinha de supor que sempre há ao menos quem gravou. Mas a
    /// ficha mostra quem foi *informado*, e afirmar "1 participante" para uma
    /// conversa vazia é inventar um dado — ainda por cima um que a pessoa não
    /// tem como corrigir, já que o número é calculado.
    private var textoDeParticipantes: String {
        switch participantesDaFicha {
        case 0: "Participantes não informados"
        case 1: "1 participante"
        default: "\(participantesDaFicha) participantes"
        }
    }

    /// Mesma coluna de ícone das linhas de cima — 18pt fixos.
    ///
    /// `Label` dimensiona cada glifo pelo desenho, e `person.2` é bem mais
    /// largo que `clock`: os textos começavam em três posições diferentes.
    private func dadoDaFicha(_ texto: String, simbolo: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: PapagaioTema.Espaco.curto) {
            Image(systemName: simbolo)
                .font(PapagaioTema.Tipo.apoio)
                .foregroundStyle(PapagaioTema.textoSecundario)
                .frame(width: 18, alignment: .leading)

            Text(texto)
                .font(PapagaioTema.Tipo.apoio)
                .foregroundStyle(PapagaioTema.textoSecundario)
        }
    }

    /// Uma linha da ficha em leitura. Campo vazio continua aparecendo, dizendo
    /// que não foi informado: sumir dava a impressão de que a ficha nem existe.
    private func linhaDaFicha(_ rotulo: String, valor: String, simbolo: String) -> some View {
        let limpo = valor.trimmingCharacters(in: .whitespacesAndNewlines)
        return HStack(alignment: .firstTextBaseline, spacing: PapagaioTema.Espaco.curto) {
            Image(systemName: simbolo)
                .font(PapagaioTema.Tipo.apoio)
                .foregroundStyle(PapagaioTema.textoSecundario)
                .frame(width: 18, alignment: .leading)

            VStack(alignment: .leading, spacing: 1) {
                Text(rotulo)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PapagaioTema.destaqueEscuro)
                    .textCase(.uppercase)
                Text(limpo.isEmpty ? "Não informado" : limpo)
                    .font(PapagaioTema.Tipo.apoio)
                    .foregroundStyle(limpo.isEmpty ? PapagaioTema.textoSecundario : PapagaioTema.texto)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var fichaDoCabecalho: some View {
        // Fluxo em vez de linha rígida: com muitos nomes ela quebra dentro do
        // próprio espaço, sem empurrar as abas nem sumir na borda da janela.
        LayoutDeFluxo(espacoHorizontal: PapagaioTema.Espaco.medio, espacoVertical: PapagaioTema.Espaco.minimo) {
            // Campo vazio continua visível, dizendo que não foi informado:
            // sumir dava a impressão de que a ficha nem existia.
            metadadoDoCabecalho(
                entrevistado.isEmpty
                    ? "Entrevistado não informado"
                    : "\(rotuloDeEntrevistados(nomesDePessoas(entrevistado))): \(entrevistado)",
                simbolo: "person"
            )
            metadadoDoCabecalho(
                entrevistadores.isEmpty
                    ? "Entrevistador não informado"
                    : "\(rotuloDeEntrevistadores(nomesDePessoas(entrevistadores))): \(entrevistadores)",
                simbolo: "person.crop.circle.badge.checkmark"
            )
            metadadoDoCabecalho(
                metadados.formato.isEmpty ? "Modalidade não informada" : metadados.formato,
                simbolo: simboloDaModalidade(metadados.formato)
            )
            metadadoDoCabecalho(
                participantes == 1 ? "1 participante" : "\(participantes) participantes",
                simbolo: participantes == 1 ? "person" : "person.2"
            )
            metadadoDoCabecalho(
                DataDigitada.textoComHora(de: arquivo.criadoEm),
                simbolo: "calendar"
            )
            metadadoDoCabecalho(arquivo.duracao.comoDuracaoPorExtenso, simbolo: "clock")
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

    private func salvarInformacoesDaConversa() {
        let tituloLimpo = tituloEditado.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tituloLimpo.isEmpty else { return }

        let quantidade = max(
            1,
            nomesInformados(entrevistadoEditado) + nomesInformados(entrevistadoresEditados)
        )

        // Antes de sobrescrever: depois, os metadados antigos já não estão
        // por aqui para comparar, e a foto ficaria presa numa chave que nada
        // mais lê.
        let entrevistadoLimpo = entrevistadoEditado.trimmingCharacters(in: .whitespacesAndNewlines)
        let entrevistadoresLimpos = entrevistadoresEditados.trimmingCharacters(in: .whitespacesAndNewlines)
        FotosDePessoas.migrarAoEditarNomes(de: metadados.entrevistado, para: entrevistadoLimpo)
        FotosDePessoas.migrarAoEditarNomes(de: metadados.entrevistadores, para: entrevistadoresLimpos)

        PreferenciasVisuaisDoArquivo.definirMetadados(
            MetadadosVisuaisDoArquivo(
                entrevistado: entrevistadoLimpo,
                emailDoEntrevistado: emailDoEntrevistadoEditado.trimmingCharacters(in: .whitespacesAndNewlines),
                entrevistadores: entrevistadoresLimpos,
                emailDosEntrevistadores: emailDosEntrevistadoresEditado.trimmingCharacters(in: .whitespacesAndNewlines),
                descricao: descricaoEditada.trimmingCharacters(in: .whitespacesAndNewlines),
                formato: formatoEditado.trimmingCharacters(in: .whitespacesAndNewlines),
                participantes: quantidade
            ),
            para: arquivo.id
        )

        aoAtualizarMetadados(tituloLimpo, dataEditada, arquivo.duracao)
        editandoInformacoes = false
    }

    private func nomesInformados(_ texto: String) -> Int {
        texto
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .count
    }

    private func simboloDaModalidade(_ formato: String) -> String {
        switch formato {
        case "Presencial": "mappin.and.ellipse"
        case "Online": "video"
        default: "questionmark.circle"
        }
    }

    private func metadadoDoCabecalho(_ texto: String, simbolo: String) -> some View {
        Label(texto, systemImage: simbolo)
            .font(PapagaioTema.Tipo.apoio)
            .foregroundStyle(PapagaioTema.textoSecundario)
            .lineLimit(1)
            // `LayoutDeFluxo` mede cada item pelo tamanho natural; sem isto o
            // rótulo comprido tentaria ocupar a linha toda.
            .fixedSize(horizontal: true, vertical: false)
    }

    private var seletorDeSecao: some View {
        BarraDeSecoesDaConversa(
            secaoSelecionada: secaoSelecionada,
            aoSelecionar: { secao in
                withAnimation(animacaoDeInterface) {
                    secaoSelecionada = secao
                }
            },
            // Sem acessório: o selo de estado saiu da tela. Dentro da conversa
            // ele era redundante — quem está lendo resumo e transcrição já sabe
            // que ambos existem. Ele continua no cartão da biblioteca, que é
            // onde a pergunta "isso já ficou pronto?" de fato aparece.
            acessorio: { EmptyView() }
        )
    }

    /// Todo o conteúdo da conversa é texto selecionável.
    ///
    /// Resumo, transcrição, citações e tarefas existem para serem levados para
    /// fora — relatório, e-mail, Notion. Sem seleção, a única saída era o
    /// Compartilhar, que exporta a conversa inteira; copiar uma frase exigia
    /// redigitá-la.
    ///
    /// `.textSelection(.enabled)` no contêiner vale para todo `Text` abaixo
    /// dele, e traz junto o que o macOS já sabe fazer com texto selecionado:
    /// Cmd+C, arrastar para outro app, Serviços e o menu de contexto.
    @ViewBuilder
    private var conteudoDaSecao: some View {
        conteudoBrutoDaSecao
            .textSelection(.enabled)
            // Atalho para quem quer tudo: selecionar a conversa inteira à mão
            // dá trabalho, e é o caso mais comum depois de copiar uma frase.
            .contextMenu {
                Button("Copiar conversa inteira", systemImage: "doc.on.doc") {
                    let texto = DossieDaConversa.gerar(arquivo: arquivo)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(texto, forType: .string)
                }
            }
    }

    @ViewBuilder
    private var conteudoBrutoDaSecao: some View {
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
            VStack(alignment: .leading, spacing: PapagaioTema.Espaco.largo) {
                Text(resumo.visaoGeral)
                    .font(PapagaioTema.Tipo.corpo)
                    .foregroundStyle(PapagaioTema.texto)
                    .fixedSize(horizontal: false, vertical: true)

                if !resumo.temas.isEmpty {
                    secao("Temas") {
                        // Grade adaptativa: numa janela estreita vira uma coluna,
                        // numa tela larga os temas ocupam a faixa toda em vez de
                        // formarem uma lista fina no canto esquerdo.
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 320), spacing: PapagaioTema.Espaco.largo, alignment: .topLeading)],
                            alignment: .leading,
                            spacing: PapagaioTema.Espaco.medio
                        ) {
                            ForEach(Array(resumo.temas.enumerated()), id: \.offset) { _, tema in
                                VStack(alignment: .leading, spacing: PapagaioTema.Espaco.minimo) {
                                    Text(tema.titulo)
                                        .font(PapagaioTema.Tipo.apoio.weight(.semibold))
                                        .foregroundStyle(PapagaioTema.texto)
                                    Text(tema.detalhe)
                                        .font(PapagaioTema.Tipo.apoio)
                                        .foregroundStyle(PapagaioTema.textoSecundario)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                                .padding(.vertical, PapagaioTema.Espaco.minimo)
                            }
                        }
                    }
                }

            }
            // O card acompanha a janela (até o limite de página) em vez de ficar
            // preso a 720pt: em tela cheia sobrava um vazio enorme à direita.
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(PapagaioTema.Espaco.secao)
            .cartaoPapagaio()
            .frame(maxWidth: .infinity, alignment: .leading)
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
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.curto) {
            Text(titulo)
                .font(PapagaioTema.Tipo.tituloDeSecao)
                .foregroundStyle(PapagaioTema.texto)
            conteudo()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, PapagaioTema.Espaco.curto)
    }

    // MARK: - Mídia

    private var midia: some View {
        MidiaDaConversaView(
            anexos: anexosDaGravacao + anexosDeMidia,
            aoAdicionar: selecionarMidias,
            aoAbrir: abrirMidia,
            aoRemover: removerMidia,
            naLixeira: midiasNaLixeiraDaConversa,
            aoRestaurar: { item in
                if LixeiraDeMidia.restaurar(item) {
                    carregarMidias()
                    recarregarLixeiraDeMidia()
                } else {
                    erroDeMidia = "Não foi possível restaurar \(item.nome)."
                }
            },
            aoApagarDeVez: { item in
                LixeiraDeMidia.remover(item)
                recarregarLixeiraDeMidia()
            }
        )
    }

    private func recarregarLixeiraDeMidia() {
        midiasNaLixeiraDaConversa = LixeiraDeMidia.itens()
            .filter { $0.arquivoID == arquivo.id }
            .sorted { $0.apagadoEm > $1.apagadoEm }
    }

    private func carregarMidias() {
        anexosDeMidia = MidiasDaConversa.carregar(arquivo.id)
        anexosDaGravacao = gravacoesDaConversa()
        recarregarLixeiraDeMidia()
    }

    /// O áudio da própria gravação entra fixo na lista de mídia: depois que a
    /// transcrição e o resumo estão prontos o arquivo costuma virar só peso em
    /// disco, e daqui o usuário consegue apagá-lo sem sair do app.
    private func gravacoesDaConversa() -> [AnexoDeMidiaDaConversa] {
        [audio, audioSecundario]
            .compactMap { $0 }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
            .compactMap { try? MidiasDaConversa.anexo(para: $0) }
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
            let destino = try MidiasDaConversa.copiar(url, para: pastaDaConversa, tituloDaConversa: titulo)
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
        AberturaDeMidia.abrir(anexo.url)
    }

    private func removerMidia(_ anexo: AnexoDeMidiaDaConversa) {
        if anexosDaGravacao.contains(where: { $0.id == anexo.id }) {
            removerAudioDaGravacao(anexo)
            return
        }

        let atualizados = anexosDeMidia.filter { $0.id != anexo.id }
        do {
            // Vai para a lixeira em vez de sumir: o anexo pode ser a única
            // cópia que a pessoa tem, e ela pode ter clicado sem querer.
            try moverParaLixeira(anexo, daGravacao: false)
            try MidiasDaConversa.salvar(atualizados, para: arquivo.id)
            anexosDeMidia = atualizados
            // Sem isto o cartão apagado só apareceria na próxima abertura da
            // aba: a lista de removidos é lida do disco, não deduzida daqui.
            recarregarLixeiraDeMidia()
        } catch {
            erroDeMidia = "Não foi possível remover esse arquivo: \(error.localizedDescription)"
        }
    }

    private func moverParaLixeira(_ anexo: AnexoDeMidiaDaConversa, daGravacao: Bool) throws {
        try LixeiraDeMidia.mover(
            url: anexo.url,
            nome: anexo.nome,
            tamanho: anexo.tamanho,
            tipo: anexo.tipoVisual,
            daGravacao: daGravacao,
            arquivoID: arquivo.id,
            conversaTitulo: titulo,
            pastaDaConversa: pastaDaConversa
        )
    }

    /// Remover o áudio cega a reprodução, então só liberamos depois que a
    /// transcrição existe — que é justamente quando o arquivo deixa de ser
    /// necessário. O arquivo vai para a lixeira, de onde volta se for o caso.
    private func removerAudioDaGravacao(_ anexo: AnexoDeMidiaDaConversa) {
        guard !trechos.isEmpty else {
            erroDeMidia = "O áudio da gravação só pode ser removido depois que a transcrição terminar."
            return
        }

        reprodutor?.pausar()

        do {
            try moverParaLixeira(anexo, daGravacao: true)
            anexosDaGravacao = gravacoesDaConversa()
            recarregarLixeiraDeMidia()
        } catch {
            erroDeMidia = "Não foi possível mover o áudio da gravação para a lixeira: \(error.localizedDescription)"
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
        statusDaNovaTarefa = .naoIniciado
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

    /// Uma ação só: documento e áudio no mesmo pacote, e dentro do painel do
    /// sistema também a opção de salvar em pasta.
    private func compartilhar() {
        let itens: [Any]
        do {
            itens = [try DossieDaConversa.pacoteComAudio(arquivo: arquivo, audioPrincipal: audio)]
        } catch {
            let destino = FileManager.default.temporaryDirectory
                .appendingPathComponent(DossieDaConversa.nomeDeArquivo(para: arquivo))
            if (try? DossieDaConversa.gerar(arquivo: arquivo)
                .write(to: destino, atomically: true, encoding: .utf8)) != nil {
                itens = [destino]
            } else {
                itens = [DossieDaConversa.gerar(arquivo: arquivo)]
            }
        }

        apresentarCompartilhamento(itens)
    }

    private func apresentarCompartilhamento(_ itens: [Any]) {
        let picker = NSSharingServicePicker(items: itens)
        let opcoes = OpcoesDeCompartilhamento(arquivos: itens.compactMap { $0 as? URL })
        delegadoDeCompartilhamento = opcoes
        picker.delegate = opcoes

        if let view = NSApp.keyWindow?.contentView {
            picker.show(relativeTo: view.bounds, of: view, preferredEdge: .maxY)
        }
    }

    private var avisoDeAudioRemovido: some View {
        HStack(spacing: PapagaioTema.Espaco.medio) {
            Image(systemName: "speaker.slash")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(PapagaioTema.aviso)
                .frame(width: 48, height: 48)
                .background(PapagaioTema.aviso.opacity(0.12), in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))

            VStack(alignment: .leading, spacing: PapagaioTema.Espaco.minimo) {
                Text("Não foi possível abrir o áudio desta conversa")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(PapagaioTema.texto)

                Text("A transcrição, as notas e o resumo continuam aqui. Restaure o áudio pela Lixeira do app — assim ele volta com o nome que a reprodução espera.")
                    .font(.callout)
                    .foregroundStyle(PapagaioTema.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)
        }
        .padding(.horizontal, PapagaioTema.Espaco.secao)
        .padding(.vertical, PapagaioTema.Espaco.largo)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .background(PapagaioTema.superficie)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(PapagaioTema.borda.opacity(0.75))
                .frame(height: 1)
        }
        .accessibilityElement(children: .combine)
    }

    /// O player em uma linha quando cabe, empilhado só quando não cabe.
    ///
    /// Estava fixo em `compacto: true`, ou seja, sempre na versão empilhada de
    /// 208pt — três vezes a altura necessária numa janela larga, comendo a
    /// parte de baixo da transcrição sem motivo. `ViewThatFits` escolhe pela
    /// largura real: a faixa de 88pt em tela normal, a empilhada só na estreita,
    /// que é o caso para o qual ela foi feita.
    private func barraFlutuante(_ reprodutor: ReprodutorDeArquivo) -> some View {
        ViewThatFits(in: .horizontal) {
            barraDeAudio(reprodutor, compacto: false)
            barraDeAudio(reprodutor, compacto: true)
        }
    }

    private func barraDeAudio(_ reprodutor: ReprodutorDeArquivo, compacto: Bool) -> some View {
        BarraDeAudioDaConversa(
            titulo: titulo,
            data: arquivo.criadoEm,
            reprodutor: reprodutor,
            tempoEmEdicao: $tempoEmEdicao,
            aoConcluirEdicao: { concluirEdicaoDaPosicao(reprodutor) },
            compacto: compacto
        )
    }

    // MARK: - Transcrição

    /// Sem `ScrollView` próprio: o conteúdo da seção já vive dentro de um.
    ///
    /// Duas rolagens empilhadas davam duas barras — uma delas caindo por cima
    /// dos botões das notas — e faziam o bloco de escrita rolar para fora da
    /// tela e ser cortado pela barra de abas. A de fora basta.
    private var notasDaConversa: some View {
        PainelDeNotasDaConversa(
            notas: $notasEditaveis,
            estadoDeSalvamento: estadoDeSalvamentoDasNotas,
            duracao: arquivo.duracao,
            instanteAtual: { reprodutor?.tempo ?? 0 },
            ditado: ditado,
            aoTocar: tocar,
            aoSalvar: agendarSalvamentoDasNotas,
            aoAlternarDitado: alternarDitado
        )
        .padding(.bottom, PapagaioTema.Espaco.secao)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Carrega as notas do arquivo. O bloco único que existia antes continua
    /// válido — vira uma nota como as outras, ancorada em 0:00.
    private func sincronizarNotasComArquivo() {
        notasEditaveis = arquivo.notas.sorted {
            $0.start == $1.start ? $0.id.uuidString < $1.id.uuidString : $0.start < $1.start
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
        let atualizadas = notasEditaveis.sorted {
            $0.start == $1.start ? $0.id.uuidString < $1.id.uuidString : $0.start < $1.start
        }
        notasEditaveis = atualizadas
        estadoDeSalvamentoDasNotas = "Salvando..."

        Task { @MainActor in
            await aoAtualizarNotas(atualizadas)
            estadoDeSalvamentoDasNotas = "Salvo"
        }
    }

    /// Ditar acrescenta uma nota nova no instante atual, em vez de emendar no
    /// fim de um bloco — cada fala vira um item que se pode marcar e filtrar.
    private func alternarDitado() {
        ditado.limparFalha()

        Task { @MainActor in
            if ditado.gravando {
                guard let falado = await ditado.concluir(transcrever: aoDitar) else { return }
                let instante = min(max(0, reprodutor?.tempo ?? 0), max(arquivo.duracao, 0))
                notasEditaveis.append(
                    NotaDaConversa(texto: falado, start: instante, critica: false, tipo: .nota)
                )
                salvarNotasAgora()
            } else {
                await ditado.iniciar()
            }
        }
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
            if let falas {
                transcricaoDeFalas(falas, no: reprodutor)
            } else {
                transcricaoDeTrechos(no: reprodutor)
            }
        }
    }

    /// Leitura por fala de falante: a voz é a unidade, não o bloco de texto.
    ///
    /// O destaque do player continua casando pela âncora da palavra — cada
    /// palavra da fala sabe o trecho e o índice de onde veio, então a rolagem
    /// e o destaque reagem ao áudio como na lista de trechos.
    private func transcricaoDeFalas(
        _ falas: [FalaDeFalante], no reprodutor: ReprodutorDeArquivo
    ) -> some View {
        ScrollViewReader { rolagem in
            LazyVStack(alignment: .leading, spacing: PapagaioTema.Espaco.curto) {
                ForEach(falas) { fala in
                    LinhaDeFala(
                        fala: fala,
                        ativo: falaEstaAtiva(fala, no: reprodutor),
                        palavraAtiva: palavraAtiva(fala, no: reprodutor),
                        animacao: animacaoDeInterface,
                        aoTocarFala: { tocar(fala, no: reprodutor) },
                        aoTocarPalavra: { palavra in
                            tocar(palavra, no: reprodutor)
                        }
                    )
                    .id(fala.id)
                    // Lápis visível, como na linha de trecho: a correção de
                    // uma fala reescreve os trechos de onde ela saiu.
                    .overlay(alignment: .topTrailing) {
                        Button {
                            iniciarEdicaoDaFala(fala)
                        } label: {
                            Image(systemName: "pencil")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(PapagaioTema.destaqueEscuro)
                                .frame(width: 26, height: 26)
                                .background(PapagaioTema.destaqueSuave, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Corrigir o texto da fala em \(fala.inicio.comoRelogio)")
                        .padding(PapagaioTema.Espaco.curto)
                    }
                }
            }
            .onChange(of: reprodutor.indiceAtivo) { _, novo in
                guard let novo, novo < trechos.count else { return }
                let trechoAtivo = trechos[novo]
                guard let fala = falas.first(where: { $0.trechoIds.contains(trechoAtivo.id) }) else {
                    return
                }
                withAnimation(animacaoDeInterface) {
                    rolagem.scrollTo(fala.id, anchor: .center)
                }
            }
        }
    }

    /// A fala está tocando quando o trecho ativo saiu dela.
    private func falaEstaAtiva(_ fala: FalaDeFalante, no reprodutor: ReprodutorDeArquivo) -> Bool {
        guard let indice = reprodutor.indiceAtivo, trechos.indices.contains(indice) else {
            return false
        }
        return fala.trechoIds.contains(trechos[indice].id)
    }

    /// A palavra tocando dentro da fala, casada pela âncora no trecho de
    /// origem — ou `nil` quando a fala não está ativa ou é legada.
    private func palavraAtiva(_ fala: FalaDeFalante, no reprodutor: ReprodutorDeArquivo) -> PalavraDeFala? {
        guard falaEstaAtiva(fala, no: reprodutor),
              let indiceDoTrecho = reprodutor.indiceAtivo,
              let indiceDaPalavra = reprodutor.indiceDePalavraAtiva,
              trechos.indices.contains(indiceDoTrecho)
        else { return nil }
        let trecho = trechos[indiceDoTrecho]
        guard trecho.palavras.indices.contains(indiceDaPalavra) else { return nil }
        return PalavraDeFala(
            palavra: trecho.palavras[indiceDaPalavra],
            trechoId: trecho.id,
            indiceNoTrecho: indiceDaPalavra
        )
    }

    private func transcricaoDeTrechos(no reprodutor: ReprodutorDeArquivo) -> some View {
        ScrollViewReader { rolagem in
            LazyVStack(alignment: .leading, spacing: PapagaioTema.Espaco.curto) {
                ForEach(Array(trechos.enumerated()), id: \.element.id) { indice, trecho in
                    let ativo = indice == reprodutor.indiceAtivo
                        LinhaDeTranscricao(
                            trecho: trecho,
                            ativo: ativo,
                            // Só o trecho ativo consulta a palavra: o
                            // destaque por palavra é observado na linha
                            // certa, não na transcrição inteira.
                            indiceDePalavraAtiva: ativo ? reprodutor.indiceDePalavraAtiva : nil,
                            animacao: animacaoDeInterface,
                            aoTocarLinha: { tocar(trecho, no: reprodutor) },
                            aoTocarPalavra: { palavra in
                                tocar(palavra, no: reprodutor)
                            }
                        )
                        .id(trecho.id)
                        // Lápis visível: escondido só no menu de contexto,
                        // ninguém descobria que dava para corrigir o texto.
                        // Fica sobreposto para a linha do Felipe continuar
                        // intacta — o clique simples segue tocando.
                        .overlay(alignment: .topTrailing) {
                            Button {
                                iniciarEdicaoDoTrecho(trecho)
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(PapagaioTema.destaqueEscuro)
                                    .frame(width: 26, height: 26)
                                    .background(PapagaioTema.destaqueSuave, in: Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Corrigir o texto do trecho em \(trecho.start.comoRelogio)")
                            .padding(PapagaioTema.Espaco.curto)
                        }
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

    /// Correção em folha, e não dentro da lista.
    ///
    /// Na lista o campo abria mas não recebia o teclado: a linha é um alvo de
    /// toque para tocar o trecho, e a rolagem automática do trecho ativo
    /// reposicionava tudo embaixo do cursor. Numa folha o foco é só dele.
    ///
    /// Serve para o trecho e para a fala: ao salvar uma fala, os trechos de
    /// onde ela saiu são fundidos num só com o texto corrigido, e as palavras
    /// são descartadas (os tempos do Whisper deixam de valer).
    private var folhaDeCorrecaoDoTrecho: some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.largo) {
            VStack(alignment: .leading, spacing: PapagaioTema.Espaco.minimo) {
                Text(trechoSendoCorrigido != nil ? "Corrigir trecho" : "Corrigir fala")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(PapagaioTema.texto)

                if let trecho = trechoSendoCorrigido {
                    Text("Em \(trecho.start.comoRelogio) da conversa")
                        .font(.callout)
                        .foregroundStyle(PapagaioTema.textoSecundario)
                } else if let fala = falaSendoCorrigida {
                    Text("Em \(fala.inicio.comoRelogio) da conversa")
                        .font(.callout)
                        .foregroundStyle(PapagaioTema.textoSecundario)
                }
            }

            TextEditor(text: $textoDoTrechoEmEdicao)
                .font(.system(size: 16))
                .foregroundStyle(PapagaioTema.texto)
                .scrollContentBackground(.hidden)
                .textEditorStyle(.plain)
                .padding(PapagaioTema.Espaco.medio)
                .frame(minHeight: 160)
                .background(PapagaioTema.superficie, in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
                        .stroke(PapagaioTema.borda, lineWidth: 1)
                }

            Text("O destaque por palavra é descartado ao salvar: os tempos vêm do Whisper e deixam de valer para o texto novo.")
                .font(.caption)
                .foregroundStyle(PapagaioTema.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: PapagaioTema.Espaco.medio) {
                Spacer()

                Button("Cancelar") { cancelarEdicaoDoTrecho(); cancelarEdicaoDaFala() }
                    .buttonStyle(BotaoDeContornoPapagaio())

                Button("Salvar") {
                    if let trecho = trechoSendoCorrigido {
                        salvarEdicaoDoTrecho(trecho)
                    } else if let fala = falaSendoCorrigida {
                        salvarEdicaoDaFala(fala)
                    }
                }
                .buttonStyle(BotaoPrincipalPapagaio())
                .keyboardShortcut(.return, modifiers: [.command])
            }
        }
        .padding(PapagaioTema.Espaco.secao)
        .frame(minWidth: 460, idealWidth: 560, alignment: .leading)
        .background(PapagaioTema.fundo)
    }

    private var trechoSendoCorrigido: Trecho? {
        trechos.first { $0.id == trechoEmEdicao }
    }

    private var falaSendoCorrigida: FalaDeFalante? {
        falas?.first { $0.id == falaEmEdicao }
    }

    private func iniciarEdicaoDoTrecho(_ trecho: Trecho) {
        textoDoTrechoEmEdicao = trecho.texto
        trechoEmEdicao = trecho.id
    }

    private func cancelarEdicaoDoTrecho() {
        trechoEmEdicao = nil
        textoDoTrechoEmEdicao = ""
    }

    private func iniciarEdicaoDaFala(_ fala: FalaDeFalante) {
        textoDoTrechoEmEdicao = fala.texto
        falaEmEdicao = fala.id
    }

    private func cancelarEdicaoDaFala() {
        falaEmEdicao = nil
        textoDoTrechoEmEdicao = ""
    }

    private func salvarEdicaoDoTrecho(_ trecho: Trecho) {
        let limpo = textoDoTrechoEmEdicao.trimmingCharacters(in: .whitespacesAndNewlines)
        cancelarEdicaoDoTrecho()
        guard !limpo.isEmpty, limpo != trecho.texto else { return }

        let atualizados = trechos.map { atual in
            atual.id == trecho.id ? atual.comTextoEditado(limpo) : atual
        }

        Task { @MainActor in
            await aoAtualizarTranscricao(atualizados)
        }
    }

    /// Corrige o texto de uma fala inteira.
    ///
    /// A fala atravessa trechos; ao salvar, os trechos de onde ela saiu são
    /// fundidos num só com o texto corrigido (o `start`/`end` dos trechos
    /// originais são mantidos: a janela da fala não muda, só o texto). As
    /// palavras são descartadas — como na correção de trecho, os tempos do
    /// Whisper deixam de valer para o texto novo.
    private func salvarEdicaoDaFala(_ fala: FalaDeFalante) {
        let limpo = textoDoTrechoEmEdicao.trimmingCharacters(in: .whitespacesAndNewlines)
        cancelarEdicaoDaFala()
        guard !limpo.isEmpty, limpo != fala.texto else { return }

        let idsDaFala = Set(fala.trechoIds)
        guard let primeiro = trechos.first(where: { idsDaFala.contains($0.id) }),
              let ultimo = trechos.last(where: { idsDaFala.contains($0.id) })
        else { return }

        let fundido = Trecho(
            id: primeiro.id,
            start: primeiro.start,
            end: ultimo.end,
            texto: limpo,
            speaker: primeiro.speaker,
            palavras: []
        )
        var atualizados = trechos
            .filter { !idsDaFala.contains($0.id) }
            .sorted { $0.start < $1.start }
        atualizados.insert(fundido, at: indiceDeInsercao(fundido, em: atualizados))

        Task { @MainActor in
            await aoAtualizarTranscricao(atualizados)
        }
    }

    /// Posição do trecho fundido numa lista ordenada por `start` — o trecho
    /// mantém a ordem cronológica depois de substituir a fala.
    private func indiceDeInsercao(_ trecho: Trecho, em trechos: [Trecho]) -> Int {
        trechos.firstIndex { $0.start > trecho.start } ?? trechos.endIndex
    }

    private var transcricaoPendente: some View {
        VStack(spacing: PapagaioTema.Espaco.medio) {
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
        .padding(PapagaioTema.Espaco.pagina)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }

    private func tocar(_ palavra: Palavra, no reprodutor: ReprodutorDeArquivo) {
        tempoEmEdicao = nil
        Task { @MainActor in
            // O timestamp é próprio da palavra (token_timestamps) — o salto
            // pousa no átomo da fala, não numa divisão do trecho.
            await reprodutor.saltar(paraSegundo: palavra.start)
        }
    }

    private func tocar(_ fala: FalaDeFalante, no reprodutor: ReprodutorDeArquivo) {
        tempoEmEdicao = nil
        revelarPlayer()
        Task { @MainActor in
            // A fala pode ter nascido no fim de um trecho; o salto usa o
            // início da fala, não o do trecho — o áudio começa na fala.
            await reprodutor.saltar(paraSegundo: fala.inicio)
            reprodutor.tocar()
        }
    }

    // MARK: - Formatação

}
