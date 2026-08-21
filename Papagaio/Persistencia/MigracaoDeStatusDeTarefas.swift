import Foundation

/// Reclassifica, uma única vez, as tarefas "Em andamento" gravadas antes de
/// existir a coluna "Não iniciado".
///
/// Até esta versão só havia dois estados, e toda tarefa nascia em "Em
/// andamento" — inclusive as que ninguém tinha sequer aberto ainda. Era o
/// "resto" do sistema antigo, não um sinal de que alguém começou a trabalhar
/// nela. Com "Não iniciado" existindo agora como estado de nascença, deixar
/// essas tarefas onde estavam faria todo o histórico da pessoa aparecer como
/// se já estivesse em progresso — exatamente o que a coluna nova existe para
/// não fingir.
///
/// Só toca em "Em andamento": tarefas concluídas continuam concluídas, e
/// qualquer tarefa que a própria pessoa mover para "Em andamento" depois desta
/// migração — inclusive de volta — não é mexida de novo, porque isto roda uma
/// vez só.
enum MigracaoDeStatusDeTarefas {
    private static let chaveDeControle = "migracaoStatusTarefaNaoIniciado.v1"
    private static let prefixoDeChave = "tarefasDaConversa."

    static func executarUmaVez(_ defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: chaveDeControle) else { return }
        defaults.set(true, forKey: chaveDeControle)

        for chave in defaults.dictionaryRepresentation().keys where chave.hasPrefix(prefixoDeChave) {
            guard let dados = defaults.data(forKey: chave),
                  var tarefas = try? JSONDecoder().decode([TarefaDaConversa].self, from: dados)
            else { continue }

            var mudou = false
            for indice in tarefas.indices where tarefas[indice].status == .emAndamento {
                tarefas[indice].status = .naoIniciado
                mudou = true
            }

            guard mudou, let novos = try? JSONEncoder().encode(tarefas) else { continue }
            defaults.set(novos, forKey: chave)
        }
    }
}
