import AppKit
import Foundation
import PapagaioCore

enum DossieDaConversa {
    static func gerar(arquivo: Arquivo) -> String {
        var texto = ExportacaoMarkdown.gerar(arquivo: arquivo)

        let anexos = MidiasDaConversa.carregar(arquivo.id)
        if !anexos.isEmpty {
            texto += "\n## Mídia\n\n"
            texto += anexos
                .map { "- \($0.nome) — \($0.tipoVisual), \($0.data.formatted(date: .numeric, time: .omitted))" }
                .joined(separator: "\n")
            texto += "\n"
        }

        let tarefas = TarefasGeraisStore.carregar(arquivo)
        if !tarefas.isEmpty {
            texto += "\n## Tarefas\n\n"
            texto += tarefas.map(linhaDaTarefa).joined(separator: "\n")
            texto += "\n"
        }

        return texto
    }

    static func nomeDeArquivo(para arquivo: Arquivo) -> String {
        ExportacaoMarkdown.nomeDeArquivo(para: arquivo)
    }

    /// Monta um `.zip` com o documento e o áudio da conversa.
    ///
    /// Zip, e não pasta: pasta solta não se anexa em e-mail nem em mensagem.
    /// A compactação sai do `NSFileCoordinator` com a opção `.forUploading`,
    /// que é a mesma coisa que o Finder faz em "Comprimir" — sem dependência
    /// externa e sem escrever um compactador à mão.
    static func pacoteComAudio(arquivo: Arquivo, audioPrincipal: URL) throws -> URL {
        let base = nomeDeArquivo(para: arquivo).replacingOccurrences(of: ".md", with: "")
        let pasta = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(base)-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent(base, isDirectory: true)
        try FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)

        try gerar(arquivo: arquivo)
            .write(to: pasta.appendingPathComponent("\(base).md"), atomically: true, encoding: .utf8)

        // O canal do sistema viaja junto quando existe: sem ele, uma gravação
        // de dois canais chegaria pela metade.
        let candidatos = [
            audioPrincipal,
            audioPrincipal.deletingLastPathComponent().appendingPathComponent("sistema.m4a"),
        ]
        for origem in candidatos where FileManager.default.fileExists(atPath: origem.path) {
            try? FileManager.default.copyItem(
                at: origem,
                to: pasta.appendingPathComponent(origem.lastPathComponent)
            )
        }

        // Duas variáveis de erro, e não uma: `&erroDoCoordenador` já está em
        // acesso exclusivo durante a chamada, então escrever nela de dentro do
        // bloco seria acesso sobreposto — o compilador barra.
        var erroDoCoordenador: NSError?
        var erroDaCopia: Error?
        var destino: URL?

        NSFileCoordinator().coordinate(
            readingItemAt: pasta,
            options: [.forUploading],
            error: &erroDoCoordenador
        ) { zipTemporario in
            let alvo = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(base).zip")
            try? FileManager.default.removeItem(at: alvo)
            do {
                try FileManager.default.copyItem(at: zipTemporario, to: alvo)
                destino = alvo
            } catch {
                erroDaCopia = error
            }
        }

        if let erroDoCoordenador { throw erroDoCoordenador }
        if let erroDaCopia { throw erroDaCopia }
        guard let destino else { throw CocoaError(.fileWriteUnknown) }
        return destino
    }

    private static func linhaDaTarefa(_ tarefa: TarefaDaConversa) -> String {
        let marca = tarefa.status == .concluida ? "x" : " "
        var detalhes = [tarefa.prioridade.rawValue]
        if let responsavel = tarefa.responsavel, !responsavel.isEmpty {
            detalhes.append(responsavel)
        }
        if let prazo = tarefa.prazo {
            detalhes.append("até \(prazo.formatted(date: .numeric, time: .omitted))")
        }
        return "- [\(marca)] \(tarefa.titulo) — \(detalhes.joined(separator: " · "))"
    }
}
