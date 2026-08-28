import AppKit
import SwiftUI

struct PerfilPessoalView: View {
    @Bindable var perfil: PerfilViewModel
    let equipeAtiva: EquipeDisponivel?
    let equipes: [EquipeDisponivel]
    let aoSelecionarEquipe: (EquipeDisponivel) -> Void
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
            // Duas colunas: a da esquerda empilha identidade, Informações
            // Pessoais e Segurança, todas do mesmo tamanho (ver
            // `colunaEsquerdaDoPerfil`); a de Equipes ocupa o vão que sobra à
            // direita.
            //
            // Sem `.frame(maxHeight: .infinity)` nela: esticar o cartão até
            // a mesma altura da coluna da esquerda parecia bom com uma
            // lista grande de equipes, mas com poucas (ou nenhuma) sobrava
            // uma faixa enorme e vazia no fim do cartão — pior do que só
            // deixá-lo do tamanho do próprio conteúdo, que já cresce
            // sozinho conforme mais equipes entram (a grade dentro dele é
            // quem decide a altura, ver `EquipesDoPerfil`).
            //
            // `ViewThatFits` troca para a versão empilhada (uma coluna só)
            // quando a janela não tem largura para as duas lado a lado.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: PapagaioTema.Espaco.secao) {
                    colunaEsquerdaDoPerfil

                    EquipesDoPerfil(
                        equipeAtiva: equipeAtiva,
                        equipes: equipes,
                        aoSelecionar: aoSelecionarEquipe
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: PapagaioTema.Espaco.pagina) {
                    colunaEsquerdaDoPerfil

                    EquipesDoPerfil(
                        equipeAtiva: equipeAtiva,
                        equipes: equipes,
                        aoSelecionar: aoSelecionarEquipe
                    )
                }
            }
            // Sem centralizar: `larguraDeConteudoPapagaio()` centraliza a
            // coluna inteira numa janela larga, sobrando o mesmo respiro dos
            // dois lados — aqui os cartões ficam melhor grudados à esquerda,
            // como o resto da página, em vez de flutuando no meio da janela.
            .frame(maxWidth: PapagaioTema.larguraMaximaDeConteudo, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, PapagaioTema.espacamentoDePagina)
            .padding(.vertical, PapagaioTema.espacamentoDePagina)
        }
        .background(PapagaioTema.fundo)
        .onAppear {
            nome = perfil.nome
            email = perfil.email
        }
        // O onAppear sozinho deixa os campos velhos quando o perfil muda com
        // a tela já montada (troca de conta, fim do sign-in): os campos
        // seguem o modelo enquanto a view existe.
        .onChange(of: perfil.nome) { _, novo in nome = novo }
        .onChange(of: perfil.email) { _, novo in email = novo }
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

    /// Identidade, Informações Pessoais e Segurança — a coluna inteira da
    /// esquerda, sempre com 990pt de largura (o mesmo teto que
    /// `CartaoDeIdentidadeDoPerfil` já usa por conta própria), pra as bordas
    /// — esquerda e direita, dos três cartões — caírem no mesmo lugar em vez
    /// de um esticar mais que o outro.
    private var colunaEsquerdaDoPerfil: some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.pagina) {
            CartaoDeIdentidadeDoPerfil(
                nome: nome,
                email: email,
                avatarURL: perfil.avatarURL,
                aoEditarAvatar: escolherAvatar
            )

            InformacoesPessoaisDoPerfil(
                nome: $nome,
                email: $email,
                aoSalvar: salvarDados
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            SegurancaDoPerfil(
                aoAlterarSenha: { mostrandoAvisoDeSenha = true },
                aoSair: aoSair,
                aoExcluirConta: { mostrandoConfirmacaoDeExclusao = true },
                excluindoConta: excluindoConta
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: 990, alignment: .leading)
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
        // `begin` no lugar de `runModal`: o painel deixa de travar a main
        // enquanto a pessoa navega.
        painel.begin { resposta in
            guard resposta == .OK, let url = painel.url else { return }
            Task { @MainActor in
                perfil.escolherAvatar(url)
            }
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
