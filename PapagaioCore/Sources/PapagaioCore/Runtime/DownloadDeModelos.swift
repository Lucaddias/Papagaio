import CryptoKit
import Foundation

/// Progresso de um download de peso, para a UI.
public struct ProgressoDownload: Sendable, Equatable {
    public let peso: PesoDeModelo
    public let bytesRecebidos: Int64
    public let bytesTotais: Int64

    public var fracao: Double {
        bytesTotais > 0 ? Double(bytesRecebidos) / Double(bytesTotais) : 0
    }
}

public enum ErroDownload: Error, CustomStringConvertible {
    case checksumInvalido(esperado: String, obtido: String)
    case respostaInvalida(Int)
    case interrompido

    public var description: String {
        switch self {
        case let .checksumInvalido(esperado, obtido):
            "O arquivo baixado não confere (esperado \(esperado.prefix(12))…, "
                + "obtido \(obtido.prefix(12))…). Ele foi descartado."
        case let .respostaInvalida(codigo):
            "O servidor respondeu \(codigo)."
        case .interrompido:
            "Download interrompido."
        }
    }
}

/// Baixa os pesos GGUF, com retomada em queda de conexão e verificação de
/// SHA-256 por artefato.
///
/// **Os pesos nunca vão no bundle** — são dados baixados depois da instalação.
/// É o que mantém o app dentro da guideline 2.5.2 da App Store (R-6) e o que
/// permite um `.app` de tamanho normal para 13,6 GB de modelo.
public actor DownloadDeModelos {
    private let pastaDeModelos: URL
    private let sessao: URLSession

    public init(pastaDeModelos: URL, sessao: URLSession = .shared) {
        self.pastaDeModelos = pastaDeModelos
        self.sessao = sessao
    }

    /// Baixa um peso, retomando de onde parou se houver arquivo parcial.
    ///
    /// A retomada usa `Range:` HTTP sobre um arquivo `.parcial` no disco, e não
    /// `URLSessionDownloadTask.cancel(byProducingResumeData:)`: o resume data da
    /// Apple não sobrevive a um encerramento do app, e 10,7 GB é grande demais
    /// para recomeçar do zero por causa disso.
    public func baixar(
        _ peso: PesoDeModelo,
        aoProgredir: @escaping @Sendable (ProgressoDownload) -> Void = { _ in }
    ) async throws -> URL {
        let destino = pastaDeModelos.appendingPathComponent(peso.nomeArquivo)
        if FileManager.default.fileExists(atPath: destino.path) {
            return destino
        }

        try FileManager.default.createDirectory(
            at: pastaDeModelos, withIntermediateDirectories: true
        )

        let parcial = destino.appendingPathExtension("parcial")
        let jaBaixado = Self.tamanhoEmDisco(parcial)

        var requisicao = URLRequest(url: peso.url)
        if jaBaixado > 0 {
            requisicao.setValue("bytes=\(jaBaixado)-", forHTTPHeaderField: "Range")
        }

        let (bytes, resposta) = try await sessao.bytes(for: requisicao)
        guard let http = resposta as? HTTPURLResponse else {
            throw ErroDownload.respostaInvalida(-1)
        }
        // 200 = do começo; 206 = retomada aceita.
        guard http.statusCode == 200 || http.statusCode == 206 else {
            throw ErroDownload.respostaInvalida(http.statusCode)
        }

        let retomando = http.statusCode == 206
        let inicio: Int64 = retomando ? jaBaixado : 0
        if !retomando { try? FileManager.default.removeItem(at: parcial) }

        if !FileManager.default.fileExists(atPath: parcial.path) {
            FileManager.default.createFile(atPath: parcial.path, contents: nil)
        }
        let escritor = try FileHandle(forWritingTo: parcial)
        try escritor.seekToEnd()
        defer { try? escritor.close() }

        var recebidos = inicio
        var buffer = Data()
        buffer.reserveCapacity(4 * 1_048_576)

        for try await byte in bytes {
            buffer.append(byte)
            if buffer.count >= 4 * 1_048_576 {
                try escritor.write(contentsOf: buffer)
                recebidos += Int64(buffer.count)
                buffer.removeAll(keepingCapacity: true)
                aoProgredir(ProgressoDownload(
                    peso: peso, bytesRecebidos: recebidos, bytesTotais: peso.bytes
                ))
                try Task.checkCancellation()
            }
        }
        if !buffer.isEmpty {
            try escritor.write(contentsOf: buffer)
            recebidos += Int64(buffer.count)
        }
        try escritor.close()

        // Verificação antes de promover: um peso corrompido que vira "ativo" é
        // pior que um download perdido — o modelo carrega e produz lixo.
        let hash = try Preflight.sha256(de: parcial)
        guard peso.sha256.isEmpty || hash == peso.sha256 else {
            try? FileManager.default.removeItem(at: parcial)
            throw ErroDownload.checksumInvalido(esperado: peso.sha256, obtido: hash)
        }

        try FileManager.default.moveItem(at: parcial, to: destino)
        aoProgredir(ProgressoDownload(
            peso: peso, bytesRecebidos: peso.bytes, bytesTotais: peso.bytes
        ))
        return destino
    }

    /// Quanto já existe em disco de um peso ainda incompleto.
    public func bytesParciais(de peso: PesoDeModelo) -> Int64 {
        let parcial = pastaDeModelos
            .appendingPathComponent(peso.nomeArquivo)
            .appendingPathExtension("parcial")
        return Self.tamanhoEmDisco(parcial)
    }

    static func tamanhoEmDisco(_ url: URL) -> Int64 {
        guard let atributos = try? FileManager.default.attributesOfItem(atPath: url.path),
              let tamanho = atributos[.size] as? Int64
        else { return 0 }
        return tamanho
    }
}
