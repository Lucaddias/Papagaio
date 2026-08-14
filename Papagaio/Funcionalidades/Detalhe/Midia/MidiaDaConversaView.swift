import SwiftUI

struct MidiaDaConversaView: View {
    let anexos: [AnexoDeMidiaDaConversa]
    let aoAdicionar: () -> Void
    let aoAbrir: (AnexoDeMidiaDaConversa) -> Void
    let aoRemover: (AnexoDeMidiaDaConversa) -> Void
    /// Só os itens desta conversa. A lixeira geral, na barra do app, mostra os
    /// de todas — aqui interessa desfazer o que acabou de acontecer nesta tela.
    let naLixeira: [MidiaNaLixeira]
    let aoRestaurar: (MidiaNaLixeira) -> Void
    let aoApagarDeVez: (MidiaNaLixeira) -> Void

    var body: some View {
        // Em janela estreita a coluna lateral roubaria a largura de um cartão
        // inteiro; aí ela volta a ser uma faixa acima da grade.
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: PapagaioTema.Espaco.secao) {
                grade
                resumoDaMidia
            }

            VStack(alignment: .leading, spacing: PapagaioTema.Espaco.medio) {
                resumoDaMidia
                    .frame(maxWidth: .infinity, alignment: .leading)
                grade
            }
        }
    }

    private var grade: some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.secao) {
            // Sem H1 nem subtítulo: a aba já se chama "Mídia", o título da
            // conversa está logo acima, e "Foto, vídeo, áudio ou arquivo" já
            // aparece dentro do cartão de adicionar. Eram três textos dizendo
            // a mesma coisa, empurrando os arquivos para baixo da dobra.
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

                // O removido continua na grade, apagado, com restaurar e
                // apagar de vez. Sumir da tela obrigaria a pessoa a sair da
                // conversa e procurar a lixeira do app para desfazer um clique
                // de dois segundos atrás — e o arrependimento acontece aqui.
                ForEach(naLixeira) { item in
                    CartaoDeMidiaRemovida(
                        item: item,
                        aoRestaurar: { aoRestaurar(item) },
                        aoApagarDeVez: { aoApagarDeVez(item) }
                    )
                }
            }
            .animation(.snappy(duration: 0.22), value: naLixeira)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Contagem, ajuda e lixeira numa linha só, ao lado dos cartões.
    ///
    /// A explicação virou botão: é texto que se lê uma vez e depois só ocupa
    /// espaço. Atrás do "i", ela continua disponível para quem chega agora
    /// sem cobrar altura de quem já sabe o que a aba faz.
    private var resumoDaMidia: some View {
        HStack(spacing: PapagaioTema.Espaco.curto) {
            // O "i" mora dentro da pastilha: solto ao lado, virava um terceiro
            // objeto na linha para dizer algo sobre o primeiro.
            HStack(spacing: PapagaioTema.Espaco.curto) {
                Text(anexos.count == 1 ? "1 arquivo" : "\(anexos.count) arquivos")
                Text(tamanhoTotal)
                botaoDeAjuda
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(PapagaioTema.textoSecundario)
            .padding(.leading, PapagaioTema.Espaco.medio)
            .padding(.trailing, PapagaioTema.Espaco.minimo)
            .frame(height: PapagaioTema.Altura.compacta)
            .background(PapagaioTema.superficieSuave, in: Capsule())
        }
        .fixedSize()
    }

    private var botaoDeAjuda: some View {
        BotaoDeAjudaPapagaio(
            texto: "Fotos, vídeos, áudios, documentos e anexos salvos nesta conversa.",
            ajuda: "O que cabe nesta aba",
            largura: 280
        )
    }

    private var tamanhoTotal: String {
        formatoDeBytes(anexos.reduce(0) { $0 + $1.tamanho })
    }
}
