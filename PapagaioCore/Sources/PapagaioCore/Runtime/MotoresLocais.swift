import Foundation
import LlamaRuntime
import WhisperRuntime

/// Os dois modelos locais, com a garantia de que **nunca ficam residentes ao
/// mesmo tempo**.
///
/// Whisper large-v3 ocupa ~3 GB e o Qwen Q5_K_M ~10,7 GB. Somados são 13,7 GB
/// num Mac cujo piso é 18 GB (D-0.7): manter os dois carregados durante um
/// processamento é o caminho mais curto para o jetsam matar o app no meio da
/// transcrição. Por isso `resumir` descarrega o Whisper antes de carregar o
/// Qwen, e `transcrever` faz o contrário.
///
/// É um ator porque a alternância entre os dois é justamente a invariante que
/// não pode ser corrida por duas chamadas concorrentes.
public actor MotoresLocais {
    public let pastaDeModelos: URL

    private var contextoWhisper: ContextoWhisper?
    private var contextoLlama: ContextoLlama?
    private let ciclo: CicloDeVidaDeModelos?

    public init(pastaDeModelos: URL, ciclo: CicloDeVidaDeModelos? = nil) {
        self.pastaDeModelos = pastaDeModelos
        self.ciclo = ciclo
    }

    public var pesoDaTranscricao: URL {
        pastaDeModelos.appendingPathComponent(Pesos.whisperLargeV3.nomeArquivo)
    }

    public var pesoDoResumo: URL {
        pastaDeModelos.appendingPathComponent(Pesos.qwen14B.nomeArquivo)
    }

    // MARK: - Uso

    public func transcrever(_ audio: URL, speaker: String?) async throws -> [Trecho] {
        await descarregarResumo()
        let contexto = contextoWhisper ?? ContextoWhisper(modelo: pesoDaTranscricao)
        contextoWhisper = contexto
        await ciclo?.registrar(contexto)
        return try await WhisperEngine(contexto: contexto).transcribe(audio, speaker: speaker)
    }

    public func resumir(_ trechos: [Trecho]) async throws -> Resumo {
        await descarregarTranscricao()
        let contexto = contextoLlama ?? ContextoLlama(modelo: pesoDoResumo)
        contextoLlama = contexto
        await ciclo?.registrar(contexto)
        return try await QwenEngine(contexto: contexto).summarize(trechos)
    }

    // MARK: - Descarga

    public func descarregarTranscricao() async {
        guard let contexto = contextoWhisper else { return }
        await contexto.descarregar()
        await ciclo?.remover(contexto.identificador)
        contextoWhisper = nil
    }

    public func descarregarResumo() async {
        guard let contexto = contextoLlama else { return }
        await contexto.descarregar()
        await ciclo?.remover(contexto.identificador)
        contextoLlama = nil
    }

    public func descarregarTudo() async {
        await descarregarTranscricao()
        await descarregarResumo()
    }
}
