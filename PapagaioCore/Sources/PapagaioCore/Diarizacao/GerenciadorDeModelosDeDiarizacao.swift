import DiarizationRuntime
import Foundation

/// Possui o `DiarizadorFluidoOffline` (pyannote community-1 via FluidAudio) e
/// entrega a diarização como `DiarizationEngine`, com os modelos carregados do
/// diretório estagiado pelo `Scripts/bootstrap-runtimes.sh`.
///
/// Carregamento sob demanda e descarga explícita: os modelos são pequenos
/// (~40 MB compilados), mas a API é a mesma do ciclo de vida dos GGUFs — o
/// `CicloDeVidaDeModelos` trata todos os residentes igual sob pressão de
/// memória.
public actor GerenciadorDeModelosDeDiarizacao: DiarizationEngine {
    /// Um só lugar para o identificador: vai para `Arquivo.engineDiarizacao`
    /// (quando houver) e para o registro no `CicloDeVidaDeModelos`.
    public static let identificador = "fluidaudio-community-1"

    public let identifier = GerenciadorDeModelosDeDiarizacao.identificador

    private let diretorio: URL?
    private var diarizador: DiarizadorFluidoOffline?

    /// - Parameter diretorio: raiz com o layout `speaker-diarization/…` que o
    ///   `ModelHub` do FluidAudio espera. `nil` (ou ausência do recurso no
    ///   bundle) só descobre na primeira chamada — e vira erro, não download.
    public init(diretorio: URL?) {
        self.diretorio = diretorio
    }

    /// O gerente dos modelos embutidos no bundle do PapagaioCore
    /// (`ModelosDeDiarizacao/diarizacao/`). Ausente quando o bootstrap ainda
    /// não rodou.
    public static func embutido() -> GerenciadorDeModelosDeDiarizacao {
        GerenciadorDeModelosDeDiarizacao(
            diretorio: Bundle.module
                .url(forResource: "ModelosDeDiarizacao", withExtension: nil)?
                .appendingPathComponent("diarizacao")
        )
    }

    /// Se os modelos pré-estagiados já estão no disco, prontos para carregar.
    ///
    /// É uma checagem de layout, não de conteúdo nem de carregamento — a UI
    /// usa para esconder ou mostrar a diarização antes de pagar o custo de
    /// compilar os modelos.
    public nonisolated var disponivel: Bool {
        guard let diretorio else { return false }
        let raiz = diretorio.appendingPathComponent("speaker-diarization")
        let arquivos = [
            "Segmentation.mlmodelc", "FBank.mlmodelc",
            "Embedding.mlmodelc", "PldaRho.mlmodelc",
            "plda-parameters.json",
        ]
        return arquivos.allSatisfy {
            FileManager.default.fileExists(atPath: raiz.appendingPathComponent($0).path)
        }
    }

    // MARK: - DiarizationEngine

    public func diarizar(_ audio: URL) async throws -> [SegmentoDeFalante] {
        let motor = try await motorPronto()
        let segmentos = try await motor.diarizar(audio)
        return segmentos.map {
            SegmentoDeFalante(falanteId: $0.falanteId, inicio: $0.inicio, fim: $0.fim)
        }
    }

    // MARK: - Ciclo de vida

    public func descarregar() async {
        diarizador = nil
    }

    private func motorPronto() async throws -> DiarizadorFluidoOffline {
        if let diarizador { return diarizador }
        guard let diretorio else { throw ErroDeDiarizacao.modelosNaoPreparados }

        let novo = DiarizadorFluidoOffline()
        try await novo.preparar(diretorio: diretorio)
        diarizador = novo
        return novo
    }
}

extension GerenciadorDeModelosDeDiarizacao: CicloDeVidaDeModelos.Residente {
    public nonisolated var identificador: String { Self.identificador }
}