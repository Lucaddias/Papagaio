import Foundation

/// Conta processos filhos do processo atual.
///
/// Existe para o critério de aceite do Passo 4: "confirme que existe **um
/// processo só**, sem subprocess". O `InterviewLab` chamava `whisper-cli` via
/// `Process()`; o Papagaio não pode, porque processo externo não roda sob App
/// Sandbox.
enum ContagemDeProcessos {
    static func filhos() -> Int {
        let processo = Process()
        processo.executableURL = URL(fileURLWithPath: "/bin/ps")
        processo.arguments = ["-o", "pid=", "--ppid", "\(ProcessInfo.processInfo.processIdentifier)"]
        let tubo = Pipe()
        processo.standardOutput = tubo
        processo.standardError = FileHandle.nullDevice
        do {
            try processo.run()
            let dados = tubo.fileHandleForReading.readDataToEndOfFile()
            processo.waitUntilExit()
            return String(decoding: dados, as: UTF8.self)
                .split(separator: "\n")
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                .count
        } catch {
            return -1
        }
    }
}
