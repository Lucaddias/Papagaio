import FluidAudio
import Foundation

/// Um segmento de fala atribuído a um falante acústico, em segundos desde o
/// início do áudio.
///
/// Espelha `FluidAudio.TimedSpeakerSegment` no mínimo que o domínio consome.
/// `falanteId` segue a convenção do FluidAudio: `"S1"`, `"S2"`, … — só serve
/// para **comparar** falantes na mesma gravação, não é um rótulo estável.
public struct SegmentoDiarizado: Sendable, Equatable {
    public let falanteId: String
    public let inicio: Double
    public let fim: Double

    public init(falanteId: String, inicio: Double, fim: Double) {
        self.falanteId = falanteId
        self.inicio = inicio
        self.fim = fim
    }
}

public enum ErroDeDiarizacao: Error, LocalizedError {
    case modelosNaoPreparados
    case semFalaDetectada
    case falhaNoProcessamento(String)

    public var errorDescription: String? {
        switch self {
        case .modelosNaoPreparados:
            "Os modelos de diarização ainda não foram carregados."
        case .semFalaDetectada:
            "Nenhuma fala foi detectada no áudio."
        case let .falhaNoProcessamento(detalhe):
            "A diarização falhou: \(detalhe)"
        }
    }
}

/// Diarização acústica offline via `FluidAudio.OfflineDiarizerManager`
/// (pipeline pyannote community-1 em CoreML).
///
/// É um ator porque o `OfflineDiarizerManager` não é `Sendable` e os métodos
/// dele são nonisolated: o ator garante que só uma tarefa o usa por vez. O
/// manager é `nonisolated(unsafe)` porque não é `Sendable` — o próprio
/// FluidAudio guarda os mesmos modelos assim.
///
/// Offline-first de propósito: o Papagaio **nunca** deixa o FluidAudio baixar
/// modelo em runtime. Os artefatos são pré-estagiados por
/// `Scripts/bootstrap-runtimes.sh` no diretório indicado em `preparar`;
/// `ModelHub.offlineMode` veda a rede de uma vez, e um cache incompleto vira
/// erro em vez de download surpresa.
public actor DiarizadorFluidoOffline {
    private nonisolated(unsafe) let gerente: OfflineDiarizerManager
    private var preparado = false

    public init(configuracao: OfflineDiarizerConfig = .default) {
        ModelHub.offlineMode = true
        self.gerente = OfflineDiarizerManager(config: configuracao)
    }

    /// Carrega os modelos pré-estagiados do diretório (layout
    /// `speaker-diarization/…`, como o ModelHub do FluidAudio espera).
    ///
    /// Idempotente: a segunda chamada não recarrega nada.
    public func preparar(diretorio: URL) async throws {
        guard !preparado else { return }
        try await gerente.prepareModels(directory: diretorio)
        preparado = true
    }

    /// Diariza o áudio e devolve os segmentos de fala por falante.
    ///
    /// `aoProgredir` recebe `(pedacosProcessados, totalDePedacos)` depois de
    /// cada pedaço de segmentação — o chamador converte em fração.
    public func diarizar(
        _ audio: URL,
        aoProgredir: (@Sendable (Int, Int) -> Void)? = nil
    ) async throws -> [SegmentoDiarizado] {
        guard preparado else { throw ErroDeDiarizacao.modelosNaoPreparados }
        do {
            let resultado = try await gerente.process(audio, progressCallback: aoProgredir)
            return resultado.segments.map {
                SegmentoDiarizado(
                    falanteId: $0.speakerId,
                    inicio: Double($0.startTimeSeconds),
                    fim: Double($0.endTimeSeconds)
                )
            }
        } catch OfflineDiarizationError.noSpeechDetected {
            // Canal em silêncio — o pipeline preserva o outro canal. Sem fala,
            // não há falantes; vazio é honesto e não é erro.
            return []
        } catch {
            throw ErroDeDiarizacao.falhaNoProcessamento(String(describing: error))
        }
    }
}