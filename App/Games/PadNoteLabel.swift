import SwiftUI

/// The note a Simon pad sounds, as a small badge in its corner for when the
/// pads are a keyboard: the name in the pad's dark shade on its pale one, so
/// it reads on the motif whatever the colour. `isShowing` fades it out,
/// as during a round of Simon, where the pads are to be remembered by
/// sight and sound rather than read.
struct PadNoteLabel: View {
    let name: String
    let shades: TileShades
    var isShowing = true

    var body: some View {
        Text(name)
            .font(.tact(.caption2).weight(.bold).monospacedDigit())
            .foregroundStyle(shades.dark)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(shades.paper.opacity(0.9), in: Capsule())
            .padding(4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .opacity(isShowing ? 1 : 0)
            .animation(.easeInOut(duration: 0.2), value: isShowing)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
