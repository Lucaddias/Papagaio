import SwiftUI

struct GestaoDeEquipeView: View {
    let equipeAtiva: EquipeDisponivel?
    let equipes: [EquipeDisponivel]
    let aoSelecionarEquipe: (EquipeDisponivel) -> Void
    let aoAtualizarQuantidadeDeMembros: (String, Int) -> Void
    /// Criar equipe é coisa desta tela, não do Perfil — lá só aparece quais
    /// equipes a pessoa já tem, com o `+` que existia antes movido pra cá.
    let aoAdicionarEquipe: (String) -> Void
    @State private var membros: [MembroDaEquipe] = []
    @State private var pagina = 0
    @State private var membroEditando: MembroDaEquipe?
    @State private var mostrandoAdicionar = false
    @State private var mostrandoTrocarEquipe = false
    @State private var mostrandoNovaEquipe = false
    @State private var nomeDaNovaEquipe = ""

    var body: some View {
        ScrollView {
            // Sem equipe não há membro para listar nem nome para exibir: a
            // tela inteira vira o convite para criar a primeira, aqui mesmo.
            if equipeAtiva == nil {
                VStack(spacing: PapagaioTema.Espaco.largo) {
                    CartaoDeEstadoVazio(
                        simbolo: "person.3",
                        titulo: "Nenhuma equipe ainda",
                        mensagem: "Crie uma equipe para convidar pessoas e distribuir as tarefas das conversas."
                    )

                    Button("Criar equipe", systemImage: "plus") {
                        mostrandoNovaEquipe = true
                    }
                    .buttonStyle(BotaoPrincipalPapagaio())
                }
                .padding(.vertical, PapagaioTema.espacamentoDePagina)
            } else {
                VStack(alignment: .leading, spacing: PapagaioTema.Espaco.pagina) {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .bottom, spacing: PapagaioTema.Espaco.largo) {
                            cabecalho
                        }

                        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.largo) {
                            cabecalho
                        }
                    }

                    TabelaDaEquipe(
                        membros: membros,
                        pagina: pagina,
                        aoEditar: { membroEditando = $0 },
                        aoRemover: remover,
                        aoAlternarPagina: alternarPagina
                    )
                }
                .larguraDeConteudoPapagaio()
                .padding(.horizontal, PapagaioTema.espacamentoDePagina)
                .padding(.vertical, PapagaioTema.espacamentoDePagina)
            }
        }
        .background(PapagaioTema.fundo)
        .onAppear {
            carregarMembrosDaEquipe()
        }
        .onChange(of: equipeAtiva?.id) { _, _ in
            carregarMembrosDaEquipe()
        }
        .sheet(isPresented: $mostrandoAdicionar) {
            EditorDeMembroDaEquipe(
                titulo: "Adicionar membro",
                membro: MembroDaEquipe(nome: "", email: "", cargo: "Transcritor", status: .ativo),
                aoCancelar: { mostrandoAdicionar = false },
                aoSalvar: { novo in
                    membros.append(novo)
                    salvarMembrosDaEquipe()
                    mostrandoAdicionar = false
                }
            )
        }
        .sheet(item: $membroEditando) { membro in
            EditorDeMembroDaEquipe(
                titulo: "Editar membro",
                membro: membro,
                aoCancelar: { membroEditando = nil },
                aoSalvar: { editado in
                    if let indice = membros.firstIndex(where: { $0.id == editado.id }) {
                        membros[indice] = editado
                        salvarMembrosDaEquipe()
                    }
                    membroEditando = nil
                }
            )
        }
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
        .alert("Nova equipe", isPresented: $mostrandoNovaEquipe) {
            TextField("Nome da equipe", text: $nomeDaNovaEquipe)
            Button("Cancelar", role: .cancel) {
                nomeDaNovaEquipe = ""
            }
            Button("Criar") {
                criarEquipe()
            }
            .disabled(nomeDaNovaEquipe.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Dá pra convidar pessoas e distribuir tarefas assim que ela existir.")
        }
    }

    private func criarEquipe() {
        let nome = nomeDaNovaEquipe.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nome.isEmpty else { return }
        aoAdicionarEquipe(nome)
        nomeDaNovaEquipe = ""
    }

    private var cabecalho: some View {
        Group {
                    VStack(alignment: .leading, spacing: PapagaioTema.Espaco.curto) {
                        Text("Equipe")
                            .font(PapagaioTema.Tipo.tituloDePagina)
                            .foregroundStyle(PapagaioTema.texto)

                        Text("Gerencie os membros de \(nomeDaEquipe) e níveis de acesso\nem um ambiente centralizado e colaborativo.")
                            .font(.title3)
                            .lineSpacing(6)
                            .foregroundStyle(PapagaioTema.textoSecundario)
                    }

                    Spacer()

                    Button("Mudar Equipe: \(nomeDaEquipe)", systemImage: "arrow.triangle.2.circlepath") {
                        mostrandoTrocarEquipe = true
                    }
                    .buttonStyle(BotaoDeContornoPapagaio())

                    Button("Nova Equipe", systemImage: "plus") {
                        mostrandoNovaEquipe = true
                    }
                    .buttonStyle(BotaoDeContornoPapagaio())

                    Button("Adicionar Membro", systemImage: "person.badge.plus") {
                        mostrandoAdicionar = true
                    }
                    .buttonStyle(BotaoPrincipalPapagaio())
        }
    }

    private func remover(_ membro: MembroDaEquipe) {
        guard !membro.atual else { return }
        membros.removeAll { $0.id == membro.id }
        salvarMembrosDaEquipe()
    }

    private func alternarPagina(_ delta: Int) {
        let ultima = max(0, (membros.count - 1) / TabelaDaEquipe.itensPorPagina)
        pagina = min(max(0, pagina + delta), ultima)
    }

    private var nomeDaEquipe: String {
        equipeAtiva?.nome ?? ""
    }

    private func carregarMembrosDaEquipe() {
        guard let equipeAtiva else {
            membros = []
            pagina = 0
            return
        }
        membros = MembrosDasEquipes.carregar(equipeID: equipeAtiva.id)
        pagina = 0
        aoAtualizarQuantidadeDeMembros(equipeAtiva.id, membros.count)
    }

    private func salvarMembrosDaEquipe() {
        guard let equipeAtiva else { return }
        MembrosDasEquipes.salvar(membros, equipeID: equipeAtiva.id)
        let ultima = max(0, (membros.count - 1) / TabelaDaEquipe.itensPorPagina)
        pagina = min(pagina, ultima)
        aoAtualizarQuantidadeDeMembros(equipeAtiva.id, membros.count)
    }
}
