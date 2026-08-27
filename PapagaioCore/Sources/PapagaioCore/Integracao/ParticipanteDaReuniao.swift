import Foundation

/// Participante de uma reunião externa com nome e email separados.
///
/// O Google Calendar entrega `attendees[].email` (obrigatório) e `displayName`
/// (opcional); o Granola entrega `name`/`email` misturados. Manter os dois
/// permite preencher `Equipe`/`Externos` com nome+email e ainda classificar
/// por email da equipe ativa.
public struct ParticipanteDaReuniao: Sendable, Hashable, Equatable, Codable {
    public var nome: String?
    public var email: String?
    public var isSelf: Bool
    public var isOrganizer: Bool
    public var responseStatus: String?

    public init(
        nome: String? = nil,
        email: String? = nil,
        isSelf: Bool = false,
        isOrganizer: Bool = false,
        responseStatus: String? = nil
    ) {
        self.nome = nome?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.email = email?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.isSelf = isSelf
        self.isOrganizer = isOrganizer
        self.responseStatus = responseStatus
    }

    /// Cria a partir de string legada ("email" ou "nome").
    public init(legado string: String) {
        let t = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.contains("@") {
            self.init(nome: nil, email: t)
        } else {
            self.init(nome: t, email: nil)
        }
    }

    /// Melhor exibição: nome quando existe, senão email.
    public var displayNome: String {
        if let n = nome, !n.isEmpty { return n }
        if let e = email, !e.isEmpty { return e }
        return ""
    }

    /// Email normalizado para comparação (lowercased, trim).
    public var emailNormalizado: String? {
        email?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Nome normalizado para cache.
    public var nomeNormalizado: String? {
        nome?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

extension ParticipanteDaReuniao {
    /// Filtra vazios (sem nome e sem email).
    public var isEmpty: Bool { nome == nil && email == nil }
}
