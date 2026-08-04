import AVFoundation
import Foundation
import Observation

/// Player de um arquivo, com navegação por trecho.
///
/// Fica em `PapagaioCore` e não no app: é AVFoundation, não SwiftUI — a regra do
/// Passo 1 é que a biblioteca não arraste SwiftUI, não que ela não conheça
/// áudio. Estar aqui é o que permite testar salto e destaque sem abrir a
/// interface.
///
/// `AVPlayer`, não `AVAudioPlayer`: `addPeriodicTimeObserver` e o salto com
/// tolerância zero são de `AVPlayer` — ver D-10.1.
///
/// - Important: quem cria **tem que chamar `encerrar()`** ao sair da tela. O
///   observador periódico retém o bloco e sobrevive à view que o criou.
@MainActor
@Observable
public final class ReprodutorDeArquivo {
    /// ~10 Hz: rápido o bastante para o destaque não parecer travado, devagar o
    /// bastante para não acordar a main thread à toa. É o intervalo do Passo 10.
    public static let intervaloDeObservacao: TimeInterval = 0.1

    /// Posição atual, em segundos. Alimentada pelo observador periódico.
    public private(set) var tempo: TimeInterval = 0
    /// Duração do arquivo, disponível depois de `preparar()`.
    public private(set) var duracao: TimeInterval = 0
    public private(set) var tocando = false
    public var volume: Float = 1 {
        didSet {
            player.volume = min(max(volume, 0), 1)
        }
    }
    public var velocidade: Float = 1 {
        didSet {
            velocidade = Self.velocidadeNormalizada(velocidade)
            aplicarVelocidadeSePossivel()
        }
    }

    /// Mutável de propósito: a transcrição chega **depois** de a tela abrir
    /// (o processamento leva minutos). Recriar o player nesse momento faria o
    /// áudio voltar ao começo no meio da escuta.
    public var trechos: [Trecho]

    /// Índice do trecho a destacar agora — `nil` antes do primeiro trecho.
    public var indiceAtivo: Int? {
        NavegacaoPorTrecho.indiceAtivo(em: tempo, trechos: trechos)
    }

    /// Existe para o critério de aceite "sair da view não deixa observer vivo":
    /// é o que o teste consegue afirmar sem inspecionar o `AVPlayer`.
    public var observando: Bool { observador != nil }

    @ObservationIgnored private let player: AVPlayer
    @ObservationIgnored private var observador: Any?
    @ObservationIgnored private var fimDaReproducao: (any NSObjectProtocol)?

    public init(
        audio: URL,
        trechos: [Trecho],
        intervalo: TimeInterval = ReprodutorDeArquivo.intervaloDeObservacao
    ) {
        self.trechos = trechos
        let item = AVPlayerItem(url: audio)
        player = AVPlayer(playerItem: item)
        // Sem isto o player volta para o começo ao terminar.
        player.actionAtItemEnd = .pause

        let passo = CMTime(seconds: intervalo, preferredTimescale: 600)
        observador = player.addPeriodicTimeObserver(forInterval: passo, queue: .main) {
            [weak self] agora in
            // O bloco é entregue na main queue, então a isolação já é a certa.
            MainActor.assumeIsolated {
                guard let self else { return }
                self.tempo = agora.seconds.isFinite ? agora.seconds : 0
                self.tocando = self.player.timeControlStatus == .playing
            }
        }

        // O observador periódico não garante um tick no fim do arquivo: sem
        // isto o botão continuaria mostrando "pausar" com o áudio parado.
        fimDaReproducao = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: item,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.tocando = false }
        }
    }

    /// Carrega a duração do arquivo.
    ///
    /// Assíncrono porque ler `AVAsset.duration` de forma síncrona bloqueia a
    /// main thread — a API síncrona está depreciada desde o macOS 13.
    public func preparar() async {
        guard let item = player.currentItem else { return }
        let segundos = (try? await item.asset.load(.duration).seconds) ?? 0
        duracao = segundos.isFinite ? segundos : 0
    }

    // MARK: - Transporte

    public func tocar() {
        aplicarVelocidadeSePossivel()
        tocando = true
    }

    public func pausar() {
        player.pause()
        tocando = false
    }

    public func alternar() {
        tocando ? pausar() : tocar()
    }

    public func definirVelocidade(_ novaVelocidade: Float) {
        velocidade = novaVelocidade
    }

    public func voltar(_ segundos: TimeInterval = 10) async {
        await saltar(paraSegundo: tempo - segundos)
    }

    public func avancar(_ segundos: TimeInterval = 10) async {
        await saltar(paraSegundo: tempo + segundos)
    }

    // MARK: - Navegação

    /// Salta para o início do trecho — o gesto do Passo 10.
    public func saltar(para trecho: Trecho) async {
        await saltar(paraSegundo: trecho.start)
    }

    /// Vai ao começo do trecho e inicia a escuta. A ordem é importante: dar
    /// `play()` antes do fim do `seek` pode produzir alguns décimos do ponto
    /// anterior em arquivos AAC.
    public func tocar(aPartirDe trecho: Trecho) async {
        await saltar(para: trecho)
        tocar()
    }

    /// Salta para um instante, com **tolerância zero**.
    ///
    /// Tolerância padrão faria o player cair no quadro sincronizado mais
    /// próximo, que em AAC pode estar segundos antes — clicar num trecho
    /// pousaria no meio do trecho anterior.
    public func saltar(paraSegundo segundo: TimeInterval) async {
        let teto = duracao > 0 ? duracao : segundo
        let alvo = min(max(0, segundo), teto)

        // Atualiza antes do `await`: o destaque responde ao clique, não ao
        // próximo tick do observador.
        tempo = alvo

        await player.seek(
            to: CMTime(seconds: alvo, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )

        let real = player.currentTime().seconds
        if real.isFinite { tempo = real }
    }

    // MARK: - Encerramento

    /// Remove o observador periódico e para o áudio.
    ///
    /// Chame no `onDisappear`. `addPeriodicTimeObserver` retém o bloco até o
    /// `removeTimeObserver`; sem isso a view morre e o bloco continua rodando,
    /// que é exatamente o que o critério de aceite do Passo 10 proíbe.
    public func encerrar() {
        if let observador {
            player.removeTimeObserver(observador)
            self.observador = nil
        }
        if let fimDaReproducao {
            NotificationCenter.default.removeObserver(fimDaReproducao)
            self.fimDaReproducao = nil
        }
        player.pause()
        tocando = false
    }

    /// Rede de segurança para quem esquecer o `encerrar()`.
    ///
    /// `isolated deinit` (SE-0371) é o que torna isto possível num tipo
    /// `@MainActor`: um `deinit` comum é `nonisolated` e não poderia tocar no
    /// estado da classe.
    isolated deinit {
        encerrar()
    }

    private static func velocidadeNormalizada(_ valor: Float) -> Float {
        min(max(valor.isFinite ? valor : 1, 0.5), 2)
    }

    private func aplicarVelocidadeSePossivel() {
        guard player.currentItem?.status == .readyToPlay else { return }
        player.rate = tocando ? velocidade : 0
    }
}
