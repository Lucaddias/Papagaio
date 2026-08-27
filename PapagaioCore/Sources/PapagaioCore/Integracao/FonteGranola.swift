import Foundation

/// Mapeia as respostas JSON do MCP oficial do Granola (`https://mcp.granola.ai/mcp`)
/// para os modelos de domínio do Papagaio.
///
/// O Granola não publica o schema JSON das respostas MCP (só a lista de tools);
/// o mapeador é tolerante de propósito: tenta as chaves conhecidas em ordem,
/// e em vez de quebrar em campo opcional, deixa `nil`. O que não pode faltar
/// (o id) falha com `ErroMCP.respostaInvalida` e mensagem clara.
///
/// Nomes de campos usados:
/// - `meeting_id`, `meeting_title`, `meeting_date`, `attendees`/`participants`
/// - notas privadas e resumo vêm em `get_meetings` (chaves variam por versão —
///   o mapeador testa candidatas)
/// - transcrição: `speaker.{name,attribution}`, `text`, `start_time`, `end_time`
///   (ISO 8601 absoluto — convertido para segundos relativos à reunião).
struct MapeadorGranola {
    // MARK: - get_account_info

    func conta(de resposta: ValorJSON) throws -> ContaExterna {
        let mapa = try objeto(resposta, contexto: "get_account_info")
        guard let email = mapa.texto("email") else {
            throw ErroMCP.respostaInvalida("get_account_info sem email")
        }
        return ContaExterna(
            email: email,
            workspace: mapa.texto("workspace") ?? mapa.texto("workspace_name")
        )
    }

    // MARK: - list_meetings

    func lista(de resposta: ValorJSON) throws -> [ReuniaoExterna] {
        let mapa = try objeto(resposta, contexto: "list_meetings")
        let itens: [ValorJSON]
        if case .lista(let lista)? = mapa["meetings"] {
            itens = lista
        } else if case .lista(let lista)? = mapa["meeting"] {
            itens = lista
        } else {
            itens = []
        }
        return try itens.map { item in
            let m = try objeto(item, contexto: "list_meetings.meetings[]")
            guard let id = m.texto("meeting_id") else {
                throw ErroMCP.respostaInvalida("reunião do Granola sem meeting_id")
            }
            return ReuniaoExterna(
                id: id,
                titulo: m.texto("meeting_title") ?? "Sem título",
                data: MapeadorGranola.data(de: m["meeting_date"] ?? m["created_at"]) ?? .distantPast,
                participantes: MapeadorGranola.participantes(de: m)
            )
        }
    }

    // MARK: - get_meetings

    func reuniao(id: String, da resposta: ValorJSON) throws -> ReuniaoExterna {
        let mapa = try objeto(resposta, contexto: "get_meetings")
        let item: ValorJSON
        if case .lista(let lista)? = mapa["meetings"] {
            guard let procurado = lista.first(where: { item in
                guard case .objeto(let m) = item, let idEncontrado = m.texto("meeting_id") else {
                    return false
                }
                return idEncontrado == id
            }) else {
                throw ErroMCP.respostaInvalida("get_meetings não devolveu a reunião \(id)")
            }
            item = procurado
        } else if let singular = mapa["meeting"] {
            item = singular
        } else if let nota = mapa["note"] {
            item = nota
        } else {
            throw ErroMCP.respostaInvalida("get_meetings sem meeting")
        }
        let m = try objeto(item, contexto: "get_meetings.meeting")
        guard let idEncontrado = m.texto("meeting_id") else {
            throw ErroMCP.respostaInvalida("get_meetings sem meeting_id")
        }
        return ReuniaoExterna(
            id: idEncontrado,
            titulo: m.texto("meeting_title") ?? "Sem título",
            data: MapeadorGranola.data(de: m["meeting_date"] ?? m["created_at"]) ?? .distantPast,
            participantes: MapeadorGranola.participantes(de: m),
            notas: conteudo(de: m, candidatas: ["notes_markdown", "notes_text", "private_notes", "note_content", "notes", "content"]),
            resumo: conteudo(de: m, candidatas: ["summary_markdown", "summary_text", "summarized_notes", "summary_notes", "summary"])
        )
    }

    // MARK: - get_meeting_transcript

    func transcricao(da resposta: ValorJSON, dataDaReuniao: Date?) throws -> [SegmentoDeTranscricaoExterna] {
        let mapa = try objeto(resposta, contexto: "get_meeting_transcript")
        let itens: [ValorJSON]
        if case .lista(let lista)? = mapa["transcript"] {
            itens = lista
        } else if case .lista(let lista)? = mapa["transcript_segments"] {
            itens = lista
        } else {
            itens = []
        }
        return try itens.map { item in
            let m = try objeto(item, contexto: "get_meeting_transcript[].segmento")
            guard let texto = m.texto("text") else {
                throw ErroMCP.respostaInvalida("segmento de transcrição sem text")
            }
            let rotuloDoFalante = m["speaker"].flatMap { falante(de: $0) }
            return SegmentoDeTranscricaoExterna(
                falante: rotuloDoFalante,
                texto: texto,
                inicio: MapeadorGranola.momento(de: m["start_time"], relativoA: dataDaReuniao),
                fim: MapeadorGranola.momento(de: m["end_time"], relativoA: dataDaReuniao)
            )
        }
    }

    // MARK: - Apoio

    private func conteudo(de mapa: [String: ValorJSON], candidatas: [String]) -> String? {
        for chave in candidatas {
            if let texto = mapa.texto(chave), !texto.isEmpty {
                return texto
            }
            // Algumas versões aninham o texto em { "text": … } / { "markdown": … }.
            if case .objeto(let aninhado)? = mapa[chave],
               let texto = aninhado.texto("text") ?? aninhado.texto("markdown") {
                return texto
            }
        }
        return nil
    }

    private func falante(de resposta: ValorJSON) -> String? {
        switch resposta {
        case .texto(let nome):
            return nome
        case .objeto(let mapa):
            if let nome = mapa.texto("name") { return nome }
            if let rotulo = mapa.texto("attribution") {
                // O Granola marca `me`/`them`; o Papagaio mostra o rótulo como veio.
                return rotulo
            }
            return mapa.texto("diarization_label")
        default:
            return nil
        }
    }

    private func objeto(_ resposta: ValorJSON, contexto: String) throws -> [String: ValorJSON] {
        guard case .objeto(let mapa) = resposta else {
            throw ErroMCP.respostaInvalida("\(contexto) fora de objeto JSON")
        }
        return mapa
    }

    static func participantes(de mapa: [String: ValorJSON]) -> [ParticipanteDaReuniao] {
        var lista: [ParticipanteDaReuniao] = []
        for chave in ["attendees", "participants"] {
            guard case .lista(let itens)? = mapa[chave] else { continue }
            for item in itens {
                switch item {
                case .texto(let nome):
                    let t = nome.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !t.isEmpty else { continue }
                    lista.append(ParticipanteDaReuniao(legado: t))
                case .objeto(let m):
                    let nome = m.texto("name")?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let email = m.texto("email")?.trimmingCharacters(in: .whitespacesAndNewlines)
                    if (nome == nil || nome?.isEmpty == true) && (email == nil || email?.isEmpty == true) { continue }
                    lista.append(ParticipanteDaReuniao(nome: nome, email: email))
                default:
                    continue
                }
            }
        }
        return lista
    }

    /// Data da reunião — ISO 8601 ou `yyyy-MM-dd`, com e sem fração de segundo.
    static func data(de resposta: ValorJSON?) -> Date? {
        guard case .texto(let texto)? = resposta, !texto.isEmpty else { return nil }
        let isoComFra = ISO8601DateFormatter()
        isoComFra.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let data = isoComFra.date(from: texto) { return data }
        isoComFra.formatOptions = [.withInternetDateTime]
        if let data = isoComFra.date(from: texto) { return data }
        let soData = DateFormatter()
        soData.locale = Locale(identifier: "en_US_POSIX")
        soData.timeZone = TimeZone(identifier: "UTC")
        soData.dateFormat = "yyyy-MM-dd"
        return soData.date(from: texto)
    }

    /// Momento do segmento: ISO 8601 absoluto ou segundos numericos —
    /// devolvido como segundos relativos ao início da reunião (nil quando
    /// não há como posicionar).
    static func momento(de resposta: ValorJSON?, relativoA dataDaReuniao: Date?) -> TimeInterval? {
        if case .numero(let segundos)? = resposta {
            return segundos
        }
        guard case .texto(let textoBruto)? = resposta,
              let instante = data(de: .texto(textoBruto)),
              let dataDaReuniao
        else { return nil }
        return instante.timeIntervalSince(dataDaReuniao)
    }
}

/// A fonte Granola por trás de `FonteDeReunioesExternas`.
///
/// Conecta no MCP oficial (`https://mcp.granola.ai/mcp`) com OAuth 2.0
/// (authorization code + PKCE + DCR) e fala as tools `get_account_info`,
/// `list_meetings`, `get_meetings` e `get_meeting_transcript`.
///
/// Nota de plano: transcrições só existem em planos pagos; no plano Basic,
/// `get_meeting_transcript` falha com erro do servidor — e o Papagaio
/// mostra a reunião sem transcrição.
public actor FonteGranola: FonteDeReunioesExternas {
    public nonisolated let identificador = "granola"

    private let cliente: ClienteMCP
    private let mapeador = MapeadorGranola()

    public init(cliente: ClienteMCP) {
        self.cliente = cliente
    }

    public func conta() async throws -> ContaExterna {
        let resposta = try await cliente.chamar(metodo: "get_account_info")
        return try mapeador.conta(de: resposta)
    }

    public func listarReunioes() async throws -> [ReuniaoExterna] {
        let resposta = try await cliente.chamar(metodo: "list_meetings")
        let reunioes = try mapeador.lista(de: resposta)
        return reunioes.sorted { $0.data > $1.data }
    }

    public func obterReuniao(id: String, incluirTranscricao: Bool) async throws -> ReuniaoExterna {
        let detalhe = try await cliente.chamar(
            metodo: "get_meetings",
            parametros: ["meeting_ids": .lista([.texto(id)])]
        )
        var reuniao = try mapeador.reuniao(id: id, da: detalhe)

        if incluirTranscricao {
            do {
                let bruto = try await cliente.chamar(
                    metodo: "get_meeting_transcript",
                    parametros: ["meeting_id": .texto(id)]
                )
                reuniao = ReuniaoExterna(
                    id: reuniao.id,
                    titulo: reuniao.titulo,
                    data: reuniao.data,
                    participantes: reuniao.participantes,
                    notas: reuniao.notas,
                    resumo: reuniao.resumo,
                    transcricao: try mapeador.transcricao(
                        da: bruto,
                        dataDaReuniao: reuniao.data == .distantPast ? nil : reuniao.data
                    )
                )
            } catch {
                // Plano sem transcrição ou transcript temporariamente
                // indisponível: a reunião continua útil sem ela.
            }
        }
        return reuniao
    }
}