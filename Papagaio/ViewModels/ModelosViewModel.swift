import Foundation
import Observation
import PapagaioCore

/// Estado dos pesos GGUF para a interface: o que falta, quanto já baixou, o que
/// impede.
///
/// O `DownloadDeModelos` e o `Preflight` são do Passo 3 e já existiam — o que
/// faltava era alguém no app chamá-los. Sem isso o container nasce vazio e
/// nenhuma transcrição é possível.
@MainActor
@Observable
final class ModelosViewModel {
    private(set) var resultado: ResultadoPreflight?
    private(set) var progresso: ProgressoDownload?
    private(set) var erro: String?
    private(set) var baixando = false

    /// Pasta escolhida pelo usuário, quando houver. `nil` significa "usar a do
    /// container", que é onde o download deposita.
    private(set) var pastaEscolhida: URL?

    private let pastaDoContainer: URL
    private let download: DownloadDeModelos
    private var tarefa: Task<Void, Never>?

    init(pastaDoContainer: URL) {
        self.pastaDoContainer = pastaDoContainer
        self.download = DownloadDeModelos(pastaDeModelos: pastaDoContainer)
        self.pastaEscolhida = PastaDeModelosDoUsuario.resolver()
    }

    /// A pasta que vale agora. O download só escreve no container: gravar dentro
    /// da pasta do usuário mexeria em arquivos que não são do app.
    var pasta: URL { pastaEscolhida ?? pastaDoContainer }

    var pronto: Bool { resultado == .pronto || resultado == .termicoCritico }

    /// Verificação barata: tamanho em disco, não SHA-256 de 13,6 GB (ver a nota
    /// em `Preflight.pesoValido`).
    func verificar() {
        resultado = Preflight(pastaDeModelos: pasta).avaliar()
    }

    /// - Important: `url` precisa vir do `.fileImporter` com o acesso
    ///   security-scoped **já aberto** por quem chama.
    func escolher(_ url: URL) {
        do {
            try PastaDeModelosDoUsuario.guardar(url)
            pastaEscolhida = PastaDeModelosDoUsuario.resolver()
            erro = nil
        } catch {
            erro = "Não foi possível guardar a pasta escolhida: \(error)"
        }
        verificar()
    }

    func usarOContainer() {
        PastaDeModelosDoUsuario.esquecer()
        pastaEscolhida = nil
        verificar()
    }

    var faltando: [PesoDeModelo] {
        if case let .pesosFaltando(pesos) = resultado { return pesos }
        return []
    }

    func baixar() {
        guard !baixando else { return }
        // O downloader escreve no container. Baixar enquanto uma pasta do
        // usuário está ativa deixaria um peso em cada lugar, e os motores só
        // olham para uma pasta.
        guard pastaEscolhida == nil else {
            erro = "Falta um modelo na pasta escolhida. Complete a pasta, "
                + "ou volte a usar a pasta do app para baixar."
            return
        }
        let pesos = faltando
        guard !pesos.isEmpty else { return }

        baixando = true
        erro = nil
        tarefa = Task {
            for peso in pesos {
                do {
                    _ = try await download.baixar(peso) { andamento in
                        Task { @MainActor in self.progresso = andamento }
                    }
                } catch is CancellationError {
                    break
                } catch {
                    erro = "\(error)"
                    break
                }
            }
            progresso = nil
            baixando = false
            verificar()
        }
    }

    func cancelar() {
        tarefa?.cancel()
        tarefa = nil
        baixando = false
        progresso = nil
    }

    /// Quanto já existe em disco de cada peso ainda incompleto — o download
    /// retoma daí, e dizer isso evita a impressão de que 10 GB foram perdidos.
    func bytesJaBaixados(de peso: PesoDeModelo) async -> Int64 {
        await download.bytesParciais(de: peso)
    }
}
