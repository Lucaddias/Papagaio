import Foundation
import Testing
@testable import PapagaioCore

@Test("Exportação Markdown contém resumo, metadados e transcrição")
func exportacaoMarkdownCompleta() {
    let arquivo = Arquivo(
        titulo: "Reunião de produto",
        criadoEm: Date(timeIntervalSince1970: 0),
        duracao: 125,
        pastaRelativa: "Gravacoes/id",
        espaco: EspacoID(),
        trechos: [Trecho(start: 12, end: 20, texto: "Vamos fechar o orçamento.", speaker: Speaker.eu)],
        notas: [
            NotaDaConversa(
                texto: "Validar o risco jurídico.",
                start: 35,
                critica: true,
                tipo: .marcador
            ),
        ],
        resumo: Resumo(
            titulo: "Decisões da reunião",
            visaoGeral: "A equipe aprovou o orçamento.",
            temas: [Tema(titulo: "Orçamento", detalhe: "Aprovar R$ 9.600")],
            citacoes: [Citacao(texto: "Fechamos hoje.", speaker: Speaker.interlocutor, start: 12)],
            proximosPassos: [ProximoPasso(descricao: "Enviar contrato", responsavel: "Luca")]
        ),
        engineTranscricao: "whisper-large-v3",
        engineResumo: "qwen2.5-14b-instruct-q5_k_m"
    )

    let markdown = ExportacaoMarkdown.gerar(arquivo: arquivo)

    #expect(markdown.contains("# Decisões da reunião"))
    #expect(markdown.contains("## Visão geral"))
    #expect(markdown.contains("## Temas"))
    #expect(markdown.contains("## Citações"))
    #expect(markdown.contains("## Próximos passos"))
    #expect(markdown.contains("## Notas"))
    #expect(markdown.contains("## Transcrição"))
    #expect(markdown.contains("**[0:35 · Marcador · Crítica]** Validar o risco jurídico."))
    #expect(markdown.contains("**[0:12 · Eu]** Vamos fechar o orçamento."))
    #expect(markdown.contains("- [ ] Enviar contrato — Luca"))
}

@Test("Nome de exportação é seguro para o sistema de arquivos")
func nomeDeExportacaoSeguro() {
    let arquivo = Arquivo(
        titulo: "Reunião: Orçamento / Q3!",
        pastaRelativa: "Gravacoes/id",
        espaco: EspacoID()
    )

    #expect(ExportacaoMarkdown.nomeDeArquivo(para: arquivo) == "reuniao-orcamento-q3.md")
}
