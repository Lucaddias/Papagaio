import AppKit
import AuthenticationServices
import Foundation
import Observation
import Security

/// Identidade opcional do perfil local.
///
/// O identificador do Sign in with Apple serve apenas ao perfil deste app;
/// arquivos, gravações e notas permanecem locais neste lançamento.
@MainActor
@Observable
final class PerfilViewModel: NSObject {
    private enum Chave {
        static let servico = "com.papagaio.Papagaio.perfil"
        static let conta = "apple-user-identifier"
    }

    private(set) var identificador: String?
    private(set) var verificando = false
    private(set) var erro: String?
    private var observadorDeRevogacao: NSObjectProtocol?

    var conectado: Bool { identificador != nil }

    override init() {
        super.init()
        observadorDeRevogacao = NotificationCenter.default.addObserver(
            forName: ASAuthorizationAppleIDProvider.credentialRevokedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.removerCredencial() }
        }
    }

    isolated deinit {
        if let observadorDeRevogacao {
            NotificationCenter.default.removeObserver(observadorDeRevogacao)
        }
    }

    /// Restaura a sessão local e confirma seu estado com a Apple.
    func iniciar() {
        guard let id = lerDoKeychain() else { return }
        identificador = id
        verificarEstadoDaCredencial(id)
    }

    func entrar() {
        erro = nil
        let requisicao = ASAuthorizationAppleIDProvider().createRequest()
        requisicao.requestedScopes = [.fullName, .email]

        let controlador = ASAuthorizationController(authorizationRequests: [requisicao])
        controlador.delegate = self
        controlador.presentationContextProvider = self
        controlador.performRequests()
    }

    func sair() {
        // Sair só remove o perfil deste app. Não revoga o consentimento na Apple.
        removerCredencial()
    }

    func dispensarErro() {
        erro = nil
    }

    private func verificarEstadoDaCredencial(_ id: String) {
        verificando = true
        ASAuthorizationAppleIDProvider().getCredentialState(forUserID: id) { [weak self] estado, erro in
            Task { @MainActor in
                guard let self else { return }
                self.verificando = false
                switch estado {
                case .authorized:
                    break
                case .revoked, .notFound, .transferred:
                    self.removerCredencial()
                @unknown default:
                    self.erro = erro?.localizedDescription ?? "Não foi possível validar a credencial da Apple."
                }
            }
        }
    }

    private func salvarNoKeychain(_ id: String) throws {
        removerDoKeychain()
        let consulta: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Chave.servico,
            kSecAttrAccount: Chave.conta,
            kSecValueData: Data(id.utf8),
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
        ]
        let status = SecItemAdd(consulta as CFDictionary, nil)
        guard status == errSecSuccess else { throw ErroKeychain(status: status) }
    }

    private func lerDoKeychain() -> String? {
        let consulta: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Chave.servico,
            kSecAttrAccount: Chave.conta,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var resultado: CFTypeRef?
        let status = SecItemCopyMatching(consulta as CFDictionary, &resultado)
        guard status == errSecSuccess, let dados = resultado as? Data else { return nil }
        return String(data: dados, encoding: .utf8)
    }

    private func removerCredencial() {
        removerDoKeychain()
        identificador = nil
    }

    private func removerDoKeychain() {
        let consulta: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Chave.servico,
            kSecAttrAccount: Chave.conta,
        ]
        SecItemDelete(consulta as CFDictionary)
    }

    private struct ErroKeychain: LocalizedError {
        let status: OSStatus
        var errorDescription: String? {
            SecCopyErrorMessageString(status, nil) as String? ?? "Erro do Keychain (\(status))."
        }
    }
}

extension PerfilViewModel: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credencial = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
        let id = credencial.user
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try self.salvarNoKeychain(id)
                self.identificador = id
            } catch {
                self.erro = "Não foi possível guardar sua sessão: \(error.localizedDescription)"
            }
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let codigo = (error as? ASAuthorizationError)?.code
        Task { @MainActor [weak self] in
            // Cancelar o painel não é um erro de produto.
            if codigo != .canceled { self?.erro = error.localizedDescription }
        }
    }
}

extension PerfilViewModel: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        NSApplication.shared.keyWindow ?? ASPresentationAnchor()
    }
}
