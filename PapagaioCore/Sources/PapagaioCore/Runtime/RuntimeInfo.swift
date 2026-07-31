import Foundation
import LlamaRuntime
import WhisperRuntime

/// Identificação dos dois runtimes locais linkados.
///
/// `PapagaioCore` fala com eles só através de `WhisperRuntime`/`LlamaRuntime`:
/// importar os módulos C `whisper` e `llama` no mesmo target não compila,
/// porque os dois frameworks embutem versões diferentes do ggml. Ver D-3.2.
public enum RuntimeInfo {
    public struct Info: Sendable {
        public let whisperSystemInfo: String
        public let llamaSystemInfo: String
        public let metalDisponivel: Bool
    }

    public static func coletar() -> Info {
        Info(
            whisperSystemInfo: WhisperRuntime.systemInfo,
            llamaSystemInfo: LlamaRuntime.systemInfo,
            metalDisponivel: WhisperRuntime.temMetal && LlamaRuntime.temMetal
        )
    }
}
