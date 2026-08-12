import AppKit
import SwiftUI

/// Roda do mouse sobre uma view, em SwiftUI.
///
/// O SwiftUI não expõe o evento de scroll fora de contêineres roláveis, então
/// a captura vem de um `NSView` invisível sobreposto. Ele não recebe clique —
/// `hitTest` devolve `nil` — para não roubar o toque dos botões que estão
/// embaixo; só o `scrollWheel` é interceptado, e isso o AppKit entrega pela
/// cadeia de responders mesmo sem hit testing.
///
/// `deltaY` chega normalizado: positivo é rolar para cima. Trackpad e mouse
/// mandam magnitudes bem diferentes, e quem chama decide a sensibilidade.
struct RodaDoMouse: NSViewRepresentable {
    let aoRolar: (CGFloat) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = ViewDeRolagem()
        view.aoRolar = aoRolar
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? ViewDeRolagem)?.aoRolar = aoRolar
    }

    private final class ViewDeRolagem: NSView {
        var aoRolar: ((CGFloat) -> Void)?

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func scrollWheel(with event: NSEvent) {
            guard let aoRolar else {
                super.scrollWheel(with: event)
                return
            }
            // `hasPreciseScrollingDeltas` distingue trackpad de mouse de roda.
            // O trackpad manda muitos eventos pequenos; a roda, poucos e
            // grandes. Sem normalizar, o mesmo gesto mudaria o volume de 2% no
            // trackpad e de 60% no mouse.
            let bruto = event.scrollingDeltaY
            let normalizado = event.hasPreciseScrollingDeltas ? bruto / 3 : bruto
            aoRolar(normalizado)
        }
    }
}

extension View {
    /// Ajusta algo com a roda do mouse sem precisar mirar num controle.
    func rodaDoMouse(_ aoRolar: @escaping (CGFloat) -> Void) -> some View {
        background(RodaDoMouse(aoRolar: aoRolar))
    }
}
