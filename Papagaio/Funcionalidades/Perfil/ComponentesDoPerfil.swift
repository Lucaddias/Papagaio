import AppKit
import SwiftUI

struct TituloDeSecaoDoPerfil: View {
    let simbolo: String
    let titulo: String

    var body: some View {
        Label(titulo, systemImage: simbolo)
            .font(.title3)
            .foregroundStyle(PapagaioTema.texto)
            .labelStyle(.titleAndIcon)
    }
}

struct CampoDoPerfil: View {
    let titulo: String
    @Binding var texto: String
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: PapagaioTema.Espaco.curto) {
            Text(titulo)
                .font(.callout.weight(.semibold))
                .foregroundStyle(PapagaioTema.textoSecundario)

            TextField(placeholder, text: $texto)
                .textFieldStyle(.plain)
                .font(.title3)
                .foregroundStyle(PapagaioTema.texto)
                .padding(.horizontal, PapagaioTema.Espaco.largo)
                .frame(height: PapagaioTema.Altura.destaque)
                .background(PapagaioTema.fundo, in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
                        .stroke(PapagaioTema.borda, lineWidth: 1)
                }
        }
    }
}

struct AvatarDoPerfil: View {
    let url: URL?
    let tamanho: CGFloat

    private var imagem: NSImage? {
        guard let url else { return nil }
        let acessou = url.startAccessingSecurityScopedResource()
        defer {
            if acessou { url.stopAccessingSecurityScopedResource() }
        }
        return NSImage(contentsOf: url)
    }

    var body: some View {
        ZStack {
            if let imagem {
                Image(nsImage: imagem)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(PapagaioTema.textoSecundario.opacity(0.35))
                    .padding(PapagaioTema.Espaco.curto)
            }
        }
        .frame(width: tamanho, height: tamanho)
        .clipShape(Circle())
        .overlay { Circle().stroke(PapagaioTema.superficie, lineWidth: 5) }
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
    }
}
