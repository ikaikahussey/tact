import SwiftUI
import UIKit

/// The device shaken: the system's gesture for Undo. Posted from the
/// window so any view can listen.
extension Notification.Name {
    static let deviceDidShake = Notification.Name("TactDeviceDidShake")
}

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShake, object: nil)
        }
        super.motionEnded(motion, with: event)
    }
}

extension View {
    /// Runs `action` when the device is shaken while this view is on screen.
    func onShake(perform action: @escaping () -> Void) -> some View {
        onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in action() }
    }
}
