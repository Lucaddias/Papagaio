import Foundation

/// Representação portátil de uma gravação para exportação.
///
/// A geração fica no Core para que o conteúdo exportado seja testável sem
/// SwiftUI. A escolha do destino e a cópia do anexo pertencem ao app, pois
/// passam pela autorização do usuário no sandbox.
public enum ExportacaoMarkdown {
    public static func gerar(arquivo: Arquivo) -> String {
        var linhas = ["# \(arquivo.resumo?.titulo ?? arquivo.titulo)", ""]
        linhas += [
            "- **Criado em:** \(data(arquivo.criadoEm))",
            "- **Duração:** \(duracao(arquivo.duracao))",
        ]

        if let engine = arquivo.engineTranscricao {
            linhas.append("- **Transcrição:** \(engine)")
        }
        if let engine = arquivo.engineResumo {
            linhas.append("- **Resumo:** \(engine)")
        }

        if let resumo = arquivo.resumo {
            linhas += ["", "## Visão geral", "", resumo.visaoGeral]

            if !resumo.temas.isEmpty {
                linhas += ["", "## Temas", ""]
                linhas += resumo.temas.map { "- **\($0.titulo):** \($0.detalhe)" }
            }

            if !resumo.citacoes.isEmpty {
                linhas += ["", "## Citações", ""]
                linhas += resumo.citacoes.map { citacao in
                    let origem = [nomeDoFalante(citacao.speaker), citacao.start.map(tempo)]
                        .compactMap { $0 }
                        .joined(separator: " · ")
                    return origem.isEmpty
                        ? "> \(citacao.texto)"
                        : "> \(citacao.texto)  \n> — \(origem)"
                }
            }

            if !resumo.proximosPassos.isEmpty {
                linhas += ["", "## Próximos passos", ""]
                linhas += resumo.proximosPassos.map { passo in
                    if let responsavel = passo.responsavel, !responsavel.isEmpty {
                        return "- [ ] \(passo.descricao) — \(responsavel)"
                    }
                    return "- [ ] \(passo.descricao)"
                }
            }
        }

        if !arquivo.trechos.isEmpty {
            linhas += ["", "## Transcrição", ""]
            linhas += arquivo.trechos.map { trecho in
                let falante = nomeDoFalante(trecho.speaker)
                let prefixo = falante.map { "**[\(tempo(trecho.start)) · \($0)]**" }
                    ?? "**[\(tempo(trecho.start))]**"
                return "\(prefixo) \(trecho.texto)"
            }
        }

        linhas.append("")
        return linhas.joined(separator: "\n")
    }

    /// Nome previsível e seguro para o arquivo salvo no painel de exportação.
    public static func nomeDeArquivo(para arquivo: Arquivo) -> String {
        let base = (arquivo.resumo?.titulo ?? arquivo.titulo)
            .folding(options: [.diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: "[^A-Za-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return (base.isEmpty ? "papagaio" : base.lowercased()) + ".md"
    }

    private static func data(_ data: Date) -> String {
        data.formatted(date: .long, time: .shortened)
    }

    private static func duracao(_ segundos: TimeInterval) -> String {
        let total = max(0, Int(segundos))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private static func tempo(_ segundos: TimeInterval) -> String {
        duracao(segundos)
    }

    private static func nomeDoFalante(_ speaker: String?) -> String? {
        switch speaker {
        case Speaker.eu: "Eu"
        case Speaker.interlocutor: "Interlocutor"
        case let valor? where !valor.isEmpty: valor
        default: nil
        }
    }
}
