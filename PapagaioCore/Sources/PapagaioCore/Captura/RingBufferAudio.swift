import Synchronization

/// Ring buffer lock-free de um produtor e um consumidor, para atravessar a
/// fronteira entre a thread de áudio e o resto do app.
///
/// O produtor é sempre uma thread de áudio de alta prioridade: o bloco do tap
/// do `AVAudioEngine` ou o `AudioDeviceIOProc`. Lá dentro é proibido alocar,
/// travar lock, criar `Task` ou logar — por isso `escrever` só faz aritmética
/// e cópia de memória.
///
/// `@unchecked Sendable`: a segurança vem dos índices atômicos com ordering
/// acquire/release, não do checador do compilador.
public final class RingBufferAudio: @unchecked Sendable {
    private let capacidade: Int
    private let dados: UnsafeMutablePointer<Float>

    /// Total de amostras já escritas e já lidas desde sempre. Monotônicos —
    /// a diferença entre eles é o que está pendente. Índice real é `% capacidade`.
    private let escritas = Atomic<Int>(0)
    private let lidas = Atomic<Int>(0)

    /// Quantas amostras o produtor teve que descartar por buffer cheio.
    /// Diagnóstico de dropout: se isto sobe, o consumidor não está acompanhando.
    private let descartadas = Atomic<Int>(0)

    public init(capacidade: Int) {
        precondition(capacidade > 0)
        self.capacidade = capacidade
        self.dados = UnsafeMutablePointer<Float>.allocate(capacity: capacidade)
        self.dados.initialize(repeating: 0, count: capacidade)
    }

    deinit {
        dados.deinitialize(count: capacidade)
        dados.deallocate()
    }

    public var amostrasDescartadas: Int { descartadas.load(ordering: .relaxed) }

    public var pendentes: Int {
        escritas.load(ordering: .acquiring) - lidas.load(ordering: .acquiring)
    }

    /// Chamado **na thread de áudio**. Sem alocação, sem lock, sem log.
    /// Retorna `false` se teve que descartar por falta de espaço.
    @discardableResult
    public func escrever(_ origem: UnsafePointer<Float>, quantidade: Int) -> Bool {
        let jaEscritas = escritas.load(ordering: .relaxed)
        let jaLidas = lidas.load(ordering: .acquiring)
        let livre = capacidade - (jaEscritas - jaLidas)

        guard livre > 0 else {
            descartadas.add(quantidade, ordering: .relaxed)
            return false
        }

        let aEscrever = min(quantidade, livre)
        let inicio = jaEscritas % capacidade
        let ateOFim = min(aEscrever, capacidade - inicio)

        (dados + inicio).update(from: origem, count: ateOFim)
        if aEscrever > ateOFim {
            dados.update(from: origem + ateOFim, count: aEscrever - ateOFim)
        }

        escritas.store(jaEscritas + aEscrever, ordering: .releasing)

        if aEscrever < quantidade {
            descartadas.add(quantidade - aEscrever, ordering: .relaxed)
            return false
        }
        return true
    }

    /// Chamado no consumidor. Retorna quantas amostras realmente saíram.
    public func ler(para destino: UnsafeMutablePointer<Float>, quantidade: Int) -> Int {
        let jaLidas = lidas.load(ordering: .relaxed)
        let jaEscritas = escritas.load(ordering: .acquiring)
        let disponivel = jaEscritas - jaLidas
        guard disponivel > 0 else { return 0 }

        let aLer = min(quantidade, disponivel)
        let inicio = jaLidas % capacidade
        let ateOFim = min(aLer, capacidade - inicio)

        destino.update(from: dados + inicio, count: ateOFim)
        if aLer > ateOFim {
            (destino + ateOFim).update(from: dados, count: aLer - ateOFim)
        }

        lidas.store(jaLidas + aLer, ordering: .releasing)
        return aLer
    }
}
