import Foundation
import Observation

/// Mantém a tela alinhada ao `CKShare`: o armazenamento local é somente um
/// espelho para abertura offline e nunca é alterado antes do sucesso remoto.
@MainActor
@Observable
final class GestorDeMembrosDaEquipe {
    private(set) var membros: [MembroDaEquipe] = []
    private(set) var operacaoEmAndamento = false
    private(set) var erro: String?

    private let servico: any ServicoDeMembrosDaEquipe
    private let defaults: UserDefaults
    private var equipeSelecionadaID: String?

    init(
        servico: any ServicoDeMembrosDaEquipe,
        defaults: UserDefaults = .standard
    ) {
        self.servico = servico
        self.defaults = defaults
    }

    func selecionar(_ equipe: EquipeDisponivel?) {
        guard equipeSelecionadaID != equipe?.id else { return }
        equipeSelecionadaID = equipe?.id
        erro = nil
        membros = equipe.map {
            MembrosDasEquipes.carregar(equipeID: $0.id, em: defaults)
        } ?? []
    }

    func carregar(_ equipe: EquipeDisponivel) async {
        selecionar(equipe)
        await executar(equipe) {
            try await servico.carregarMembros(da: equipe)
        }
    }

    func convidar(
        email: String,
        permissao: PermissaoDoMembroDaEquipe,
        para equipe: EquipeDisponivel
    ) async {
        await executar(equipe) {
            try await servico.adicionarMembro(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                permissao: permissao,
                a: equipe
            )
        }
    }

    func atualizar(
        _ membro: MembroDaEquipe,
        permissao: PermissaoDoMembroDaEquipe,
        na equipe: EquipeDisponivel
    ) async {
        await executar(equipe) {
            try await servico.atualizarPermissao(
                do: membro,
                para: permissao,
                na: equipe
            )
        }
    }

    func remover(_ membro: MembroDaEquipe, da equipe: EquipeDisponivel) async {
        await executar(equipe) {
            try await servico.removerMembro(membro, da: equipe)
        }
    }

    func limparErro() {
        erro = nil
    }

    private func executar(
        _ equipe: EquipeDisponivel,
        operacao: () async throws -> [MembroDaEquipe]
    ) async {
        guard equipeSelecionadaID == equipe.id else { return }
        operacaoEmAndamento = true
        erro = nil
        defer { operacaoEmAndamento = false }

        do {
            let membrosRemotos = try await operacao()
            guard equipeSelecionadaID == equipe.id else { return }
            membros = membrosRemotos
            MembrosDasEquipes.salvar(membrosRemotos, equipeID: equipe.id, em: defaults)
        } catch {
            erro = error.localizedDescription
        }
    }
}
