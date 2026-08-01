import Foundation

// MARK: - Identificadores

public struct ArquivoID: Hashable, Sendable, Codable, RawRepresentable {
    public let rawValue: UUID
    public init(rawValue: UUID) { self.rawValue = rawValue }
    public init() { self.rawValue = UUID() }
}

public struct EspacoID: Hashable, Sendable, Codable, RawRepresentable {
    public let rawValue: UUID
    public init(rawValue: UUID) { self.rawValue = rawValue }
    public init() { self.rawValue = UUID() }
}

// MARK: - Trecho

/// Unidade navegável da transcrição. `start` é a chave da navegação do player
/// (Passo 10) — não é índice, é tempo em segundos desde o início do áudio.
///
/// Contrato definido no Passo 1 do prompt mestre. Não altere sem justificar.
public struct Trecho: Sendable, Identifiable, Codable, Equatable {
    public let id: UUID
    public let start: TimeInterval
    public let end: TimeInterval
    public let texto: String

    /// `"eu"` | `"interlocutor"` | `nil`.
    ///
    /// Vem do **canal de origem** da captura (microfone vs. tap do sistema),
    /// não de um modelo de diarização — ver skill `papagaio-speaker-attribution`.
    /// Use as constantes de `Speaker` em vez de literais soltos.
    public let speaker: String?

    public init(
        id: UUID = UUID(),
        start: TimeInterval,
        end: TimeInterval,
        texto: String,
        speaker: String? = nil
    ) {
        self.id = id
        self.start = start
        self.end = end
        self.texto = texto
        self.speaker = speaker
    }

    public var duracao: TimeInterval { end - start }
}

/// Os dois únicos valores válidos de `Trecho.speaker`.
///
/// O contrato mantém `speaker` como `String?` (é o que o prompt mestre define);
/// isto existe para evitar literais divergentes espalhados pelo código.
public enum Speaker {
    public static let eu = "eu"
    public static let interlocutor = "interlocutor"
}

// MARK: - Resumo

/// Saída estruturada da sumarização. O formato é forçado na decodificação por
/// gramática GBNF + JSON schema no Passo 7 — ver skill `papagaio-summarization`.
public struct Resumo: Sendable, Codable, Equatable {
    public let titulo: String
    public let visaoGeral: String
    public let temas: [Tema]
    public let citacoes: [Citacao]
    public let proximosPassos: [ProximoPasso]

    public init(
        titulo: String,
        visaoGeral: String,
        temas: [Tema] = [],
        citacoes: [Citacao] = [],
        proximosPassos: [ProximoPasso] = []
    ) {
        self.titulo = titulo
        self.visaoGeral = visaoGeral
        self.temas = temas
        self.citacoes = citacoes
        self.proximosPassos = proximosPassos
    }
}

public struct Tema: Sendable, Codable, Equatable {
    public let titulo: String
    public let detalhe: String
    public init(titulo: String, detalhe: String) {
        self.titulo = titulo
        self.detalhe = detalhe
    }
}

public struct Citacao: Sendable, Codable, Equatable {
    public let texto: String
    public let speaker: String?
    /// Âncora de tempo para o player saltar até a origem da citação.
    public let start: TimeInterval?
    public init(texto: String, speaker: String? = nil, start: TimeInterval? = nil) {
        self.texto = texto
        self.speaker = speaker
        self.start = start
    }
}

public struct ProximoPasso: Sendable, Codable, Equatable {
    public let descricao: String
    public let responsavel: String?
    public init(descricao: String, responsavel: String? = nil) {
        self.descricao = descricao
        self.responsavel = responsavel
    }
}

// MARK: - Arquivo

/// Uma gravação com sua transcrição e seu resumo.
///
/// É um **struct de domínio**, não a entidade de persistência. O `@Model` do
/// SwiftData entra no Passo 8 como detalhe do `SwiftDataRepository` e é mapeado
/// para cá — ver D-1.2 em `DECISIONS.md`. Um `@Model` é classe e não é
/// `Sendable`; se ele atravessasse o protocolo, `ArquivoRepository: Sendable`
/// seria mentira.
public struct Arquivo: Sendable, Identifiable, Equatable {
    public let id: ArquivoID
    public var titulo: String
    public var criadoEm: Date
    public var duracao: TimeInterval
    /// Caminho **relativo** ao container do app. Nunca absoluto — ver Passo 8.
    public var pastaRelativa: String
    public var espaco: EspacoID
    public var trechos: [Trecho]
    public var resumo: Resumo?
    /// Identificadores das engines que produziram este arquivo, para os
    /// metadados exigidos nos Passos 4 e 7.
    public var engineTranscricao: String?
    public var engineResumo: String?
    /// `nil` enquanto aparece em Todos os arquivos. Quando preenchido, o
    /// registro está na lixeira: seus dados e áudio ainda existem e podem ser
    /// restaurados antes da exclusão definitiva.
    public var apagadoEm: Date?

    public init(
        id: ArquivoID = ArquivoID(),
        titulo: String,
        criadoEm: Date = Date(),
        duracao: TimeInterval = 0,
        pastaRelativa: String,
        espaco: EspacoID,
        trechos: [Trecho] = [],
        resumo: Resumo? = nil,
        engineTranscricao: String? = nil,
        engineResumo: String? = nil,
        apagadoEm: Date? = nil
    ) {
        self.id = id
        self.titulo = titulo
        self.criadoEm = criadoEm
        self.duracao = duracao
        self.pastaRelativa = pastaRelativa
        self.espaco = espaco
        self.trechos = trechos
        self.resumo = resumo
        self.engineTranscricao = engineTranscricao
        self.engineResumo = engineResumo
        self.apagadoEm = apagadoEm
    }
}
