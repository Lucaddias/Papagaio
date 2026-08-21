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

    /// Fallback fixo para registro legado sem a relação de espaço. Não pode
    /// ser um `UUID()` novo a cada leitura: o mesmo arquivo trocaria de espaço
    /// toda vez que fosse relido do banco.
    public static let legado = EspacoID(
        rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    )
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

    /// Falante atribuído pela **diarização acústica** (ex.: `"S1"`, `"S2"`).
    ///
    /// Não confundir com `Trecho.speaker`, que vem do canal de origem — ver a
    /// regra em `SegmentoDeFalante`. `nil` = sem diarização (transcrição
    /// legada, falante desconhecido no empate técnico, ou modelos ausentes).
    public let falanteAcustico: String?

    public init(
        id: UUID = UUID(),
        start: TimeInterval,
        end: TimeInterval,
        texto: String,
        falanteAcustico: String? = nil
    ) {
        self.id = id
        self.start = start
        self.end = end
        self.texto = texto
        self.falanteAcustico = falanteAcustico
    }
}

// MARK: - Segmento de falante

/// Um intervalo de fala atribuído a um falante pela diarização acústica.
///
/// `falanteId` usa a convenção do FluidAudio (`"S1"`, `"S2"`, …): serve para
/// **comparar** falantes dentro da mesma gravação, não é um rótulo estável.
///
/// Regra dos dois rótulos (skill `papagaio-speaker-attribution`): `Trecho.speaker`
/// continua sendo o canal de origem ("eu"/"interlocutor") e nunca é fundido com
/// o falante acústico — um microfone pode conter duas vozes ("S1"/"S2"), e o
/// mesmo "S1" pode aparecer no microfone e no tap do sistema.
public struct SegmentoDeFalante: Sendable, Equatable {
    public let falanteId: String
    public let inicio: TimeInterval
    public let fim: TimeInterval

    public init(falanteId: String, inicio: TimeInterval, fim: TimeInterval) {
        self.falanteId = falanteId
        self.inicio = inicio
        self.fim = fim
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

    /// Cópia com outras palavras — usada pela diarização para trocar as
    /// palavras do trecho pelas versões com `falanteAcustico`.
    public func comPalavras(_ novas: [Palavra]) -> Trecho {
        Trecho(
            id: id,
            start: start,
            end: end,
            texto: texto,
            speaker: speaker,
            palavras: novas
        )
    }

    /// O rótulo acústico predominante nas palavras do trecho, ou `nil` sem
    /// diarização.
    ///
    /// Derivado, nunca persistido: o fonte da verdade são os
    /// `Palavra.falanteAcustico`. A UI usa isto para nomear o trecho quando o
    /// canal tem mais de um falante.
    public var falanteAcusticoDominante: String? {
        let contagens = palavras.reduce(into: [String: Int]()) { contagens, palavra in
            if let falante = palavra.falanteAcustico {
                contagens[falante, default: 0] += 1
            }
        }
        return contagens.max { $0.value < $1.value }?.key
    }

    /// Se o trecho comprova mais de uma voz acústica — o caso em que a UI
    /// mostra a voz predominante para distinguir os falantes do trecho.
    public var temVozesDistintas: Bool {
        Set(palavras.compactMap(\.falanteAcustico)).count > 1
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
    /// Só em arquivos importados: o momento em que a pessoa trouxe o arquivo
    /// para dentro do app — distinto de `criadoEm`, que numa importação passa
    /// a valer a data real da gravação (lida do próprio arquivo em disco,
    /// quando disponível), e não o instante da importação.
    ///
    /// `nil` numa gravação feita pelo microfone: ali as duas datas são a
    /// mesma coisa, e um segundo campo só repetiria `criadoEm`.
    public var importadoEm: Date?

    /// O critério certo para ordenar "mais recente primeiro" na biblioteca.
    ///
    /// Não é `criadoEm`: numa importação, `criadoEm` passou a valer a data
    /// real da gravação, que pode ser dias ou meses no passado — ordenar por
    /// ela jogava um arquivo recém-importado para o meio da grade, longe de
    /// onde a pessoa acabou de agir. Esta é a data do **gesto** (gravar ou
    /// importar), que é o que "recente" quer dizer numa lista de atividade.
    public var entradaNaBiblioteca: Date { importadoEm ?? criadoEm }

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
        apagadoEm: Date? = nil,
        importadoEm: Date? = nil
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
        self.importadoEm = importadoEm
    }
}
