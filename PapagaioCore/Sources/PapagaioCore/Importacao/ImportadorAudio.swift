import AVFoundation
import Foundation

/// Importa um arquivo de áudio externo para dentro do container.
///
/// Backend portado do Eko (`AudioLibrary.storeImportedAudio`): o arquivo é
/// **copiado como veio**, sem re-encodar para AAC mono 16 kHz. A conversão
/// para o formato do Whisper acontece na leitura (em `DecodificadorDeAudio`),
/// não na importação — re-encodar na entrada era outra fonte de áudio abafado
/// e de falhas de leitura em `.m4a` fora do padrão.
///
/// Um arquivo importado tem **um canal só de origem** — não há microfone nem
/// tap para separar. Os trechos que saírem dele ficam com `speaker: nil`,
/// sem atribuição de falante (ver skill `papagaio-speaker-attribution`).
public struct ImportadorAudio: Sendable {
    public struct Resultado: Sendable {
        public let id: UUID
        public let pastaRelativa: String
        public let duracao: TimeInterval
        public let bytes: Int
        public let tituloSugerido: String
        /// Quando a gravação em si aconteceu, lida do arquivo original — e
        /// não o instante da importação. Um arquivo trazido de outro app ou
        /// de um gravador externo já tem sua própria data; usar `Date()`
        /// aqui faria toda importação parecer ter sido gravada agora mesmo.
        public let dataOriginal: Date
    }

    private let armazenamento: Armazenamento

    public init(armazenamento: Armazenamento) {
        self.armazenamento = armazenamento
    }

    /// Valida, copia para o container e devolve os metadados. Nenhuma
    /// referência ao arquivo original sobrevive.
    ///
    /// - Important: se o arquivo ainda estiver só no iCloud (ícone de nuvem
    ///   no Finder), a cópia espera o download terminar antes de copiar —
    ///   copiar na hora baixa um arquivo incompleto, e a transcrição falha no
    ///   meio da leitura com um erro genérico.
    public func importar(de origem: URL, id: UUID = UUID()) async throws -> Resultado {
        let acessou = origem.startAccessingSecurityScopedResource()
        defer {
            if acessou {
                origem.stopAccessingSecurityScopedResource()
            }
        }

        try await AudioBiblioteca.garantirBaixadoLocalmente(origem)

        let asset = AVURLAsset(url: origem)
        let trilhas = try await asset.loadTracks(withMediaType: .audio)
        guard !trilhas.isEmpty else {
            throw ErroCaptura.arquivoInvalido("nenhuma trilha de áudio em \(origem.lastPathComponent)")
        }

        let duracao = try await asset.load(.duration)
        let segundos = CMTimeGetSeconds(duracao)
        guard segundos.isFinite, segundos > 0 else {
            throw ErroCaptura.arquivoInvalido("duração inválida")
        }

        // Copia o original, preservando a extensão — o formato original é o
        // que o usuário escolheu, e a reprodução/transcrição decodificam
        // qualquer formato (ver `DecodificadorDeAudio`).
        let extensao = origem.pathExtension.isEmpty ? "m4a" : origem.pathExtension
        let destino = try armazenamento.criarArquivoImportado(id: id, extensao: extensao)
        try? FileManager.default.removeItem(at: destino)
        try FileManager.default.copyItem(at: origem, to: destino)

        let bytes = (try? FileManager.default.attributesOfItem(atPath: destino.path)[.size] as? Int) ?? 0

        return Resultado(
            id: id,
            pastaRelativa: Armazenamento.caminhoRelativo(id: id),
            duracao: segundos,
            bytes: bytes,
            tituloSugerido: origem.deletingPathExtension().lastPathComponent,
            dataOriginal: dataDeGravacao(de: origem)
        )
    }

    /// A data de criação do arquivo original — lida **antes** de copiar, do
    /// arquivo que ainda está fora do container.
    ///
    /// `.creationDate` é o que mais se aproxima de "quando isso foi
    /// gravado": é o carimbo que o gravador, o AirDrop ou o Finder deram ao
    /// arquivo ao criá-lo. Nem todo sistema de arquivos preserva esse campo
    /// ao copiar de outro lugar (alguns só preservam a modificação), então
    /// cai para `.contentModificationDate` quando falta — e para agora
    /// mesmo só se nem isso existir, o que na prática não acontece.
    private func dataDeGravacao(de origem: URL) -> Date {
        let valores = try? origem.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
        return valores?.creationDate ?? valores?.contentModificationDate ?? Date()
    }
}
