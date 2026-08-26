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
    /// Nomes escolhidos para as vozes desta conversa ("S1" → "João"...) — ver
    /// `RotuloDeVoz`. Vazio quando ninguém ainda renomeou nada, e a fala volta
    /// a mostrar "Voz N".
    let nomesDeVoz: [String: String]
    let aoTocarFala: () -> Void
    let aoTocarPalavra: (Palavra) -> Void
    /// Corrige o texto desta fala. Fica ao lado direito do parágrafo,
    /// centralizado na altura dele — nem preso só à linha do cabeçalho (fica
    /// solto demais lá em cima), nem flutuando fora de qualquer texto.
    let aoEditar: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: PapagaioTema.Espaco.medio) {
            Text(fala.inicio.comoRelogio)
                .font(.system(.caption, design: .monospaced).weight(.medium))
                .monospacedDigit()
                .foregroundStyle(ativo ? PapagaioTema.destaqueEscuro : PapagaioTema.textoSecundario)
                .frame(width: 52, alignment: .trailing)

            // `.center` aqui, e não `.top`: o lápis fica ao lado do
            // parágrafo inteiro (cabeçalho + texto), centralizado na altura
            // dele — não colado só na linha do cabeçalho lá em cima.
            HStack(alignment: .center, spacing: PapagaioTema.Espaco.medio) {
                VStack(alignment: .leading, spacing: PapagaioTema.Espaco.minimo) {
                    cabecalhoDaFala

                    corpoDaFala
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                botaoEditar
            }
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
                Text(RotuloDeVoz.exibicao(acustico, nomes: nomesDeVoz))
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
        }
    }

    private var botaoEditar: some View {
        Button(action: aoEditar) {
            Image(systemName: "pencil")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(PapagaioTema.destaqueEscuro)
                .frame(width: 26, height: 26)
                .background(PapagaioTema.destaqueSuave, in: Circle())
                .overlay {
                    Circle().stroke(PapagaioTema.destaque.opacity(0.4), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .help("Corrigir o texto desta fala")
        .accessibilityLabel("Corrigir o texto desta fala")
    }

    @ViewBuilder
    private var corpoDaFala: some View {
        if !fala.palavras.isEmpty {
            LayoutDeFluxo(espacoHorizontal: 1, espacoVertical: 3, justificado: true) {
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
}