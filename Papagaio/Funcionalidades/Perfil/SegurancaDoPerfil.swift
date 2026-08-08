import SwiftUI

struct SegurancaDoPerfil: View {
    let aoAlterarSenha: () -> Void
    let aoSair: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.secao) {
            TituloDeSecaoDoPerfil(simbolo: "shield", titulo: "Segurança")

            SeparadorPapagaio()

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center) {
                    conteudo
                }

                VStack(alignment: .leading, spacing: PapagaioTema.Espaco.largo) {
                    conteudo
                }
            }
        }
        .padding(PapagaioTema.Espaco.secao)
        .cartaoPapagaio()
    }

    private var conteudo: some View {
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
}
