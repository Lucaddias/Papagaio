import Foundation
// `internal`: o módulo C não vaza para quem importa este target. Ver D-3.2.
internal import whisper

/// Um segmento nativo do Whisper. Tipo Swift puro — nenhum tipo do ggml
/// atravessa a fronteira deste target, que é o que permite o `internal import`.
public struct SegmentoWhisper: Sendable, Equatable {
    public let start: TimeInterval
    public let end: TimeInterval
    public let texto: String

    public init(start: TimeInterval, end: TimeInterval, texto: String) {
        self.start = start
        self.end = end
        self.texto = texto
    }
}

public enum ErroWhisper: Error, CustomStringConvertible {
    case modeloNaoCarregou(String)
    case falhaNaTranscricao(Int32)
    case audioVazio

    public var description: String {
        switch self {
        case let .modeloNaoCarregou(caminho):
            "não foi possível carregar o modelo em \(caminho)"
        case let .falhaNaTranscricao(codigo):
            "whisper_full falhou (código \(codigo))"
        case .audioVazio:
            "áudio sem amostras"
        }
    }
}

/// Envolve um `whisper_context` num ator.
///
/// **`whisper_context` não é thread-safe.** Um ator por contexto, e nunca duas
/// chamadas concorrentes ao mesmo. É por isso que a carga do modelo e a
/// transcrição vivem aqui dentro, e não numa struct qualquer.
///
/// O modelo fica **residente** entre transcrições: carregar 3 GB do disco leva
/// segundos, e recarregar a cada chamada tornaria a transcrição de um trecho
/// curto mais lenta que o próprio áudio.
public actor ContextoWhisper {
    /// Caixa em volta do ponteiro C.
    ///
    /// Existe por uma restrição do Swift 6: um `deinit` não isolado não pode
    /// tocar propriedade isolada do ator. Com a caixa, quem libera o
    /// `whisper_context` é o `deinit` dela, que roda quando o ator morre.
    private final class Caixa: @unchecked Sendable {
        var ponteiro: OpaquePointer?
        init(_ ponteiro: OpaquePointer? = nil) { self.ponteiro = ponteiro }
        deinit { if let ponteiro { whisper_free(ponteiro) } }
    }

    private var caixa = Caixa()
    private var contexto: OpaquePointer? { caixa.ponteiro }
    private let caminhoDoModelo: URL

    /// Amostras esperadas: PCM Float32 **mono 16 kHz** — o formato canônico do
    /// `FormatoAudio`. O Whisper não reamostra por conta própria.
    public static let taxaEsperada: Double = 16_000

    public init(modelo: URL) {
        self.caminhoDoModelo = modelo
    }

    public var carregado: Bool { contexto != nil }

    /// Carrega o peso GGUF na memória (e na GPU, via Metal).
    public func carregar() throws {
        guard contexto == nil else { return }

        var params = whisper_context_default_params()
        params.use_gpu = true
        params.flash_attn = true

        let ponteiro = caminhoDoModelo.path.withCString { caminho in
            whisper_init_from_file_with_params(caminho, params)
        }
        guard let ponteiro else {
            throw ErroWhisper.modeloNaoCarregou(caminhoDoModelo.path)
        }
        caixa.ponteiro = ponteiro
    }

    /// Libera o modelo. Chamado sob pressão de memória — ver `CicloDeVidaDeModelos`.
    public func descarregar() {
        if let ponteiro = caixa.ponteiro { whisper_free(ponteiro) }
        caixa.ponteiro = nil
    }

    /// Transcreve amostras PCM Float32 mono 16 kHz.
    ///
    /// - Parameter idioma: código ISO-639-1 (`"pt"`). O peso large-v3 é
    ///   multilíngue; não há gestão de asset de locale — por isso o protocolo
    ///   `TranscriptionEngine` não tem parâmetro de locale.
    public func transcrever(
        amostras: [Float],
        idioma: String = "pt",
        threads: Int32 = Int32(max(1, ProcessInfo.processInfo.activeProcessorCount - 2))
    ) throws -> [SegmentoWhisper] {
        guard !amostras.isEmpty else { throw ErroWhisper.audioVazio }
        try carregar()
        guard let contexto else { throw ErroWhisper.modeloNaoCarregou(caminhoDoModelo.path) }

        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.n_threads = threads
        params.translate = false
        params.no_timestamps = false
        params.single_segment = false
        // Nada de imprimir: a saída do whisper.cpp vai para stdout e polui a UI
        // e os logs do app.
        params.print_progress = false
        params.print_realtime = false
        params.print_timestamps = false
        params.print_special = false
        params.suppress_blank = true

        let codigo: Int32 = idioma.withCString { ponteiroIdioma in
            params.language = ponteiroIdioma
            return amostras.withUnsafeBufferPointer { buffer in
                whisper_full(contexto, params, buffer.baseAddress, Int32(buffer.count))
            }
        }
        guard codigo == 0 else { throw ErroWhisper.falhaNaTranscricao(codigo) }

        let total = whisper_full_n_segments(contexto)
        var segmentos: [SegmentoWhisper] = []
        segmentos.reserveCapacity(Int(total))

        for indice in 0..<total {
            guard let cTexto = whisper_full_get_segment_text(contexto, indice) else { continue }
            let texto = String(cString: cTexto).trimmingCharacters(in: .whitespaces)
            guard !texto.isEmpty else { continue }

            // Os timestamps vêm em centésimos de segundo.
            let t0 = TimeInterval(whisper_full_get_segment_t0(contexto, indice)) / 100
            let t1 = TimeInterval(whisper_full_get_segment_t1(contexto, indice)) / 100

            segmentos.append(SegmentoWhisper(start: t0, end: t1, texto: texto))
        }
        return segmentos
    }

    /// Capacidades do build, para diagnóstico.
    public nonisolated var systemInfo: String { WhisperRuntime.systemInfo }
}
