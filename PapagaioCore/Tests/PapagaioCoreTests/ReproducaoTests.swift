import AVFoundation
import Foundation
import Testing
@testable import PapagaioCore

// Testes do Passo 10 — player e navegação por trecho.
//
// O que dá para verificar aqui: o salto pousa no ponto certo (inclusive no
// último trecho), o observador periódico publica o tempo, o destaque segue o
// tempo e `encerrar()` não deixa observador vivo. O que **não** dá: o clique do
// mouse e a impressão de "acompanhar sem travar" — isso é olho no app.

// MARK: - Navegação (sem áudio)

private let trechosDeExemplo: [Trecho] = [
    Trecho(start: 0, end: 5, texto: "primeiro", speaker: Speaker.eu),
    Trecho(start: 5, end: 10, texto: "segundo", speaker: Speaker.interlocutor),
    // Buraco de 2 s: silêncio entre trechos.
    Trecho(start: 12, end: 20, texto: "terceiro", speaker: Speaker.eu),
]

@Test("Lista vazia e tempo antes do primeiro trecho não destacam nada")
func navegacaoSemDestaque() {
    #expect(NavegacaoPorTrecho.indiceAtivo(em: 3, trechos: []) == nil)

    let comSilencioInicial = [Trecho(start: 4.2, end: 9, texto: "fala")]
    #expect(NavegacaoPorTrecho.indiceAtivo(em: 0, trechos: comSilencioInicial) == nil)
    #expect(NavegacaoPorTrecho.indiceAtivo(em: 4.19, trechos: comSilencioInicial) == nil)
    #expect(NavegacaoPorTrecho.indiceAtivo(em: 4.2, trechos: comSilencioInicial) == 0)
}

@Test("O destaque acompanha o tempo, inclusive na borda de cada trecho")
func navegacaoAcompanha() {
    #expect(NavegacaoPorTrecho.indiceAtivo(em: 0, trechos: trechosDeExemplo) == 0)
    #expect(NavegacaoPorTrecho.indiceAtivo(em: 4.99, trechos: trechosDeExemplo) == 0)
    #expect(NavegacaoPorTrecho.indiceAtivo(em: 5, trechos: trechosDeExemplo) == 1)
    #expect(NavegacaoPorTrecho.indiceAtivo(em: 12.5, trechos: trechosDeExemplo) == 2)
    #expect(NavegacaoPorTrecho.trechoAtivo(em: 12.5, trechos: trechosDeExemplo)?.texto == "terceiro")
}

@Test("Silêncio entre trechos mantém o destaque no que acabou de tocar")
func navegacaoNoSilencio() {
    // 10 s → 12 s é buraco. Sumir com o destaque aqui pareceria defeito (D-10.2).
    #expect(NavegacaoPorTrecho.indiceAtivo(em: 11, trechos: trechosDeExemplo) == 1)
    // Depois do fim do último, o destaque fica no último.
    #expect(NavegacaoPorTrecho.indiceAtivo(em: 99, trechos: trechosDeExemplo) == 2)
}

// MARK: - Player com áudio real

/// Gera um `.m4a` no mesmo formato de arquivamento da captura (AAC 16 kHz mono).
///
/// A frequência do tom sobe a cada segundo — não é decorativo: é o que permite
/// conferir de ouvido, no app, que o salto pousou onde devia.
private func gerarM4A(segundos: Double, em pasta: URL) throws -> URL {
    let destino = pasta.appendingPathComponent("gravacao.m4a")
    let formato = FormatoAudio.canonico
    let taxa = FormatoAudio.taxaCanonica

    // O `AVAudioFile` de escrita só finaliza o arquivo no `deinit` — ler com ele
    // vivo devolve arquivo truncado, sem erro (mesma armadilha do Passo 4).
    do {
        let arquivo = try AVAudioFile(forWriting: destino, settings: FormatoAudio.arquivamento)
        let porBloco = AVAudioFrameCount(taxa)  // 1 s por bloco
        var escritos = 0.0
        while escritos < segundos {
            let buffer = AVAudioPCMBuffer(pcmFormat: formato, frameCapacity: porBloco)!
            buffer.frameLength = porBloco
            let canal = buffer.floatChannelData![0]
            let hertz = 220.0 + 40.0 * escritos
            for quadro in 0..<Int(porBloco) {
                let fase = 2 * Double.pi * hertz * Double(quadro) / taxa
                canal[quadro] = Float(0.2 * sin(fase))
            }
            try arquivo.write(from: buffer)
            escritos += 1
        }
    }
    return destino
}

@MainActor
@Suite(.serialized)
struct TestesDoPlayer {
    @Test("Salto pousa no início do trecho, inclusive no último", .timeLimit(.minutes(1)))
    func saltoPousaNoTrecho() async throws {
        let pasta = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: pasta) }

        let audio = try gerarM4A(segundos: 20, em: pasta)
        let player = ReprodutorDeArquivo(audio: audio, trechos: trechosDeExemplo)
        await player.preparar()
        #expect(abs(player.duracao - 20) < 0.5, "duração lida: \(player.duracao)")

        // Os três cliques do teste do passo — o terceiro é o último trecho.
        for indice in [0, 1, 2] {
            let trecho = trechosDeExemplo[indice]
            await player.saltar(para: trecho)
            #expect(abs(player.tempo - trecho.start) < 0.15,
                    "trecho \(indice): pediu \(trecho.start) s, pousou em \(player.tempo) s")
            #expect(player.indiceAtivo == indice)
        }

        await player.tocar(aPartirDe: trechosDeExemplo[1])
        #expect(player.tocando)
        #expect(abs(player.tempo - trechosDeExemplo[1].start) < 0.15)
        player.pausar()
    }

    @Test("Tocar publica o tempo pelo observador periódico", .timeLimit(.minutes(1)))
    func observadorPublicaTempo() async throws {
        let pasta = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: pasta) }

        let audio = try gerarM4A(segundos: 20, em: pasta)
        let player = ReprodutorDeArquivo(audio: audio, trechos: trechosDeExemplo)
        await player.preparar()

        await player.saltar(paraSegundo: 4.6)
        #expect(player.indiceAtivo == 0)

        player.tocar()
        #expect(player.tocando)

        // O AVPlayer pode levar alguns ticks para sair do estado de preparação,
        // especialmente quando a suite acabou de inicializar outros recursos de
        // AVFoundation. Esperar um período fixo de 900 ms tornava o teste
        // dependente do agendamento da máquina, não do observador. O critério
        // real é a posição atravessar a fronteira do segundo trecho.
        for _ in 0..<30 where player.tempo <= 5.0 {
            try await Task.sleep(for: .milliseconds(100))
        }

        // Cruzou a fronteira do trecho seguinte dentro de 3 s.
        #expect(player.tempo > 5.0, "tempo depois de até 3 s tocando: \(player.tempo)")
        #expect(player.indiceAtivo == 1)

        player.pausar()
        #expect(!player.tocando)
        let parado = player.tempo
        try await Task.sleep(for: .milliseconds(300))
        // Uma última chamada do observador ainda chega com o tempo em que o
        // player de fato parou — medido em ~31 ms além do `pausar()`. O que não
        // pode acontecer é o tempo continuar andando: em 300 ms parado, a folga
        // de um intervalo de observação (0,1 s) é generosa.
        #expect(player.tempo - parado < 0.1,
                "andou \(player.tempo - parado) s depois do pausar")
    }

    @Test("encerrar() não deixa observador vivo", .timeLimit(.minutes(1)))
    func encerrarRemoveObservador() async throws {
        let pasta = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: pasta) }

        let audio = try gerarM4A(segundos: 5, em: pasta)
        let player = ReprodutorDeArquivo(audio: audio, trechos: trechosDeExemplo)
        await player.preparar()
        #expect(player.observando)

        player.tocar()
        try await Task.sleep(for: .milliseconds(300))
        player.encerrar()

        #expect(!player.observando)
        #expect(!player.tocando)

        // Depois de encerrado, nada mais publica tempo.
        let ultimo = player.tempo
        try await Task.sleep(for: .milliseconds(400))
        #expect(player.tempo == ultimo, "o observador continuou publicando depois do encerrar()")

        // Encerrar duas vezes não pode explodir — `onDisappear` pode repetir.
        player.encerrar()
    }
}
