import SwiftUI

/// A small round button floating over the Tiles and Tangram canvases, for
/// actions that rearrange everyone at once. The label is spoken, not shown.
struct CanvasActionButton: View {
    let title: String
    let systemImage: String
    let hint: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.tint, in: Circle())
                .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
                .opacity(isEnabled ? 1 : 0.35)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(title)
        .accessibilityHint(hint)
    }
}
