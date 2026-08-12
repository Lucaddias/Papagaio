import AppKit
import SwiftUI

struct PerfilPessoalView: View {
    @Bindable var perfil: PerfilViewModel
    let equipeAtiva: EquipeDisponivel?
    let equipes: [EquipeDisponivel]
    let aoSelecionarEquipe: (EquipeDisponivel) -> Void
    let aoAdicionarEquipe: (String) -> Void
    let aoSair: () -> Void
    let aoExcluirConta: () async throws -> Void
    @State private var nome: String = ""
    @State private var email: String = ""
    @State private var mostrandoAvisoDeSenha = false
    @State private var mostrandoConfirmacaoDeExclusao = false
    @State private var excluindoConta = false
    @State private var erroDeExclusao: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PapagaioTema.Espaco.pagina) {
                Text("Meu Perfil")
                    .font(PapagaioTema.Tipo.tituloDePagina)
                    .foregroundStyle(PapagaioTema.texto)

                CartaoDeIdentidadeDoPerfil(
                    nome: nome,
                    email: email,
                    avatarURL: perfil.avatarURL,
                    aoEditarAvatar: escolherAvatar
                )

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: PapagaioTema.Espaco.secao) {
                        InformacoesPessoaisDoPerfil(
                            nome: $nome,
                            email: $email,
                            aoSalvar: salvarDados
                        )
                        .frame(maxWidth: .infinity)

                        EquipesDoPerfil(
                            equipeAtiva: equipeAtiva,
                            equipes: equipes,
                            aoSelecionar: aoSelecionarEquipe,
                            aoAdicionarEquipe: aoAdicionarEquipe
                        )
                        .frame(width: 330)
                    }

                    VStack(alignment: .leading, spacing: PapagaioTema.Espaco.secao) {
                        InformacoesPessoaisDoPerfil(
                            nome: $nome,
                            email: $email,
                            aoSalvar: salvarDados
                        )

                        EquipesDoPerfil(
                            equipeAtiva: equipeAtiva,
                            equipes: equipes,
                            aoSelecionar: aoSelecionarEquipe,
                            aoAdicionarEquipe: aoAdicionarEquipe
                        )
                    }
                }

                SegurancaDoPerfil(
                    aoAlterarSenha: { mostrandoAvisoDeSenha = true },
                    aoSair: aoSair,
                    aoExcluirConta: { mostrandoConfirmacaoDeExclusao = true },
                    excluindoConta: excluindoConta
                )
                .frame(maxWidth: 690)
            }
            .larguraDeConteudoPapagaio()
            .padding(.horizontal, PapagaioTema.espacamentoDePagina)
            .padding(.vertical, PapagaioTema.espacamentoDePagina)
        }
        .background(PapagaioTema.fundo)
        .onAppear {
            nome = perfil.nome
            email = perfil.email
        }
        .alert("Login com Apple", isPresented: $mostrandoAvisoDeSenha) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("A senha é gerenciada pelo seu ID Apple. Para alterar, use os ajustes da sua conta Apple.")
        }
        .alert("Excluir conta permanentemente?", isPresented: $mostrandoConfirmacaoDeExclusao) {
            Button("Cancelar", role: .cancel) {}
            Button("Excluir conta e arquivos", role: .destructive) {
                Task { await excluirConta() }
            }
        } message: {
            Text("Esta ação não pode ser desfeita. Seu perfil, conversas, áudios, transcrições, notas, tarefas e equipes deste Mac serão removidos.")
        }
        .alert("Não foi possível excluir a conta", isPresented: Binding(
            get: { erroDeExclusao != nil },
            set: { if !$0 { erroDeExclusao = nil } }
        )) {
            Button("OK", role: .cancel) { erroDeExclusao = nil }
        } message: {
            Text(erroDeExclusao ?? "")
        }
    }

    private func salvarDados() {
        perfil.salvarDados(nome: nome, email: email)
        nome = perfil.nome
        email = perfil.email
    }

    private func escolherAvatar() {
        let painel = NSOpenPanel()
        painel.allowedContentTypes = [.image]
        painel.allowsMultipleSelection = false
        painel.canChooseDirectories = false
        painel.canChooseFiles = true
        painel.title = "Escolher foto do perfil"
        if painel.runModal() == .OK, let url = painel.url {
            perfil.escolherAvatar(url)
        }
    }

    private func excluirConta() async {
        excluindoConta = true
        defer { excluindoConta = false }

        do {
            try await aoExcluirConta()
        } catch {
            erroDeExclusao = error.localizedDescription
        }
    }
}
