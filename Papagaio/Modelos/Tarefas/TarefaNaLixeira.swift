import Foundation
import PapagaioCore

struct TarefaNaLixeira: Identifiable, Codable, Equatable {
    let id: UUID
    let arquivoID: ArquivoID
    let conversaTitulo: String
    let tarefa: TarefaDaConversa
    let apagadoEm: Date

    init(
        id: UUID = UUID(),
        arquivoID: ArquivoID,
        conversaTitulo: String,
        tarefa: TarefaDaConversa,
        apagadoEm: Date = Date()
    ) {
        self.id = id
        self.arquivoID = arquivoID
        self.conversaTitulo = conversaTitulo
        self.tarefa = tarefa
        self.apagadoEm = apagadoEm
    }
}
