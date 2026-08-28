import SwiftUI

struct GestaoDeEquipeView: View {
    let equipeAtiva: EquipeDisponivel?
    let equipes: [EquipeDisponivel]
    let aoSelecionarEquipe: (EquipeDisponivel) -> Void
    let estadoDaSincronizacao: EstadoDaSincronizacaoCloudKit
    let aoRetomarSincronizacao: () -> Void

    @State private var mostrandoTrocarEquipe = false
    @State private var atualizandoEntradaPorCodigo = false
    @State private var erroDaEntradaPorCodigo: String?
    @State private var entradaPorCodigoAtualizada = false
    private let servicoDeEquipes: ServicoDeEquipesCloudKit

    init(
        equipeAtiva: EquipeDisponivel?,
        equipes: [EquipeDisponivel],
        aoSelecionarEquipe: @escaping (EquipeDisponivel) -> Void,
        estadoDaSincronizacao: EstadoDaSincronizacaoCloudKit = .local,
        aoRetomarSincronizacao: @escaping () -> Void = {},
        servicoDeEquipes: ServicoDeEquipesCloudKit = ServicoDeEquipesCloudKit()
    ) {
        self.equipeAtiva = equipeAtiva
        self.equipes = equipes
        self.aoSelecionarEquipe = aoSelecionarEquipe
        self.estadoDaSincronizacao = estadoDaSincronizacao
        self.aoRetomarSincronizacao = aoRetomarSincronizacao
        self.servicoDeEquipes = servicoDeEquipes
    }

    var body: some View {
        ScrollView {
            if let equipeAtiva {
                VStack(alignment: .leading, spacing: PapagaioTema.Espaco.pagina) {
                    cabecalho(equipeAtiva)
                    estadoDoICloud
                    codigoDaEquipe(equipeAtiva)
                    if podeAtualizarEntradaPorCodigo(equipeAtiva) {
                        atualizacaoDeEquipeExistente(equipeAtiva)
                    }
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
    }

    private func cabecalho(_ equipe: EquipeDisponivel) -> some View {
        HStack(alignment: .bottom, spacing: PapagaioTema.Espaco.largo) {
            VStack(alignment: .leading, spacing: PapagaioTema.Espaco.curto) {
                Text("Gerenciar equipe")
                    .font(PapagaioTema.Tipo.tituloDePagina)
                    .foregroundStyle(PapagaioTema.texto)
                Text("Compartilhe o código para dar acesso ao espaço compartilhado.")
                    .font(.title3)
                    .foregroundStyle(PapagaioTema.textoSecundario)
            }
            Spacer()
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
            Text("Compartilhe este código com quem deve entrar. Ao informá-lo no Loro, a pessoa recebe acesso de leitura e escrita à equipe nesta Apple Account.")
                .font(.callout)
                .foregroundStyle(PapagaioTema.textoSecundario)
        }
        .padding(PapagaioTema.Espaco.secao)
        .cartaoPapagaio()
    }

    private func atualizacaoDeEquipeExistente(_ equipe: EquipeDisponivel) -> some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.medio) {
            Label("Já usava esta equipe antes do acesso por código?", systemImage: "arrow.triangle.2.circlepath")
                .font(.headline)
            Text("Use esta ação uma vez para que o código também libere a zona compartilhada no iCloud. Convites pendentes por e-mail deixam de valer.")
                .font(.callout)
                .foregroundStyle(PapagaioTema.textoSecundario)
            if let erroDaEntradaPorCodigo {
                Label(erroDaEntradaPorCodigo, systemImage: "exclamationmark.icloud")
                    .font(.callout)
                    .foregroundStyle(PapagaioTema.perigo)
            } else if entradaPorCodigoAtualizada {
                Label("A entrada por código está ativa.", systemImage: "checkmark.icloud")
                    .font(.callout)
                    .foregroundStyle(PapagaioTema.sucesso)
            }
            Button("Reconfigurar acesso por código") {
                Task { await ativarEntradaPorCodigo(na: equipe) }
            }
            .buttonStyle(BotaoDeContornoPapagaio())
            .disabled(atualizandoEntradaPorCodigo)
        }
        .padding(PapagaioTema.Espaco.secao)
        .cartaoPapagaio()
    }

    private func ativarEntradaPorCodigo(na equipe: EquipeDisponivel) async {
        atualizandoEntradaPorCodigo = true
        erroDaEntradaPorCodigo = nil
        defer { atualizandoEntradaPorCodigo = false }
        do {
            try await servicoDeEquipes.ativarEntradaPorCodigo(na: equipe)
            entradaPorCodigoAtualizada = true
        } catch {
            erroDaEntradaPorCodigo = error.localizedDescription
        }
    }

    private func podeAtualizarEntradaPorCodigo(_ equipe: EquipeDisponivel) -> Bool {
        equipe.bancoCloudKit == BancoCloudKitDaEquipe.privado.rawValue
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
        aoSelecionarEquipe: { _ in }
    )
    .frame(width: 1_200, height: 760)
}
