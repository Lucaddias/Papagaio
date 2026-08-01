import Foundation
import Testing
@testable import PapagaioCore

// Passo 1: os testes verificam que os contratos fecham e que as implementações
// vazias falham do jeito declarado. Não testam comportamento de feature —
// não existe feature ainda.

@Test("Trecho calcula duração e aceita speaker nulo")
func trechoDuracao() {
    let t = Trecho(start: 12.5, end: 52.5, texto: "olá", speaker: nil)
    #expect(t.duracao == 40.0)
    #expect(t.speaker == nil)
}

@Test("Speaker expõe os dois únicos valores válidos")
func speakerConstantes() {
    #expect(Speaker.eu == "eu")
    #expect(Speaker.interlocutor == "interlocutor")
}

@Test("WhisperEngine cumpre TranscriptionEngine com o identificador do modelo")
func whisperEngineContrato() {
    // A implementação real chegou no Passo 4 — o que se verifica aqui é só o
    // contrato. O comportamento está em TranscricaoTests.
    let engine: any TranscriptionEngine = WhisperEngine(
        modelo: URL(fileURLWithPath: "/nao/existe/modelo.bin")
    )
    #expect(engine.identifier == "whisper-large-v3")
}

@Test("QwenEngine cumpre SummarizationEngine com o identificador do modelo")
func qwenEngineContrato() {
    // A implementação real chegou no Passo 7. Comportamento em SumarizacaoTests.
    let engine: any SummarizationEngine = QwenEngine(
        modelo: URL(fileURLWithPath: "/nao/existe/modelo.gguf")
    )
    #expect(engine.identifier == "qwen2.5-14b-instruct-q5_k_m")
}

@Test("Resumo faz round-trip de JSON")
func resumoCodable() throws {
    let original = Resumo(
        titulo: "Reunião de kickoff",
        visaoGeral: "Alinhamento de escopo.",
        temas: [Tema(titulo: "Prazo", detalhe: "Entrega em setembro.")],
        citacoes: [Citacao(texto: "vamos manter o Whisper", speaker: Speaker.eu, start: 91.2)],
        proximosPassos: [ProximoPasso(descricao: "Fechar o Passo 1", responsavel: "Luca")]
    )

    let dados = try JSONEncoder().encode(original)
    let volta = try JSONDecoder().decode(Resumo.self, from: dados)

    #expect(volta == original)
}

@Test("Arquivo guarda caminho relativo, nunca absoluto")
func arquivoCaminhoRelativo() {
    let a = Arquivo(
        titulo: "entrevista",
        pastaRelativa: "Gravacoes/\(UUID().uuidString)",
        espaco: EspacoID()
    )
    #expect(!a.pastaRelativa.hasPrefix("/"))
}
