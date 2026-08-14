import Foundation

/// Quanto tempo este Mac leva para processar um segundo de áudio.
///
/// A estimativa antiga era um fator fixo — duração do áudio vezes 0,75 —, e
/// fator fixo erra por construção: depende do chip, de quantos apps disputam a
/// GPU, de o modelo estar carregado ou vindo do disco, e da temperatura. Numa
/// conversa de uma hora, errar por 30% são vinte minutos de diferença entre o
/// que a barra promete e o que acontece.
///
/// Aqui o número vem de medição: ao fim de cada processamento, guardamos a
/// razão entre o tempo gasto e a duração do áudio. A estimativa seguinte usa a
/// média das últimas execuções, então o app acerta cada vez mais nesta máquina
/// específica — sem precisar de instrumentação dentro do whisper.
enum RitmoDeProcessamento {
    private static let chave = "ritmoDeProcessamento.amostras"

    /// Quantas execuções entram na média.
    ///
    /// Poucas demais e um pico de calor estraga a próxima estimativa; muitas
    /// demais e o app demora a perceber que a máquina mudou de condição — como
    /// fechar o Xcode e liberar a GPU. Cinco equilibra os dois.
    private static let amostrasConsideradas = 5

    /// Palpite inicial, para a primeira conversa de todas.
    ///
    /// Medido nos Macs da equipe: uma hora de áudio leva de 10 a 15 minutos —
    /// razão entre 0,17 e 0,25. Fica na ponta pessimista da faixa, porque
    /// barra que termina antes do previsto é boa surpresa e barra que estoura
    /// o prazo faz a pessoa achar que o app travou.
    ///
    /// Vale só para a primeira execução; da segunda em diante manda a medição.
    private static let razaoInicial: Double = 0.25

    /// Piso de tempo, para áudios curtos.
    ///
    /// Carregar os modelos locais custa dezenas de segundos independentemente
    /// do tamanho do áudio. Sem o piso, um áudio de 20 segundos prometeria
    /// terminar em 20 e ficaria travado em 95% durante um minuto.
    private static let pisoEmSegundos: TimeInterval = 45

    /// Tempo provável, em segundos, para processar um áudio desta duração.
    static func estimativa(paraAudioDe duracao: TimeInterval) -> TimeInterval {
        max(pisoEmSegundos, duracao * razaoMedia)
    }

    /// Guarda o resultado de uma execução concluída.
    static func registrar(decorrido: TimeInterval, paraAudioDe duracao: TimeInterval) {
        guard duracao > 0, decorrido > 0 else { return }

        // Descarta absurdos: uma execução interrompida e retomada, ou o Mac
        // dormindo no meio, produz razões que não descrevem máquina nenhuma.
        let razao = decorrido / duracao
        guard razao > 0.05, razao < 20 else { return }

        var amostras = UserDefaults.standard.array(forKey: chave) as? [Double] ?? []
        amostras.append(razao)
        if amostras.count > amostrasConsideradas {
            amostras.removeFirst(amostras.count - amostrasConsideradas)
        }
        UserDefaults.standard.set(amostras, forKey: chave)
    }

    /// Razão média medida, ou o palpite inicial enquanto não há histórico.
    static var razaoMedia: Double {
        let amostras = UserDefaults.standard.array(forKey: chave) as? [Double] ?? []
        guard !amostras.isEmpty else { return razaoInicial }
        return amostras.reduce(0, +) / Double(amostras.count)
    }

    /// Para testes e para quando a máquina muda de condição de forma drástica.
    static func esquecer() {
        UserDefaults.standard.removeObject(forKey: chave)
    }
}
