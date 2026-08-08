import SwiftUI

struct InformacoesPessoaisDoPerfil: View {
    @Binding var nome: String
    @Binding var email: String
    let aoSalvar: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.secao) {
            TituloDeSecaoDoPerfil(simbolo: "person", titulo: "Informações Pessoais")

            SeparadorPapagaio()

            CampoDoPerfil(titulo: "Nome Completo", texto: $nome, placeholder: "Seu nome")
            CampoDoPerfil(titulo: "Email Primário", texto: $email, placeholder: "seu@email.com")

            Button("Salvar alterações", systemImage: "checkmark") {
                aoSalvar()
            }
            .buttonStyle(BotaoDeContornoPapagaio())
        }
        .padding(PapagaioTema.Espaco.secao)
        .cartaoPapagaio()
    }
}
