import SwiftUI

/// Escolhe o que os cartões da biblioteca mostram.
///
/// Chega pelos três pontinhos de um cartão, porque é ali que a pessoa está
/// olhando quando pensa "não preciso ver isto" — e não numa tela de ajustes,
/// onde ela teria de imaginar o cartão de memória. O que ela muda, porém, vale
/// para a grade inteira: ver o efeito no cartão que a levou até aqui é o que
/// deixa isso claro sem precisar de explicação.
struct PersonalizacaoDoCartao: View {
    @Binding var campos: CamposDoCartao
    let aoFechar: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: PapagaioTema.Espaco.medio) {
                VStack(alignment: .leading, spacing: PapagaioTema.Espaco.minimo) {
                    Text("Personalizar cartões")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(PapagaioTema.texto)
                    Text("Escolha o que aparece nos cartões da biblioteca. Vale para todos.")
                        .font(.callout)
                        .foregroundStyle(PapagaioTema.textoSecundario)
                }

                Spacer()

                BotaoCircularPapagaio(
                    simbolo: "xmark",
                    ajuda: "Fechar",
                    destaque: true,
                    acao: aoFechar
                )
            }
            .padding(PapagaioTema.Espaco.secao)

            SeparadorPapagaio()

            ScrollView {
                VStack(alignment: .leading, spacing: PapagaioTema.Espaco.medio) {
                    ForEach(CamposDoCartao.catalogo, id: \.campo.rawValue) { item in
                        linha(campo: item.campo, titulo: item.titulo, detalhe: item.detalhe)
                    }
                }
                .padding(PapagaioTema.Espaco.secao)
            }
            .scrollBounceBehavior(.basedOnSize)

            SeparadorPapagaio()

            HStack {
                // Sem confirmação: nada aqui é destrutivo, e voltar ao padrão é
                // um clique de desfazer para quem desligou demais e se perdeu.
                Button("Restaurar padrão") {
                    campos = .padrao
                }
                .buttonStyle(BotaoDeContornoPapagaio())

                Spacer()

                Button("Concluir", action: aoFechar)
                    .buttonStyle(BotaoPrincipalPapagaio())
            }
            .padding(PapagaioTema.Espaco.secao)
        }
        .frame(width: 460, height: 560)
        .background(PapagaioTema.fundo)
    }

    private func linha(campo: CamposDoCartao, titulo: String, detalhe: String) -> some View {
        Toggle(isOn: ligado(campo)) {
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(PapagaioTema.texto)
                Text(detalhe)
                    .font(.caption)
                    .foregroundStyle(PapagaioTema.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .toggleStyle(.switch)
        .tint(PapagaioTema.destaque)
    }

    /// Um `Binding` por campo, montado a partir do conjunto.
    ///
    /// Guardar nove `@State` de `Bool` e sincronizá-los com o `OptionSet` daria
    /// dois lugares para a mesma verdade — e é exatamente aí que a folha e o
    /// cartão passam a discordar.
    private func ligado(_ campo: CamposDoCartao) -> Binding<Bool> {
        Binding(
            get: { campos.contains(campo) },
            set: { ativo in
                if ativo {
                    campos.insert(campo)
                } else {
                    campos.remove(campo)
                }
            }
        )
    }
}
