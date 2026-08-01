import Foundation

/// Onde os arquivos vivem sob App Sandbox.
///
/// Tudo dentro do container do app. Nunca `~/Documents`, nunca caminho
/// absoluto fora do container — e no modelo guarda-se apenas o **caminho
/// relativo**, porque o UUID do container muda entre instalações.
///
/// É um valor com a raiz injetada, não um `enum` de estáticos: teste que
/// gravasse na Application Support de verdade sujaria a máquina de quem roda.
public struct Armazenamento: Sendable {
    public static let pastaRaiz = "Papagaio"
    public static let pastaGravacoes = "Gravacoes"
    public static let pastaModelos = "Models"

    /// Raiz absoluta: `<Application Support>/Papagaio` em produção,
    /// um diretório temporário nos testes.
    public let raiz: URL

    public init(raiz: URL) {
        self.raiz = raiz
    }

    /// `~/Library/Application Support/Papagaio` — dentro do container sob sandbox.
    public static func padrao(_ fm: FileManager = .default) throws -> Armazenamento {
        let suporte = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return Armazenamento(raiz: suporte.appendingPathComponent(pastaRaiz, isDirectory: true))
    }

    /// Caminho relativo de uma gravação: `Gravacoes/<uuid>`.
    /// É isto que vai para `Arquivo.pastaRelativa`.
    public static func caminhoRelativo(id: UUID) -> String {
        "\(pastaGravacoes)/\(id.uuidString)"
    }

    /// Cria e devolve a pasta absoluta de uma gravação.
    @discardableResult
    public func criarPastaDaGravacao(id: UUID, _ fm: FileManager = .default) throws -> URL {
        let pasta = pastaDaGravacao(id: id)
        try fm.createDirectory(at: pasta, withIntermediateDirectories: true)
        return pasta
    }

    public func pastaDaGravacao(id: UUID) -> URL {
        raiz.appendingPathComponent(Self.caminhoRelativo(id: id), isDirectory: true)
    }

    /// Onde os pesos GGUF ficam: `<raiz>/Models`.
    ///
    /// Dentro do container, e não numa pasta do usuário: sob sandbox o app não
    /// alcança `~/Documents` sem que o usuário escolha a pasta. É também o que
    /// o downloader do Passo 3 preenche.
    public var pastaDeModelos: URL {
        raiz.appendingPathComponent(Self.pastaModelos, isDirectory: true)
    }

    /// Resolve um caminho relativo guardado no modelo para a URL absoluta de agora.
    public func resolver(relativo: String) -> URL {
        raiz.appendingPathComponent(relativo, isDirectory: true)
    }

    /// Remove uma pasta de gravação somente quando o caminho persistido tem o
    /// formato canônico `Gravacoes/<UUID>`. A exclusão definitiva não deve
    /// aceitar uma string arbitrária do banco como alvo no filesystem.
    public func removerGravacao(
        relativa: String,
        _ fm: FileManager = .default
    ) throws {
        let partes = relativa.split(separator: "/", omittingEmptySubsequences: false)
        guard partes.count == 2,
              partes[0] == Substring(Self.pastaGravacoes),
              let id = UUID(uuidString: String(partes[1]))
        else {
            throw ErroArmazenamento.caminhoDeGravacaoInvalido(relativa)
        }

        let pasta = pastaDaGravacao(id: id)
        guard fm.fileExists(atPath: pasta.path) else { return }
        try fm.removeItem(at: pasta)
    }

    /// Nomes canônicos dentro da pasta de uma gravação.
    public enum Nome {
        /// Arquivamento: mixagem dos dois canais, AAC.
        public static let mixagem = "gravacao.m4a"
        /// PCM canônico do microfone — efêmero, insumo do ASR.
        public static let pcmMicrofone = "microfone.pcm"
        /// PCM canônico do áudio do sistema — efêmero, insumo do ASR.
        public static let pcmSistema = "sistema.pcm"
    }
}

public enum ErroArmazenamento: LocalizedError {
    case caminhoDeGravacaoInvalido(String)

    public var errorDescription: String? {
        switch self {
        case let .caminhoDeGravacaoInvalido(caminho):
            "O caminho da gravação não é seguro para excluir: \(caminho)"
        }
    }
}
