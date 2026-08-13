import SwiftUI

struct CartaoNovaConversa: View {
    let gravando: Bool
    let bloqueado: Bool
    let prontoParaEntrada: Bool
    let aoAlternarGravacao: () async -> Void
    let aoImportar: () -> Void
    let aoSoltarArquivos: ([URL]) -> Void
    /// Volta para a tela de captura. Só usado enquanto `gravando`.
    let aoVoltarParaGravacao: () -> Void

    /// Realce enquanto o arquivo paira sobre o cartão. Sem ele, arrastar até
    /// aqui é um chute: nada na tela confirma que soltar vai funcionar.
    @State private var recebendoArraste = false

    private static let formatosAceitos: Set<String> = [
        "m4a", "mp3", "wav", "aac", "aiff", "aif", "caf", "flac", "mp4", "mov",
    ]

    var body: some View {
        if gravando {
            Button(action: aoVoltarParaGravacao) {
                corpo
            }
            .buttonStyle(.plain)
            .help("Voltar para a gravação em andamento")
        } else {
            corpo
        }
    }

    private var corpo: some View {
        VStack(spacing: PapagaioTema.Espaco.largo) {
            Image(systemName: gravando ? "mic.fill" : "plus")
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(gravando ? PapagaioTema.perigo : PapagaioTema.destaqueEscuro)
                .frame(width: 64, height: 64)
                .background(PapagaioTema.destaqueSuave, in: Circle())

            VStack(spacing: PapagaioTema.Espaco.minimo) {
                Text(gravando ? "Gravação em andamento" : "Gerar nova conversa")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(PapagaioTema.texto)
                Text(
                    gravando
                        ? "Clique para voltar à tela de gravação."
                        : "Grave áudio, importe um arquivo ou arraste aqui do Finder."
                )
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(PapagaioTema.textoSecundario)
            }

            if !prontoParaEntrada {
                SeloDeStatus(
                    texto: "Preparando biblioteca",
                    simbolo: "arrow.triangle.2.circlepath",
                    estilo: .neutro
                )
                .accessibilityLabel("Preparando a biblioteca. Gravar e importar estarão disponíveis em instantes.")
            }

            if bloqueado {
                SeloDeStatus(
                    texto: "Preparando áudio",
                    simbolo: "waveform",
                    estilo: .destaque
                )
            }

            // Gravando, os dois botões somem. Começar outra gravação não é
            // possível, e importar no meio de uma captura é pedir para a
            // pessoa dividir a atenção — o cartão passa a ter uma função só,
            // que é levar de volta para a tela de captura.
            if gravando {
                Label("Voltar para a gravação", systemImage: "waveform")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(PapagaioTema.destaqueEscuro)
            } else {
                // Em coluna estreita os dois botões lado a lado eram espremidos
                // até o rótulo hifenizar ("Impor-tar"). Empilhar é melhor que
                // quebrar a palavra.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: PapagaioTema.Espaco.curto) {
                        botoes
                    }

                    VStack(spacing: PapagaioTema.Espaco.curto) {
                        botoes
                    }
                }
            }
        }
        .padding(PapagaioTema.Espaco.secao)
        .contentShape(Rectangle())
        // A área de soltar é o cartão inteiro, não só os botões: quem arrasta
        // mira no retângulo tracejado, que é o que parece uma zona de entrada.
        .dropDestination(for: URL.self) { urls, _ in
            let aceitos = urls.filter {
                Self.formatosAceitos.contains($0.pathExtension.lowercased())
            }
            guard !aceitos.isEmpty else { return false }
            aoSoltarArquivos(aceitos)
            return true
        } isTargeted: { pairando in
            withAnimation(.snappy(duration: 0.16)) { recebendoArraste = pairando }
        }
        // `maxHeight: .infinity` faz o cartão acompanhar a altura da linha da
        // grade. Sem isso ele parava no conteúdo e ficava mais baixo que os
        // cartões de conversa ao lado, que têm capa, selo e ficha.
        .frame(maxWidth: .infinity, minHeight: 260, maxHeight: .infinity)
        .background(
            recebendoArraste
                ? PapagaioTema.destaque.opacity(0.12)
                : PapagaioTema.superficie.opacity(0.55),
            in: RoundedRectangle(cornerRadius: PapagaioTema.raioDeCard, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: PapagaioTema.raioDeCard, style: .continuous)
                .stroke(
                    recebendoArraste ? PapagaioTema.destaque : PapagaioTema.borda,
                    style: StrokeStyle(lineWidth: recebendoArraste ? 3 : 2, dash: [7, 6])
                )
        }
        // Gravando, o cartão inteiro vira um botão de volta — e é `Button` de
        // verdade, não `onTapGesture`: assim ele responde a Enter e à
        // navegação por teclado, e o cursor vira mãozinha, avisando que dá
        // para clicar em qualquer ponto.
        .accessibilityElement(children: .contain)
    }

    private var botoes: some View {
        Group {
            Button("Gravar", systemImage: "mic.fill") {
                Task { await aoAlternarGravacao() }
            }
            .buttonStyle(BotaoPrincipalPapagaio())
            .disabled(bloqueado || !prontoParaEntrada)

            Button("Importar", systemImage: "arrow.down.doc") {
                aoImportar()
            }
            .buttonStyle(BotaoDeContornoPapagaio())
            .disabled(bloqueado || !prontoParaEntrada)
        }
    }
}
