import AppKit
import SwiftUI

/// Expõe a `NSWindow` que hospeda a view, para quem precisa converter um
/// retângulo local em coordenadas de tela (por exemplo, para animar um
/// `NSPanel` "nascendo" de dentro da janela principal).
///
/// SwiftUI não dá acesso direto à janela; o único jeito é espiar por uma
/// `NSView` invisível e perguntar a ela.
private struct RastreadorDeJanela: NSViewRepresentable {
    let aoEncontrar: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { aoEncontrar(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { aoEncontrar(nsView.window) }
    }
}

extension View {
    /// Chama `aoEncontrar` com a `NSWindow` da view assim que ela existir (e
    /// de novo se a hierarquia for reconstruída).
    func rastreandoJanela(_ aoEncontrar: @escaping (NSWindow?) -> Void) -> some View {
        background(RastreadorDeJanela(aoEncontrar: aoEncontrar))
    }
}
