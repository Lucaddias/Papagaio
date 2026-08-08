import PapagaioCore
import SwiftUI

/// Player compacto e fixado na parte inferior. Ele só expõe as funções de uma
/// conversa: tocar/pausar e navegar pela posição; não simula recursos de um
/// app de música que não pertencem ao produto.
struct BarraDeAudioDaConversa: View {
    let titulo: String
    let data: Date
    let reprodutor: ReprodutorDeArquivo
    @Binding var tempoEmEdicao: TimeInterval?
    let aoConcluirEdicao: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: PapagaioTema.Espaco.secao) {
                blocoDoArquivo
                controlesCentrais
                progresso
                volumeEVelocidade
            }

            VStack(alignment: .leading, spacing: PapagaioTema.Espaco.medio) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: PapagaioTema.Espaco.medio) {
                        blocoDoArquivo
                        Spacer(minLength: 0)
                        controlesCentrais
                    }

                    VStack(alignment: .leading, spacing: PapagaioTema.Espaco.medio) {
                        blocoDoArquivo
                        controlesCentrais
                    }
                }

                progresso

                volumeEVelocidade
            }
        }
        .padding(.horizontal, PapagaioTema.Espaco.secao)
        .padding(.vertical, PapagaioTema.Espaco.largo)
        .frame(maxWidth: .infinity, minHeight: 88)
        .background(PapagaioTema.superficie)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(PapagaioTema.borda.opacity(0.75))
                .frame(height: 1)
        }
    }

    private var blocoDoArquivo: some View {
        HStack(spacing: PapagaioTema.Espaco.medio) {
            Image(systemName: "mic")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(PapagaioTema.destaqueEscuro)
                .frame(width: 48, height: 48)
                .background(PapagaioTema.destaqueSuave, in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous))

            VStack(alignment: .leading, spacing: PapagaioTema.Espaco.minimo) {
                Text(titulo)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(PapagaioTema.texto)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(data.formatted(.dateTime.day().month(.wide).year()))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(PapagaioTema.textoSecundario)
            }
            .frame(minWidth: 130, idealWidth: 210, maxWidth: 230, alignment: .leading)
        }
    }

    private var controlesCentrais: some View {
        HStack(spacing: PapagaioTema.Espaco.medio) {
            BotaoCircularDoPlayer(simbolo: "gobackward.10", tamanho: 18, destaque: false) {
                Task { await reprodutor.voltar(10) }
            }
            .help("Voltar 10 segundos")

            BotaoCircularDoPlayer(
                simbolo: reprodutor.tocando ? "pause.fill" : "play.fill",
                tamanho: 20,
                destaque: true
            ) {
                reprodutor.alternar()
            }
            .help(reprodutor.tocando ? "Pausar" : "Tocar")
            .accessibilityLabel(reprodutor.tocando ? "Pausar" : "Tocar")

            BotaoCircularDoPlayer(simbolo: "goforward.10", tamanho: 18, destaque: false) {
                Task { await reprodutor.avancar(10) }
            }
            .help("Avançar 10 segundos")
        }
    }

    private var progresso: some View {
        HStack(spacing: PapagaioTema.Espaco.medio) {
            Text(posicaoAtual.comoRelogio)
                .font(.system(.caption, design: .monospaced).weight(.medium))
                .foregroundStyle(PapagaioTema.texto)
                .monospacedDigit()
                .frame(width: 48, alignment: .trailing)

            Slider(
                value: posicao,
                in: 0...max(reprodutor.duracao, 0.1),
                onEditingChanged: { editando in
                    if editando {
                        tempoEmEdicao = reprodutor.tempo
                    } else {
                        aoConcluirEdicao()
                    }
                }
            )
            .tint(PapagaioTema.destaque)
            .accessibilityLabel("Posição do áudio")
            .accessibilityValue("\(posicaoAtual.faladoPorExtenso) de \(reprodutor.duracao.faladoPorExtenso)")

            Text(reprodutor.duracao.comoRelogio)
                .font(.system(.caption, design: .monospaced).weight(.medium))
                .foregroundStyle(PapagaioTema.texto)
                .monospacedDigit()
                .frame(width: 48, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
    }

    private var volumeEVelocidade: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: PapagaioTema.Espaco.medio) {
                controlesDeVolumeEVelocidade
            }

            VStack(alignment: .leading, spacing: PapagaioTema.Espaco.curto) {
                controlesDeVolumeEVelocidade
            }
        }
        .frame(minWidth: 140, idealWidth: 190, alignment: .leading)
    }

    private var controlesDeVolumeEVelocidade: some View {
        Group {
            Image(systemName: reprodutor.volume == 0 ? "speaker.slash" : "speaker.wave.2")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(PapagaioTema.textoSecundario)

            Slider(value: volume, in: 0...1)
                .tint(PapagaioTema.destaqueEscuro)
                .frame(minWidth: 92, idealWidth: 120)
                .accessibilityLabel("Volume")

            Menu {
                ForEach([0.75, 1, 1.25, 1.5, 2], id: \.self) { velocidade in
                    Button(String(format: "%.2gx", velocidade)) {
                        reprodutor.definirVelocidade(Float(velocidade))
                    }
                }
            } label: {
                Text(textoDaVelocidade)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PapagaioTema.texto)
                    .padding(.horizontal, PapagaioTema.Espaco.curto)
                    .frame(height: PapagaioTema.Altura.compacta)
                    .background(PapagaioTema.superficieSuave, in: Capsule())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .help("Velocidade")
        }
    }

    private var posicaoAtual: TimeInterval {
        tempoEmEdicao ?? reprodutor.tempo
    }

    private var posicao: Binding<TimeInterval> {
        Binding(
            get: { posicaoAtual },
            set: { tempoEmEdicao = $0 }
        )
    }

    private var volume: Binding<Float> {
        Binding(
            get: { reprodutor.volume },
            set: { reprodutor.volume = $0 }
        )
    }

    private var textoDaVelocidade: String {
        String(format: "%.1fx", reprodutor.velocidade)
    }

    private func alternarVelocidade() {
        let opcoes: [Float] = [0.75, 1, 1.25, 1.5, 2]
        let atual = reprodutor.velocidade
        let proxima = opcoes.first { $0 > atual + 0.01 } ?? opcoes[0]
        reprodutor.velocidade = proxima
    }
}

struct BotaoCircularDoPlayer: View {
    let simbolo: String
    let tamanho: CGFloat
    let destaque: Bool
    let acao: () -> Void

    var body: some View {
        Button(action: acao) {
            Image(systemName: simbolo)
                .font(.system(size: tamanho, weight: .semibold))
                .foregroundStyle(destaque ? PapagaioTema.textoSobrePrimario : PapagaioTema.textoSecundario)
                .frame(width: destaque ? 48 : 34, height: destaque ? 48 : 34)
                .background(destaque ? PapagaioTema.destaqueEscuro : Color.clear, in: Circle())
        }
        .buttonStyle(.plain)
    }
}
