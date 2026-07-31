import Foundation
// `internal`: impede que o módulo C `whisper` — e com ele o ggml — vaze
// para quem importa este target. Sem isso, `PapagaioCore` carrega os dois
// ggml no mesmo contexto clang e o build quebra. Ver D-3.2.
internal import whisper

/// Fronteira Swift do `whisper.cpp`. **Nenhum outro target importa `whisper`**
/// — ver D-3.2 sobre a colisão de ggml entre os dois frameworks.
public enum WhisperRuntime {
    /// String de capacidades do build (backends, SIMD, Metal).
    public static var systemInfo: String {
        String(cString: whisper_print_system_info())
    }

    /// `true` quando a biblioteca Metal vem embutida no binário.
    public static var temMetal: Bool {
        systemInfo.contains("MTL")
    }
}
