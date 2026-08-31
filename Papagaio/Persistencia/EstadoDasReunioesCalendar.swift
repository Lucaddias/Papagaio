import Foundation

/// Estado local mínimo de cada evento do Google Calendar.
///
/// O identificador externo é a chave estável. A cópia da reunião só é
/// necessária para que a lixeira continue utilizável quando o evento já não
/// vier na janela atual da API.
struct RegistroDeReuniaoCalendar: Codable, Equatable {
    enum Estado: String, Codable {
        case ativa
        case ignorada
        case convertida
    }

    var estado: Estado
    var reuniao: ReuniaoPendenteCalendar
}

/// Fonte única de verdade para ignorar, restaurar e converter reuniões.
/// `UserDefaults` é suficiente porque são somente metadados pequenos, sem
/// áudio, transcrição ou credencial.
struct EstadoDasReunioesCalendar {
    static let chave = "estadoDasReunioesGoogleCalendar.v1"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func registro(de idExterno: String) -> RegistroDeReuniaoCalendar? {
        todos()[idExterno]
    }

    func reunioesIgnoradas() -> [ReuniaoPendenteCalendar] {
        todos().values
            .filter { $0.estado == .ignorada }
            .map(\.reuniao)
            .sorted { $0.dataHora < $1.dataHora }
    }

    func definir(_ estado: RegistroDeReuniaoCalendar.Estado, para reuniao: ReuniaoPendenteCalendar) {
        var registros = todos()
        registros[reuniao.idExterno] = RegistroDeReuniaoCalendar(
            estado: estado,
            reuniao: reuniao
        )
        salvar(registros)
    }

    /// Atualiza o snapshot sem desfazer uma escolha já persistida.
    func registrarSeNecessario(_ reuniao: ReuniaoPendenteCalendar) {
        var registros = todos()
        if var existente = registros[reuniao.idExterno] {
            existente.reuniao = reuniao
            registros[reuniao.idExterno] = existente
        } else {
            registros[reuniao.idExterno] = RegistroDeReuniaoCalendar(
                estado: .ativa,
                reuniao: reuniao
            )
        }
        salvar(registros)
    }

    func removerTodos() {
        defaults.removeObject(forKey: Self.chave)
    }

    private func todos() -> [String: RegistroDeReuniaoCalendar] {
        guard let dados = defaults.data(forKey: Self.chave),
              let registros = try? JSONDecoder().decode(
                [String: RegistroDeReuniaoCalendar].self,
                from: dados
              )
        else { return [:] }
        return registros
    }

    private func salvar(_ registros: [String: RegistroDeReuniaoCalendar]) {
        guard let dados = try? JSONEncoder().encode(registros) else { return }
        defaults.set(dados, forKey: Self.chave)
    }
}
