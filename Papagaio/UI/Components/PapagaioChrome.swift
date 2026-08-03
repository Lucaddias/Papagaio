import SwiftUI

/// Conteúdo da barra de ferramentas nativa. Só expõe ações existentes — não
/// adiciona ícones decorativos sem comportamento.
struct BarraSuperiorPapagaio: ToolbarContent {
    @Binding var consulta: String
    @State private var exibindoMenuDePerfil = false
    let exibindoBotaoVoltar: Bool
    let perfilConectado: Bool
    let perfilVerificando: Bool
    let gravando: Bool
    let processandoBiblioteca: Bool
    let quantidadeDeAvisos: Int
    let aoEntrar: () -> Void
    let aoSair: () -> Void
    let aoVoltar: () -> Void
    let aoAbrirBiblioteca: () -> Void
    let aoAbrirTarefas: () -> Void
    let aoAbrirConfiguracoes: () -> Void
    let aoAbrirLixeira: () -> Void

    var body: some ToolbarContent {
        if exibindoBotaoVoltar {
            ToolbarItem(placement: .navigation) {
                Button(action: aoVoltar) {
                    Image(systemName: "chevron.backward")
                }
                .help("Voltar à biblioteca")
                .accessibilityLabel("Voltar à biblioteca")
            }
        }

        ToolbarItem(placement: .principal) {
            HStack(spacing: 28) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(PapagaioTema.textoSecundario)
                    TextField("Buscar conversas…", text: $consulta)
                        .textFieldStyle(.plain)
                        .foregroundStyle(PapagaioTema.texto)
                        .accessibilityLabel("Buscar conversas")
                }
                .padding(.horizontal, 12)
                .frame(width: exibindoBotaoVoltar ? 300 : 360, height: 34)
                .background(PapagaioTema.superficie, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(PapagaioTema.borda, lineWidth: 1)
                }

                Button(action: aoAbrirBiblioteca) {
                    Image(systemName: "folder")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(PapagaioTema.destaqueEscuro)
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Biblioteca de conversas")
                .accessibilityLabel("Biblioteca de conversas")

                Button(action: aoAbrirTarefas) {
                    Image(systemName: "list.clipboard")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(PapagaioTema.textoSecundario)
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Tarefas")
                .accessibilityLabel("Tarefas")
            }
            .fixedSize()
            .padding(.leading, 10)
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Button {} label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(PapagaioTema.textoSecundario)
                        .frame(width: 32, height: 32)
                        .contentShape(Circle())

                    if temNotificacoesAtivas {
                        Circle()
                            .fill(PapagaioTema.destaque)
                            .frame(width: 8, height: 8)
                            .offset(x: -4, y: 5)
                    }
                }
            }
            .buttonStyle(.plain)
            .help("Notificações")
            .accessibilityLabel("Notificações")

            Button(action: aoAbrirConfiguracoes) {
                Image(systemName: "gearshape")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(PapagaioTema.textoSecundario)
                    .frame(width: 32, height: 32)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Configurações")
            .accessibilityLabel("Configurações")
            .accessibilityHint("Abre as preferências de transcrição.")

            Button(action: aoAbrirLixeira) {
                Image(systemName: "trash")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(PapagaioTema.perigo)
                    .frame(width: 32, height: 32)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Lixeira")
            .accessibilityLabel("Lixeira")
            .accessibilityHint("Abre os arquivos removidos da biblioteca.")
        }

        ToolbarSpacer(.fixed, placement: .primaryAction)

        ToolbarItem(placement: .primaryAction) {
            Button {
                exibindoMenuDePerfil = true
            } label: {
                Image(systemName: perfilConectado ? "person.crop.circle.fill" : "person.crop.circle")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(PapagaioTema.textoSecundario)
                    .frame(width: 36, height: 36)
                    .background(.regularMaterial, in: Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(PapagaioTema.borda.opacity(0.8), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .help(perfilConectado ? "Perfil conectado" : "Perfil")
            .accessibilityLabel(perfilConectado ? "Perfil conectado" : "Perfil")
            .popover(isPresented: $exibindoMenuDePerfil, arrowEdge: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    if perfilConectado {
                        Text("Conectado com Apple")
                            .font(.subheadline)
                            .foregroundStyle(PapagaioTema.textoSecundario)
                        Divider()
                        Button("Sair", role: .destructive) {
                            exibindoMenuDePerfil = false
                            aoSair()
                        }
                    } else {
                        Button("Entrar com Apple") {
                            exibindoMenuDePerfil = false
                            aoEntrar()
                        }
                        .disabled(perfilVerificando)
                    }
                }
                .padding(12)
                .frame(minWidth: 180, alignment: .leading)
            }
        }
    }

    private var temNotificacoesAtivas: Bool {
        gravando || processandoBiblioteca || quantidadeDeAvisos > 0
    }
}

struct CabecalhoDePagina<Acoes: View>: View {
    let titulo: String
    let subtitulo: String?
    @ViewBuilder let acoes: () -> Acoes

    init(
        titulo: String,
        subtitulo: String? = nil,
        @ViewBuilder acoes: @escaping () -> Acoes = { EmptyView() }
    ) {
        self.titulo = titulo
        self.subtitulo = subtitulo
        self.acoes = acoes
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(titulo)
                    .font(.system(size: 32, weight: .bold, design: .default))
                    .foregroundStyle(PapagaioTema.texto)
                if let subtitulo {
                    Text(subtitulo)
                        .font(.title3)
                        .foregroundStyle(PapagaioTema.textoSecundario)
                }
            }
            Spacer(minLength: 16)
            acoes()
        }
    }
}

struct CartaoDeEstadoVazio: View {
    let simbolo: String
    let titulo: String
    let mensagem: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: simbolo)
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(PapagaioTema.destaqueEscuro)
                .frame(width: 64, height: 64)
                .background(PapagaioTema.destaqueSuave, in: Circle())
            Text(titulo)
                .font(.title3.weight(.semibold))
                .foregroundStyle(PapagaioTema.texto)
            Text(mensagem)
                .multilineTextAlignment(.center)
                .foregroundStyle(PapagaioTema.textoSecundario)
                .frame(maxWidth: 420)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

struct SeparadorPapagaio: View {
    var body: some View {
        Rectangle()
            .fill(PapagaioTema.borda.opacity(0.75))
            .frame(height: 1)
    }
}
