import SwiftUI

struct EquipesDoPerfil: View {
    let equipeAtiva: EquipeDisponivel?
    let equipes: [EquipeDisponivel]
    let aoSelecionar: (EquipeDisponivel) -> Void
    let aoAdicionarEquipe: (String) -> Void
    @State private var mostrandoNovaEquipe = false
    @State private var nomeDaNovaEquipe = ""

    var body: some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.largo) {
            HStack {
                Text("Equipes")
                    .font(.title3)
                    .foregroundStyle(PapagaioTema.texto)

                Spacer()

                Button {
                    mostrandoNovaEquipe = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .foregroundStyle(PapagaioTema.destaqueEscuro)
                .background(PapagaioTema.destaqueSuave, in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))
                .help("Adicionar nova equipe")
            }

            SeparadorPapagaio()

            if equipes.isEmpty {
                Text("Você ainda não tem equipes. Use o + para criar a primeira e convidar pessoas.")
                    .font(.callout)
                    .foregroundStyle(PapagaioTema.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: PapagaioTema.Espaco.curto) {
                ForEach(equipes) { equipe in
                    Button {
                        aoSelecionar(equipe)
                    } label: {
                        HStack(spacing: PapagaioTema.Espaco.medio) {
                            Image(systemName: equipe.id == equipeAtiva?.id ? "checkmark.circle.fill" : "person.3")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(equipe.id == equipeAtiva?.id ? PapagaioTema.destaqueEscuro : PapagaioTema.textoSecundario)
                                .frame(width: 28, height: 28)

                            VStack(alignment: .leading, spacing: PapagaioTema.Espaco.minimo) {
                                Text(equipe.nome)
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(PapagaioTema.texto)
                                    .lineLimit(1)

                                Text("\(equipe.papel) • \(equipe.quantidadeDeMembros) membros")
                                    .font(.caption)
                                    .foregroundStyle(PapagaioTema.textoSecundario)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 0)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(PapagaioTema.Espaco.curto)
                    .background(
                        equipe.id == equipeAtiva?.id ? PapagaioTema.destaqueSuave.opacity(0.58) : Color.clear,
                        in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
                    )
                }
            }
        }
        .padding(PapagaioTema.Espaco.secao)
        .frame(maxWidth: .infinity, minHeight: 226, alignment: .topLeading)
        .cartaoPapagaio()
        .alert("Nova equipe", isPresented: $mostrandoNovaEquipe) {
            TextField("Nome da equipe", text: $nomeDaNovaEquipe)
            Button("Cancelar", role: .cancel) {
                nomeDaNovaEquipe = ""
            }
            Button("Adicionar") {
                adicionarEquipe()
            }
            .disabled(nomeDaNovaEquipe.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Crie uma equipe para vincular ao seu perfil.")
        }
    }

    private func adicionarEquipe() {
        let nome = nomeDaNovaEquipe.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nome.isEmpty else { return }
        aoAdicionarEquipe(nome)
        nomeDaNovaEquipe = ""
    }
}
