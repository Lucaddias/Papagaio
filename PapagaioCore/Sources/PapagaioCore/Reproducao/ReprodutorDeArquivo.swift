import AVFoundation
import Foundation
import Observation

/// Player de áudio com navegação por trecho — backend portado do Eko
/// (`AudioPlaybackController`).
///
/// Toca **dois arquivos em paralelo**: o microfone (`.wav`) e o canal do
/// sistema (`.m4a`) são reproduzidos juntos, sincronizados pelo
/// `deviceCurrentTime` do `AVAudioPlayer` — o "merge só no playback" do Eko.
/// Nunca há mixagem prévia em disco, e é por isso que o áudio não sai mais
/// abafado (a mixagem antiga re-encodava tudo para AAC mono de 16 kHz).
///
/// Para arquivo de canal único (importado ou gravação antiga) o secundário é
/// `nil` e toca normal. Usa `AVAudioPlayer`, não `AVPlayer` — é o que o Eko
/// usa, e é o que abre o `.wav` do microfone e o `.m4a` do tap sem os
/// problemas do player antigo.
///
/// - Important: quem cria **tem que chamar `encerrar()`** ao sair da tela. O
///   temporizador de observação retém o bloco e sobrevive à view que o criou.
@MainActor
@Observable
public final class ReprodutorDeArquivo {
    /// ~10 Hz: rápido o bastante para o destaque não parecer travado, devagar o
    /// bastante para não acordar a main thread à toa. É o intervalo do Passo 10.
    public static let intervaloDeObservacao: TimeInterval = 0.1

    /// Posição atual, em segundos. Alimentada pelo temporizador de observação.
    public private(set) var tempo: TimeInterval = 0
    /// Duração do arquivo — o maior dos dois canais quando existem dois.
    public private(set) var duracao: TimeInterval = 0
    public private(set) var tocando = false
    public var volume: Float = 1 {
        didSet {
            let nivel = min(max(volume, 0), 1)
            primario?.volume = nivel
            secundario?.volume = nivel
        }
    }
    public var velocidade: Float = 1 {
        didSet {
            velocidade = Self.velocidadeNormalizada(velocidade)
            aplicarVelocidade()
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

    /// Existe para o critério de aceite "sair da view não deixa observador vivo":
    /// é o que o teste consegue afirmar sem inspecionar o player.
    public var observando: Bool { temporizador != nil }

    /// Canal do microfone (ou o arquivo único, no caso de importado/legado).
    private let primario: AVAudioPlayer?
    /// Canal do sistema, tocado em paralelo ao microfone quando ambos existem.
    private let secundario: AVAudioPlayer?

    @ObservationIgnored private var temporizador: Timer?

    public init(
        audio: URL,
        trechos: [Trecho],
        secundario urlSecundario: URL? = nil,
        intervalo: TimeInterval = ReprodutorDeArquivo.intervaloDeObservacao
    ) {
        self.trechos = trechos
        self.primario = try? AVAudioPlayer(contentsOf: audio)
        self.secundario = urlSecundario.flatMap { try? AVAudioPlayer(contentsOf: $0) }
        self.intervaloDeObservacao = intervalo

        primario?.enableRate = true
        primario?.volume = volume
        secundario?.enableRate = true
        secundario?.volume = volume
    }

    /// `preparar()` carrega a duração e liga o observador.
    ///
    /// A duração do `AVAudioPlayer` já vem sincrona do `init`; aqui é onde o
    /// observador de tempo nasce — antes de qualquer `tocar()`, para que o
    /// `tempo` publicado nunca fique preso no 0.
    public func preparar() async {
        let primaria = primario?.duration ?? 0
        let secundaria = secundario?.duration ?? 0
        duracao = max(primaria, secundaria)
        temporizador?.invalidate()
        // `Timer.scheduledTimer` é indisponível de contexto async no Swift 6.2
        // (pode nunca disparar); criar o timer e anexá-lo ao RunLoop da main
        // foge disso e garante o modo `.common` (roda também durante gestos).
        //
        // Bloco, e não `target:`/`selector:`, por dois motivos. O `#selector`
        // exige um método `@objc`, e só classe que herda de `NSObject` pode
        // declarar membro `@objc` — esta não herda (é `@Observable` puro).
        // E o inicializador com alvo **retém** o alvo: o `deinit` abaixo nunca
        // rodaria, justamente a rede de segurança que ele existe para ser.
        //
        // O timer é entregue no RunLoop da main, então a isolação já é a certa.
        let timer = Timer(timeInterval: intervaloDeObservacao, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.atualizarTempo() }
        }
        temporizador = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    // MARK: - Transporte

    public func tocar() {
        guard let primario, !primario.isPlaying else { return }
        // Sincroniza os dois pelo mesmo deviceCurrentTime — evita que um
        // comece perceptivelmente antes do outro.
        let inicio = primario.deviceCurrentTime + 0.05
        aplicarVelocidade()
        primario.play(atTime: inicio)
        secundario?.play(atTime: inicio)
        tocando = true
    }

    public func pausar() {
        primario?.pause()
        secundario?.pause()
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

    /// Vai ao começo do trecho e inicia a escuta.
    public func tocar(aPartirDe trecho: Trecho) async {
        await saltar(para: trecho)
        tocar()
    }

    /// Salta para um instante. No `AVAudioPlayer` o `currentTime` é exato —
    /// sem a tolerância de quadro sincronizado do `AVPlayer` que fazia cliques
    /// em AAC pousarem no trecho anterior.
    public func saltar(paraSegundo segundo: TimeInterval) async {
        let teto = duracao > 0 ? duracao : segundo
        let alvo = min(max(0, segundo), teto)

        // Atualiza antes do tick: o destaque responde ao clique, não ao
        // próximo tick do observador.
        tempo = alvo
        primario?.currentTime = alvo
        secundario?.currentTime = alvo
    }

    // MARK: - Encerramento

    /// Para o áudio e remove o observador.
    ///
    /// Chame no `onDisappear`. O `Timer` retém o alvo até o `invalidate`;
    /// sem isto a view morre e o observador continua rodando, que é
    /// exatamente o que o critério de aceite do Passo 10 proíbe.
    public func encerrar() {
        temporizador?.invalidate()
        temporizador = nil
        primario?.stop()
        secundario?.stop()
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

    // MARK: - Observação

    private func atualizarTempo() {
        tempo = primario?.currentTime ?? 0
        tocando = primario?.isPlaying ?? false
    }

    private func aplicarVelocidade() {
        primario?.rate = velocidade
        secundario?.rate = velocidade
    }

    private let intervaloDeObservacao: TimeInterval

    private static func velocidadeNormalizada(_ valor: Float) -> Float {
        min(max(valor.isFinite ? valor : 1, 0.5), 2)
    }
}
