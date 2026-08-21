import Foundation

struct TarefaDaConversa: Identifiable, Codable, Equatable {
    let id: UUID
    var titulo: String
    var origem: String
    var prioridade: PrioridadeDaTarefa
    var status: StatusDaTarefa
    var responsavel: String?
    var prazo: Date?
    /// Opcional e por último de propósito: tarefas gravadas antes desta versão
    /// decodificam com `nil` aqui, sem quebrar.
    var descricao: String?

    init(
        id: UUID = UUID(),
        titulo: String,
        origem: String,
        prioridade: PrioridadeDaTarefa,
        status: StatusDaTarefa,
        responsavel: String?,
        prazo: Date?,
        descricao: String? = nil
    ) {
        self.id = id
        self.titulo = titulo
        self.origem = origem
        self.prioridade = prioridade
        self.status = status
        self.responsavel = responsavel
        self.prazo = prazo
        self.descricao = descricao
    }

    /// O nome do responsável, só quando é um nome de verdade.
    ///
    /// O resumo vem de um modelo local que, quando um próximo passo não cita
    /// ninguém, às vezes preenche o campo com o texto literal "null" em vez
    /// de omiti-lo — comportamento de LLM, não uma pessoa chamada Null. Sem
    /// este filtro esse texto ia direto para a tela, como se fosse o nome de
    /// alguém.
    var responsavelValido: String? { Self.responsavelSaneado(responsavel) }

    static func responsavelSaneado(_ texto: String?) -> String? {
        guard let texto else { return nil }
        let limpo = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpo.isEmpty, !["null", "nil", "n/a", "none"].contains(limpo.lowercased()) else { return nil }
        return limpo
    }
}
