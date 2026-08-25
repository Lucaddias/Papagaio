import SwiftUI

struct GestaoDeEquipeView: View {
    let equipeAtiva: EquipeDisponivel?
    let equipes: [EquipeDisponivel]
    let aoSelecionarEquipe: (EquipeDisponivel) -> Void
    let aoAtualizarQuantidadeDeMembros: (String, Int) -> Void
    let aoAtualizarConfiguracoes: (EquipeDisponivel, ConfiguracoesDaEquipe) -> Void
    @State private var membros: [MembroDaEquipe] = []
    @State private var pagina = 0
    @State private var mostrandoTrocarEquipe = false
    @State private var configuracoes = ConfiguracoesDaEquipe()

    var body: some View {
        ScrollView {
            if let equipeAtiva {
                VStack(alignment: .leading, spacing: PapagaioTema.Espaco.pagina) {
                    cabecalho(equipeAtiva)
                    codigoDaEquipe(equipeAtiva)
                    configuracoesDaEquipe(equipeAtiva)
                    TabelaDaEquipe(membros: membros, pagina: pagina, aoEditar: { _ in }, aoRemover: remover, aoAlternarPagina: alternarPagina)
                }
                .larguraDeConteudoPapagaio()
                .padding(.horizontal, PapagaioTema.espacamentoDePagina)
                .padding(.vertical, PapagaioTema.espacamentoDePagina)
            } else {
                CartaoDeEstadoVazio(simbolo: "person.3", titulo: "Nenhuma equipe ainda", mensagem: "Crie uma equipe ou entre com um código no seu perfil.")
                    .padding(.vertical, PapagaioTema.espacamentoDePagina)
            }
        }
        .background(PapagaioTema.fundo)
        .onAppear(perform: carregarEquipe)
        .onChange(of: equipeAtiva?.id) { _, _ in carregarEquipe() }
        .sheet(isPresented: $mostrandoTrocarEquipe) {
            SeletorDeEquipeView(equipeAtiva: equipeAtiva, equipes: equipes, aoCancelar: { mostrandoTrocarEquipe = false }, aoSelecionar: { equipe in
                aoSelecionarEquipe(equipe)
                mostrandoTrocarEquipe = false
            })
        }
    }

    private func cabecalho(_ equipe: EquipeDisponivel) -> some View {
        HStack(alignment: .bottom, spacing: PapagaioTema.Espaco.largo) {
            VStack(alignment: .leading, spacing: PapagaioTema.Espaco.curto) {
                Text("Gerenciar equipe").font(PapagaioTema.Tipo.tituloDePagina).foregroundStyle(PapagaioTema.texto)
                Text("Defina como as pessoas entram e como os arquivos da equipe são recebidos.")
                    .font(.title3).foregroundStyle(PapagaioTema.textoSecundario)
            }
            Spacer()
            Button("Mudar: \(equipe.nome)", systemImage: "arrow.triangle.2.circlepath") { mostrandoTrocarEquipe = true }
                .buttonStyle(BotaoDeContornoPapagaio())
        }
    }

    private func codigoDaEquipe(_ equipe: EquipeDisponivel) -> some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.medio) {
            Label("Código de entrada", systemImage: "number").font(.headline)
            Text(equipe.codigoDeEntrada ?? "Código indisponível para equipes criadas antes desta atualização.")
                .font(.title2.monospaced().weight(.semibold))
                .textSelection(.enabled)
            Text("Compartilhe este código somente com quem deve entrar na equipe. Ele dá acesso de leitura e escrita ao espaço compartilhado.")
                .font(.callout).foregroundStyle(PapagaioTema.textoSecundario)
        }
        .padding(PapagaioTema.Espaco.secao)
        .cartaoPapagaio()
    }

    private func configuracoesDaEquipe(_ equipe: EquipeDisponivel) -> some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.medio) {
            Label("Arquivos da equipe", systemImage: "folder.badge.gearshape").font(.headline)
            Picker("Quem pode ver os arquivos enviados", selection: $configuracoes.visibilidadeDosArquivos) {
                ForEach(VisibilidadeDosArquivosDaEquipe.allCases) { Text($0.rawValue).tag($0) }
            }
            Picker("Quando um arquivo chega", selection: $configuracoes.recebimentoDeArquivos) {
                ForEach(RecebimentoDeArquivosDaEquipe.allCases) { Text($0.rawValue).tag($0) }
            }
            .onChange(of: configuracoes) { _, novo in aoAtualizarConfiguracoes(equipe, novo) }
            Text("Estas preferências ficam salvas na equipe. A revisão de arquivos será aplicada quando o fluxo de aprovação estiver disponível.")
                .font(.caption).foregroundStyle(PapagaioTema.textoSecundario)
        }
        .padding(PapagaioTema.Espaco.secao)
        .cartaoPapagaio()
    }

    private func carregarEquipe() {
        guard let equipeAtiva else { membros = []; pagina = 0; return }
        membros = MembrosDasEquipes.carregar(equipeID: equipeAtiva.id)
        configuracoes = equipeAtiva.configuracoes
        pagina = 0
        aoAtualizarQuantidadeDeMembros(equipeAtiva.id, membros.count)
    }

    private func remover(_ membro: MembroDaEquipe) {
        guard !membro.atual, let equipeAtiva else { return }
        membros.removeAll { $0.id == membro.id }
        MembrosDasEquipes.salvar(membros, equipeID: equipeAtiva.id)
        aoAtualizarQuantidadeDeMembros(equipeAtiva.id, membros.count)
    }

    private func alternarPagina(_ delta: Int) {
        let ultima = max(0, (membros.count - 1) / TabelaDaEquipe.itensPorPagina)
        pagina = min(max(0, pagina + delta), ultima)
    }
}

#Preview("Gerenciar equipe") {
    GestaoDeEquipeView(
        equipeAtiva: .init(
            id: "produto",
            nome: "Produto",
            papel: "Administrador",
            quantidadeDeMembros: 4,
            codigoDeEntrada: "A7K2M9"
        ),
        equipes: [.init(id: "produto", nome: "Produto", papel: "Administrador", quantidadeDeMembros: 4, codigoDeEntrada: "A7K2M9")],
        aoSelecionarEquipe: { _ in },
        aoAtualizarQuantidadeDeMembros: { _, _ in },
        aoAtualizarConfiguracoes: { _, _ in }
    )
    .frame(width: 1_200, height: 760)
}
