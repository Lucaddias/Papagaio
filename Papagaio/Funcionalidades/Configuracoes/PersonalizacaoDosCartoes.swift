import SwiftUI

/// Os interruptores dos campos do cartão, sem moldura própria.
///
/// Existe separado porque os mesmos controles aparecem em dois lugares — nas
/// Configurações e no menu de um cartão. Duplicar a lista significaria, mais
/// cedo ou mais tarde, um campo novo aparecendo só num dos dois.
struct ListaDeCamposDoCartao: View {
    @Binding var campos: CamposDoCartao

    var body: some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.medio) {
            ForEach(CamposDoCartao.catalogo, id: \.campo.rawValue) { item in
                Toggle(isOn: ligado(item.campo)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.titulo)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(PapagaioTema.texto)
                        Text(item.detalhe)
                            .font(.caption)
                            .foregroundStyle(PapagaioTema.textoSecundario)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .toggleStyle(.switch)
                .tint(PapagaioTema.destaque)
                // Largura limitada: o rótulo esticando com a janela jogava o
                // interruptor para o outro lado da tela, e ligar o campo certo
                // virava um exercício de mirar na linha. Alinhados numa coluna
                // logo depois do texto, os dois continuam sendo um só objeto.
                .frame(maxWidth: 440, alignment: .leading)
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
            Label("Cartões da biblioteca", systemImage: "rectangle.grid.2x2")
                .font(PapagaioTema.Tipo.tituloDeSecao)
                .foregroundStyle(PapagaioTema.destaqueEscuro)

            SeparadorPapagaio()

            Text("Escolha o que aparece nos cartões. Vale para todos.")
                .font(PapagaioTema.Tipo.apoio)
                .foregroundStyle(PapagaioTema.textoSecundario)

            // Lado a lado quando cabe, para o exemplo estar no campo de visão
            // enquanto a pessoa mexe nos interruptores. Em janela estreita ele
            // desce, que é melhor do que espremer os dois.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: PapagaioTema.Espaco.secao) {
                    // A lista cresce com a janela e o exemplo tem largura fixa:
                    // ele imita um cartão da grade, que também não muda de
                    // tamanho. Deixar os dois crescerem afastaria o interruptor
                    // do seu rótulo em telas largas.
                    ListaDeCamposDoCartao(campos: campos)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    exemplo
                }

                VStack(alignment: .leading, spacing: PapagaioTema.Espaco.secao) {
                    ListaDeCamposDoCartao(campos: campos)
                    exemplo
                }
            }

            HStack {
                Button("Restaurar padrão") {
                    withAnimation(.snappy(duration: 0.22)) {
                        camposBrutos = CamposDoCartao.padrao.rawValue
                    }
                }
                .buttonStyle(BotaoDeContornoPapagaio())

                Spacer()
            }
        }
        .padding(PapagaioTema.Espaco.secao)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoPapagaio()
    }

    private var exemplo: some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.curto) {
            Text("Exemplo")
                .font(.caption.weight(.bold))
                .foregroundStyle(PapagaioTema.textoSecundario)
                .textCase(.uppercase)

            PreviaDoCartaoDeConversa(campos: campos.wrappedValue)

            Text("O exemplo está com tudo preenchido — os avisos de campo em branco só aparecem em conversas incompletas.")
                .font(.caption)
                .foregroundStyle(PapagaioTema.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 300, alignment: .leading)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                PapagaioTema.destaque

                VStack(alignment: .leading, spacing: 2) {
                    Text("Entrevista com Ana Silva")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)

                    Spacer(minLength: 0)

                    if campos.contains(.descricao) {
                        Text("Primeira rodada de testes do fluxo de cadastro.")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.95))
                            .lineLimit(2)
                    }

                    if campos.contains(.pessoas) {
                        HStack(alignment: .top, spacing: PapagaioTema.Espaco.largo) {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Entrevistados:")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.7))
                                Text("Ana Silva")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white)
                            }

                            VStack(alignment: .leading, spacing: 0) {
                                Text("Entrevistadores:")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.7))
                                Text("João Santos")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                }
                .padding(PapagaioTema.Espaco.medio)
            }
            .frame(height: CartaoDeConversa.alturaDaFaixa)
            // O exemplo precisa da mesma textura do cartão de verdade: sem ela,
            // a prévia mostra uma faixa chapada que não existe em lugar nenhum.
            .overlay { TexturaDaFaixa() }

            VStack(alignment: .leading, spacing: PapagaioTema.Espaco.curto) {
                // Uma linha por dado, como no cartão de verdade.
                VStack(alignment: .leading, spacing: PapagaioTema.Espaco.curto) {
                    if campos.contains(.data) {
                        Label("13/08/2026, 14:32", systemImage: "calendar")
                    }
                    if campos.contains(.duracao) {
                        Label("42 min", systemImage: "clock")
                    }
                    if campos.contains(.participantes) {
                        HStack(spacing: PapagaioTema.Espaco.curto) {
                            PilhaDeParticipantes(nomes: ["João Santos", "Ana Silva"])
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(PapagaioTema.destaqueEscuro)
                    }
                }
                .font(.system(size: 14))
                .foregroundStyle(PapagaioTema.textoSecundario)
                .lineLimit(1)
            }
            .padding(PapagaioTema.Espaco.medio)
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            // A mesma barra do cartão de verdade — é ela que explica por que o
            // rodapé fica sempre reservado.
            SeparadorPapagaio()

            // Mesmo rodapé do cartão real: a pasta à esquerda, as três ações à
            // direita.
            HStack(spacing: PapagaioTema.Espaco.medio) {
                if campos.contains(.pasta) {
                    Label("Pesquisa", systemImage: "folder.fill")
                        .font(PapagaioTema.Tipo.rotulo)
                        .foregroundStyle(PapagaioTema.destaque)
                        .padding(.horizontal, PapagaioTema.Espaco.medio)
                        .frame(height: PapagaioTema.Altura.compacta)
                        .background(PapagaioTema.destaque.opacity(0.14), in: Capsule())
                }

                Spacer(minLength: 0)

                Image(systemName: "star")
                Image(systemName: "folder")
                Image(systemName: "ellipsis").rotationEffect(.degrees(90))
            }
            .font(.system(size: 14, weight: .regular))
            .foregroundStyle(PapagaioTema.textoSecundario)
            .padding(.horizontal, PapagaioTema.Espaco.medio)
            .frame(height: CartaoDeConversa.alturaDaBarra)
        }
        // Altura fixa: o exemplo encolher a cada interruptor faria o texto
        // abaixo dele pular e o botão "Restaurar padrão" mudar de lugar no meio
        // do ajuste. O cartão perde conteúdo por dentro, não muda de tamanho.
        // Mesma altura do cartão de verdade, para o exemplo não mentir sobre a
        // proporção.
        .frame(width: 300, height: CartaoDeConversa.alturaDoCartao, alignment: .top)
        .clipShape(RoundedRectangle(cornerRadius: PapagaioTema.raioDeCard, style: .continuous))
        .cartaoPapagaio()
        .animation(.snappy(duration: 0.22), value: campos.rawValue)
        .accessibilityHidden(true)
    }
}
