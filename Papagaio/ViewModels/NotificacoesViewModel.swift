import Foundation
import Observation
import UserNotifications

struct NotificacaoDoApp: Identifiable, Equatable {
    enum Tipo {
        case sucesso
        case aviso
        case erro
    }

    let id = UUID()
    let titulo: String
    let mensagem: String
    let data: Date
    let tipo: Tipo
    var lida = false

    var simbolo: String {
        switch tipo {
        case .sucesso: "checkmark.circle.fill"
        case .aviso: "clock.fill"
        case .erro: "exclamationmark.triangle.fill"
        }
    }
}

/// Avisos do app: a lista interna, no sino, e a faixa do sistema.
///
/// As duas coisas andam juntas de propósito. A lista responde "o que aconteceu
/// enquanto eu não estava olhando"; a faixa responde "aconteceu agora". Um
/// aviso que só existe dentro do app não serve para o caso principal daqui, que
/// é transcrever por vários minutos com a janela minimizada.
@MainActor
@Observable
final class NotificacoesViewModel {
    private(set) var itens: [NotificacaoDoApp] = []

    /// O delegate precisa viver enquanto o app viver: o
    /// `UNUserNotificationCenter` guarda uma referência fraca, e um delegate
    /// liberado significa nenhuma faixa com o app em primeiro plano.
    private let delegate = DelegateDeNotificacoes()
    private var preparado = false

    var naoLidas: Int {
        itens.filter { !$0.lida }.count
    }

    /// Monta o delegate e pede autorização. Idempotente.
    func preparar() {
        guard !preparado else { return }
        preparado = true

        let central = UNUserNotificationCenter.current()
        // Antes do pedido de autorização: é o delegate que decide se a faixa
        // aparece com a janela na frente, e ele precisa estar no lugar quando
        // a primeira notificação chegar.
        central.delegate = delegate
        central.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func registrar(titulo: String, mensagem: String, tipo: NotificacaoDoApp.Tipo) {
        let notificacao = NotificacaoDoApp(
            titulo: titulo,
            mensagem: mensagem,
            data: Date(),
            tipo: tipo
        )
        itens.insert(notificacao, at: 0)
        itens = Array(itens.prefix(20))
        entregar(notificacao)
    }

    func marcarComoLidas() {
        for indice in itens.indices {
            itens[indice].lida = true
        }
    }

    func limpar() {
        itens.removeAll()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    private func entregar(_ notificacao: NotificacaoDoApp) {
        let conteudo = UNMutableNotificationContent()
        conteudo.title = notificacao.titulo
        conteudo.body = notificacao.mensagem
        conteudo.sound = .default

        // Sem `interruptionLevel`: os níveis acima do padrão dependem de
        // entitlement, que por sua vez depende de perfil de provisionamento
        // válido. Numa build assinada localmente o macOS aceita o pedido, não
        // devolve erro e descarta a notificação em silêncio.
        //
        // Sem `trigger`: entrega imediata. Com gatilho por tempo, fechar ou
        // minimizar a janela no intervalo às vezes cancelava a entrega — e é
        // justamente aí que o aviso importa.
        let pedido = UNNotificationRequest(
            identifier: notificacao.id.uuidString,
            content: conteudo,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(pedido)
    }
}

/// Autoriza a faixa mesmo com o app em primeiro plano.
///
/// Sem isto o macOS entrega a notificação em silêncio quando a janela está
/// visível, no pressuposto de que a pessoa já está vendo o que aconteceu — o
/// que não vale aqui, já que a transcrição termina em outra tela.
private final class DelegateDeNotificacoes: NSObject, UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}
