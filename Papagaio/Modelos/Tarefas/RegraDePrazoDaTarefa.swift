import Foundation

/// Prioridade sugerida pela proximidade do prazo — só promove, nunca rebaixa.
///
/// Inspirada no cálculo de urgência por deadline do Antikaos: lá, quanto mais
/// perto o prazo, maior o peso da tarefa. Aqui não existe "dificuldade
/// percebida" nem sessões — só o prazo —, então a régua tem dois degraus em
/// vez de quatro: perto vira Alta, próximo vira pelo menos Média.
///
/// Só promove porque uma tarefa que a pessoa marcou como Alta por conta
/// própria, sem prazo perto, não deveria cair sozinha para Baixa — isso seria
/// a régua decidindo por ela. Sem prazo, ou com prazo longe, a prioridade
/// continua sendo o que já era.
enum RegraDePrazoDaTarefa {
    /// Mesmo limite do Antikaos para "prazo perto" (`nearDeadlineDayLimit`).
    private static let diasParaAlta = 2
    /// Uma semana: perto o bastante para merecer atenção, longe o bastante
    /// para não empurrar tudo para Alta.
    private static let diasParaMedia = 7

    /// Aplica a régua a uma tarefa. Tarefas concluídas não mudam — prioridade
    /// de algo já feito não tem para quem servir — e tarefas cuja prioridade a
    /// pessoa já escolheu à mão também não: a régua é para promover sugestões
    /// esquecidas, não para desfazer uma escolha manual.
    static func ajustada(_ tarefa: TarefaDaConversa) -> TarefaDaConversa {
        var ajustada = tarefa
        guard !ajustada.prioridadeEhManual,
              ajustada.status != .concluida,
              let dias = diasAte(ajustada.prazo)
        else { return ajustada }

        if dias <= diasParaAlta {
            ajustada.prioridade = .alta
        } else if dias <= diasParaMedia, ajustada.prioridade == .baixa {
            ajustada.prioridade = .media
        }
        return ajustada
    }

    /// Perto o bastante para avisar a pessoa — o mesmo limite que promove
    /// para Alta.
    static func prazoEstaPerto(_ prazo: Date?) -> Bool {
        guard let dias = diasAte(prazo) else { return false }
        return dias <= diasParaAlta
    }

    private static func diasAte(_ prazo: Date?) -> Int? {
        guard let prazo else { return nil }
        let calendario = Calendar.current
        let hoje = calendario.startOfDay(for: Date())
        let diaDoPrazo = calendario.startOfDay(for: prazo)
        return calendario.dateComponents([.day], from: hoje, to: diaDoPrazo).day
    }
}
