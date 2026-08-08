import Foundation
import PapagaioCore

/// Anexo removido da aba Mídia de uma conversa.
///
/// O arquivo não é apagado: sai da pasta `Midia/` e vai para `MidiaNaLixeira/`
/// dentro da mesma conversa, de onde pode voltar. Guardamos o caminho de origem
/// justamente para a restauração saber onde devolvê-lo.
struct MidiaNaLixeira: Identifiable, Codable, Equatable {
    let id: UUID
    let arquivoID: ArquivoID
    let conversaTitulo: String
    let nome: String
    let tamanho: Int64
    let tipo: String
    /// Era o áudio da própria gravação, não um anexo adicionado à mão.
    let daGravacao: Bool
    let caminhoOriginal: String
    let caminhoNaLixeira: String
    let apagadoEm: Date

    init(
        id: UUID = UUID(),
        arquivoID: ArquivoID,
        conversaTitulo: String,
        nome: String,
        tamanho: Int64,
        tipo: String,
        daGravacao: Bool,
        caminhoOriginal: String,
        caminhoNaLixeira: String,
        apagadoEm: Date = Date()
    ) {
        self.id = id
        self.arquivoID = arquivoID
        self.conversaTitulo = conversaTitulo
        self.nome = nome
        self.tamanho = tamanho
        self.tipo = tipo
        self.daGravacao = daGravacao
        self.caminhoOriginal = caminhoOriginal
        self.caminhoNaLixeira = caminhoNaLixeira
        self.apagadoEm = apagadoEm
    }
}
