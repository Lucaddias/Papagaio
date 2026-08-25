import AppKit
import Foundation
import PapagaioCore

enum LixeiraDeMidia {
    static func itens() -> [MidiaNaLixeira] {
        guard let dados = UserDefaults.standard.data(forKey: chave),
              let itens = try? JSONDecoder().decode([MidiaNaLixeira].self, from: dados)
        else { return [] }
        return itens.sorted { $0.apagadoEm > $1.apagadoEm }
    }

    /// Move o arquivo para a subpasta de lixeira da conversa e registra o item.
    static func mover(
        url: URL,
        nome: String,
        tamanho: Int64,
        tipo: String,
        daGravacao: Bool,
        arquivoID: ArquivoID,
        conversaTitulo: String,
        pastaDaConversa: URL
    ) throws {
        let pasta = pastaDaConversa.appendingPathComponent(
            "\(NomeDeArquivoSeguro.gerar(de: conversaTitulo)) (excluídos)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)

        // Prefixo com UUID: dois "gravacao.m4a" apagados em momentos
        // diferentes não podem se sobrescrever dentro da lixeira.
        let identificador = UUID()
        let destino = pasta.appendingPathComponent("\(identificador.uuidString)-\(nome)")
        try FileManager.default.moveItem(at: url, to: destino)

        var atuais = itens()
        atuais.append(
            MidiaNaLixeira(
                id: identificador,
                arquivoID: arquivoID,
                conversaTitulo: conversaTitulo,
                nome: nome,
                tamanho: tamanho,
                tipo: tipo,
                daGravacao: daGravacao,
                caminhoOriginal: url.path,
                caminhoNaLixeira: destino.path
            )
        )
        salvar(atuais)
    }

    /// Devolve o arquivo ao lugar e ao **nome** de origem.
    ///
    /// O nome importa: o app procura o áudio por nome exato
    /// (`microfone.wav`, `sistema.caf`, `gravacao.<ext>`). Na lixeira o arquivo
    /// ganha um prefixo com UUID para dois homônimos não se sobrescreverem, e
    /// é aqui que esse prefixo sai. Restaurar por fora, arrastando no Finder,
    /// deixaria o prefixo e o player não acharia nada.
    @discardableResult
    static func restaurar(_ item: MidiaNaLixeira) -> Bool {
        let origem = URL(fileURLWithPath: item.caminhoNaLixeira)
        let destino = URL(fileURLWithPath: item.caminhoOriginal)

        guard FileManager.default.fileExists(atPath: origem.path) else {
            remover(item, apagandoArquivo: false)
            return false
        }

        do {
            try FileManager.default.createDirectory(
                at: destino.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            // Já existe um arquivo com o nome de destino: o que vale é o que
            // está na conversa, então o da lixeira é descartado.
            if FileManager.default.fileExists(atPath: destino.path) {
                try FileManager.default.removeItem(at: origem)
            } else {
                try FileManager.default.moveItem(at: origem, to: destino)
            }
        } catch {
            return false
        }

        remover(item, apagandoArquivo: false)
        return true
    }

    /// Reabre no Finder a pasta onde o arquivo está — para quem quiser ver
    /// onde as coisas moram sem caçar dentro do container do app.
    static func revelarNoFinder(_ item: MidiaNaLixeira) {
        #if os(macOS)
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.caminhoNaLixeira)])
        #endif
    }

    static func remover(_ item: MidiaNaLixeira, apagandoArquivo: Bool = true) {
        if apagandoArquivo {
            try? FileManager.default.removeItem(atPath: item.caminhoNaLixeira)
        }
        salvar(itens().filter { $0.id != item.id })
    }

    static func restaurarTudo() {
        itens().forEach { restaurar($0) }
    }

    static func esvaziar() {
        itens().forEach { try? FileManager.default.removeItem(atPath: $0.caminhoNaLixeira) }
        UserDefaults.standard.removeObject(forKey: chave)
    }

    /// A biblioteca já removeu a pasta de gravações inteira. Aqui descartamos
    /// só os metadados, sem seguir caminhos absolutos fora do container.
    static func limparRegistros(em defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: chave)
    }

    /// Descarta referências a mídias de uma conversa cuja pasta já foi
    /// removida pela exclusão definitiva.
    static func removerRegistros(
        do arquivoID: ArquivoID,
        em defaults: UserDefaults = .standard
    ) {
        guard let dados = defaults.data(forKey: chave),
              let atuais = try? JSONDecoder().decode([MidiaNaLixeira].self, from: dados),
              let novos = try? JSONEncoder().encode(atuais.filter { $0.arquivoID != arquivoID })
        else { return }
        defaults.set(novos, forKey: chave)
    }

    private static func salvar(_ itens: [MidiaNaLixeira]) {
        guard let dados = try? JSONEncoder().encode(itens) else { return }
        UserDefaults.standard.set(dados, forKey: chave)
    }

    private static let chave = "midiaNaLixeira"
}
