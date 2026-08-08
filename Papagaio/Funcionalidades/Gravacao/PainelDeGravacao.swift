import SwiftUI

struct PainelDeGravacao: View {
    let waveform: [Float]
    let tempoDeGravacao: TimeInterval
    let pausado: Bool
    let aoPausar: () async -> Void
    let aoContinuar: () async -> Void
    let aoFinalizar: () async -> Void
    let aoCancelar: () async -> Void

    /// Numa janela estreita os três botões espremiam a waveform até ela sumir e
    /// os rótulos hifenizarem. `ViewThatFits` tenta a linha única e, quando não
    /// cabe, empilha: medidor em cima, controles embaixo em largura cheia.
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: PapagaioTema.Espaco.largo) {
                medidor
                Waveform(amostras: waveform, ativo: !pausado)
                    .frame(minWidth: 160, maxWidth: .infinity, minHeight: 48, maxHeight: 48)
                controles
            }

            VStack(alignment: .leading, spacing: PapagaioTema.Espaco.medio) {
                HStack(spacing: PapagaioTema.Espaco.medio) {
                    medidor
                    Waveform(amostras: waveform, ativo: !pausado)
                        .frame(minWidth: 80, maxWidth: .infinity, minHeight: 40, maxHeight: 40)
                }

                controles
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(PapagaioTema.Espaco.largo)
        .cartaoPapagaio()
        .accessibilityElement(children: .contain)
    }

    private var medidor: some View {
        HStack(spacing: PapagaioTema.Espaco.medio) {
            Image(systemName: pausado ? "pause.fill" : "mic.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(PapagaioTema.destaqueEscuro)
                .frame(width: 56, height: 56)
                .background(PapagaioTema.destaqueSuave, in: Circle())

            Text(tempoDeGravacao.comoCronometro)
                .font(.system(.title3, design: .monospaced).weight(.semibold))
                .foregroundStyle(PapagaioTema.texto)
                .monospacedDigit()
                .frame(width: 72, alignment: .leading)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var controles: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: PapagaioTema.Espaco.curto) {
                botoes
            }

            VStack(spacing: PapagaioTema.Espaco.curto) {
                botoes
            }
        }
    }

    private var botoes: some View {
        Group {
            Button(pausado ? "Continuar" : "Pausar", systemImage: pausado ? "play.fill" : "pause.fill") {
                Task {
                    if pausado {
                        await aoContinuar()
                    } else {
                        await aoPausar()
                    }
                }
            }
            .buttonStyle(BotaoDeContornoPapagaio())

            Button("Finalizar", systemImage: "stop.fill") {
                Task { await aoFinalizar() }
            }
            .buttonStyle(BotaoPrincipalPapagaio())

            Button("Cancelar", systemImage: "xmark") {
                Task { await aoCancelar() }
            }
            .buttonStyle(BotaoDeContornoPapagaio())
            .foregroundStyle(PapagaioTema.perigo)
        }
    }

}
