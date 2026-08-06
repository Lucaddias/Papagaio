import Foundation
// `internal`: o módulo C não vaza para quem importa este target. Ver D-3.2.
internal import whisper

/// Uma palavra com timestamps reais do Whisper (`token_timestamps`).
///
/// Os tempos vêm em centésimos de segundo, como os do segmento. O agrupamento
/// dos tokens em palavras é do `ContextoWhisper` — aqui só viaja o valor.
public struct PalavraWhisper: Sendable, Equatable {
    public let start: TimeInterval
    public let end: TimeInterval
    public let texto: String

    public init(start: TimeInterval, end: TimeInterval, texto: String) {
        self.start = start
        self.end = end
        self.texto = texto
    }
}

/// Um segmento nativo do Whisper. Tipo Swift puro — nenhum tipo do ggml
/// atravessa a fronteira deste target, que é o que permite o `internal import`.
public struct SegmentoWhisper: Sendable, Equatable {
    public let start: TimeInterval
    public let end: TimeInterval
    public let texto: String
    /// Palavras com timestamps próprios, na ordem da fala.
    public let palavras: [PalavraWhisper]

    public init(
        start: TimeInterval,
        end: TimeInterval,
        texto: String,
        palavras: [PalavraWhisper] = []
    ) {
        self.start = start
        self.end = end
        self.texto = texto
        self.palavras = palavras
    }
}

public enum ErroWhisper: Error, CustomStringConvertible {
    case modeloNaoCarregou(String)
    case falhaNaTranscricao(Int32)
    case audioVazio
    case semFalaDetectada

    public var description: String {
        switch self {
        case let .modeloNaoCarregou(caminho):
            "não foi possível carregar o modelo em \(caminho)"
        case let .falhaNaTranscricao(codigo):
            "whisper_full falhou (código \(codigo))"
        case .audioVazio:
            "áudio sem amostras"
        case .semFalaDetectada:
            "não foi detectada fala suficiente neste áudio"
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
        initialPrompt: String? = nil,
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
        // Uma hipótese ruim não pode contaminar janelas posteriores e virar
        // repetição em cascata durante silêncio ou ruído.
        params.no_context = true
        // Timestamps por token: é o que permite destacar a palavra exata que
        // está tocando (a UI não cai em divisão do tempo do trecho). O large-v3
        // foi treinado com timestamps de palavra, então o `t0`/`t1` dos tokens
        // é medido, não estimado por distribuição.
        params.token_timestamps = true

        let codigo: Int32
        if let initialPrompt, !initialPrompt.isEmpty {
            codigo = initialPrompt.withCString { prompt in
                idioma.withCString { ponteiroIdioma in
                    params.initial_prompt = prompt
                    params.language = ponteiroIdioma
                    return amostras.withUnsafeBufferPointer { buffer in
                        whisper_full(contexto, params, buffer.baseAddress, Int32(buffer.count))
                    }
                }
            }
        } else {
            codigo = idioma.withCString { ponteiroIdioma in
                params.language = ponteiroIdioma
                return amostras.withUnsafeBufferPointer { buffer in
                    whisper_full(contexto, params, buffer.baseAddress, Int32(buffer.count))
                }
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

            segmentos.append(SegmentoWhisper(
                start: t0,
                end: t1,
                texto: texto,
                palavras: palavrasDoSegmento(indice)
            ))
        }
        return segmentos
    }

    /// Agrupa os tokens do segmento em palavras, na ordem da fala.
    ///
    /// O tokenizer do Whisper prefixa o espaço à token que **abre** uma palavra
    /// (`" olá"`, `" mundo"`); as tokens seguintes sem espaço (`"lá"`) são
    /// fragmentos da mesma palavra (BPE). Combinar um espaço à frente →
    /// palavra nova reproduz o desmembramento de frase do próprio whisper.cpp.
    ///
    /// `t0`/`t1` de cada token são medidos em centésimos: a palavra herda o
    /// início da primeira token e o fim da última.
    private func palavrasDoSegmento(_ indice: Int32) -> [PalavraWhisper] {
        let total = whisper_full_n_tokens(contexto, indice)
        guard total > 0 else { return [] }

        var palavras: [PalavraWhisper] = []
        palavras.reserveCapacity(Int(total))
        var textoDaPalavra = ""
        var inicioDaPalavra: TimeInterval = 0
        var fimDaPalavra: TimeInterval = 0

        func fecharPalavra() {
            guard !textoDaPalavra.isEmpty else { return }
            palavras.append(PalavraWhisper(
                start: inicioDaPalavra,
                end: fimDaPalavra,
                texto: textoDaPalavra
            ))
            textoDaPalavra = ""
        }

for token in 0..<total {
            let dados = whisper_full_get_token_data(contexto, indice, token)

            // Tokens especiais não são fala — timestamps, controle (`<|SOT|>`),
            // idiomas, etc. Todos têm id a partir do `eot`. Filtra-se por **id**,
            // nunca pelo texto: este build do whisper.cpp os renderiza como
            // `[_BEG_]` e `[_TT_88]`, sem o `<|` do vocabulário, e o filtro de
            // texto da primeira tentativa os vazou para as palavras mostradas.
            guard dados.id < whisper_token_eot(contexto) else { continue }

            guard let cToken = whisper_full_get_token_text(contexto, indice, token) else { continue }
            let textoDoToken = String(cString: cToken)
            let t0 = TimeInterval(dados.t0) / 100
            let t1 = TimeInterval(dados.t1) / 100

            if textoDoToken.hasPrefix(" ") {
                fecharPalavra()
                textoDaPalavra = textoDoToken.trimmingCharacters(in: .whitespaces)
                inicioDaPalavra = t0
                fimDaPalavra = t1
            } else {
                textoDaPalavra += textoDoToken
                fimDaPalavra = t1
            }
        }
        fecharPalavra()
        return palavras
    }

    /// Capacidades do build, para diagnóstico.
    public nonisolated var systemInfo: String { WhisperRuntime.systemInfo }
}
