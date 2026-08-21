import PapagaioCore
import SwiftUI

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
    /// Nomes escolhidos para as vozes desta conversa — ver `RotuloDeVoz`.
    let nomesDeVoz: [String: String]
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
                    HStack(spacing: PapagaioTema.Espaco.minimo) {
                        Text(speaker == Speaker.eu ? "Eu" : "Interlocutor")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PapagaioTema.textoSecundario)

                        // Falante acústico (diarização): aparece só quando o
                        // canal carrega mais de uma voz — canal de uma voz só
                        // não precisa do chip. O rótulo do canal nunca muda
                        // (ver a regra dos dois rótulos em SegmentoDeFalante).
                        if trecho.temVozesDistintas,
                           let acustico = trecho.falanteAcusticoDominante {
                            Text(RotuloDeVoz.exibicao(acustico, nomes: nomesDeVoz))
                                .font(.caption)
                                .foregroundStyle(PapagaioTema.destaqueEscuro)
                                .padding(.horizontal, PapagaioTema.Espaco.minimo)
                                .padding(.vertical, 1)
                                .background(
                                    PapagaioTema.destaqueSuave,
                                    in: Capsule()
                                )
                        }
                    }
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
        .accessibilityHint("Inicia a reprodução a partir de \(trecho.start.faladoPorExtenso).")
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
}

/// Uma palavra clicável do parágrafo corrido. O tap salta o áudio para o
/// timestamp próprio dela; o destaque segue `indiceDePalavraAtiva` do trecho.
struct BotaoDePalavra: View {
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
