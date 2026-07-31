import AVFoundation
import Foundation
import Testing
@testable import PapagaioCore

// Testes do Passo 2. Cobrem o que dá para verificar sem microfone, sem
// permissão de TCC e sem uma reunião real: o ring buffer, os caminhos sob
// sandbox, o medidor de nível, a reamostragem e a importação de arquivo.
//
// O que NÃO dá para testar aqui está listado no relatório do passo: gravação
// de chamada real, inteligibilidade das duas vozes e ausência de alocação nos
// blocos de tap (isso é Instruments, não teste unitário).

// MARK: - Ring buffer

@Test("Ring buffer devolve na ordem o que foi escrito")
func ringBufferOrdem() {
    let buffer = RingBufferAudio(capacidade: 16)
    var entrada: [Float] = [1, 2, 3, 4, 5]
    entrada.withUnsafeBufferPointer { _ = buffer.escrever($0.baseAddress!, quantidade: 5) }

    #expect(buffer.pendentes == 5)

    var saida = [Float](repeating: 0, count: 5)
    let lidas = saida.withUnsafeMutableBufferPointer {
        buffer.ler(para: $0.baseAddress!, quantidade: 5)
    }

    #expect(lidas == 5)
    #expect(saida == entrada)
    #expect(buffer.pendentes == 0)
}

@Test("Ring buffer dá a volta sem embaralhar as amostras")
func ringBufferCircular() {
    let buffer = RingBufferAudio(capacidade: 8)

    // Enche, esvazia parcialmente e escreve de novo para forçar o wrap.
    var primeiro = [Float](repeating: 0, count: 6)
    for i in 0..<6 { primeiro[i] = Float(i) }
    primeiro.withUnsafeBufferPointer { _ = buffer.escrever($0.baseAddress!, quantidade: 6) }

    var descarte = [Float](repeating: 0, count: 4)
    _ = descarte.withUnsafeMutableBufferPointer { buffer.ler(para: $0.baseAddress!, quantidade: 4) }

    var segundo: [Float] = [100, 101, 102, 103]
    segundo.withUnsafeBufferPointer { _ = buffer.escrever($0.baseAddress!, quantidade: 4) }

    var saida = [Float](repeating: 0, count: 6)
    let lidas = saida.withUnsafeMutableBufferPointer {
        buffer.ler(para: $0.baseAddress!, quantidade: 6)
    }

    #expect(lidas == 6)
    #expect(saida == [4, 5, 100, 101, 102, 103])
}

@Test("Ring buffer cheio descarta e contabiliza, em vez de corromper")
func ringBufferDescarte() {
    let buffer = RingBufferAudio(capacidade: 4)
    var entrada: [Float] = [1, 2, 3, 4, 5, 6]

    let coube = entrada.withUnsafeBufferPointer {
        buffer.escrever($0.baseAddress!, quantidade: 6)
    }

    #expect(coube == false)
    #expect(buffer.amostrasDescartadas == 2)
    #expect(buffer.pendentes == 4)
}

// MARK: - Nível

@Test("NivelAudio calcula RMS e normaliza em dB")
func nivelRMS() {
    let nivel = NivelAudio()
    var amostras = [Float](repeating: 0.5, count: 100)
    amostras.withUnsafeBufferPointer { nivel.registrar($0.baseAddress!, quantidade: 100) }

    #expect(abs(nivel.rms - 0.5) < 0.0001)
    // 0,5 linear ≈ -6 dBFS → (−6+60)/60 = 0,9
    #expect(abs(nivel.normalizado - 0.9) < 0.01)

    let silencio = NivelAudio()
    var zeros = [Float](repeating: 0, count: 10)
    zeros.withUnsafeBufferPointer { silencio.registrar($0.baseAddress!, quantidade: 10) }
    #expect(silencio.normalizado == 0)
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

// MARK: - Conversão

@Test("Conversor reamostra 48 kHz para os 16 kHz canônicos")
func conversorReamostra() throws {
    let conversor = try #require(ConversorCanonico(taxaNativa: 48_000))

    // 48.000 amostras = 1 s a 48 kHz → ~16.000 amostras a 16 kHz.
    let entrada = [Float](repeating: 0.1, count: 48_000)
    let saida = conversor.converter(entrada)

    #expect(saida.count > 15_000)
    #expect(saida.count < 17_000)
}

@Test("Conversor recusa taxa inválida em vez de crashar")
func conversorTaxaInvalida() {
    #expect(ConversorCanonico(taxaNativa: 0) == nil)
    #expect(ConversorCanonico(taxaNativa: -1) == nil)
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

@Test("Importa .m4a externo, converte e copia para dentro do container")
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
        .appendingPathComponent(Armazenamento.Nome.mixagem)
    #expect(FileManager.default.fileExists(atPath: destino.path))

    // E tem que ter sido reescrito no formato canônico: mono, 16 kHz.
    let convertido = try AVAudioFile(forReading: destino)
    #expect(convertido.fileFormat.sampleRate == 16_000)
    #expect(convertido.fileFormat.channelCount == 1)
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
