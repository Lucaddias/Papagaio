import Foundation
import PapagaioCore

/// Mesma ideia de `TarefasDaConversaGeral`, para a tela agregada de Mídias:
/// os anexos de uma conversa, mais os dados dela que a tela precisa (título,
/// e a pasta onde os anexos moram em disco, necessária para poder remover
/// um deles direto daqui — ver `MidiasDaConversa`/`LixeiraDeMidia`).
struct MidiasDaConversaGeral: Identifiable {
    let arquivo: Arquivo
    let titulo: String
    let pastaDaConversa: URL
    let anexos: [AnexoDeMidiaDaConversa]

    var id: ArquivoID { arquivo.id }
}

/// Mesma ideia de `TarefaGeral`: um anexo, mais a conversa de onde ele veio
/// — é isso que permite a grade agregada mostrar "de qual conversa é" cada
/// cartão, e remover/abrir o arquivo certo mesmo fora da tela da conversa.
struct MidiaGeral: Identifiable {
    let conversa: MidiasDaConversaGeral
    let anexo: AnexoDeMidiaDaConversa

    var id: String { "\(conversa.id.rawValue.uuidString)-\(anexo.id.uuidString)" }
}
