import SwiftUI

struct EquipesDoPerfil: View {
    let equipeAtiva: EquipeDisponivel?
    let equipes: [EquipeDisponivel]
    let aoSelecionar: (EquipeDisponivel) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.largo) {
            // Sem botão de "+": este cartão só mostra as equipes que a
            // pessoa já tem e deixa trocar qual está ativa — criar uma nova
            // é coisa de "Gerenciar equipe" (ver `GestaoDeEquipeView`), não
            // daqui. Duas telas oferecendo o mesmo "criar" confundia mais do
            // que ajudava.
            Text("Equipes")
                .font(.title3)
                .foregroundStyle(PapagaioTema.texto)

            SeparadorPapagaio()

            if equipes.isEmpty {
                Text("Você ainda não tem equipes. Crie a primeira em \"Gerenciar equipe\".")
                    .font(.callout)
                    .foregroundStyle(PapagaioTema.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Grade, e não uma lista de uma coluna só: o cartão de Equipes
            // agora ocupa o mesmo espaço vertical da coluna inteira à
            // esquerda (identidade + Informações Pessoais + Segurança — ver
            // `PerfilPessoalView.colunaEsquerdaDoPerfil`), então sobrava uma
            // faixa enorme de espaço vazio à direita de cada linha. Três
            // colunas (`.adaptive(minimum: 220)`, sem teto: encolhe para 2 ou
            // 1 coluna sozinha numa janela estreita, nunca corta) aproveitam
            // essa largura em vez de deixá-la parada.
            // Espaço horizontal maior que o vertical (`secao`, não `curto`):
            // com as colunas quase coladas, a linha divisória do meio ficava
            // espremida entre os textos dos dois lados, sem respiro nenhum
            // — mais parecendo sujeira na tela do que uma divisão de
            // verdade. Com folga de sobra dos dois lados, ela lê como algo
            // desenhado de propósito.
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 220), spacing: PapagaioTema.Espaco.secao, alignment: .top)],
                spacing: PapagaioTema.Espaco.curto
            ) {
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
            // Linha vertical no meio, só quando a grade de fato tem duas
            // colunas lado a lado — medida pela própria largura da grade
            // (`.adaptive` não avisa quantas colunas escolheu, então a conta
            // aqui refaz a mesma regra do `GridItem` acima: cabe uma segunda
            // coluna de 220pt, mais o espaçamento entre elas). Numa janela
            // estreita, onde a grade vira uma coluna só, a linha some — não
            // faria sentido dividir ao meio o que já é uma lista única.
            .background {
                GeometryReader { geometria in
                    if geometria.size.width >= 220 * 2 + PapagaioTema.Espaco.secao {
                        Rectangle()
                            .fill(PapagaioTema.borda)
                            .frame(width: 1)
                            .position(x: geometria.size.width / 2, y: geometria.size.height / 2)
                    }
                }
            }
        }
        .padding(PapagaioTema.Espaco.secao)
        .frame(maxWidth: .infinity, minHeight: 226, alignment: .topLeading)
        .cartaoPapagaio()
    }
}
