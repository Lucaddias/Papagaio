import Foundation
import os
import PapagaioCore

struct FonteGoogleCalendarAPI: FonteDeReunioesExternas {
    let identificador = "google-calendar-api"
    private let obterToken: @Sendable (Bool) async throws -> String

    private let baseURL = URL(string: "https://www.googleapis.com/calendar/v3")!
    private let registro = Logger(subsystem: "Papagaio", category: "GoogleCalendar")

    init(obterToken: @escaping @Sendable (Bool) async throws -> String) {
        self.obterToken = obterToken
    }

    func conta() async throws -> ContaExterna {
        let token = try await obterToken(false)
        var pedido = URLRequest(url: URL(string: "https://www.googleapis.com/oauth2/v3/userinfo")!)
        pedido.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        pedido.timeoutInterval = 15

        let (dados, resposta) = try await URLSession.shared.data(for: pedido)
        guard let http = resposta as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw FonteGoogleCalendarErro.respostaInesperada
        }
        guard let json = try JSONSerialization.jsonObject(with: dados) as? [String: Any],
              let email = json["email"] as? String
        else {
            throw FonteGoogleCalendarErro.respostaInesperada
        }
        return ContaExterna(email: email, workspace: nil)
    }

    func listarReunioes() async throws -> [ReuniaoExterna] {
        let token = try await obterToken(false)

        let agora = Date()
        let fim = Calendar.current.date(byAdding: .day, value: 90, to: agora) ?? agora

        let formatador = ISO8601DateFormatter()
        formatador.formatOptions = [.withInternetDateTime]
        let timeMin = formatador.string(from: agora)
        let timeMax = formatador.string(from: fim)

        var componentes = URLComponents(url: baseURL.appendingPathComponent("calendars/primary/events"), resolvingAgainstBaseURL: false)!
        componentes.queryItems = [
            URLQueryItem(name: "timeMin", value: timeMin),
            URLQueryItem(name: "timeMax", value: timeMax),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime"),
            URLQueryItem(name: "maxResults", value: "250"),
            URLQueryItem(name: "showDeleted", value: "false"),
        ]

        var pedido = URLRequest(url: componentes.url!)
        pedido.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        pedido.timeoutInterval = 15

        let (dados, resposta) = try await URLSession.shared.data(for: pedido)
        guard let http = resposta as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw FonteGoogleCalendarErro.respostaInesperada
        }
        guard let json = try JSONSerialization.jsonObject(with: dados) as? [String: Any],
              let itens = json["items"] as? [[String: Any]]
        else {
            return []
        }

        let reunioes = itens
            .filter { evento in
                // Só reuniões reais: eventType == "default" E attendees não vazio
                let tipo = evento["eventType"] as? String ?? "default"
                let attendees = evento["attendees"] as? [[String: Any]]
                return tipo == "default" && (attendees?.isEmpty == false)
            }
            .compactMap { ReuniaoExterna(fromGoogleEvent: $0) }
        registro.info("\(reunioes.count) reuniões futuras (com participantes) carregadas do Google Calendar")
        return reunioes
    }

    func obterReuniao(id: String, incluirTranscricao: Bool) async throws -> ReuniaoExterna {
        let token = try await obterToken(false)

        var pedido = URLRequest(url: baseURL.appendingPathComponent("calendars/primary/events/\(id)"))
        pedido.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        pedido.timeoutInterval = 15

        let (dados, resposta) = try await URLSession.shared.data(for: pedido)
        guard let http = resposta as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            if (resposta as? HTTPURLResponse)?.statusCode == 404 {
                throw FonteGoogleCalendarErro.reuniaoNaoEncontrada(id)
            }
            throw FonteGoogleCalendarErro.respostaInesperada
        }
        guard let json = try JSONSerialization.jsonObject(with: dados) as? [String: Any],
              let reuniao = ReuniaoExterna(fromGoogleEvent: json)
        else {
            throw FonteGoogleCalendarErro.respostaInesperada
        }
        return reuniao
    }
}

enum FonteGoogleCalendarErro: LocalizedError {
    case semToken
    case respostaInesperada
    case reuniaoNaoEncontrada(String)

    var errorDescription: String? {
        switch self {
        case .semToken:
            return "Não foi possível obter token de acesso."
        case .respostaInesperada:
            return "O Google Calendar respondeu algo inesperado."
        case let .reuniaoNaoEncontrada(id):
            return "A reunião \(id) não foi encontrada no Google Calendar."
        }
    }
}

extension ReuniaoExterna {
    init?(fromGoogleEvent evento: [String: Any]) {
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

        let participantes: [String]
        if let attendees = evento["attendees"] as? [[String: Any]] {
            participantes = attendees.compactMap { a in
                if let email = a["email"] as? String {
                    return email
                }
                if let displayName = a["displayName"] as? String {
                    return displayName
                }
                return nil
            }
        } else {
            participantes = []
        }

        let notas = evento["description"] as? String

        self.init(
            id: id,
            titulo: titulo,
            data: inicio,
            participantes: participantes,
            notas: notas,
            resumo: nil,
            transcricao: nil
        )
    }

    private static func parseDateTime(_ string: String) -> Date? {
        let formatador = ISO8601DateFormatter()
        formatador.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let data = formatador.date(from: string) { return data }
        let formatadorSemFracao = ISO8601DateFormatter()
        formatadorSemFracao.formatOptions = [.withInternetDateTime]
        return formatadorSemFracao.date(from: string)
    }

    private static func parseDate(_ string: String) -> Date? {
        let formatador = DateFormatter()
        formatador.locale = Locale(identifier: "en_US_POSIX")
        formatador.dateFormat = "yyyy-MM-dd"
        formatador.timeZone = TimeZone(secondsFromGMT: 0)
        return formatador.date(from: string)
    }
}