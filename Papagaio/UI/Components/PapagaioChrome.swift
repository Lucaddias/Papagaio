import SwiftUI

/// Barra superior reutilizável. Só expõe ações existentes — não adiciona ícones
/// decorativos sem comportamento.
struct BarraSuperiorPapagaio: View {
    @Binding var consulta: String
    let perfilConectado: Bool
    let perfilVerificando: Bool
    let aoEntrar: () -> Void
    let aoSair: () -> Void

    var body: some View {
        HStack(spacing: 20) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(PapagaioTema.textoSecundario)
                TextField("Buscar conversas…", text: $consulta)
                    .textFieldStyle(.plain)
                    .foregroundStyle(PapagaioTema.texto)
                    .accessibilityLabel("Buscar conversas")
            }
            .padding(.horizontal, 13)
            .frame(width: 280, height: 40)
            .background(PapagaioTema.superficie, in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
                    .stroke(PapagaioTema.borda, lineWidth: 1)
            }

            Label("Biblioteca", systemImage: "folder")
                .font(.callout.weight(.semibold))
                .foregroundStyle(PapagaioTema.destaqueEscuro)
                .accessibilityHidden(true)

            Spacer(minLength: 20)

            Menu {
                if perfilConectado {
                    Text("Conectado com Apple")
                    Divider()
                    Button("Sair", role: .destructive, action: aoSair)
                } else {
                    Button("Entrar com Apple", action: aoEntrar)
                        .disabled(perfilVerificando)
                }
            } label: {
                Image(systemName: perfilConectado ? "person.crop.circle.fill" : "person.crop.circle")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(PapagaioTema.destaqueEscuro)
                    .frame(width: 40, height: 40)
                    .background(PapagaioTema.destaqueSuave, in: Circle())
            }
            .menuStyle(.borderlessButton)
            .accessibilityLabel(perfilConectado ? "Perfil conectado" : "Perfil")
        }
        .padding(.horizontal, PapagaioTema.espacamentoDePagina)
        .padding(.vertical, 18)
        .background(PapagaioTema.fundo)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PapagaioTema.borda.opacity(0.8))
                .frame(height: 1)
        }
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
