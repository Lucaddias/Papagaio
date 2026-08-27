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
        let eventos = try await listarEventos()
        return eventos.map { evento in
            ReuniaoExterna(
                id: evento.id,
                titulo: evento.titulo,
                data: evento.dataHora,
                participantes: evento.participantes,
                notas: evento.descricao,
                resumo: nil,
                transcricao: nil
            )
        }
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
              let reuniao = ReuniaoExterna.fromGoogleEvent(json)
        else {
            throw FonteGoogleCalendarErro.respostaInesperada
        }
        return reuniao
    }

    // MARK: - Internal

    struct EventoCalendarSimples {
        let id: String
        let titulo: String
        let dataHora: Date
        let participantes: [String]
        let descricao: String?
    }

    func listarEventos() async throws -> [EventoCalendarSimples] {
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

        let eventos = itens
            .filter { evento in
                let tipo = evento["eventType"] as? String ?? "default"
                let attendees = evento["attendees"] as? [[String: Any]]
                return tipo == "default" && (attendees?.isEmpty == false)
            }
            .compactMap { evento -> EventoCalendarSimples? in
                guard let id = evento["id"] as? String, !id.isEmpty else { return nil }
                let titulo = (evento["summary"] as? String) ?? "Evento sem título"

                let inicio: Date
                if let startDateTime = evento["start"] as? [String: Any],
                   let dateTimeStr = startDateTime["dateTime"] as? String {
                    inicio = ReuniaoExterna.parseDateTime(dateTimeStr) ?? Date()
                } else if let startDate = evento["start"] as? [String: Any],
                          let dateStr = startDate["date"] as? String {
                    inicio = ReuniaoExterna.parseDate(dateStr) ?? Date()
                } else {
                    inicio = Date()
                }

                let participantes: [String]
                if let attendees = evento["attendees"] as? [[String: Any]] {
                    participantes = attendees.compactMap { a in
                        if let email = a["email"] as? String { return email }
                        if let displayName = a["displayName"] as? String { return displayName }
                        return nil
                    }
                } else {
                    participantes = []
                }

                let descricao = evento["description"] as? String

                return EventoCalendarSimples(
                    id: id,
                    titulo: titulo,
                    dataHora: inicio,
                    participantes: participantes,
                    descricao: descricao
                )
            }
        registro.info("\(eventos.count) eventos futuros (com participantes) carregados do Google Calendar")
        return eventos
    }

    // Internal method for detailed event fetch
    func obterEventoDetalhado(id: String) async throws -> EventoCalendarSimples? {
        let token = try await obterToken(false)

        var pedido = URLRequest(url: baseURL.appendingPathComponent("calendars/primary/events/\(id)"))
        pedido.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        pedido.timeoutInterval = 15

        let (dados, resposta) = try await URLSession.shared.data(for: pedido)
        guard let http = resposta as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            if (resposta as? HTTPURLResponse)?.statusCode == 404 {
                return nil
            }
            throw FonteGoogleCalendarErro.respostaInesperada
        }
        guard let json = try JSONSerialization.jsonObject(with: dados) as? [String: Any] else {
            return nil
        }

        guard let id = json["id"] as? String, !id.isEmpty else { return nil }
        let titulo = (json["summary"] as? String) ?? "Evento sem título"

        let inicio: Date
        if let startDateTime = json["start"] as? [String: Any],
           let dateTimeStr = startDateTime["dateTime"] as? String {
            inicio = ReuniaoExterna.parseDateTime(dateTimeStr) ?? Date()
        } else if let startDate = json["start"] as? [String: Any],
                  let dateStr = startDate["date"] as? String {
            inicio = ReuniaoExterna.parseDate(dateStr) ?? Date()
        } else {
            inicio = Date()
        }

        let participantes: [String]
        if let attendees = json["attendees"] as? [[String: Any]] {
            participantes = attendees.compactMap { a in
                if let email = a["email"] as? String { return email }
                if let displayName = a["displayName"] as? String { return displayName }
                return nil
            }
        } else {
            participantes = []
        }

        let descricao = json["description"] as? String

        return EventoCalendarSimples(
            id: id,
            titulo: titulo,
            dataHora: inicio,
            participantes: participantes,
            descricao: descricao
        )
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