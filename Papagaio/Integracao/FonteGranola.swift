import Foundation
import PapagaioCore

/// A fonte Granola por trás do protocolo `FonteDeReunioesExternas`.
///
/// Conversa com o servidor MCP do Granola (`https://mcp.granola.ai/mcp`) e
/// traduz as respostas — que chegam como JSON dentro do `content[].text` do
/// transporte — para o formato neutro do Papagaio (`ReuniaoExterna`).
///
/// O formato de cada reunião segue o JSON de exportação do Granola:
/// `title`, `date`, `attendees`, `gpt_summarized_notes` (resumo de IA em
/// markdown), `manual_notes` (anotações privadas) e `transcript` com
/// `segments` (`start`/`end` em segundos, `speaker` por índice) mapeados por
/// um dicionário/lista de `speakers`. O parser é tolerante a chaves variantes,
/// porque o MCP pode renomear campos entre versões.
struct FonteGranola: FonteDeReunioesExternas {
    let identificador = "granola"
    let cliente: ClienteMCP

    func conta() async throws -> ContaExterna {
        let resposta = try await cliente.chamar(ferramenta: "get_account_info", argumentos: [:])
        guard let info = resposta as? [String: Any] else {
            throw FonteGranolaErro.respostaInesperada
        }
        let email = info["email"] as? String
            ?? (info["account"] as? String)
            ?? ""
        let workspace = info["workspace"] as? String
            ?? (info["workspace_title"] as? String)
            ?? (info["active_workspace"] as? String)
        return ContaExterna(email: email, workspace: workspace)
    }

    func listarReunioes() async throws -> [ReuniaoExterna] {
        let resposta = try await cliente.chamar(
            ferramenta: "list_meetings",
            argumentos: ["time_range": "last_30_days"]
        )
        let itens = FonteGranolaDicionario.extrairLista(resposta)
        return try itens.compactMap { item in
            guard let id = item["id"] as? String,
                  let titulo = item["title"] as? String
            else { return nil }
            return ReuniaoExterna(
                id: id,
                titulo: titulo,
                data: FonteGranolaDicionario.data(in: item) ?? Date(),
                participantes: FonteGranolaDicionario.nomesDeParticipantes(in: item),
                notas: item["manual_notes"] as? String,
                resumo: item["gpt_summarized_notes"] as? String
                    ?? item["summary"] as? String
            )
        }
    }

    func obterReuniao(id: String, incluirTranscricao: Bool) async throws -> ReuniaoExterna {
        let resposta = try await cliente.chamar(
            ferramenta: "get_meetings",
            argumentos: ["meeting_ids": [id]]
        )
        let itens = FonteGranolaDicionario.extrairLista(resposta)
        guard let item = itens.first(where: { ($0["id"] as? String) == id }) ?? itens.first else {
            throw FonteGranolaErro.reuniaoNaoEncontrada(id)
        }

        var transcricao: [SegmentoDeTranscricaoExterna]? = nil
        if incluirTranscricao {
            transcricao = try await transcricaoDaReuniao(id: id, contexto: item)
        }

        return ReuniaoExterna(
            id: id,
            titulo: item["title"] as? String ?? "Reunião",
            data: FonteGranolaDicionario.data(in: item) ?? Date(),
            participantes: FonteGranolaDicionario.nomesDeParticipantes(in: item),
            notas: item["manual_notes"] as? String
                ?? item["notes"] as? String,
            resumo: item["gpt_summarized_notes"] as? String
                ?? item["summary"] as? String,
            transcricao: transcricao
        )
    }

    /// Transcrição separada (`get_meeting_transcript`), reservada aos planos
    /// pagos. Sem plano, o tool falha — a reunião entra com notas e resumo.
    private func transcricaoDaReuniao(
        id: String,
        contexto: [String: Any]
    ) async throws -> [SegmentoDeTranscricaoExterna]? {
        let resposta = try await cliente.chamar(
            ferramenta: "get_meeting_transcript",
            argumentos: ["meeting_id": id]
        )
        guard let dados = resposta as? [String: Any] else { return nil }

        let segmentos = (dados["segments"] as? [[String: Any]])
            ?? FonteGranolaDicionario.extrairLista(resposta)
        let nomes = FonteGranolaDicionario.nomesDosFalantes(in: dados, contexto: contexto)
        guard !segmentos.isEmpty else {
            // Sem transcription no plano: `transcricao` fica `nil`.
            return nil
        }

        return segmentos.compactMap { segmento in
            let indice = segmento["speaker"] as? Int
                ?? Int(segmento["speaker"] as? String ?? "")
            let nome = indice.flatMap { nomes[$0] } ?? nomes[indice ?? -1]
            return SegmentoDeTranscricaoExterna(
                falante: nome,
                texto: segmento["text"] as? String ?? "",
                inicio: segmento["start"] as? TimeInterval
                    ?? TimeInterval(segmento["start"] as? Int ?? 0),
                fim: segmento["end"] as? TimeInterval
                    ?? TimeInterval(segmento["end"] as? Int ?? 0)
            )
        }
    }
}

enum FonteGranolaErro: LocalizedError {
    case respostaInesperada
    case reuniaoNaoEncontrada(String)

    var errorDescription: String? {
        switch self {
        case .respostaInesperada:
            "O Granola respondeu algo que o Papagaio não reconheceu."
        case let .reuniaoNaoEncontrada(id):
            "A reunião \(id) não foi encontrada no Granola."
        }
    }
}

/// Acesso tolerante a dicionários vindos do JSON do Granola.
private enum FonteGranolaDicionario {
    /// O payload pode ser um array direto, `{meetings:[...]}` ou
    /// `{result:[...]}` — normaliza tudo para uma lista de dicionários.
    static func extrairLista(_ resposta: Any) -> [[String: Any]] {
        if let lista = resposta as? [[String: Any]] {
            return lista
        }
        guard let obj = resposta as? [String: Any] else { return [] }
        for chave in ["meetings", "results", "result", "data"] {
            if let lista = obj[chave] as? [[String: Any]] {
                return lista
            }
        }
        return [obj]
    }

    static func nomesDosFalantes(in dados: [String: Any], contexto: [String: Any]) -> [Int: String] {
        var nomes: [Int: String] = [:]
        // Lista: índice = id do falante.
        if let lista = dados["speakers"] as? [String] {
            for (indice, nome) in lista.enumerated() {
                nomes[indice] = nome
            }
            return nomes
        }
        // Dicionário: id -> nome (ou objeto com `name`).
        if let dict = dados["speakers"] as? [String: Any] {
            for (chave, valor) in dict {
                if let nome = valor as? String {
                    nomes[Int(chave) ?? -1] = nome
                } else if let objeto = valor as? [String: Any], let nome = objeto["name"] as? String {
                    nomes[Int(chave) ?? -1] = nome
                }
            }
            return nomes
        }
        // Fallback: participantes do contexto da reunião (login antes do nome).
        let participantes = nomesDeParticipantes(in: contexto)
        for (indice, participante) in participantes.enumerated() {
            nomes[indice] = participante
        }
        return nomes
    }

    /// `attendees` (array de strings ou de objetos com `email`) ou
    /// `participants` (idem).
    static func nomesDeParticipantes(in dicionario: [String: Any]) -> [String] {
        for chave in ["attendees", "participants", "people"] {
            guard let lista = dicionario[chave] as? [Any] else { continue }
            let nomes = lista.compactMap { item -> String? in
                if let texto = item as? String { return texto }
                if let objeto = item as? [String: Any] {
                    return objeto["email"] as? String
                        ?? objeto["name"] as? String
                }
                return nil
            }
            if !nomes.isEmpty { return nomes }
        }
        return []
    }

/// `date` ISO-8601 (com ou sem frações de segundo) ou `created_at`.
    static func data(in dicionario: [String: Any]) -> Date? {
        let comFracao = ISO8601DateFormatter()
        comFracao.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let semFracao = ISO8601DateFormatter()
        semFracao.formatOptions = [.withInternetDateTime]
        for chave in ["date", "created_at", "datetime"] {
            guard let texto = dicionario[chave] as? String else { continue }
            if let data = comFracao.date(from: texto) ?? semFracao.date(from: texto) {
                return data
            }
        }
        return nil
    }
}