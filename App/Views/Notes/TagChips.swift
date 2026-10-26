import SwiftUI

/// Starts a search for a tag from anywhere: the root opens its search
/// field with `#tag` in it (popping back to itself first).
struct SearchTagKey: EnvironmentKey {
    static let defaultValue: (String) -> Void = { _ in }
}

extension EnvironmentValues {
    var searchTag: (String) -> Void {
        get { self[SearchTagKey.self] }
        set { self[SearchTagKey.self] = newValue }
    }
}

/// One tag as a small capsule.
struct TagChip: View {
    let tag: String
    var isSelected = false
    @Environment(\.appPalette) private var palette

    var body: some View {
        Text("#" + tag)
            .font(.tact(.caption).weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .foregroundStyle(isSelected ? AnyShapeStyle(palette.onAccent) : AnyShapeStyle(.tint))
            .background(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.tactTileGray.opacity(0.45)),
                        in: Capsule())
    }
}

/// A note's tags, wrapping; tapping one searches for it.
struct TagChips: View {
    let tags: [String]
    @Environment(\.searchTag) private var searchTag

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                Button { searchTag(tag) } label: {
                    TagChip(tag: tag)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Tag \(tag)")
                .accessibilityHint("Searches for notes with this tag")
            }
        }
    }
}

/// A row of tags to choose from, scrolling sideways: the search's recent
/// tags, or the editor's completions.
struct TagRow: View {
    let tags: [TagCount]
    var selected: String? = nil
    let choose: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tags) { entry in
                    Button { choose(entry.tag) } label: {
                        TagChip(tag: entry.tag, isSelected: selected == entry.id)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Tag \(entry.tag), \(entry.count) notes")
                    .accessibilityAddTraits(selected == entry.id ? [.isSelected] : [])
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }
}

/// Above the keyboard while a note is edited: once a `#` is typed, the
/// existing tags that start with what follows it. Tapping one completes it.
struct TagSuggestionStrip: View {
    @Binding var text: String
    @EnvironmentObject private var store: TactStore

    private var matches: [TagCount] {
        guard let partial = NoteTags.partialTag(endOf: text) else { return [] }
        let partialKey = NoteTags.normalized(partial)
        return TagCount.matching(partial, in: store.tagCounts).filter { $0.id != partialKey }
    }

    var body: some View {
        if !matches.isEmpty {
            TagRow(tags: matches) { tag in
                text = NoteTags.completing(text, with: tag)
            }
            .padding(.horizontal, -12)
        }
    }
}
