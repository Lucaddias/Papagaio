import Foundation
import Observation
import PapagaioCore

/// Estado de gravação para a UI. Fica no app, não em `PapagaioCore` — a
/// biblioteca não conhece SwiftUI nem `@Observable` de tela.
@MainActor
@Observable
final class GravadorViewModel {
    enum Estado: Equatable {
        case ocioso
        case gravando
        case processando
        case falhou(String)
    }

    private(set) var estado: Estado = .ocioso
    private(set) var avisos: [String] = []

    /// Entrega o áudio pronto para quem persiste e processa (`Biblioteca`).
    /// A gravação em si não sabe o que é um `Arquivo` — só produz bytes.
    var aoProduzirAudio: (@MainActor (_ titulo: String, _ pastaRelativa: String,
                                      _ duracao: TimeInterval) async -> Void)?

    /// Amostras de nível para a waveform ao vivo, ~20 Hz, janela de ~6 s.
    private(set) var waveform: [Float] = []
    private let quadrosWaveform = 120

    private var sessao: SessaoGravacao?
    private var tarefaNivel: Task<Void, Never>?
    private let armazenamento: Armazenamento?

    init() {
        armazenamento = try? Armazenamento.padrao()
        if armazenamento == nil {
            estado = .falhou("não foi possível abrir a pasta de suporte do app")
        }
    }

    var gravando: Bool { estado == .gravando }

    // MARK: - Gravação

    func alternarGravacao() async {
        if gravando {
            await parar()
        } else {
            await iniciar()
        }
    }

    private func iniciar() async {
        guard let armazenamento else { return }
        avisos = []
        waveform = []

        let sessao = SessaoGravacao(armazenamento: armazenamento)
        do {
            try await sessao.iniciar()
        } catch {
            estado = .falhou("\(error)")
            return
        }

        self.sessao = sessao
        estado = .gravando

        // Waveform: amostra o nível a ~20 Hz. O medidor é atômico, então
        // ler daqui não toca na thread de áudio.
        let nivel = sessao.nivelMicrofone
        tarefaNivel = Task { [weak self] in
            while !Task.isCancelled {
                let valor = nivel.normalizado
                await MainActor.run { self?.acrescentarAoWaveform(valor) }
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    private func parar() async {
        tarefaNivel?.cancel()
        tarefaNivel = nil
        guard let sessao else { return }

        estado = .processando
        let resultado = await sessao.parar()
        self.sessao = nil

        avisos = resultado.avisos
        estado = .ocioso

        // Gravação descartada por ser curta demais volta com duração 0 e já foi
        // apagada do disco — não entra na biblioteca.
        if resultado.duracao > 0 {
            await aoProduzirAudio?(Self.tituloParaAgora(), resultado.pastaRelativa, resultado.duracao)
        }
    }

    /// Título provisório de uma gravação. O resumo produz um título melhor
    /// (`Resumo.titulo`) — mas só depois de rodar, e a lista precisa mostrar
    /// alguma coisa enquanto isso.
    private static func tituloParaAgora() -> String {
        let formato = Date.FormatStyle(date: .abbreviated, time: .shortened)
        return "Gravação de \(Date().formatted(formato))"
    }

    private func acrescentarAoWaveform(_ valor: Float) {
        waveform.append(valor)
        if waveform.count > quadrosWaveform {
            waveform.removeFirst(waveform.count - quadrosWaveform)
        }
    }

    // MARK: - Importação

    /// - Important: `url` precisa vir do `.fileImporter` **com o acesso
    ///   security-scoped já aberto** por quem chama.
    func importar(_ url: URL) async {
        guard let armazenamento else { return }
        estado = .processando
        do {
            let importado = try await ImportadorAudio(armazenamento: armazenamento).importar(de: url)
            avisos = ["Arquivo importado: um canal só, sem separação de falante."]
            estado = .ocioso
            await aoProduzirAudio?(
                importado.tituloSugerido, importado.pastaRelativa, importado.duracao
            )
        } catch {
            estado = .falhou("\(error)")
        }
    }
}
