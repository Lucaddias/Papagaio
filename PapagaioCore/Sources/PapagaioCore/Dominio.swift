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

// MARK: - Palavra

/// Uma palavra da transcrição com âncora de tempo **própria**.
///
/// `start`/`end` vêm do `token_timestamps` do Whisper — nunca são uma divisão
/// do tempo do trecho — e são medidos em segundos desde o início do áudio,
/// como `Trecho.start`.
public struct Palavra: Sendable, Identifiable, Codable, Equatable {
    public let id: UUID
    public let start: TimeInterval
    public let end: TimeInterval
    public let texto: String

    public init(
        id: UUID = UUID(),
        start: TimeInterval,
        end: TimeInterval,
        texto: String
    ) {
        self.id = id
        self.start = start
        self.end = end
        self.texto = texto
    }
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

    /// Palavras com timestamps próprios do Whisper, na ordem da fala.
    ///
    /// Vazio para transcrições legadas — a interface volta ao `Text` inteiro.
    public let palavras: [Palavra]

    public init(
        id: UUID = UUID(),
        start: TimeInterval,
        end: TimeInterval,
        texto: String,
        speaker: String? = nil,
        palavras: [Palavra] = []
    ) {
        self.id = id
        self.start = start
        self.end = end
        self.texto = texto
        self.speaker = speaker
        self.palavras = palavras
    }

    public var duracao: TimeInterval { end - start }

    /// Cópia com o texto corrigido à mão.
    ///
    /// `palavras` é zerado de propósito: os timestamps por palavra vêm do
    /// Whisper e deixam de corresponder ao texto assim que alguém edita. Sem
    /// palavras, a interface volta ao destaque por trecho inteiro — que é o
    /// mesmo caminho das transcrições legadas. Manter timestamps velhos
    /// destacaria a palavra errada, e errado é pior que grosso.
    public func comTextoEditado(_ novoTexto: String) -> Trecho {
        Trecho(
            id: id,
            start: start,
            end: end,
            texto: novoTexto,
            speaker: speaker,
            palavras: []
        )
    }
}

/// Os dois únicos valores válidos de `Trecho.speaker`.
///
/// O contrato mantém `speaker` como `String?` (é o que o prompt mestre define);
/// isto existe para evitar literais divergentes espalhados pelo código.
public enum Speaker {
    public static let eu = "eu"
    public static let interlocutor = "interlocutor"
}

// MARK: - Notas da conversa

/// O tipo visual de uma anotação feita durante a gravação.
///
/// O marcador registra um instante importante mesmo quando não há texto; a
/// criticidade é uma propriedade separada de `NotaDaConversa`, pois tanto uma
/// nota quanto um marcador podem ser críticos.
public enum TipoDeNotaDaConversa: String, Sendable, Codable, CaseIterable {
    case nota
    case marcador
}

/// Uma anotação criada enquanto a conversa ainda está sendo gravada.
///
/// `start` é medido em segundos a partir do início do áudio e pode ser
/// ajustado para a duração final real quando a sessão é encerrada. Não é uma
/// posição textual da transcrição: deve continuar apontando para o áudio mesmo
/// antes de a transcrição terminar.
public struct NotaDaConversa: Sendable, Identifiable, Codable, Equatable {
    public let id: UUID
    public var texto: String
    public var start: TimeInterval
    public var critica: Bool
    public var tipo: TipoDeNotaDaConversa

    public init(
        id: UUID = UUID(),
        texto: String,
        start: TimeInterval,
        critica: Bool = false,
        tipo: TipoDeNotaDaConversa = .nota
    ) {
        self.id = id
        self.texto = texto
        self.start = start
        self.critica = critica
        self.tipo = tipo
    }
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
    /// Anotações e marcadores criados durante a gravação, ancorados no áudio.
    public var notas: [NotaDaConversa]
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
        notas: [NotaDaConversa] = [],
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
        self.notas = notas
        self.resumo = resumo
        self.engineTranscricao = engineTranscricao
        self.engineResumo = engineResumo
        self.apagadoEm = apagadoEm
    }
}
