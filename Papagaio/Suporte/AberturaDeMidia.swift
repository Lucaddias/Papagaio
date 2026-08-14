import AppKit
import UniformTypeIdentifiers

/// Abre um anexo fora do app, escolhendo o player em vez de aceitar o padrão.
///
/// **Por que não `NSWorkspace.open` puro.** No macOS, `.m4a` e `.wav` estão
/// associados ao Música. Clicar em "ouvir" abria o app inteiro, que pode
/// interromper o que estava tocando, e às vezes **importa o arquivo para a
/// biblioteca do usuário** — uma gravação de entrevista misturada com as
/// músicas dele. Nada disso foi pedido: o pedido era ouvir um arquivo.
///
/// O QuickTime é o oposto: abre uma janela, toca, fecha. Não tem biblioteca,
/// não importa nada, não mexe no que já estava tocando.
///
/// Vale só para áudio e vídeo. PDF, imagem e documento continuam indo para o
/// app padrão do sistema, onde a escolha do usuário faz sentido.
enum AberturaDeMidia {
    private static let quickTime = "com.apple.QuickTimePlayerX"

    static func abrir(_ url: URL) {
        guard
            ehAudioOuVideo(url),
            let player = NSWorkspace.shared.urlForApplication(withBundleIdentifier: quickTime)
        else {
            // Sem QuickTime instalado — raro, mas é removível — o padrão do
            // sistema é melhor que não abrir nada.
            NSWorkspace.shared.open(url)
            return
        }

        let configuracao = NSWorkspace.OpenConfiguration()
        configuracao.activates = true

        NSWorkspace.shared.open([url], withApplicationAt: player, configuration: configuracao) { _, erro in
            guard erro != nil else { return }
            Task { @MainActor in NSWorkspace.shared.open(url) }
        }
    }

    /// Pelo tipo declarado da extensão, não por uma lista de extensões: a
    /// lista esqueceria `.aiff`, `.mov`, `.mp3` gravado por outro app, e
    /// qualquer formato que a equipe passe a importar depois.
    private static func ehAudioOuVideo(_ url: URL) -> Bool {
        guard let tipo = UTType(filenameExtension: url.pathExtension) else { return false }
        return tipo.conforms(to: .audio) || tipo.conforms(to: .audiovisualContent)
    }
}
