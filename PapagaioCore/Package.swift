// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PapagaioCore",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "PapagaioCore", targets: ["PapagaioCore"]),
        .executable(name: "papagaio-eval", targets: ["papagaio-eval"]),
    ],
    targets: [
        // Runtimes locais, pré-compilados com backend Metal.
        // Baixados por Scripts/bootstrap-runtimes.sh (versão + SHA-256 fixados),
        // fora do git por causa do tamanho (~1 GB). Ver D-3.1.
        .binaryTarget(name: "whisper", path: "Frameworks/whisper.xcframework"),
        .binaryTarget(name: "llama", path: "Frameworks/llama.xcframework"),

        // Cada runtime fica isolado no seu próprio target Swift.
        //
        // Não é organização: é obrigatório. Os dois frameworks embutem versões
        // **diferentes** do ggml, e importar `whisper` e `llama` no mesmo
        // contexto de módulo quebra o build com "'ggml_type' has different
        // definitions in different modules". Separando os targets, cada módulo
        // clang enxerga só o seu ggml. Ver D-3.2.
        .target(
            name: "WhisperRuntime",
            dependencies: ["whisper"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "LlamaRuntime",
            dependencies: ["llama"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // Biblioteca de domínio. NÃO importa SwiftUI — a CLI depende dela.
        // Também não importa `whisper`/`llama` direto: só os wrappers acima.
        .target(
            name: "PapagaioCore",
            dependencies: ["WhisperRuntime", "LlamaRuntime"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "papagaio-eval",
            dependencies: ["PapagaioCore", "WhisperRuntime", "LlamaRuntime"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "PapagaioCoreTests",
            dependencies: ["PapagaioCore"],
            swiftSettings: [.swiftLanguageMode(.v6)],
            // O bundle .xctest carrega de
            // Products/Debug/PapagaioCoreTests.xctest/Contents/MacOS/, e os
            // frameworks ficam três níveis acima, em Products/Debug/.
            // Sem este rpath o `dlopen` do bundle falha em
            // "@rpath/whisper.framework/…", e `DYLD_FRAMEWORK_PATH` não
            // resolve: o SIP remove variáveis DYLD_* do helper de teste do
            // Xcode, que é um binário assinado pelo sistema.
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@loader_path/../../.."])
            ]
        ),
    ]
)
