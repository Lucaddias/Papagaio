import Foundation
import SwiftData

// Entidades de persistência. **Não são os tipos de domínio** — `Arquivo` e
// `Trecho` de `Dominio.swift` são structs `Sendable`, e é isso que atravessa
// `ArquivoRepository` (D-1.2). Aqui vivem as classes `@Model`, que são de
// referência e não são `Sendable`.
//
// A modelagem já respeita as restrições do CloudKit, mesmo com
// `cloudKitDatabase: .none` hoje: **tudo opcional ou com default**, nenhum
// `@Attribute(.unique)`, relações opcionais com `inverse`. Migrar schema depois
// que já há dado sincronizado é o pior lugar possível para estar (D-0.3).

@Model
public final class EspacoPersistido {
    public var id: UUID = UUID()
    public var nome: String = ""
    public var criadoEm: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \ArquivoPersistido.espaco)
    public var arquivos: [ArquivoPersistido]? = []

    public init(id: UUID = UUID(), nome: String = "") {
        self.id = id
        self.nome = nome
    }
}

@Model
public final class ArquivoPersistido {
    public var id: UUID = UUID()
    public var titulo: String = ""
    public var criadoEm: Date = Date()
    public var duracao: TimeInterval = 0

    /// **Caminho relativo ao container.** Nunca absoluto: o UUID do container
    /// muda entre instalações, e um caminho absoluto salvo hoje aponta para o
    /// nada amanhã.
    public var pastaRelativa: String = ""

    public var engineTranscricao: String?
    public var engineResumo: String?

    /// Título e visão geral do resumo. O resto do `Resumo` vira `InsightPersistido`.
    ///
    /// **Não opcionais, com default.** Um `String?` obrigaria o predicado de
    /// busca a usar `?? ""`, que o CoreData traduz para um `TERNARY` e recusa
    /// com "unimplemented SQL generation for predicate". Ter default também é o
    /// que o CloudKit exige (D-0.3). `temResumo` distingue "sem resumo" de
    /// "resumo vazio".
    public var temResumo: Bool = false
    public var resumoTitulo: String = ""
    public var resumoVisaoGeral: String = ""

    public var espaco: EspacoPersistido?

    @Relationship(deleteRule: .cascade, inverse: \TrechoPersistido.arquivo)
    public var trechos: [TrechoPersistido]? = []

    @Relationship(deleteRule: .cascade, inverse: \InsightPersistido.arquivo)
    public var insights: [InsightPersistido]? = []

    public init(id: UUID = UUID()) {
        self.id = id
    }
}

@Model
public final class TrechoPersistido {
    public var id: UUID = UUID()
    public var start: TimeInterval = 0
    public var fim: TimeInterval = 0
    public var texto: String = ""
    /// `"eu"` | `"interlocutor"` | `nil` — vem do canal de origem.
    public var speaker: String?

    public var arquivo: ArquivoPersistido?

    public init(id: UUID = UUID()) {
        self.id = id
    }
}

/// Um item acionável do resumo: tema, citação ou próximo passo.
///
/// O prompt mestre lista `Insight` como entidade própria. Modelar assim (em vez
/// de guardar o `Resumo` como um blob JSON) é o que permite a busca do Passo 9
/// encontrar um próximo passo pelo texto dele.
@Model
public final class InsightPersistido {
    public var id: UUID = UUID()
    /// `tema` | `citacao` | `proximoPasso`
    public var tipo: String = ""
    public var texto: String = ""
    public var detalhe: String?
    /// Âncora de tempo, quando houver — o player do Passo 10 salta para cá.
    public var start: TimeInterval?
    public var speaker: String?
    public var ordem: Int = 0

    public var arquivo: ArquivoPersistido?

    public init(id: UUID = UUID()) {
        self.id = id
    }
}

public enum TipoDeInsight {
    public static let tema = "tema"
    public static let citacao = "citacao"
    public static let proximoPasso = "proximoPasso"
}
