import CryptoKit
import Foundation

/// Descrição de um peso GGUF que o app precisa ter em disco.
public struct PesoDeModelo: Sendable, Hashable {
    public let nomeArquivo: String
    public let bytes: Int64
    public let sha256: String
    public let url: URL

    public init(nomeArquivo: String, bytes: Int64, sha256: String, url: URL) {
        self.nomeArquivo = nomeArquivo
        self.bytes = bytes
        self.sha256 = sha256
        self.url = url
    }
}

/// Os dois pesos do Papagaio. Não há terceiro, e não há alternativa mais leve —
/// se o Mac não couber, o app bloqueia (D-0.7).
public enum Pesos {
    public static let whisperLargeV3 = PesoDeModelo(
        nomeArquivo: "ggml-large-v3.bin",
        bytes: 3_095_033_483,
        sha256: "64d182b440b98d5203c4f9bd541544d84c605196c4f7b845dfa11fb23594d1e2",
        url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin")!
    )

    public static let qwen14B = PesoDeModelo(
        nomeArquivo: "Qwen2.5-14B-Instruct-Q5_K_M.gguf",
        bytes: 10_508_873_856,
        sha256: "48ad2dafedac636f62847f5338c356cd21f5cfa6b1e2c885360cb10c890b8cb2",
        url: URL(string: "https://huggingface.co/bartowski/Qwen2.5-14B-Instruct-GGUF/resolve/main/Qwen2.5-14B-Instruct-Q5_K_M.gguf")!
    )

    public static var todos: [PesoDeModelo] { [whisperLargeV3, qwen14B] }
}

/// Resultado do preflight de hardware, na ordem exata do Passo 3.
public enum ResultadoPreflight: Sendable, Equatable {
    /// Tudo pronto: hardware passa e os dois pesos estão íntegros.
    case pronto

    /// `bloqueia` — não existe caminho degradado.
    case ramInsuficiente(instalada: Int64, minima: Int64)
    case discoInsuficiente(livre: Int64, minimo: Int64)

    /// Hardware passa, mas falta baixar (ou rebaixar) peso.
    case pesosFaltando([PesoDeModelo])

    /// Passa, com ressalva: o usuário decide se adia.
    case termicoCritico

    public var bloqueia: Bool {
        switch self {
        case .ramInsuficiente, .discoInsuficiente: true
        case .pronto, .pesosFaltando, .termicoCritico: false
        }
    }

    public var mensagem: String {
        switch self {
        case .pronto:
            "Tudo pronto."
        case let .ramInsuficiente(instalada, minima):
            "O Papagaio precisa de \(Preflight.gb(minima)) de memória e este Mac tem "
                + "\(Preflight.gb(instalada)). Não há modo reduzido: a transcrição e o resumo "
                + "rodam inteiramente no seu Mac, e os modelos não cabem."
        case let .discoInsuficiente(livre, minimo):
            "São necessários \(Preflight.gb(minimo)) livres para os modelos, e há "
                + "\(Preflight.gb(livre)) disponíveis."
        case let .pesosFaltando(pesos):
            "Faltam baixar \(pesos.count) modelo(s): "
                + pesos.map(\.nomeArquivo).joined(separator: ", ")
        case .termicoCritico:
            "Seu Mac está muito quente. Transcrever agora vai ficar lento e esquentar mais. "
                + "Dá para adiar."
        }
    }
}

/// Preflight de hardware e de pesos.
///
/// A ordem é a do Passo 3 e importa: não faz sentido oferecer download de 13 GB
/// para um Mac que nunca vai conseguir carregar os modelos.
public struct Preflight: Sendable {
    /// Qwen Q5_K_M ≈ 10,7 GB + KV cache. Piso de hardware, não degradação.
    public static let ramMinima: Int64 = 18 * 1_073_741_824
    /// Whisper ≈ 3 GB + Qwen ≈ 10,7 GB + folga.
    public static let discoMinimo: Int64 = 20 * 1_073_741_824

    private let pastaDeModelos: URL

    public init(pastaDeModelos: URL) {
        self.pastaDeModelos = pastaDeModelos
    }

    /// Roda os quatro portões na ordem, parando no primeiro que bloqueia.
    public func avaliar(
        pesos: [PesoDeModelo] = Pesos.todos,
        verificarChecksum: Bool = false
    ) -> ResultadoPreflight {
        // 1. RAM física — bloqueia.
        let ram = Self.ramInstalada
        guard ram >= Self.ramMinima else {
            return .ramInsuficiente(instalada: ram, minima: Self.ramMinima)
        }

        // 2. Disco livre — bloqueia.
        let livre = discoLivre
        guard livre >= Self.discoMinimo else {
            return .discoInsuficiente(livre: livre, minimo: Self.discoMinimo)
        }

        // 3. Pesos presentes e íntegros — oferece download.
        let faltando = pesos.filter { !pesoValido($0, verificarChecksum: verificarChecksum) }
        guard faltando.isEmpty else { return .pesosFaltando(faltando) }

        // 4. Térmico — avisa.
        if ProcessInfo.processInfo.thermalState == .critical {
            return .termicoCritico
        }

        return .pronto
    }

    /// Um peso é válido se existe, tem o tamanho esperado e — quando pedido —
    /// bate o SHA-256. Checar 13 GB de hash não é de graça: só na instalação e
    /// quando o usuário pedir verificação, não a cada abertura.
    public func pesoValido(_ peso: PesoDeModelo, verificarChecksum: Bool) -> Bool {
        let caminho = pastaDeModelos.appendingPathComponent(peso.nomeArquivo)
        guard let atributos = try? FileManager.default.attributesOfItem(atPath: caminho.path),
              let tamanho = atributos[.size] as? Int64,
              tamanho == peso.bytes
        else { return false }

        guard verificarChecksum, !peso.sha256.isEmpty else { return true }
        guard let hash = try? Self.sha256(de: caminho) else { return false }
        return hash == peso.sha256
    }

    // MARK: - Medições

    public static var ramInstalada: Int64 {
        Int64(ProcessInfo.processInfo.physicalMemory)
    }

    public var discoLivre: Int64 {
        let valores = try? pastaDeModelos.resourceValues(
            forKeys: [.volumeAvailableCapacityForImportantUsageKey]
        )
        if let importante = valores?.volumeAvailableCapacityForImportantUsage {
            return Int64(importante)
        }
        // Fallback: a pasta pode ainda não existir.
        let raiz = URL(fileURLWithPath: NSHomeDirectory())
        let deRaiz = try? raiz.resourceValues(
            forKeys: [.volumeAvailableCapacityForImportantUsageKey]
        )
        return Int64(deRaiz?.volumeAvailableCapacityForImportantUsage ?? 0)
    }

    /// SHA-256 em streaming: um `Data(contentsOf:)` de 10,7 GB estoura a memória
    /// justamente na máquina que já está no limite.
    public static func sha256(de url: URL) throws -> String {
        let arquivo = try FileHandle(forReadingFrom: url)
        defer { try? arquivo.close() }

        var digestor = SHA256()
        while true {
            let bloco = try autoreleasepool {
                try arquivo.read(upToCount: 4 * 1_048_576)
            }
            guard let bloco, !bloco.isEmpty else { break }
            digestor.update(data: bloco)
        }
        return digestor.finalize().map { String(format: "%02x", $0) }.joined()
    }

    static func gb(_ bytes: Int64) -> String {
        String(format: "%.0f GB", Double(bytes) / 1_073_741_824)
    }
}
