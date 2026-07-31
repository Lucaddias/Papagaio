import AVFoundation
import Foundation

/// Lê qualquer arquivo de áudio e devolve amostras no formato que o Whisper
/// consome: PCM Float32 **mono 16 kHz**.
///
/// O Whisper não reamostra por conta própria — mandar 48 kHz produz uma
/// transcrição de lixo, não um erro. Por isso a conversão é obrigatória aqui.
public enum DecodificadorDeAudio {
    /// Arquivos `.pcm` do Papagaio já são Float32 mono 16 kHz crus (é o que a
    /// `SessaoGravacao` escreve por canal). Ler é só reinterpretar os bytes.
    public static let extensaoCrua = "pcm"

    public static func amostras(de url: URL) throws -> [Float] {
        if url.pathExtension.lowercased() == extensaoCrua {
            return try amostrasCruas(de: url)
        }
        return try amostrasDecodificadas(de: url)
    }

    private static func amostrasCruas(de url: URL) throws -> [Float] {
        let dados = try Data(contentsOf: url, options: .mappedIfSafe)
        guard !dados.isEmpty else { return [] }
        return dados.withUnsafeBytes { bruto in
            Array(bruto.bindMemory(to: Float.self))
        }
    }

    private static func amostrasDecodificadas(de url: URL) throws -> [Float] {
        let arquivo = try AVAudioFile(forReading: url)
        let formatoDoArquivo = arquivo.processingFormat
        let quadros = AVAudioFrameCount(arquivo.length)
        guard quadros > 0 else { return [] }

        guard let entrada = AVAudioPCMBuffer(pcmFormat: formatoDoArquivo, frameCapacity: quadros)
        else { throw ErroCaptura.arquivoInvalido("não foi possível alocar buffer de leitura") }
        try arquivo.read(into: entrada)

        // Já está no formato canônico? Devolve direto.
        let canonico = FormatoAudio.canonico
        if formatoDoArquivo.sampleRate == canonico.sampleRate,
           formatoDoArquivo.channelCount == 1,
           let canal = entrada.floatChannelData {
            return Array(UnsafeBufferPointer(start: canal[0], count: Int(entrada.frameLength)))
        }

        guard let conversor = AVAudioConverter(from: formatoDoArquivo, to: canonico) else {
            throw ErroCaptura.arquivoInvalido("sem conversor de \(formatoDoArquivo) para 16 kHz mono")
        }

        // `convert(to:error:withInputFrom:)` **não consome todo o input numa
        // chamada** — ele preenche o buffer de saída e volta. Com um arquivo
        // inteiro na entrada, uma única chamada devolve só o primeiro pedaço, e
        // o resto do áudio some sem erro nenhum. Por isso o laço.
        let razao = canonico.sampleRate / formatoDoArquivo.sampleRate
        let estimativa = Int(Double(entrada.frameLength) * razao) + 4096
        var acumulado = [Float]()
        acumulado.reserveCapacity(estimativa)

        var jaEntregue = false
        let porChamada = AVAudioFrameCount(min(estimativa, 1 << 18))

        while true {
            guard let saida = AVAudioPCMBuffer(pcmFormat: canonico, frameCapacity: porChamada)
            else { throw ErroCaptura.arquivoInvalido("não foi possível alocar buffer de saída") }

            var erro: NSError?
            let status = conversor.convert(to: saida, error: &erro) { _, statusEntrada in
                if jaEntregue {
                    statusEntrada.pointee = .endOfStream
                    return nil
                }
                jaEntregue = true
                statusEntrada.pointee = .haveData
                return entrada
            }

            if status == .error {
                throw ErroCaptura.arquivoInvalido(erro?.localizedDescription ?? "conversão falhou")
            }
            if let canal = saida.floatChannelData, saida.frameLength > 0 {
                acumulado.append(contentsOf: UnsafeBufferPointer(
                    start: canal[0], count: Int(saida.frameLength)
                ))
            }
            if status == .endOfStream || status == .inputRanDry || saida.frameLength == 0 {
                break
            }
        }
        return acumulado
    }

    /// Duração em segundos de um vetor de amostras no formato canônico.
    public static func duracao(de amostras: [Float]) -> TimeInterval {
        TimeInterval(amostras.count) / FormatoAudio.taxaCanonica
    }
}
