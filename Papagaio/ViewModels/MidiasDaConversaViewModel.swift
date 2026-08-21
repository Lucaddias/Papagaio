import AppKit
import Foundation
import Observation
import PapagaioCore

/// Os anexos de uma conversa: a lista, a escolha no painel do sistema e a
/// cópia para dentro da pasta da gravação.
///
/// Estes cinco métodos viviam na `ArquivoDetalheView`, onde `NSOpenPanel`,
/// cópia de arquivo e tradução de erro do Cocoa dividiam espaço com a
/// composição da tela.
@MainActor
@Observable
final class MidiasDaConversaViewModel {
    private(set) var anexos: [AnexoDeMidiaDaConversa] = []
    var erro: String?

    private let arquivoID: ArquivoID
    /// Os anexos são copiados para cá, ao lado do áudio. Guardar só o caminho
    /// de origem deixaria o anexo quebrado assim que a pessoa movesse o
    /// arquivo original.
    private let pastaDaConversa: URL
    /// Nomeia a subpasta de mídia — para que "Mostrar no Finder" caia numa
    /// pasta reconhecível pelo título, não por um UUID.
    private let tituloDaConversa: String

    init(arquivoID: ArquivoID, pastaDaConversa: URL, tituloDaConversa: String) {
        self.arquivoID = arquivoID
        self.pastaDaConversa = pastaDaConversa
        self.tituloDaConversa = tituloDaConversa
    }

    func carregar() {
        anexos = MidiasDaConversa.carregar(arquivoID)
    }

    func selecionar() {
        let painel = NSOpenPanel()
        painel.title = "Adicionar mídia"
        painel.prompt = "Adicionar"
        painel.message = "Escolha fotos, vídeos, áudios, PDFs ou outros arquivos para salvar nesta conversa."
        painel.canChooseFiles = true
        painel.canChooseDirectories = false
        painel.allowsMultipleSelection = true
        painel.resolvesAliases = true

        guard painel.runModal() == .OK else { return }

        for url in painel.urls {
            adicionar(url)
        }
    }

    func adicionar(_ url: URL) {
        let acessando = url.startAccessingSecurityScopedResource()
        defer {
            if acessando { url.stopAccessingSecurityScopedResource() }
        }

        do {
            let destino = try MidiasDaConversa.copiar(url, para: pastaDaConversa, tituloDaConversa: tituloDaConversa)
            let anexo = try MidiasDaConversa.anexo(para: destino)
            var atualizados = anexos.filter { $0.url != anexo.url }
            atualizados.append(anexo)
            atualizados.sort { $0.data > $1.data }
            try MidiasDaConversa.salvar(atualizados, para: arquivoID)
            anexos = atualizados
        } catch {
            erro = Self.mensagemAmigavel(error)
        }
    }

    func abrir(_ anexo: AnexoDeMidiaDaConversa) {
        AberturaDeMidia.abrir(anexo.url)
    }

    func remover(_ anexo: AnexoDeMidiaDaConversa) {
        let atualizados = anexos.filter { $0.id != anexo.id }
        do {
            try? MidiasDaConversa.apagarArquivoSalvo(anexo, pastaDaConversa: pastaDaConversa)
            try MidiasDaConversa.salvar(atualizados, para: arquivoID)
            anexos = atualizados
        } catch {
            erro = "Não foi possível remover esse arquivo: \(error.localizedDescription)"
        }
    }

    /// O erro do Cocoa para "iPhone bloqueado" chega como um código genérico de
    /// arquivo ilegível, que não diz à pessoa o que fazer. Estes três casos
    /// cobrem o que aparece na prática ao arrastar mídia do celular.
    private static func mensagemAmigavel(_ error: Error) -> String {
        let nsError = error as NSError
        let texto = "\(nsError.localizedDescription) \(nsError.localizedFailureReason ?? "")"
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

        if texto.contains("iphone") || texto.contains("locked") || texto.contains("bloqueado") {
            return "Você precisa desbloquear seu iPhone antes de importar esse arquivo."
        }
        if nsError.domain == NSCocoaErrorDomain && [257, 260, 513].contains(nsError.code) {
            return "Não consegui acessar esse arquivo. Se ele estiver no iPhone, desbloqueie o aparelho e tente importar de novo."
        }
        return "Não foi possível guardar esse arquivo: \(error.localizedDescription)"
    }
}
