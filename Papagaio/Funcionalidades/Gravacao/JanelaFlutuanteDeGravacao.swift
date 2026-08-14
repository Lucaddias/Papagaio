import AppKit
import SwiftUI

/// A janela que hospeda o painel de gravação por cima dos outros apps.
///
/// É um `NSPanel`, e não uma `Window` do SwiftUI, por três exigências que só o
/// AppKit atende:
///
/// - **Sobrevive à troca de app.** `.floating` a mantém acima das janelas dos
///   outros programas, que é o ponto de gravar enquanto se trabalha em outro
///   lugar. `hidesOnDeactivate = false` impede que ela suma quando o Papagaio
///   deixa de ser o app da frente.
/// - **Não rouba o foco ao aparecer.** `.nonactivatingPanel` com
///   `becomesKeyOnlyIfNeeded` deixa a pessoa continuar digitando no Zoom, no
///   Notion ou onde estiver; o painel só toma o teclado quando ela clica no
///   campo de nota.
/// - **Acompanha em todos os espaços.** `.canJoinAllSpaces` faz a janela seguir
///   quem troca de Mission Control no meio da conversa.
@MainActor
final class JanelaFlutuanteDeGravacao {
    private var painel: NSPanel?

    /// Tamanho inicial: o "padrão" da `PainelFlutuanteDeGravacao`, com o campo
    /// de nota visível. Cabe folgado em qualquer Mac, inclusive num Air de 13".
    private static let tamanhoInicial = NSSize(width: 360, height: 190)

    /// Piso e teto do arrasto. O mínimo é a barra de transporte sozinha; o
    /// máximo evita que o painel deixe de ser painel e vire uma segunda janela.
    private static let tamanhoMinimo = NSSize(width: 240, height: 84)
    private static let tamanhoMaximo = NSSize(width: 620, height: 460)

    func exibir(gravador: GravadorViewModel, aoAbrirNoApp: @escaping () -> Void) {
        if let painel {
            painel.orderFrontRegardless()
            return
        }

        let conteudo = PainelFlutuanteDeGravacao(
            gravador: gravador,
            aoAbrirNoApp: aoAbrirNoApp
        )

        let novo = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.tamanhoInicial),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        novo.title = "Gravando"
        novo.titlebarAppearsTransparent = true
        novo.titleVisibility = .hidden
        novo.isMovableByWindowBackground = true
        novo.level = .floating
        novo.hidesOnDeactivate = false
        novo.becomesKeyOnlyIfNeeded = true
        novo.isReleasedWhenClosed = false
        novo.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        novo.minSize = Self.tamanhoMinimo
        novo.maxSize = Self.tamanhoMaximo
        novo.contentView = NSHostingView(rootView: conteudo)

        posicionar(novo)
        novo.orderFrontRegardless()
        painel = novo
    }

    func esconder() {
        painel?.close()
        painel = nil
    }

    /// Canto inferior direito da tela onde está o cursor, com folga.
    ///
    /// Escolhido por eliminação: o topo tem a barra de menus e o notch, a
    /// esquerda costuma ter o Dock em telas pequenas, e o centro é onde a
    /// pessoa está trabalhando. Também é onde o macOS já coloca avisos, então a
    /// pessoa olha para lá naturalmente.
    ///
    /// A tela é a do cursor, e não a principal: em setup de dois monitores, a
    /// janela precisa nascer onde a pessoa está olhando.
    private func posicionar(_ painel: NSPanel) {
        let tela = NSScreen.screens.first {
            NSMouseInRect(NSEvent.mouseLocation, $0.frame, false)
        } ?? NSScreen.main

        guard let area = tela?.visibleFrame else {
            painel.center()
            return
        }

        let folga: CGFloat = 24
        let origem = NSPoint(
            x: area.maxX - Self.tamanhoInicial.width - folga,
            y: area.minY + folga
        )
        painel.setFrameOrigin(origem)
    }
}
