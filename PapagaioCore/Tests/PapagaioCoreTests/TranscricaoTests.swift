import AVFoundation
import Foundation
import Testing
import WhisperRuntime
@testable import PapagaioCore

/// Os testes que carregam o peso de 3 GB só rodam se ele estiver na máquina.
/// Em CI sem o modelo, eles são pulados em vez de falharem.
private var modeloWhisper: URL? {
    let caminho = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent("Documents/InterviewLab/Models")
        .appendingPathComponent(Pesos.whisperLargeV3.nomeArquivo)
    return FileManager.default.fileExists(atPath: caminho.path) ? caminho : nil
}

private var audioDeTeste: URL? {
    let caminho = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent("Documents/InterviewLab/Audio")
        .appendingPathComponent("entrevista-2026-07-27T20-12-00Z.wav")
    return FileManager.default.fileExists(atPath: caminho.path) ? caminho : nil
}

// MARK: - Decodificação

@Test("Decodificador entrega 16 kHz mono, reamostrando quando precisa")
func decodificadorReamostra() async throws {
    let pasta = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: pasta) }

    // 2 s de seno a 44,1 kHz.
    let taxa: Double = 44_100
    let formato = AVAudioFormat(
        commonFormat: .pcmFormatFloat32, sampleRate: taxa, channels: 1, interleaved: false
    )!
    let destino = pasta.appendingPathComponent("tom.wav")
    // O `AVAudioFile` de escrita precisa ser liberado antes da leitura: ele só
    // finaliza o arquivo no `deinit`. Ler com ele ainda vivo devolve um arquivo
    // truncado, sem erro nenhum.
    do {
        let arquivo = try AVAudioFile(forWriting: destino, settings: formato.settings)
        let quadros = AVAudioFrameCount(taxa * 2)
        let buffer = AVAudioPCMBuffer(pcmFormat: formato, frameCapacity: quadros)!
        buffer.frameLength = quadros
        let canal = buffer.floatChannelData![0]
        let doisPi: Double = 2 * Double.pi
        for quadro in 0..<Int(quadros) {
            let fase: Double = doisPi * 440 * Double(quadro) / taxa
            canal[quadro] = Float(0.25 * sin(fase))
        }
        try arquivo.write(from: buffer)
    }

    let amostras = try await DecodificadorDeAudio.amostras(de: destino)
    // 2 s a 16 kHz ≈ 32.000 amostras.
    #expect(amostras.count > 31_000)
    #expect(amostras.count < 33_000)
    #expect(abs(DecodificadorDeAudio.duracao(de: amostras) - 2) < 0.1)
}

@Test("Arquivo .pcm cru é lido sem conversão")
func decodificadorPCMCru() async throws {
    let pasta = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: pasta) }

    let original: [Float] = (0..<16_000).map { Float($0 % 100) / 100 }
    let destino = pasta.appendingPathComponent("canal.pcm")
    try original.withUnsafeBufferPointer { Data(buffer: $0) }.write(to: destino)

    let lidas = try await DecodificadorDeAudio.amostras(de: destino)
    #expect(lidas.count == original.count)
    #expect(lidas.first == original.first)
    #expect(lidas.last == original.last)
    #expect(abs(DecodificadorDeAudio.duracao(de: lidas) - 1) < 0.001)
}

@Test("VAD recusa silêncio e aceita fala com energia sustentada")
func detectorDeAtividadeDeVoz() {
    let silencio = [Float](repeating: 0, count: 16_000)
    let fala = [Float](repeating: 0.02, count: 16_000)

    #expect(!DetectorDeAtividadeDeVoz.contemFala(nas: silencio))
    #expect(DetectorDeAtividadeDeVoz.contemFala(nas: fala))
}

// MARK: - Transcrição real

/// Testes que carregam os 3 GB do Whisper.
///
/// `.serialized`: o swift-testing roda em paralelo por padrão, e dois modelos
/// grandes ao mesmo tempo estouram a GPU
/// (`kIOGPUCommandBufferCallbackErrorOutOfMemory`) numa máquina de 24 GB.
@Suite(.serialized)
struct TestesComModeloWhisper {
    @Test("WhisperEngine transcreve áudio real em PT-BR, in-process",
          .enabled(if: modeloWhisper != nil && audioDeTeste != nil),
          .timeLimit(.minutes(5)))
    func transcricaoReal() async throws {
        let engine = WhisperEngine(modelo: try #require(modeloWhisper))
        let trechos = try await engine.transcribe(try #require(audioDeTeste), speaker: Speaker.eu)

        #expect(trechos.count > 10)

        // Todo trecho tem tempo válido e crescente.
        var anterior: TimeInterval = -1
        for trecho in trechos {
            #expect(trecho.end >= trecho.start)
            #expect(trecho.start >= anterior)
            #expect(!trecho.texto.isEmpty)
            #expect(trecho.speaker == Speaker.eu)
            anterior = trecho.start
        }

        // Conteúdo reconhecível: o áudio fala de orçamento e prazo.
        let tudo = trechos.map(\.texto).joined(separator: " ").lowercased()
        #expect(tudo.contains("reunião"))
        #expect(tudo.contains("fornecedor"))
        // Números são o que mais quebra em ASR — este é o teste que importa.
        #expect(tudo.contains("1.730") || tudo.contains("1730"))

        await engine.descarregar()
    }

    @Test("Chamadas concorrentes ao mesmo contexto serializam sem corromper",
          .enabled(if: modeloWhisper != nil),
          .timeLimit(.minutes(5)))
    func contextoConcorrente() async throws {
        // `whisper_context` não é thread-safe. O ator tem que serializar.
        let contexto = ContextoWhisper(modelo: try #require(modeloWhisper))
        try await contexto.carregar()

        // 3 s de silêncio: barato, e o que importa aqui é não crashar nem vazar.
        let amostras = [Float](repeating: 0, count: 16_000 * 3)

        let resultados = await withTaskGroup(of: Int.self) { grupo in
            for _ in 0..<4 {
                grupo.addTask {
                    (try? await contexto.transcrever(amostras: amostras))?.count ?? -1
                }
            }
            var contagens: [Int] = []
            for await contagem in grupo { contagens.append(contagem) }
            return contagens
        }

        #expect(resultados.count == 4)
        // Nenhuma chamada pode ter falhado.
        #expect(resultados.allSatisfy { $0 >= 0 })
        #expect(await contexto.carregado)

        await contexto.descarregar()
        #expect(await !contexto.carregado)
    }

    @Test("Áudio vazio é recusado em vez de virar transcrição fantasma",
          .enabled(if: modeloWhisper != nil))
    func audioVazio() async throws {
        let contexto = ContextoWhisper(modelo: try #require(modeloWhisper))
        await #expect(throws: ErroWhisper.self) {
            _ = try await contexto.transcrever(amostras: [])
        }
    }

    @Test("Modelo inexistente falha ao carregar, sem crashar")
    func modeloInexistente() async {
        let contexto = ContextoWhisper(
            modelo: URL(fileURLWithPath: "/nao/existe/modelo.bin")
        )
        await #expect(throws: ErroWhisper.self) {
            try await contexto.carregar()
        }
    }
}
