import SwiftUI

struct SeletorDeContextoDaConta: View {
    let contexto: ContextoDaConta
    let equipeAtiva: EquipeDisponivel
    let aoUsarPerfil: () -> Void
    let aoUsarEquipe: () -> Void

    var body: some View {
        VStack(spacing: PapagaioTema.Espaco.minimo) {
            BotaoDeContextoDaConta(
                titulo: "Perfil pessoal",
                subtitulo: "Conta pessoal",
                simbolo: "person.crop.circle",
                selecionado: contexto == .perfil,
                acao: aoUsarPerfil
            )

            BotaoDeContextoDaConta(
                titulo: "Equipe",
                subtitulo: equipeAtiva.nome,
                simbolo: "person.3",
                selecionado: contexto == .equipe,
                acao: aoUsarEquipe
            )
        }
    }
}

struct BotaoDeContextoDaConta: View {
    let titulo: String
    let subtitulo: String
    let simbolo: String
    let selecionado: Bool
    let acao: () -> Void

    var body: some View {
        Button(action: acao) {
            HStack(spacing: PapagaioTema.Espaco.curto) {
                Image(systemName: simbolo)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(selecionado ? PapagaioTema.destaqueEscuro : PapagaioTema.textoSecundario)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: PapagaioTema.Espaco.minimo) {
                    Text(titulo)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(PapagaioTema.texto)
                    Text(subtitulo)
                        .font(.caption)
                        .foregroundStyle(PapagaioTema.textoSecundario)
                        .lineLimit(1)
                }

                Spacer()

                if selecionado {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PapagaioTema.destaqueEscuro)
                }
            }
            .padding(PapagaioTema.Espaco.curto)
            .background(
                selecionado ? PapagaioTema.destaqueSuave.opacity(0.7) : Color.clear,
                in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }
}
