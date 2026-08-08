import SwiftUI
import UniformTypeIdentifiers

/// Documento de texto entregue ao `fileExporter`.
struct DocumentoMarkdown: FileDocument {
    /// `UTType.markdown` só foi anotado como disponível a partir do macOS 27;
    /// o app suporta macOS 26. A extensão registrada mantém o mesmo formato.
    static let tipo = UTType(filenameExtension: "md") ?? .plainText
    static var readableContentTypes: [UTType] { [tipo] }

    let conteudo: String

    init(conteudo: String) {
        self.conteudo = conteudo
    }

    init(configuration: ReadConfiguration) throws {
        conteudo = String(data: configuration.file.regularFileContents ?? Data(), encoding: .utf8) ?? ""
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(conteudo.utf8))
    }
}
