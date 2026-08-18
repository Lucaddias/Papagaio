import SwiftUI

/// Os interruptores dos campos do cartão, sem moldura própria.
///
/// Existe separado porque os mesmos controles aparecem em dois lugares — nas
/// Configurações e no menu de um cartão. Duplicar a lista significaria, mais
/// cedo ou mais tarde, um campo novo aparecendo só num dos dois.
struct ListaDeCamposDoCartao: View {
    @Binding var campos: CamposDoCartao

    /// Fileiras, e não interruptores soltos numa coluna.
    ///
    /// Com o rótulo à esquerda e o interruptor lá no fim da linha, o olho tinha
    /// de atravessar um vão vazio para ligar um ao outro — e a alguns campos de
    /// distância já não dava para ter certeza de qual interruptor era de qual
    /// campo. Cada fileira ganha um fundo próprio: o par volta a ser um objeto
    /// só, e a linha inteira responde ao clique, que é o alvo que a pessoa
    /// mira de qualquer jeito.
    var body: some View {
        VStack(spacing: PapagaioTema.Espaco.minimo) {
            ForEach(CamposDoCartao.catalogo, id: \.campo.rawValue) { item in
                FileiraDeCampoDoCartao(
                    titulo: item.titulo,
                    detalhe: item.detalhe,
                    ligado: ligado(item.campo)
                )
            }
        }
    }

    /// Um `Binding` por campo, montado a partir do conjunto.
    ///
    /// Guardar um `Bool` de estado por campo daria dois lugares para a mesma
    /// verdade — e é aí que a lista e o cartão passam a discordar.
    private func ligado(_ campo: CamposDoCartao) -> Binding<Bool> {
        Binding(
            get: { campos.contains(campo) },
            set: { ativo in
                withAnimation(.snappy(duration: 0.22)) {
                    if ativo { campos.insert(campo) } else { campos.remove(campo) }
                }
            }
        )
    }
}

/// Uma linha da lista: nome, explicação e o interruptor, num bloco só.
private struct FileiraDeCampoDoCartao: View {
    let titulo: String
    let detalhe: String
    @Binding var ligado: Bool

    @State private var pairando = false

    var body: some View {
        HStack(alignment: .center, spacing: PapagaioTema.Espaco.medio) {
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(PapagaioTema.texto)

                Text(detalhe)
                    .font(.caption)
                    .foregroundStyle(PapagaioTema.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Toggle("", isOn: $ligado)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(PapagaioTema.destaque)
        }
        .padding(.horizontal, PapagaioTema.Espaco.medio)
        .padding(.vertical, PapagaioTema.Espaco.curto)
        .background(
            fundo,
            in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
        )
        .contentShape(Rectangle())
        // A fileira inteira alterna o campo. O interruptor continua ali como
        // sinal de estado — e continua clicável por conta própria.
        .onTapGesture { ligado.toggle() }
        .onHover { pairando = $0 }
        .animation(.easeOut(duration: 0.12), value: pairando)
        .animation(.easeOut(duration: 0.12), value: ligado)
    }

    /// Ligado tem fundo, desligado não: a coluna vira um resumo visual do que
    /// está aparecendo no cartão, legível sem ler os interruptores um a um.
    private var fundo: Color {
        if ligado { return PapagaioTema.destaque.opacity(pairando ? 0.16 : 0.10) }
        return pairando ? PapagaioTema.superficieSuave : .clear
    }
}

/// A seção de personalização dentro das Configurações.
///
/// Aqui a lista ganha o que não cabia no menu do cartão: um exemplo que
/// responde em tempo real. Ler "Modalidade — presencial ou online" e ver a
/// linha aparecer no cartão são duas compreensões diferentes, e a segunda não
/// exige imaginar nada.
struct SecaoDePersonalizacaoDosCartoes: View {
    @AppStorage(CamposDoCartao.chave) private var camposBrutos = CamposDoCartao.padrao.rawValue

    private var campos: Binding<CamposDoCartao> {
        Binding(
            get: { CamposDoCartao(rawValue: camposBrutos) },
            set: { camposBrutos = $0.rawValue }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.largo) {
            // "Restaurar padrão" sobe para a linha do título.
            //
            // No pé da seção ele ficava sozinho num canto, longe do que
            // restaura, e empurrava para baixo tudo o que vinha depois. Ao lado
            // do título ele é o que é: a ação da seção inteira, disponível sem
            // precisar rolar até o fim dela.
            // Centralizado, e não pela linha de base: com um botão de altura
            // fixa ao lado do título, a base do texto dele não é a base do
            // botão, e o par ficava desencontrado.
            HStack(alignment: .center) {
                Label("Cartões da biblioteca", systemImage: "rectangle.grid.2x2")
                    .font(PapagaioTema.Tipo.tituloDeSecao)
                    .foregroundStyle(PapagaioTema.destaqueEscuro)

                Spacer(minLength: PapagaioTema.Espaco.medio)

                // Botão de verdade, com moldura: como texto solto ele não se
                // anunciava como clicável, e uma ação que ninguém reconhece
                // como ação é uma ação que não existe.
                Button("Restaurar padrão", systemImage: "arrow.uturn.backward") {
                    withAnimation(.snappy(duration: 0.22)) {
                        camposBrutos = CamposDoCartao.padrao.rawValue
                    }
                }
                .buttonStyle(BotaoDeContornoPapagaio())
                .help("Voltar aos campos que vêm ligados de fábrica")
            }

            SeparadorPapagaio()

            HStack(alignment: .top, spacing: PapagaioTema.Espaco.pagina) {
                VStack(alignment: .leading, spacing: PapagaioTema.Espaco.medio) {
                    Text("Escolha o que aparece nos cartões. Vale para todos.")
                        .font(PapagaioTema.Tipo.apoio)
                        .foregroundStyle(PapagaioTema.textoSecundario)

                    ListaDeCamposDoCartao(campos: campos)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // O exemplo à direita, com largura fixa: é uma réplica de um
                // cartão real, e cartão real tem tamanho. Deixá-lo esticar com
                // a janela faria o exemplo mentir sobre a proporção justamente
                // no ponto em que ele existe para não mentir.
                exemplo
                    .frame(width: 360)
            }
        }
        .padding(PapagaioTema.Espaco.secao)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoPapagaio()
    }

    /// O exemplo com seu rótulo, sempre no mesmo canto da seção.
    private var exemplo: some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.curto) {
            Text("Exemplo")
                .font(.caption.weight(.bold))
                .foregroundStyle(PapagaioTema.textoSecundario)
                .textCase(.uppercase)

            cartaoDeExemplo
        }
    }

    /// O cartão e a nota abaixo dele.
    private var cartaoDeExemplo: some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.curto) {
            PreviaDoCartaoDeConversa(campos: campos.wrappedValue)

            Text("O exemplo está com tudo preenchido — os avisos de campo em branco só aparecem em conversas incompletas.")
                .font(.caption)
                .foregroundStyle(PapagaioTema.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Um cartão de mentira, com dados de exemplo, que obedece aos mesmos campos.
///
/// Não reaproveita `CartaoDeConversa` porque aquele depende de um `Arquivo`
/// real, de preferências gravadas e de navegação — fabricar tudo isso só para
/// desenhar um exemplo traria efeitos colaterais reais (gravar capa, abrir
/// conversa) numa tela de configuração.
struct PreviaDoCartaoDeConversa: View {
    let campos: CamposDoCartao

    /// A cor do exemplo. Sem pasta e sem escolha manual, o cartão real cai no
    /// coral da marca — é exatamente esse o caso aqui.
    private var cor: Color { PapagaioTema.destaque }

    /// Mesma regra do cartão real: os acentos do rodapé são lidos sobre o
    /// branco, e por isso a cor passa por `acentoSobreSuperficie`.
    private var acento: Color { cor.acentoSobreSuperficie }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            faixa

            corpo

            // A barra é uma camada sobre o rodapé no cartão real; aqui ela é o
            // último item da pilha, que dá no mesmo resultado visual.
            rodape
        }
        // Altura fixa: o exemplo encolher a cada interruptor faria o texto
        // abaixo dele pular e o botão "Restaurar padrão" mudar de lugar no meio
        // do ajuste. O cartão perde conteúdo por dentro, não muda de tamanho.
        // Mesma altura do cartão de verdade, para o exemplo não mentir sobre a
        // proporção.
        // 360 é o teto da coluna adaptativa da biblioteca — ou seja, a largura
        // de um cartão real em janela cheia, que é onde a pessoa vai ver o
        // resultado. Em 300 o exemplo era o cartão mais estreito possível e
        // ainda deixava a coluna da direita meio vazia.
        .frame(width: 360, height: CartaoDeConversa.alturaDoCartao, alignment: .top)
        .clipShape(RoundedRectangle(cornerRadius: PapagaioTema.raioDeCard, style: .continuous))
        .cartaoPapagaio(borda: acento.opacity(0.35))
        .animation(.snappy(duration: 0.22), value: campos.rawValue)
        .accessibilityHidden(true)
    }

    /// Título no alto, descrição embaixo — as pessoas saíram daqui há tempos,
    /// e o exemplo ainda as mostrava em duas colunas que o cartão real não tem.
    private var faixa: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Entrevista com Ana Silva")
                .font(.system(size: 20, weight: .regular))
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: PapagaioTema.Espaco.curto)

            if campos.contains(.descricao) {
                Text("Primeira rodada de testes do fluxo de cadastro.")
                    .font(.callout.weight(.semibold))
                    .lineLimit(2)
            }
        }
        .foregroundStyle(cor.textoLegivel)
        .padding(PapagaioTema.Espaco.largo)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: CartaoDeConversa.alturaDaFaixa)
        .background {
            ZStack {
                cor
                TexturaDaFaixa()
            }
        }
    }

    /// As mesmas linhas do cartão real, com os mesmos vãos elásticos: é o que
    /// faz o exemplo mostrar de verdade como os campos se espalham quando a
    /// pessoa desliga alguns.
    private var corpo: some View {
        VStack(alignment: .leading, spacing: 0) {
            if campos.contains(.data) {
                linha("calendar", "13/08/2026, 14:32")
                vao
            }

            if campos.contains(.duracao) {
                linha("clock", "42 min")
                vao
            }

            if campos.contains(.participantes) {
                HStack(alignment: .top, spacing: PapagaioTema.Espaco.curto) {
                    HStack(spacing: 3) {
                        Image(systemName: "person.2")
                            .font(.system(size: 16))
                            .frame(width: 20, alignment: .leading)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .padding(.top, 5)

                    PilhaDeParticipantes(nomes: ["João Santos", "Ana Silva"])
                        .padding(.leading, PapagaioTema.Espaco.minimo)
                }
                .foregroundStyle(PapagaioTema.textoSecundario)
            } else if campos.contains(.lacunas) {
                linha("person.badge.plus", "Participantes não informados")
            }

            Spacer(minLength: 0)
                .frame(height: PapagaioTema.Espaco.medio)
        }
        .padding(PapagaioTema.Espaco.largo)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
    }

    private var rodape: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(acento.opacity(0.28))
                .frame(height: 1)

            HStack(spacing: PapagaioTema.Espaco.medio) {
                if campos.contains(.pasta) {
                    SeloDaPastaDoCartao(nome: "Pesquisa")
                        .padding(.leading, PapagaioTema.Espaco.largo)
                }

                Spacer(minLength: 0)

                Image(systemName: "star")
                    .font(.system(size: 16, weight: .regular))
                    .frame(width: 32, height: 32)

                Image(systemName: "folder")
                    .font(.system(size: 16, weight: .regular))
                    .frame(width: 32, height: 32)

                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .semibold))
                    .rotationEffect(.degrees(90))
                    .frame(width: 32, height: 32)
            }
            .foregroundStyle(PapagaioTema.textoSecundario)
            .padding(.trailing, PapagaioTema.Espaco.largo)
            .frame(height: CartaoDeConversa.alturaDaBarra)
        }
    }

    /// Mesmo desenho de linha do cartão: ícone de largura fixa, texto de 16pt.
    private func linha(_ simbolo: String, _ texto: String) -> some View {
        HStack(spacing: PapagaioTema.Espaco.curto) {
            Image(systemName: simbolo)
                .font(.system(size: 16))
                .frame(width: 20, alignment: .leading)

            Text(texto)
                .font(.system(size: 16))
                .lineLimit(1)
        }
        .foregroundStyle(PapagaioTema.textoSecundario)
    }

    /// O mesmo vão elástico do cartão real: piso fixo, teto de 34pt.
    private var vao: some View {
        Spacer(minLength: PapagaioTema.Espaco.medio)
            .frame(maxHeight: 34)
    }
}

