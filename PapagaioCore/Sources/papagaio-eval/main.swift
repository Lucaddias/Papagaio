import Foundation
import LlamaRuntime
import PapagaioCore
import WhisperRuntime

// Passo 1: a CLI existe para provar que `PapagaioCore` é importável sem
// arrastar SwiftUI. O harness de medição real (WER, acurácia de entidades)
// chega no Passo 6.

let versao = "0.1.0-passo1"

func uso() {
    print("""
    papagaio-eval \(versao)

    USO:
      papagaio-eval contratos    imprime os contratos disponíveis
      papagaio-eval run          harness de medição — chega no Passo 6

    Nesta fase o binário só confirma que PapagaioCore linka fora do app.
    """)
}

let argumentos = Array(CommandLine.arguments.dropFirst())

switch argumentos.first {
case "contratos":
    let modelosPadrao = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent("Documents/InterviewLab/Models")
    let transcricao: any TranscriptionEngine = WhisperEngine(
        modelo: modelosPadrao.appendingPathComponent(Pesos.whisperLargeV3.nomeArquivo)
    )
    let resumo: any SummarizationEngine = QwenEngine(
        modelo: modelosPadrao.appendingPathComponent(Pesos.qwen14B.nomeArquivo)
    )
    print("TranscriptionEngine  -> \(transcricao.identifier)")
    print("SummarizationEngine  -> \(resumo.identifier)")
    print("ArquivoRepository    -> SwiftDataRepository (biblioteca local)")

case "runtime":
    let info = RuntimeInfo.coletar()
    print("whisper.cpp: \(info.whisperSystemInfo)")
    print("llama.cpp:   \(info.llamaSystemInfo)")
    print("Metal:       \(info.metalDisponivel ? "sim" : "NÃO")")

case "preflight":
    let pasta = argumentos.count > 1
        ? URL(fileURLWithPath: argumentos[1])
        : URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents/InterviewLab/Models")
    let verificar = argumentos.contains("--checksum")
    print("pasta: \(pasta.path)")
    print("RAM instalada: \(Preflight.ramInstalada / 1_073_741_824) GB (piso \(Preflight.ramMinima / 1_073_741_824) GB)")
    let pf = Preflight(pastaDeModelos: pasta)
    print("disco livre:   \(pf.discoLivre / 1_073_741_824) GB (piso \(Preflight.discoMinimo / 1_073_741_824) GB)")
    if verificar { print("verificando SHA-256 de 13,6 GB — leva um tempo…") }
    let r = pf.avaliar(verificarChecksum: verificar)
    print("resultado: \(r)")
    print("bloqueia:  \(r.bloqueia)")
    print("mensagem:  \(r.mensagem)")

case "transcrever":
    guard argumentos.count > 1 else {
        print("uso: papagaio-eval transcrever <audio> [--modelo <caminho>]")
        exit(2)
    }
    let audio = URL(fileURLWithPath: argumentos[1])
    let modelo: URL
    if let i = argumentos.firstIndex(of: "--modelo"), i + 1 < argumentos.count {
        modelo = URL(fileURLWithPath: argumentos[i + 1])
    } else {
        modelo = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Documents/InterviewLab/Models")
            .appendingPathComponent(Pesos.whisperLargeV3.nomeArquivo)
    }

    let amostras = try DecodificadorDeAudio.amostras(de: audio)
    let duracao = DecodificadorDeAudio.duracao(de: amostras)
    print("áudio:  \(audio.lastPathComponent)")
    print("modelo: \(modelo.lastPathComponent)")
    print(String(format: "duração: %.1f s (%d amostras a 16 kHz)", duracao, amostras.count))
    print("processos filhos antes: \(ContagemDeProcessos.filhos())")

    let engine = WhisperEngine(modelo: modelo)
    let relogio = ContinuousClock()
    let inicio = relogio.now
    let trechos = try await engine.transcribe(audio, speaker: Speaker.eu)
    let gasto = relogio.now - inicio

    print("processos filhos depois: \(ContagemDeProcessos.filhos())")
    print("tempo: \(gasto)")
    if duracao > 0 {
        let segundos = Double(gasto.components.seconds) + Double(gasto.components.attoseconds) / 1e18
        print(String(format: "fator de tempo real: %.2fx", duracao / segundos))
    }
    let agrupados = Segmentacao.agrupar(trechos)
    print("segmentos brutos: \(trechos.count)  →  trechos agrupados: \(agrupados.count)")
    let duracoes = agrupados.map { $0.end - $0.start }
    if let menor = duracoes.min(), let maior = duracoes.max() {
        let media = duracoes.reduce(0, +) / Double(duracoes.count)
        print(String(format: "duração dos trechos: min %.1f s · média %.1f s · max %.1f s",
                     menor, media, maior))
        let foraDaFaixa = duracoes.dropLast().filter { $0 < 20 || $0 > 60 }.count
        print("trechos fora de 20–60 s (ignorando o último): \(foraDaFaixa)")
    }
    print("primeiro trecho começa em \(String(format: "%.2f", agrupados.first?.start ?? 0)) s")
    print("--- trechos ---")
    for t in agrupados.prefix(6) {
        print(String(format: "  [%6.2f → %6.2f · %4.1fs] (%@) %@",
                     t.start, t.end, t.end - t.start, t.speaker ?? "—",
                     String(t.texto.prefix(90))))
    }
    if agrupados.count > 6 { print("  … mais \(agrupados.count - 6)") }
    print("--- segmentos brutos (amostra) ---")
    for t in trechos.prefix(4) {
        print(String(format: "  [%6.2f → %6.2f · %4.1fs] %@",
                     t.start, t.end, t.end - t.start, String(t.texto.prefix(70))))
    }

case "resumir":
    guard argumentos.count > 1 else {
        print("uso: papagaio-eval resumir <audio>")
        exit(2)
    }
    let audioR = URL(fileURLWithPath: argumentos[1])
    let modelos = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent("Documents/InterviewLab/Models")

    let engineW = WhisperEngine(modelo: modelos.appendingPathComponent(Pesos.whisperLargeV3.nomeArquivo))
    let brutos = try await engineW.transcribe(audioR, speaker: Speaker.eu)
    let trechosR = Segmentacao.agrupar(brutos)
    await engineW.descarregar()
    print("transcrição: \(brutos.count) segmentos → \(trechosR.count) trechos")

    let contextoQ = ContextoLlama(modelo: modelos.appendingPathComponent(Pesos.qwen14B.nomeArquivo))
    let engineQ = QwenEngine(contexto: contextoQ)
    let entrada = QwenEngine.formatar(trechosR)
    let nTokens = try await contextoQ.contarTokens(entrada)
    print("entrada: \(nTokens) tokens (teto de passe único: \(ContextoLlama.tetoDeEntrada))")
    print("modo: \(nTokens <= ContextoLlama.tetoDeEntrada ? "passe único" : "map-reduce")")

    let relogioQ = ContinuousClock()
    let inicioQ = relogioQ.now
    let resumoFinal: Resumo
    do {
        resumoFinal = try await engineQ.summarize(trechosR)
    } catch {
        FileHandle.standardError.write(Data("ERRO na sumarização: \(error)\n".utf8))
        await engineQ.descarregar()
        exit(3)
    }
    print("tempo de resumo: \(relogioQ.now - inicioQ)")
    print("engine: \(engineQ.identifier)")
    print()
    print("# \(resumoFinal.titulo)")
    print()
    print(resumoFinal.visaoGeral)
    print()
    print("## Temas")
    for t in resumoFinal.temas { print("- **\(t.titulo)** — \(t.detalhe)") }
    print("## Citações")
    for c in resumoFinal.citacoes {
        print("> \(c.texto)  [\(c.speaker ?? "—") @ \(c.start.map { String(format: "%.1fs", $0) } ?? "—")]")
    }
    print("## Próximos passos")
    for p in resumoFinal.proximosPassos { print("- \(p.descricao) (\(p.responsavel ?? "—"))") }
    await engineQ.descarregar()

case "run":
    FileHandle.standardError.write(
        Data("papagaio-eval run: \(NotImplemented("harness de medição", passo: 6))\n".utf8)
    )
    exit(2)

default:
    uso()
}
