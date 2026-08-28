import SwiftUI

struct SeletorDeContextoDaConta: View {
    let contexto: ContextoDaConta
    let equipeAtiva: EquipeDisponivel?
    /// Todas as equipes da pessoa — uma linha para cada, não só a ativa.
    /// Com só uma linha genérica "Equipe" (o que havia antes), quem tinha
    /// várias não tinha como trocar por aqui: precisava ir em "Gerenciar
    /// equipe" só para escolher outra. Criar continua sendo coisa de lá —
    /// aqui é só trocar entre as que já existem.
    let equipes: [EquipeDisponivel]
    let aoUsarPerfil: () -> Void
    let aoUsarEquipe: (EquipeDisponivel) -> Void

    var body: some View {
        // Duas colunas, não uma lista só: Pessoal à esquerda (sempre uma
        // linha só, o próprio perfil) e Equipes à direita — separadas de
        // verdade, em vez de "Perfil pessoal" e nove equipes competindo pela
        // mesma lista vertical. Sem equipe nenhuma a coluna da direita nem
        // aparece (ver `BarraSuperiorPapagaio.menuDePerfil`, que também
        // encolhe o menu de volta para o tamanho estreito de sempre nesse
        // caso).
        HStack(alignment: .top, spacing: PapagaioTema.Espaco.medio) {
            VStack(alignment: .leading, spacing: PapagaioTema.Espaco.curto) {
                Text("Pessoal")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(PapagaioTema.textoSecundario)

                BotaoDeContextoDaConta(
                    titulo: "Perfil pessoal",
                    subtitulo: "Conta pessoal",
                    simbolo: "person.crop.circle",
                    selecionado: contexto == .perfil,
                    acao: aoUsarPerfil
                )
            }
            .frame(width: equipes.isEmpty ? nil : 170, alignment: .leading)

            if !equipes.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: PapagaioTema.Espaco.curto) {
                    Text("Equipes")
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(PapagaioTema.textoSecundario)

                    if equipes.count <= Self.maximoSemRolagem {
                        VStack(spacing: PapagaioTema.Espaco.minimo) {
                            ForEach(equipes) { equipe in
                                linhaDaEquipe(equipe)
                            }
                        }
                    } else {
                        // Com muitas equipes, listar todas sem limite (o que
                        // aconteceu antes disto) vira um menu do tamanho da
                        // tela inteira — nada "legal" de ver, e ainda
                        // empurra "Gerenciar perfil"/"Sair" para bem longe
                        // do clique. Uma altura travada com rolagem mantém o
                        // popover num tamanho razoável em qualquer
                        // quantidade de equipes.
                        ScrollView {
                            VStack(spacing: PapagaioTema.Espaco.minimo) {
                                ForEach(equipes) { equipe in
                                    linhaDaEquipe(equipe)
                                }
                            }
                        }
                        .frame(maxHeight: Self.alturaDaRolagem)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// Acima disso, a lista de equipes vira rolagem — ver o comentário no
    /// `body`.
    private static let maximoSemRolagem = 5
    /// Cabe pouco mais de 4 linhas (cada `BotaoDeContextoDaConta` tem ~50pt)
    /// antes de rolar — dá pra ver que a lista continua sem precisar abrir
    /// o menu inteiro do tamanho da tela.
    private static let alturaDaRolagem: CGFloat = 220

    private func linhaDaEquipe(_ equipe: EquipeDisponivel) -> some View {
        BotaoDeContextoDaConta(
            titulo: equipe.nome,
            subtitulo: "\(equipe.papel) • \(equipe.quantidadeDeMembros) membros",
            simbolo: "person.3",
            selecionado: contexto == .equipe && equipe.id == equipeAtiva?.id,
            acao: { aoUsarEquipe(equipe) }
        )
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
