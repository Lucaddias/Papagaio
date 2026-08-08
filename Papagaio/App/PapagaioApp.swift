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
        WindowGroup("") {
            ContentView()
        }
        .defaultSize(width: 1_000, height: 700)
        // Sem isto o `minWidth` da `ContentView` é só uma sugestão: a janela
        // continua arrastável abaixo dele e o conteúdo transborda em vez de
        // parar de encolher.
        .windowResizability(.contentMinSize)
    }
}
