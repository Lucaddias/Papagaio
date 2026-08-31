import SwiftUI

struct SegurancaDoPerfil: View {
    let aoAlterarSenha: () -> Void
    let aoSair: () -> Void
    let aoExcluirConta: () -> Void
    let excluindoConta: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.secao) {
            TituloDeSecaoDoPerfil(simbolo: "shield", titulo: "Segurança")

            SeparadorPapagaio()

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center) {
                    conteudoDaSessao
                }

                VStack(alignment: .leading, spacing: PapagaioTema.Espaco.largo) {
                    conteudoDaSessao
                }
            }

            SeparadorPapagaio()

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: PapagaioTema.Espaco.largo) {
                    conteudoDeExclusao
                }

                VStack(alignment: .leading, spacing: PapagaioTema.Espaco.largo) {
                    conteudoDeExclusao
                }
            }
        }
        .padding(PapagaioTema.Espaco.secao)
        .cartaoPapagaio()
    }

    private var conteudoDaSessao: some View {
        Group {
                VStack(alignment: .leading, spacing: PapagaioTema.Espaco.minimo) {
                    Text("Senha")
                        .font(.headline)
                        .foregroundStyle(PapagaioTema.texto)
                    Text("Gerenciada pelo ID Apple")
                        .font(.callout)
                        .foregroundStyle(PapagaioTema.textoSecundario)
                }

                Spacer()

                Button("Alterar Senha", action: aoAlterarSenha)
                    .buttonStyle(BotaoDeContornoPapagaio())

                Button("Sair", role: .destructive, action: aoSair)
                    .buttonStyle(BotaoDeContornoPapagaio())
        }
    }

    private var conteudoDeExclusao: some View {
        Group {
            VStack(alignment: .leading, spacing: PapagaioTema.Espaco.minimo) {
                Text("Excluir perfil")
                    .font(.headline)
                    .foregroundStyle(PapagaioTema.perigo)
                Text("Remove deste Mac o perfil e seus dados pessoais, sem apagar os espaços de equipe nem as preferências do app.")
                    .font(.callout)
                    .foregroundStyle(PapagaioTema.textoSecundario)
            }

            Spacer()

            Button(role: .destructive, action: aoExcluirConta) {
                Label(excluindoConta ? "Excluindo..." : "Excluir perfil", systemImage: "trash")
            }
            .buttonStyle(BotaoDeContornoPapagaio())
            .disabled(excluindoConta)
        }
    }
}
