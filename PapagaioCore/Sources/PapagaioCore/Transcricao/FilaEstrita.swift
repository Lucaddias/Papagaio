import Foundation

/// Fila FIFO de exclusão mútua para seções críticas assíncronas.
///
/// Um ator comum não basta: cada `await` dentro de um método do ator libera a
/// fila dele, e quem espera entra no meio — reentrância. Para estado de
/// sequência (o `contexto` e o `estado` do Silero VAD, por exemplo) é preciso
/// que a sessão **inteira** aconteça sem ninguém atravessando: quem entrou
/// termina antes do próximo entrar.
///
/// Uso: `await fila.entrar()` … trabalho … `await fila.sair()`. O `sair`
/// precisa acontecer em todo caminho (inclusive no de erro) — ver o
/// `do/catch` do `DetectorDeAtividadeDeVoz.janelasDeFala`.
actor FilaEstrita {
    private var ocupado = false
    private var fila: [CheckedContinuation<Void, Never>] = []

    func entrar() async {
        if ocupado {
            await withCheckedContinuation { continuacao in
                fila.append(continuacao)
            }
            // Ao retomar, o dono anterior já entregou a vez: a exclusividade
            // é nossa sem tocar em `ocupado` (continua `true`).
            return
        }
        ocupado = true
    }

    func sair() {
        if let proximo = fila.first {
            fila.removeFirst()
            proximo.resume()
        } else {
            ocupado = false
        }
    }
}
