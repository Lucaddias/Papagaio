import SwiftUI

@main
struct PapagaioApp: App {
    init() {
        // Modo de diagnóstico do R-11: roda a matriz de configurações do tap
        // dentro deste bundle (que tem a permissão de TCC) e encerra.
        if DiagnosticoTap.pedido {
            DiagnosticoTap.executar()
            exit(0)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 900, height: 600)
    }
}
