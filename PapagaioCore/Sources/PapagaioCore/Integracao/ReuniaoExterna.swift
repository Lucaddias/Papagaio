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
    public let participantes: [String]
    public let notas: String?
    public let resumo: String?
    public let transcricao: [SegmentoDeTranscricaoExterna]?

    public init(
        id: String,
        titulo: String,
        data: Date,
        participantes: [String] = [],
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

    public var temTranscricao: Bool {
        guard let transcricao, !transcricao.isEmpty else { return false }
        return true
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