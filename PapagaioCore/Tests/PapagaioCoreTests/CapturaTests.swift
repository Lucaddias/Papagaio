import AVFoundation
import Foundation
import Testing
@testable import PapagaioCore

// Testes do Passo 2, atualizados para o backend do Eko. Cobrem o que dá para
// verificar sem microfone, sem permissão de TCC e sem uma reunião real: o
// medidor de nível, os caminhos sob sandbox, os formatos de gravação e a
// importação de arquivo.
//
// O que NÃO dá para testar aqui está listado no relatório do passo: gravação
// de chamada real, subida do `SystemAudioTap`, inteligibilidade das duas
// vozes e ausência de alocação nos blocos de tap (isso é Instruments, não
// teste unitário).

// MARK: - Nível

@Test("NivelAudio calcula RMS e normaliza em dB")
func nivelRMS() {
    let nivel = NivelAudio()
    let amostras = [Float](repeating: 0.5, count: 100)
    amostras.withUnsafeBufferPointer { nivel.registrar($0.baseAddress!, quantidade: 100) }

    #expect(abs(nivel.rms - 0.5) < 0.0001)
    // 0,5 linear ≈ -6 dBFS → (−6+60)/60 = 0,9
    #expect(abs(nivel.normalizado - 0.9) < 0.01)

    let silencio = NivelAudio()
    let zeros = [Float](repeating: 0, count: 10)
    zeros.withUnsafeBufferPointer { silencio.registrar($0.baseAddress!, quantidade: 10) }
    #expect(silencio.normalizado == 0)
}

@Test("NivelAudio aceita valor normalizado do medidor do AVAudioRecorder")
func nivelDefinidoNormalizado() {
    let nivel = NivelAudio()
    nivel.definirNormalizado(0.9)
    #expect(abs(nivel.normalizado - 0.9) < 0.01)

    nivel.definirNormalizado(0)
    #expect(nivel.normalizado == 0)

    // O medidor entrega dB reais; 0 dBFS vira 1, e o clamp protege a UI.
    nivel.definirNormalizado(2)
    #expect(nivel.normalizado == 1)
    nivel.definirNormalizado(-1)
    #expect(nivel.normalizado == 0)
}

// MARK: - Formato de gravação

@Test("Formato do microfone é WAV PCM 16 kHz mono de 16 bits")
func formatoMicrofone() {
    let formato = FormatoAudio.microfoneWAV
    #expect(formato[AVFormatIDKey] as? UInt32 == kAudioFormatLinearPCM)
    #expect(formato[AVSampleRateKey] as? Double == FormatoAudio.taxaCanonica)
    #expect(formato[AVNumberOfChannelsKey] as? Int == 1)
    #expect(formato[AVLinearPCMBitDepthKey] as? Int == 16)
    #expect(formato[AVLinearPCMIsFloatKey] as? Bool == false)
}

@Test("Gravação mais curta que 1 s é descartada como clique acidental")
func duracaoMinima() {
    #expect(SessaoGravacao.duracaoMinima == 1.0)
}

// MARK: - Armazenamento

@Test("Caminho da gravação é relativo e fica sob a raiz")
func armazenamentoCaminhoRelativo() throws {
    let temporaria = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: temporaria) }

    let armazenamento = Armazenamento(raiz: temporaria)
    let id = UUID()

    let relativo = Armazenamento.caminhoRelativo(id: id)
    #expect(!relativo.hasPrefix("/"))
    #expect(relativo == "Gravacoes/\(id.uuidString)")

    let pasta = try armazenamento.criarPastaDaGravacao(id: id)
    #expect(FileManager.default.fileExists(atPath: pasta.path))
    #expect(pasta.path.hasPrefix(temporaria.path))

    // O caminho relativo guardado no modelo resolve de volta para a mesma pasta.
    #expect(armazenamento.resolver(relativo: relativo).standardizedFileURL == pasta.standardizedFileURL)
}

@Test("Arquivos de áudio canônicos nascem com os nomes da nova convenção")
func armazenamentoArquivosCanonicos() throws {
    let temporaria = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: temporaria) }

    let armazenamento = Armazenamento(raiz: temporaria)
    let id = UUID()

    let microfone = try armazenamento.criarArquivoDeAudio(id: id, nome: Armazenamento.Nome.microfone)
    #expect(microfone.lastPathComponent == "microfone.wav")
    #expect(microfone.deletingLastPathComponent().lastPathComponent == id.uuidString)
    #expect(FileManager.default.fileExists(atPath: microfone.deletingLastPathComponent().path))

    let sistema = try armazenamento.criarArquivoDeAudio(id: id, nome: Armazenamento.Nome.sistema)
    #expect(sistema.lastPathComponent == "sistema.caf")

    let importado = try armazenamento.criarArquivoImportado(id: id, extensao: "m4a")
    #expect(importado.lastPathComponent == "gravacao.m4a")
    let importadoWav = try armazenamento.criarArquivoImportado(id: id, extensao: "wav")
    #expect(importadoWav.lastPathComponent == "gravacao.wav")
}

// MARK: - Importação

/// Gera um `.m4a` real de teste: um seno de 440 Hz, 2 s, 44,1 kHz mono.
private func gerarAudioDeTeste(em destino: URL, segundos: Double = 2) throws {
    let taxa: Double = 44_100
    let formato = AVAudioFormat(
        commonFormat: .pcmFormatFloat32, sampleRate: taxa, channels: 1, interleaved: false
    )!
    let arquivo = try AVAudioFile(
        forWriting: destino,
        settings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: taxa,
            AVNumberOfChannelsKey: 1,
        ]
    )

    let quadros = AVAudioFrameCount(taxa * segundos)
    let buffer = AVAudioPCMBuffer(pcmFormat: formato, frameCapacity: quadros)!
    buffer.frameLength = quadros
    let canal = buffer.floatChannelData![0]
    let doisPi: Double = 2 * Double.pi
    let frequencia: Double = 440
    for quadro in 0..<Int(quadros) {
        let fase: Double = doisPi * frequencia * Double(quadro) / taxa
        canal[quadro] = Float(0.3 * sin(fase))
    }
    try arquivo.write(from: buffer)
}

@Test("Importa .m4a externo copiando como veio, sem re-encodar")
func importacaoCopiaParaContainer() async throws {
    let temporaria = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: temporaria, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaria) }

    let origem = temporaria.appendingPathComponent("entrevista-externa.m4a")
    try gerarAudioDeTeste(em: origem)

    let armazenamento = Armazenamento(raiz: temporaria.appendingPathComponent("container"))
    let importador = ImportadorAudio(armazenamento: armazenamento)
    let resultado = try await importador.importar(de: origem)

    #expect(resultado.tituloSugerido == "entrevista-externa")
    #expect(abs(resultado.duracao - 2) < 0.5)
    #expect(resultado.bytes > 0)
    #expect(!resultado.pastaRelativa.hasPrefix("/"))

    // O arquivo tem que estar dentro do container, não ser referência ao original.
    let destino = armazenamento
        .resolver(relativo: resultado.pastaRelativa)
        .appendingPathComponent("gravacao.m4a")
    #expect(FileManager.default.fileExists(atPath: destino.path))

    // E tem que ter sido copiado no formato original, sem conversão — a
    // conversão acontece na leitura (`DecodificadorDeAudio`), não na importação.
    let copiado = try AVAudioFile(forReading: destino)
    #expect(copiado.fileFormat.sampleRate == 44_100)
    #expect(copiado.fileFormat.channelCount == 1)
}

@Test("Importação recusa arquivo que não tem trilha de áudio")
func importacaoRecusaArquivoInvalido() async throws {
    let temporaria = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: temporaria, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaria) }

    let falso = temporaria.appendingPathComponent("nao-e-audio.m4a")
    try Data("isto não é áudio".utf8).write(to: falso)

    let importador = ImportadorAudio(
        armazenamento: Armazenamento(raiz: temporaria.appendingPathComponent("container"))
    )

    await #expect(throws: (any Error).self) {
        _ = try await importador.importar(de: falso)
    }
}
