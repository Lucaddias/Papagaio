import AppKit
import Foundation

enum Diagnostico {
    /// Sob App Sandbox o home do processo é redirecionado para
    /// `~/Library/Containers/<bundle-id>/Data`.
    static var sandboxAtivo: Bool {
        NSHomeDirectory().contains("/Library/Containers/")
    }
}
