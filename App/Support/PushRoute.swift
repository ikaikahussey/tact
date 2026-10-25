import SwiftUI

/// Pushes a screen onto the root navigation stack from anywhere beneath it,
/// for places that cannot hold a `NavigationLink` (gestures, menus).
struct PushRouteKey: EnvironmentKey {
    static let defaultValue: (Route) -> Void = { _ in }
}

extension EnvironmentValues {
    var pushRoute: (Route) -> Void {
        get { self[PushRouteKey.self] }
        set { self[PushRouteKey.self] = newValue }
    }
}
