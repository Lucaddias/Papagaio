import PapagaioCore
import SwiftUI

/// Linha de uma fala da conversa — a unidade de leitura quando a diarização
/// atribuiu vozes às palavras.
///
/// Substitui a linha por trecho no modo com falas: a fala atravessa trechos
/// (a voz não respeita a janela de 40 s), então o timestamp é o da fala e a
/// palavra ativa é casada pela âncora `(trechoId, indiceNoTrecho)` do player.
struct LinhaDeFala: View {
    let fala: FalaDeFalante
    let ativo: Bool
    /// Palavra sendo tocada, com a âncora no trecho de origem — `nil` quando
    /// nada toca ou a fala é legada (sem palavras).
    let palavraAtiva: PalavraDeFala?
    /// Animação do destaque de palavra, vinda do container.
    let animacao: Animation?
    let aoTocarFala: () -> Void
    let aoTocarPalavra: (Palavra) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: PapagaioTema.Espaco.medio) {
            Text(fala.inicio.comoRelogio)
                .font(.system(.caption, design: .monospaced).weight(.medium))
                .monospacedDigit()
                .foregroundStyle(ativo ? PapagaioTema.destaqueEscuro : PapagaioTema.textoSecundario)
                .frame(width: 52, alignment: .trailing)

            VStack(alignment: .leading, spacing: PapagaioTema.Espaco.minimo) {
                cabecalhoDaFala

                corpoDaFala
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
            aoTocarFala()
        }
        .accessibilityElement(children: .contain)
        .accessibilityAction {
            aoTocarFala()
        }
        .accessibilityHint("Inicia a reprodução a partir de \(fala.inicio.faladoPorExtenso).")
        .accessibilityAddTraits(ativo ? [.isSelected] : [])
    }

    /// A voz acústica é a identidade da fala; o canal de origem aparece quando
    /// a fala veio inteira dele (regra dos dois rótulos — nunca se fundem).
    @ViewBuilder
    private var cabecalhoDaFala: some View {
        HStack(spacing: PapagaioTema.Espaco.minimo) {
            if let acustico = fala.falanteAcustico {
                Text(LinhaDeFala.rotuloDe(acustico))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PapagaioTema.destaqueEscuro)
                    .padding(.horizontal, PapagaioTema.Espaco.minimo)
                    .padding(.vertical, 1)
                    .background(PapagaioTema.destaqueSuave, in: Capsule())
            } else {
                Text("Voz desconhecida")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PapagaioTema.textoSecundario)
            }

            if let speaker = fala.speaker {
                Text(speaker == Speaker.eu ? "Eu" : "Interlocutor")
                    .font(.caption)
                    .foregroundStyle(PapagaioTema.textoSecundario)
            }
        }
    }

    @ViewBuilder
    private var corpoDaFala: some View {
        if !fala.palavras.isEmpty {
            LayoutDeFluxo(espacoHorizontal: 1, espacoVertical: 3) {
                ForEach(Array(fala.palavras.enumerated()), id: \.element.palavra.id) { _, item in
                    BotaoDePalavra(
                        palavra: item.palavra,
                        ativa: item.trechoId == palavraAtiva?.trechoId
                            && item.indiceNoTrecho == palavraAtiva?.indiceNoTrecho,
                        animacao: animacao,
                        acao: { aoTocarPalavra(item.palavra) }
                    )
                }
            }
        } else {
            // Fala sem palavras: trecho legado ou editado à mão. Cai no
            // parágrafo inteiro, como sempre foi.
            Text(fala.texto)
                .font(.body)
                .fontWeight(ativo ? .medium : .regular)
                .foregroundStyle(PapagaioTema.texto)
                .multilineTextAlignment(.leading)
        }
    }

    /// Traduz o rótulo do FluidAudio ("S1") para o que um humano entende
    /// ("Voz 1"). Rótulo acústico só serve para comparar vozes da mesma
    /// gravação — nunca é um nome de pessoa.
    private static func rotuloDe(_ falanteAcustico: String) -> String {
        if falanteAcustico.hasPrefix("S"), let numero = Int(falanteAcustico.dropFirst()) {
            return "Voz \(numero)"
        }
        return "Voz \(falanteAcustico)"
    }
}