import SwiftUI

/// Wrapping row of person chips that toggle membership in `selectedPersonIds`,
/// with an "Add" chip at the end. Long-press a chip to open that person.
struct PersonChipRow: View {
    @EnvironmentObject private var store: TactStore
    @Binding var selectedPersonIds: Set<UUID>
    var onAdd: () -> Void
    var onOpen: ((UUID) -> Void)? = nil

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(store.people) { person in
                let isSelected = selectedPersonIds.contains(person.id)
                Button {
                    if isSelected { selectedPersonIds.remove(person.id) } else { selectedPersonIds.insert(person.id) }
                } label: {
                    PersonChip(person: person, isSelected: isSelected)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(person.name)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                .accessibilityHint(isSelected ? "Unlinks this person" : "Links this person")
                .contextMenu {
                    if let onOpen {
                        Button { onOpen(person.id) } label: {
                            Label("Open \(person.name)", systemImage: "person.crop.circle")
                        }
                    }
                }
            }
            Button(action: onAdd) {
                Label("Add", systemImage: "plus")
                    .font(.tact(.subheadline))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .overlay(Capsule().strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3])).foregroundStyle(.secondary))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add Person")
        }
    }
}

struct PersonChip: View {
    let person: Person
    let isSelected: Bool
    @Environment(\.appPalette) private var palette

    var body: some View {
        HStack(spacing: 6) {
            PersonAvatar(person: person, size: 22)
            Text(person.name)
                .font(.tact(.subheadline))
                .lineLimit(1)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.tact(.caption).weight(.bold))
            }
        }
        .padding(.leading, 4)
        .padding(.trailing, 12)
        .padding(.vertical, 4)
        .foregroundStyle(isSelected ? palette.onAccent : .primary)
        .background(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.tactCardBackground), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.primary.opacity(isSelected ? 0 : 0.12)))
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

/// Lays out subviews left to right, wrapping to a new row when the width runs out.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let origins = arrange(width: bounds.width, subviews: subviews).origins
        for (subview, origin) in zip(subviews, origins) {
            subview.place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            widest = max(widest, x - spacing)
        }
        return (CGSize(width: widest, height: y + rowHeight), origins)
    }
}
