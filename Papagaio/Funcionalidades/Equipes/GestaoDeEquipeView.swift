import SwiftUI

struct GestaoDeEquipeView: View {
    let equipeAtiva: EquipeDisponivel?
    let equipes: [EquipeDisponivel]
    let aoSelecionarEquipe: (EquipeDisponivel) -> Void
    let aoAtualizarQuantidadeDeMembros: (String, Int) -> Void
    let estadoDaSincronizacao: EstadoDaSincronizacaoCloudKit
    let aoRetomarSincronizacao: () -> Void

    @State private var gestor: GestorDeMembrosDaEquipe
    @State private var pagina = 0
    @State private var mostrandoTrocarEquipe = false
    @State private var mostrandoConvite = false
    @State private var convite = Self.novoConvite()
    @State private var membroEmEdicao: MembroDaEquipe?

    init(
        equipeAtiva: EquipeDisponivel?,
        equipes: [EquipeDisponivel],
        aoSelecionarEquipe: @escaping (EquipeDisponivel) -> Void,
        aoAtualizarQuantidadeDeMembros: @escaping (String, Int) -> Void,
        estadoDaSincronizacao: EstadoDaSincronizacaoCloudKit = .local,
        aoRetomarSincronizacao: @escaping () -> Void = {},
        servicoDeMembros: any ServicoDeMembrosDaEquipe = ServicoDeEquipesCloudKit()
    ) {
        self.equipeAtiva = equipeAtiva
        self.equipes = equipes
        self.aoSelecionarEquipe = aoSelecionarEquipe
        self.aoAtualizarQuantidadeDeMembros = aoAtualizarQuantidadeDeMembros
        self.estadoDaSincronizacao = estadoDaSincronizacao
        self.aoRetomarSincronizacao = aoRetomarSincronizacao
        _gestor = State(initialValue: GestorDeMembrosDaEquipe(servico: servicoDeMembros))
    }

    var body: some View {
        ScrollView {
            if let equipeAtiva {
                VStack(alignment: .leading, spacing: PapagaioTema.Espaco.pagina) {
                    cabecalho(equipeAtiva)
                    estadoDoICloud
                    codigoDaEquipe(equipeAtiva)

                    if let erro = gestor.erro {
                        avisoDeErro(erro, equipe: equipeAtiva)
                    }

                    TabelaDaEquipe(
                        membros: gestor.membros,
                        pagina: pagina,
                        podeGerenciar: podeGerenciar(equipeAtiva),
                        aoEditar: { membroEmEdicao = $0 },
                        aoRemover: { membro in
                            Task { await remover(membro, da: equipeAtiva) }
                        },
                        aoAlternarPagina: alternarPagina
                    )
                    .opacity(gestor.operacaoEmAndamento ? 0.65 : 1)
                    .disabled(gestor.operacaoEmAndamento)
                }
                .larguraDeConteudoPapagaio()
                .padding(.horizontal, PapagaioTema.espacamentoDePagina)
                .padding(.vertical, PapagaioTema.espacamentoDePagina)
            } else {
                CartaoDeEstadoVazio(
                    simbolo: "person.3",
                    titulo: "Nenhuma equipe ainda",
                    mensagem: "Crie uma equipe ou entre com um código no seu perfil."
                )
                .padding(.vertical, PapagaioTema.espacamentoDePagina)
            }
        }
        .background(PapagaioTema.fundo)
        .task(id: equipeAtiva?.id) { await carregarEquipe() }
        .sheet(isPresented: $mostrandoTrocarEquipe) {
            SeletorDeEquipeView(
                equipeAtiva: equipeAtiva,
                equipes: equipes,
                aoCancelar: { mostrandoTrocarEquipe = false },
                aoSelecionar: { equipe in
                    aoSelecionarEquipe(equipe)
                    mostrandoTrocarEquipe = false
                }
            )
        }
        .sheet(isPresented: $mostrandoConvite) {
            if let equipeAtiva {
                EditorDeMembroDaEquipe(
                    titulo: "Adicionar membro",
                    membro: convite,
                    novoMembro: true,
                    salvando: gestor.operacaoEmAndamento,
                    mensagemDeErro: gestor.erro,
                    aoCancelar: { mostrandoConvite = false },
                    aoSalvar: { membro in
                        Task { await convidar(membro, para: equipeAtiva) }
                    }
                )
            }
        }
        .sheet(item: $membroEmEdicao) { membro in
            if let equipeAtiva {
                EditorDeMembroDaEquipe(
                    titulo: "Permissão do membro",
                    membro: membro,
                    novoMembro: false,
                    salvando: gestor.operacaoEmAndamento,
                    mensagemDeErro: gestor.erro,
                    aoCancelar: { membroEmEdicao = nil },
                    aoSalvar: { alterado in
                        Task { await atualizar(alterado, na: equipeAtiva) }
                    }
                )
            }
        }
    }

    private func cabecalho(_ equipe: EquipeDisponivel) -> some View {
        HStack(alignment: .bottom, spacing: PapagaioTema.Espaco.largo) {
            VStack(alignment: .leading, spacing: PapagaioTema.Espaco.curto) {
                Text("Gerenciar equipe")
                    .font(PapagaioTema.Tipo.tituloDePagina)
                    .foregroundStyle(PapagaioTema.texto)
                Text("Gerencie participantes e o acesso ao espaço compartilhado.")
                    .font(.title3)
                    .foregroundStyle(PapagaioTema.textoSecundario)
            }
            Spacer()
            if podeGerenciar(equipe) {
                Button("Adicionar membro", systemImage: "person.badge.plus") {
                    convite = Self.novoConvite()
                    gestor.limparErro()
                    mostrandoConvite = true
                }
                .buttonStyle(BotaoPrincipalPapagaio())
            }
            Button("Mudar: \(equipe.nome)", systemImage: "arrow.triangle.2.circlepath") {
                mostrandoTrocarEquipe = true
            }
            .buttonStyle(BotaoDeContornoPapagaio())
        }
    }

    private var estadoDoICloud: some View {
        HStack(spacing: PapagaioTema.Espaco.medio) {
            switch estadoDaSincronizacao {
            case .local:
                Label("Espaço local", systemImage: "internaldrive")
            case .enviando:
                ProgressView()
                Text("Sincronizando com o iCloud…")
            case .sincronizado:
                Label("Sincronizado com o iCloud", systemImage: "checkmark.icloud")
                    .foregroundStyle(PapagaioTema.sucesso)
            case let .falhou(mensagem):
                Label(mensagem, systemImage: "exclamationmark.icloud")
                    .foregroundStyle(PapagaioTema.perigo)
                Spacer()
                Button("Tentar agora", action: aoRetomarSincronizacao)
                    .buttonStyle(BotaoDeContornoPapagaio())
            }
            if !sincronizacaoFalhou {
                Spacer()
            }
        }
        .font(.callout)
        .padding(PapagaioTema.Espaco.secao)
        .cartaoPapagaio()
    }

    private var sincronizacaoFalhou: Bool {
        if case .falhou = estadoDaSincronizacao { return true }
        return false
    }

    private func codigoDaEquipe(_ equipe: EquipeDisponivel) -> some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.medio) {
            Label("Código de entrada", systemImage: "number").font(.headline)
            Text(equipe.codigoDeEntrada ?? "Código indisponível para equipes criadas antes desta atualização.")
                .font(.title2.monospaced().weight(.semibold))
                .textSelection(.enabled)
            Text("Antes de enviar o código, adicione o Apple Account da pessoa. Só participantes autorizados no iCloud conseguem aceitar o compartilhamento.")
                .font(.callout)
                .foregroundStyle(PapagaioTema.textoSecundario)
        }
        .padding(PapagaioTema.Espaco.secao)
        .cartaoPapagaio()
    }

    private func avisoDeErro(_ mensagem: String, equipe: EquipeDisponivel) -> some View {
        HStack(spacing: PapagaioTema.Espaco.medio) {
            Image(systemName: "exclamationmark.icloud")
                .foregroundStyle(PapagaioTema.perigo)
            Text(mensagem).foregroundStyle(PapagaioTema.texto)
            Spacer()
            Button("Tentar novamente") { Task { await recarregar(equipe) } }
                .buttonStyle(BotaoDeContornoPapagaio())
        }
        .padding(PapagaioTema.Espaco.secao)
        .cartaoPapagaio()
    }

    private func carregarEquipe() async {
        gestor.selecionar(equipeAtiva)
        pagina = 0
        guard let equipeAtiva else { return }
        await recarregar(equipeAtiva)
    }

    private func recarregar(_ equipe: EquipeDisponivel) async {
        await gestor.carregar(equipe)
        sincronizarQuantidade(equipe)
    }

    private func convidar(_ membro: MembroDaEquipe, para equipe: EquipeDisponivel) async {
        await gestor.convidar(email: membro.email, permissao: membro.permissao, para: equipe)
        sincronizarQuantidade(equipe)
        guard gestor.erro == nil else { return }
        mostrandoConvite = false
    }

    private func atualizar(_ membro: MembroDaEquipe, na equipe: EquipeDisponivel) async {
        await gestor.atualizar(membro, permissao: membro.permissao, na: equipe)
        sincronizarQuantidade(equipe)
        guard gestor.erro == nil else { return }
        membroEmEdicao = nil
    }

    private func remover(_ membro: MembroDaEquipe, da equipe: EquipeDisponivel) async {
        await gestor.remover(membro, da: equipe)
        sincronizarQuantidade(equipe)
    }

    private func sincronizarQuantidade(_ equipe: EquipeDisponivel) {
        aoAtualizarQuantidadeDeMembros(equipe.id, gestor.membros.count)
        let ultima = max(0, (gestor.membros.count - 1) / TabelaDaEquipe.itensPorPagina)
        pagina = min(pagina, ultima)
    }

    private func podeGerenciar(_ equipe: EquipeDisponivel) -> Bool {
        equipe.bancoCloudKit == BancoCloudKitDaEquipe.privado.rawValue
    }

    private func alternarPagina(_ delta: Int) {
        let ultima = max(0, (gestor.membros.count - 1) / TabelaDaEquipe.itensPorPagina)
        pagina = min(max(0, pagina + delta), ultima)
    }

    private static func novoConvite() -> MembroDaEquipe {
        MembroDaEquipe(
            nome: "Novo membro",
            email: "",
            cargo: "Membro",
            status: .aguardando,
            permissao: .escrita
        )
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
        equipes: [
            .init(
                id: "produto",
                nome: "Produto",
                papel: "Administrador",
                quantidadeDeMembros: 4,
                codigoDeEntrada: "A7K2M9"
            )
        ],
        aoSelecionarEquipe: { _ in },
        aoAtualizarQuantidadeDeMembros: { _, _ in }
    )
    .frame(width: 1_200, height: 760)
}
