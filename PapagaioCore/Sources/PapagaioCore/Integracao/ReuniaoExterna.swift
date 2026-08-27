import Foundation

/// Conta conectada a uma fonte externa de reuniões — o que o
/// `get_account_info` de cada fonte responde.
public struct ContaExterna: Sendable, Equatable {
    public let email: String
    public let workspace: String?

    public init(email: String, workspace: String? = nil) {
        self.email = email
        self.workspace = workspace
    }
}

/// Um trecho da transcrição de uma reunião externa, com o falante quando a
/// fonte entrega (Granola rotula por nome em transcrições pagas).
///
/// `inicio`/`fim` são segundos — as fontes entregam em escala de segmento,
/// nunca palavra a palavra; por isso o Papagaio guarda cada segmento como um
/// trecho inteiro, sem `palavras` (sem áudio não há destaque por palavra).
public struct SegmentoDeTranscricaoExterna: Sendable, Equatable {
    public let falante: String?
    public let texto: String
    public let inicio: TimeInterval?
    public let fim: TimeInterval?

    public init(falante: String?, texto: String, inicio: TimeInterval?, fim: TimeInterval?) {
        self.falante = falante
        self.texto = texto
        self.inicio = inicio
        self.fim = fim
    }
}

/// Uma reunião vinda de uma fonte externa (Granola hoje; Fireflies, Otter,
/// Zoom amanhã), no formato neutro de domínio do Papagaio.
///
/// `notas` = anotações manuscritas do usuário; `resumo` = a síntese de IA da
/// fonte; `transcricao` = `nil` quando o plano da conta não expõe transcrição.
public struct ReuniaoExterna: Sendable, Identifiable, Equatable {
    public let id: String
    public let titulo: String
    public let data: Date
    public let participantes: [ParticipanteDaReuniao]
    public let notas: String?
    public let resumo: String?
    public let transcricao: [SegmentoDeTranscricaoExterna]?

    public init(
        id: String,
        titulo: String,
        data: Date,
        participantes: [ParticipanteDaReuniao] = [],
        notas: String? = nil,
        resumo: String? = nil,
        transcricao: [SegmentoDeTranscricaoExterna]? = nil
    ) {
        self.id = id
        self.titulo = titulo
        self.data = data
        self.participantes = participantes
        self.notas = notas
        self.resumo = resumo
        self.transcricao = transcricao
    }

    /// Compat: inicializa a partir de strings legadas (email ou nome).
    public init(
        id: String,
        titulo: String,
        data: Date,
        participantesLegado: [String],
        notas: String? = nil,
        resumo: String? = nil,
        transcricao: [SegmentoDeTranscricaoExterna]? = nil
    ) {
        self.init(
            id: id,
            titulo: titulo,
            data: data,
            participantes: participantesLegado.map { ParticipanteDaReuniao(legado: $0) },
            notas: notas,
            resumo: resumo,
            transcricao: transcricao
        )
    }

    /// Nomes para exibição legada (nome ?? email).
    public var participantesNomes: [String] {
        participantes.map(\.displayNome).filter { !$0.isEmpty }
    }

    public var temTranscricao: Bool {
        guard let transcricao, !transcricao.isEmpty else { return false }
        return true
    }

    // MARK: - Parsing helpers for Google Calendar integration

    /// Parse ISO8601 date-time string with optional fractional seconds
    public static func parseDateTime(_ string: String) -> Date? {
        let formatador = ISO8601DateFormatter()
        formatador.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let data = formatador.date(from: string) { return data }
        let formatadorSemFracao = ISO8601DateFormatter()
        formatadorSemFracao.formatOptions = [.withInternetDateTime]
        return formatadorSemFracao.date(from: string)
    }

    /// Parse date-only string (yyyy-MM-dd)
public static func parseDate(_ string: String) -> Date? {
        let formatador = DateFormatter()
        formatador.locale = Locale(identifier: "en_US_POSIX")
        formatador.dateFormat = "yyyy-MM-dd"
        formatador.timeZone = TimeZone(secondsFromGMT: 0)
        return formatador.date(from: string)
    }

    /// Creates a ReuniaoExterna from a Google Calendar event dictionary
    public static func fromGoogleEvent(_ evento: [String: Any]) -> ReuniaoExterna? {
        guard let id = evento["id"] as? String,
              !id.isEmpty
        else { return nil }

        let titulo = (evento["summary"] as? String) ?? "Evento sem título"

        let inicio: Date
        if let startDateTime = evento["start"] as? [String: Any],
           let dateTimeStr = startDateTime["dateTime"] as? String {
            inicio = Self.parseDateTime(dateTimeStr) ?? Date()
        } else if let startDate = evento["start"] as? [String: Any],
                  let dateStr = startDate["date"] as? String {
            inicio = Self.parseDate(dateStr) ?? Date()
        } else {
            inicio = Date()
        }

        let participantes: [ParticipanteDaReuniao]
        if let attendees = evento["attendees"] as? [[String: Any]] {
            participantes = attendees.compactMap { a -> ParticipanteDaReuniao? in
                let email = (a["email"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let nome = (a["displayName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let isSelf = (a["self"] as? Bool) ?? false
                let isOrganizer = (a["organizer"] as? Bool) ?? false
                let status = a["responseStatus"] as? String
                if (email == nil || email?.isEmpty == true) && (nome == nil || nome?.isEmpty == true) { return nil }
                return ParticipanteDaReuniao(nome: nome, email: email, isSelf: isSelf, isOrganizer: isOrganizer, responseStatus: status)
            }
        } else {
            participantes = []
        }

        let notas = evento["description"] as? String

        return ReuniaoExterna(
            id: id,
            titulo: titulo,
            data: inicio,
            participantes: participantes,
            notas: notas,
            resumo: nil,
            transcricao: nil
        )
    }
}

/// Contrato de uma fonte de reuniões externas.
///
/// O app conhece só isto — a autenticação, o transporte e o formato de cada
/// fonte ficam atrás do protocolo. Adicionar uma fonte nova (Fireflies,
/// Otter, Zoom…) é implementar este contrato mais uma vez.
public protocol FonteDeReunioesExternas: Sendable {
    /// Identificador estável usado em `Arquivo.idExterno` (ex.: `granola`).
    var identificador: String { get }
    /// A conta conectada — email e workspace ativo. Lança quando a
    /// autenticação não existe mais (a UI usa isto para re-autenticar).
    func conta() async throws -> ContaExterna
    /// Lista as reuniões acessíveis, ordenadas da mais nova para a mais
    /// antiga, só com metadados (id, título, data, participantes).
    func listarReunioes() async throws -> [ReuniaoExterna]
    /// Detalha uma reunião: notas, resumo e — quando pedido e o plano
    /// permitir — transcrição com falantes.
    func obterReuniao(id: String, incluirTranscricao: Bool) async throws -> ReuniaoExterna
}