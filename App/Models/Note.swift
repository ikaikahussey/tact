import Foundation

/// A free-text note, optionally linked to one or more people.
struct Note: Identifiable, Codable, Equatable, Hashable {
    var id = UUID()
    var personIds: [UUID] = []
    var text: String
    var date = Date()

    func isLinked(to personID: UUID) -> Bool {
        personIds.contains(personID)
    }
}
