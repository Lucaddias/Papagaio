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
