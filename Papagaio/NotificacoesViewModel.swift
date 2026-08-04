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

@MainActor
@Observable
final class NotificacoesViewModel {
    private(set) var itens: [NotificacaoDoApp] = []
    private var permissaoSolicitada = false
    private let delegate = NotificacoesDoSistemaDelegate()

    var naoLidas: Int {
        itens.filter { !$0.lida }.count
    }

    func preparar() {
        guard !permissaoSolicitada else { return }
        permissaoSolicitada = true

        let central = UNUserNotificationCenter.current()
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
        enviarNotificacaoDoSistema(notificacao)
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

    private func enviarNotificacaoDoSistema(_ notificacao: NotificacaoDoApp) {
        let conteudo = UNMutableNotificationContent()
        conteudo.title = notificacao.titulo
        conteudo.body = notificacao.mensagem
        conteudo.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: notificacao.id.uuidString,
            content: conteudo,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }
}

private final class NotificacoesDoSistemaDelegate: NSObject, UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}
