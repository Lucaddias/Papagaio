import SwiftUI

struct MenuDeArquivoAberto: View {
    let bloqueioDeEdicao: Bool
    let bloqueioDeLixeira: Bool
    let podeDiarizar: Bool
    let aoDiarizar: () -> Void
    let aoReprocessar: () -> Void
    let aoEditarImagem: () -> Void
    let aoRenomear: () -> Void
    let aoMoverParaPasta: () -> Void
    let aoCompartilhar: () -> Void
    let aoDuplicar: () -> Void
    let aoMoverParaLixeira: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ItemDoMenuDeArquivo(simbolo: "pencil.and.outline", titulo: "Editar imagem", acao: aoEditarImagem)
            ItemDoMenuDeArquivo(simbolo: "square.and.pencil", titulo: "Editar informações", acao: aoRenomear)
            ItemDoMenuDeArquivo(simbolo: "folder", titulo: "Mover para pasta", acao: aoMoverParaPasta)
            ItemDoMenuDeArquivo(simbolo: "square.and.arrow.up", titulo: "Compartilhar", acao: aoCompartilhar)
            ItemDoMenuDeArquivo(simbolo: "rectangle.on.rectangle", titulo: "Duplicar", desabilitado: bloqueioDeEdicao, acao: aoDuplicar)
            // Favoritar sai daqui: a estrela no canto do card já faz isso, e
            // repetir a ação no menu só alongava a lista.

            SeparadorPapagaio()
                .padding(.horizontal, PapagaioTema.Espaco.medio)
                .padding(.vertical, PapagaioTema.Espaco.minimo)

            // Diarização retroativa: arquivos gravados antes da diarização
            // existir têm palavras sem falante — distinguir é leve (só os
            // modelos pequenos), reprocessar re-transcreve tudo.
            ItemDoMenuDeArquivo(
                simbolo: "person.2.wave.2",
                titulo: "Distinguir falantes",
                desabilitado: bloqueioDeEdicao || !podeDiarizar,
                acao: aoDiarizar
            )
            ItemDoMenuDeArquivo(
                simbolo: "arrow.clockwise",
                titulo: "Reprocessar",
                desabilitado: bloqueioDeEdicao,
                acao: aoReprocessar
            )

            SeparadorPapagaio()
                .padding(.horizontal, PapagaioTema.Espaco.medio)
                .padding(.vertical, PapagaioTema.Espaco.minimo)

            ItemDoMenuDeArquivo(
                simbolo: "trash",
                titulo: "Mover para Lixeira",
                destrutivo: true,
                desabilitado: bloqueioDeLixeira,
                acao: aoMoverParaLixeira
            )
        }
        .frame(width: 214)
        .padding(.vertical, PapagaioTema.Espaco.minimo)
        .background(PapagaioTema.superficie, in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
                .stroke(PapagaioTema.borda, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 12, y: 6)
        .shadow(color: PapagaioTema.destaque.opacity(0.12), radius: 4, y: 1)
    }
}

struct ItemDoMenuDeArquivo: View {
    let simbolo: String
    let titulo: String
    var destrutivo = false
    var desabilitado = false
    let acao: () -> Void

    var body: some View {
        Button(action: acao) {
            HStack(spacing: PapagaioTema.Espaco.medio) {
                Image(systemName: simbolo)
                    .font(.system(size: 15, weight: .regular))
                    .symbolRenderingMode(.monochrome)
                    .frame(width: 18)

                Text(titulo)
                    .font(.system(size: 14, weight: .regular))
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .foregroundStyle(cor.opacity(desabilitado ? 0.42 : 1))
            .padding(.horizontal, PapagaioTema.Espaco.medio)
            .frame(height: PapagaioTema.Altura.padrao)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(desabilitado)
    }

    private var cor: Color {
        destrutivo ? PapagaioTema.perigo : PapagaioTema.textoSecundario
    }
}
