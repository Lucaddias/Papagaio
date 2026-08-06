import Foundation
import WhisperRuntime

/// A engine de transcrição do Papagaio. Não existe segunda (D-0.5).
///
/// Chama o `whisper.cpp` **in-process**, pela biblioteca linkada no Passo 3.
/// Nenhum `Process()`, nenhum binário do Homebrew — é o que permite manter
/// estes pesos e a Mac App Store ao mesmo tempo (D-0.6).
public struct WhisperEngine: TranscriptionEngine {
    /// Um só lugar para o identificador: ele vai para `Arquivo.engineTranscricao`
    /// e para o registro no `CicloDeVidaDeModelos`, e os três divergirem seria
    /// um bug silencioso nos metadados.
    public static let identificador = "whisper-large-v3"

    public let identifier = WhisperEngine.identificador

    private let contexto: ContextoWhisper

    /// - Parameter modelo: caminho do `ggml-large-v3.bin`.
    public init(modelo: URL) {
        self.contexto = ContextoWhisper(modelo: modelo)
    }

    /// Reaproveita um contexto já carregado — é o que mantém os 3 GB residentes
    /// entre transcrições.
    public init(contexto: ContextoWhisper) {
        self.contexto = contexto
    }

    public func transcribe(_ url: URL) async throws -> [Trecho] {
        try await transcribe(url, speaker: nil)
    }

    /// Transcreve atribuindo o falante pelo **canal de origem**.
    ///
    /// Não há modelo de diarização: microfone é `"eu"`, tap do sistema é
    /// `"interlocutor"`, e arquivo importado é `nil` — ver skill
    /// `papagaio-speaker-attribution`.
    ///
    /// Chama o Whisper **uma vez por janela de fala** (ver
    /// `DetectorDeAtividadeDeVoz.janelasDeFala`), não uma vez para o arquivo
    /// inteiro — silêncio longo entre janelas nunca chega ao decoder. Ver o
    /// comentário de `DetectorDeAtividadeDeVoz.swift` para o porquê: era
    /// isso que causava a repetição/alucinação em cascata.
    public func transcribe(
        _ url: URL,
        speaker: String?,
        initialPrompt: String? = nil
    ) async throws -> [Trecho] {
        let amostras = try await DecodificadorDeAudio.amostras(de: url)
        guard !amostras.isEmpty else { return [] }

        let janelas = try await DetectorDeAtividadeDeVoz.janelasDeFala(nas: amostras)
        guard !janelas.isEmpty else {
            // Em uma reunião de dois canais, o microfone pode estar em silêncio
            // enquanto só o interlocutor fala. Devolver vazio permite que o
            // pipeline preserve o outro canal; se ambos estiverem vazios, ele
            // encerra sem resumo e informa que nenhuma fala foi reconhecida.
            return []
        }

        var trechos: [Trecho] = []
        for janela in janelas {
            let amostrasDaJanela = DetectorDeAtividadeDeVoz.amostras(de: amostras, na: janela)
            guard !amostrasDaJanela.isEmpty else { continue }

            let segmentos = try await contexto.transcrever(amostras: amostrasDaJanela, initialPrompt: initialPrompt)
            // O Whisper devolve t0/t1 relativos ao início da JANELA — soma o
            // deslocamento para voltar à linha do tempo do arquivo original.
            trechos.append(contentsOf: segmentos.map {
                Trecho(start: $0.start + janela.inicio, end: $0.end + janela.inicio, texto: $0.texto, speaker: speaker)
            })
        }
        return trechos
    }

    /// Carrega o modelo antecipadamente, para a primeira transcrição não pagar
    /// os segundos de carga.
    public func preaquecer() async throws {
        try await contexto.carregar()
    }

    public func descarregar() async {
        await contexto.descarregar()
    }
}

extension ContextoWhisper: CicloDeVidaDeModelos.Residente {
    public nonisolated var identificador: String { WhisperEngine.identificador }
}
