import AppKit
import Foundation
import PapagaioCore

enum MidiasDaConversa {
    private struct Registro: Codable {
        let id: UUID
        let nome: String
        let tamanho: Int64
        let data: Date
        let bookmark: Data
    }

    static func carregar(_ arquivoID: ArquivoID) -> [AnexoDeMidiaDaConversa] {
        guard let dados = UserDefaults.standard.data(forKey: chave(arquivoID)),
              let registros = try? JSONDecoder().decode([Registro].self, from: dados)
        else { return [] }

        return registros.compactMap { registro in
            var obsoleto = false
            guard let url = try? URL(
                resolvingBookmarkData: registro.bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &obsoleto
            ) else { return nil }

            return AnexoDeMidiaDaConversa(
                id: registro.id,
                nome: registro.nome,
                tamanho: registro.tamanho,
                data: registro.data,
                url: url
            )
        }
    }

    static func anexo(para url: URL) throws -> AnexoDeMidiaDaConversa {
        let valores = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        return AnexoDeMidiaDaConversa(
            id: UUID(),
            nome: url.lastPathComponent,
            tamanho: Int64(valores.fileSize ?? 0),
            data: valores.contentModificationDate ?? Date(),
            url: url
        )
    }

    static func copiar(_ origem: URL, para pastaDaConversa: URL) throws -> URL {
        let pastaDeMidia = pastaDaConversa.appendingPathComponent("Midia", isDirectory: true)
        try FileManager.default.createDirectory(at: pastaDeMidia, withIntermediateDirectories: true)

        let nomeUnico = nomeDisponivel(para: origem.lastPathComponent, em: pastaDeMidia)
        let destino = pastaDeMidia.appendingPathComponent(nomeUnico)
        try FileManager.default.copyItem(at: origem, to: destino)
        return destino
    }

    static func apagarArquivoSalvo(_ anexo: AnexoDeMidiaDaConversa, pastaDaConversa: URL) throws {
        let pastaDeMidia = pastaDaConversa.appendingPathComponent("Midia", isDirectory: true)
        let caminhoPadronizado = anexo.url.standardizedFileURL.path
        guard caminhoPadronizado.hasPrefix(pastaDeMidia.standardizedFileURL.path) else { return }
        if FileManager.default.fileExists(atPath: anexo.url.path) {
            try FileManager.default.removeItem(at: anexo.url)
        }
    }

    static func salvar(_ anexos: [AnexoDeMidiaDaConversa], para arquivoID: ArquivoID) throws {
        let registros = try anexos.map { anexo in
            let bookmark = try anexo.url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            return Registro(
                id: anexo.id,
                nome: anexo.nome,
                tamanho: anexo.tamanho,
                data: anexo.data,
                bookmark: bookmark
            )
        }
        let dados = try JSONEncoder().encode(registros)
        UserDefaults.standard.set(dados, forKey: chave(arquivoID))
    }

    private static func chave(_ arquivoID: ArquivoID) -> String {
        "midiasDaConversa.\(arquivoID.rawValue.uuidString)"
    }

    private static func nomeDisponivel(para nomeOriginal: String, em pasta: URL) -> String {
        let original = nomeOriginal.isEmpty ? "arquivo" : nomeOriginal
        let base = (original as NSString).deletingPathExtension
        let ext = (original as NSString).pathExtension
        var candidato = original
        var indice = 2

        while FileManager.default.fileExists(atPath: pasta.appendingPathComponent(candidato).path) {
            candidato = ext.isEmpty ? "\(base) \(indice)" : "\(base) \(indice).\(ext)"
            indice += 1
        }

        return candidato
    }
}
