import SwiftUI

struct EditorDeMembroDaEquipe: View {
    let titulo: String
    @State var membro: MembroDaEquipe
    let novoMembro: Bool
    let salvando: Bool
    let mensagemDeErro: String?
    let aoCancelar: () -> Void
    let aoSalvar: (MembroDaEquipe) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.secao) {
            HStack {
                Text(titulo)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(PapagaioTema.texto)
                Spacer()
                Button(action: aoCancelar) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
            }

            if novoMembro {
                CampoDoPerfil(
                    titulo: "Apple Account",
                    texto: $membro.email,
                    placeholder: "email@icloud.com"
                )
            } else {
                LabeledContent("Nome", value: membro.nome)
                LabeledContent("Apple Account", value: membro.email)
                LabeledContent("Status", value: membro.status.rawValue)
            }

            Picker("Permissão", selection: $membro.permissao) {
                ForEach(PermissaoDoMembroDaEquipe.allCases) { permissao in
                    Text(permissao.rawValue).tag(permissao)
                }
            }
            .pickerStyle(.segmented)

            if let mensagemDeErro {
                Label(mensagemDeErro, systemImage: "exclamationmark.icloud")
                    .font(.callout)
                    .foregroundStyle(PapagaioTema.perigo)
            }

            HStack {
                Spacer()
                Button("Cancelar", role: .cancel, action: aoCancelar)
                    .buttonStyle(BotaoDeContornoPapagaio())
                Button("Salvar", systemImage: "checkmark") {
                    aoSalvar(membro)
                }
                .buttonStyle(BotaoPrincipalPapagaio())
                .disabled(
                    salvando
                        || membro.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
        }
        .padding(PapagaioTema.Espaco.secao)
        .frame(minWidth: 340, idealWidth: 440, maxWidth: 460)
        .background(PapagaioTema.fundo)
    }
}
