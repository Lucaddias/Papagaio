import Foundation

/// Uma palavra dentro de uma fala, com a âncora no trecho de origem.
///
/// A fala atravessa trechos (a voz não respeita a janela de 40 s da
/// `Segmentacao`) — para o player continuar navegando, cada palavra guarda o
/// trecho e o índice de onde veio.
public struct PalavraDeFala: Sendable, Equatable {
    public let palavra: Palavra
    public let trechoId: UUID
    public let indiceNoTrecho: Int

    public init(palavra: Palavra, trechoId: UUID, indiceNoTrecho: Int) {
        self.palavra = palavra
        self.trechoId = trechoId
        self.indiceNoTrecho = indiceNoTrecho
    }
}

/// Uma fala: o maior encadeamento contínuo de palavras do mesmo falante
/// acústico, na ordem cronológica da conversa.
///
/// Regra dos dois rótulos: `speaker` (canal de origem) continua separado de
/// `falanteAcustico` (voz). `speaker` só é preenchido quando a fala inteira
/// veio de um único canal — misturou microfone e sistema, fica `nil`.
public struct FalaDeFalante: Sendable, Identifiable, Equatable {
    public let id: UUID
    public let falanteAcustico: String?
    public let inicio: TimeInterval
    public let fim: TimeInterval
    public let palavras: [PalavraDeFala]
    /// Texto corrido: palavras unidas, ou o texto do trecho sem palavras
    /// (editado à mão ou gravado antes da diarização) — sem isto a fala
    /// desapareceria da interface.
    public let texto: String
    public let speaker: String?
    /// Trechos de origem, únicos e na ordem em que aparecem na fala.
    public let trechoIds: [UUID]

    public init(
        id: UUID,
        falanteAcustico: String?,
        inicio: TimeInterval,
        fim: TimeInterval,
        palavras: [PalavraDeFala],
        texto: String,
        speaker: String?,
        trechoIds: [UUID],
    ) {
        self.id = id
        self.falanteAcustico = falanteAcustico
        self.inicio = inicio
        self.fim = fim
        self.palavras = palavras
        self.texto = texto
        self.speaker = speaker
        self.trechoIds = trechoIds
    }
}

/// Agrupa a transcrição em falas por falante acústico.
///
/// Uma fala é o maior encadeamento de palavras consecutivas com o mesmo
/// `Palavra.falanteAcustico`, na ordem cronológica da conversa — o trecho é só
/// a janela de leitura e não corta a fala. Palavras sem falante (empate
/// técnico da diarização) formam fala própria: não se fundem com ninguém.
///
/// - Returns: `nil` quando nenhuma palavra tem `falanteAcustico` (sem
///   diarização) — a interface volta aos blocos de trecho.
/// - Precondition: `trechos` ordenado por `start`, contrato da `Segmentacao`.
public enum FalasDaConversa {
    public static func agrupar(_ trechos: [Trecho]) -> [FalaDeFalante]? {
        let temDiarizacao = trechos.contains { trecho in
            trecho.palavras.contains { $0.falanteAcustico != nil }
        }
        guard temDiarizacao else { return nil }

        var falas: [FalaDeFalante] = []
        var atuais: [PalavraDeFala] = []
        var falanteAtual: String?
        var trechosDaFala: [UUID] = []

        func fechar() {
            guard let primeira = atuais.first, let ultima = atuais.last else { return }
            falas.append(FalaDeFalante(
                id: primeira.palavra.id,
                falanteAcustico: falanteAtual,
                inicio: primeira.palavra.start,
                fim: ultima.palavra.end,
                palavras: atuais,
                texto: atuais.map { $0.palavra.texto }.joined(separator: " "),
                speaker: canalUniforme(dos: trechosDaFala, em: trechos),
                trechoIds: trechosDaFala
            ))
            atuais = []
            falanteAtual = nil
            trechosDaFala = []
        }

        for trecho in trechos {
            // Trecho sem palavras (legado ou editado à mão): vira fala própria.
            // Não pode sumir da conversa nem se fundir com uma voz.
            if trecho.palavras.isEmpty {
                fechar()
                falas.append(FalaDeFalante(
                    id: trecho.id,
                    falanteAcustico: nil,
                    inicio: trecho.start,
                    fim: trecho.end,
                    palavras: [],
                    texto: trecho.texto,
                    speaker: trecho.speaker,
                    trechoIds: [trecho.id]
                ))
                continue
            }

            for (indice, palavra) in trecho.palavras.enumerated() {
                if falanteAtual != palavra.falanteAcustico {
                    fechar()
                    falanteAtual = palavra.falanteAcustico
                }
                atuais.append(PalavraDeFala(
                    palavra: palavra,
                    trechoId: trecho.id,
                    indiceNoTrecho: indice
                ))
                if trechosDaFala.last != trecho.id {
                    trechosDaFala.append(trecho.id)
                }
            }
        }
        fechar()
        return falas
    }

    /// O canal de origem quando todos os trechos da fala vieram do mesmo
    /// canal; `nil` quando a fala mistura microfone e sistema.
    private static func canalUniforme(dos ids: [UUID], em trechos: [Trecho]) -> String? {
        let canais = ids.compactMap { id in
            trechos.first { $0.id == id }?.speaker
        }
        guard !canais.isEmpty, Set(canais).count == 1 else { return nil }
        return canais[0]
    }
}
