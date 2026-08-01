import PapagaioCore
import SwiftUI

/// Seções reais disponíveis para uma conversa. Mantê-las fora da view de
/// composição permite reutilizar a barra de navegação sem criar telas que o
/// produto ainda não oferece.
enum SecaoDoDetalhe: String, CaseIterable, Identifiable {
    case resumo = "Resumo"
    case transcricao = "Transcrição"
    case notas = "Notas"
    case audio = "Áudio"
    case proximosPassos = "Próximos passos"

    var id: Self { self }

    var simbolo: String {
        switch self {
        case .resumo: "text.alignleft"
        case .transcricao: "text.quote"
        case .notas: "note.text"
        case .audio: "waveform"
        case .proximosPassos: "checklist"
        }
    }
}

/// Navegação horizontal entre os conteúdos que já existem no domínio de uma
/// conversa. A mudança de estado fica no container para preservar a regra de
/// abrir o player ao entrar na aba de áudio.
struct BarraDeSecoesDaConversa: View {
    let secaoSelecionada: SecaoDoDetalhe
    let aoSelecionar: (SecaoDoDetalhe) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(SecaoDoDetalhe.allCases) { secao in
                let estaSelecionada = secaoSelecionada == secao

                Button {
                    aoSelecionar(secao)
                } label: {
                    VStack(spacing: 9) {
                        Label(secao.rawValue, systemImage: secao.simbolo)
                            .labelStyle(.titleAndIcon)
                            .font(.callout.weight(estaSelecionada ? .semibold : .regular))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .foregroundStyle(
                                estaSelecionada
                                    ? PapagaioTema.destaqueEscuro
                                    : PapagaioTema.textoSecundario
                            )
                            .frame(maxWidth: .infinity)

                        Rectangle()
                            .fill(estaSelecionada ? PapagaioTema.destaque : .clear)
                            .frame(height: 3)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(estaSelecionada ? .isSelected : [])
            }
        }
        .padding(.top, 4)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PapagaioTema.borda.opacity(0.72))
                .frame(height: 1)
        }
    }
}

/// Linha interativa da transcrição. A ação de tocar pertence ao container;
/// assim a célula continua puramente visual e pode ser usada dentro de um
/// `Button` sem duplicar lógica de AVFoundation.
struct LinhaDeTranscricao: View {
    let trecho: Trecho
    let ativo: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(tempoCurto(trecho.start))
                .font(.system(.caption, design: .monospaced).weight(.medium))
                .monospacedDigit()
                .foregroundStyle(ativo ? PapagaioTema.destaqueEscuro : PapagaioTema.textoSecundario)
                .frame(width: 52, alignment: .trailing)

            VStack(alignment: .leading, spacing: 4) {
                if let speaker = trecho.speaker {
                    Text(speaker == Speaker.eu ? "Eu" : "Interlocutor")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PapagaioTema.textoSecundario)
                }

                Text(trecho.texto)
                    .font(.body)
                    .fontWeight(ativo ? .medium : .regular)
                    .foregroundStyle(PapagaioTema.texto)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ativo ? PapagaioTema.destaqueSuave.opacity(0.76) : PapagaioTema.superficie,
            in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
        )
        .overlay(alignment: .leading) {
            Capsule()
                .fill(ativo ? PapagaioTema.destaque : .clear)
                .frame(width: 4)
                .padding(.vertical, 10)
        }
        .overlay {
            RoundedRectangle(cornerRadius: PapagaioTema.raioDeControle, style: .continuous)
                .stroke(ativo ? PapagaioTema.borda : PapagaioTema.borda.opacity(0.58), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(tempoLongo(trecho.start)). \(trecho.texto)")
        .accessibilityAddTraits(ativo ? [.isSelected] : [])
    }

    private func tempoCurto(_ segundos: TimeInterval) -> String {
        let inteiros = Int(max(0, segundos))
        return String(format: "%d:%02d", inteiros / 60, inteiros % 60)
    }

    private func tempoLongo(_ segundos: TimeInterval) -> String {
        let inteiros = Int(max(0, segundos))
        let minutos = inteiros / 60
        let resto = inteiros % 60
        return minutos > 0 ? "\(minutos) min \(resto) s" : "\(resto) s"
    }
}

/// Player compacto e fixado na parte inferior. Ele só expõe as funções de uma
/// conversa: tocar/pausar e navegar pela posição; não simula recursos de um
/// app de música que não pertencem ao produto.
struct BarraDeAudioDaConversa: View {
    let titulo: String
    let reprodutor: ReprodutorDeArquivo
    @Binding var tempoEmEdicao: TimeInterval?
    let aoConcluirEdicao: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button {
                reprodutor.alternar()
            } label: {
                Image(systemName: reprodutor.tocando ? "pause.fill" : "play.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.glassProminent)
            .tint(PapagaioTema.destaque)
            .accessibilityLabel(reprodutor.tocando ? "Pausar" : "Tocar")

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(titulo)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(PapagaioTema.texto)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    Text("\(tempoCurto(posicaoAtual)) / \(tempoCurto(reprodutor.duracao))")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(PapagaioTema.textoSecundario)
                        .monospacedDigit()
                }

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
                .accessibilityValue("\(tempoLongo(posicaoAtual)) de \(tempoLongo(reprodutor.duracao))")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .frame(maxWidth: 720)
        .glassEffect(.regular, in: Capsule())
        .overlay {
            Capsule()
                .stroke(PapagaioTema.borda.opacity(0.7), lineWidth: 1)
        }
        .padding(.horizontal, 24)
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

    private func tempoCurto(_ segundos: TimeInterval) -> String {
        guard segundos.isFinite, segundos >= 0 else { return "0:00" }
        let inteiros = Int(segundos)
        return String(format: "%d:%02d", inteiros / 60, inteiros % 60)
    }

    private func tempoLongo(_ segundos: TimeInterval) -> String {
        let inteiros = Int(max(0, segundos))
        let minutos = inteiros / 60
        let resto = inteiros % 60
        return minutos > 0 ? "\(minutos) min \(resto) s" : "\(resto) s"
    }
}

/// Orientação central para a aba Áudio, visualmente alinhada aos outros
/// estados de conteúdo enquanto o transporte permanece no player inferior.
struct OrientacaoDeAudio: View {
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "waveform")
                .font(.system(size: 42, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(PapagaioTema.destaqueEscuro)
                .frame(width: 78, height: 78)
                .background(PapagaioTema.destaqueSuave, in: Circle())

            VStack(spacing: 8) {
                Text("Ouça a conversa")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(PapagaioTema.texto)

                Text(
                    "Use a barra fixa abaixo para ouvir a gravação. Na aba Transcrição, selecione um trecho para iniciar a reprodução daquele ponto."
                )
                .font(.body)
                .foregroundStyle(PapagaioTema.textoSecundario)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 620)
            }
        }
        .padding(32)
        .cartaoPapagaio()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Áudio. Use a barra fixa abaixo para ouvir a gravação. Na aba Transcrição, selecione um trecho para iniciar a reprodução daquele ponto."
        )
    }
}
