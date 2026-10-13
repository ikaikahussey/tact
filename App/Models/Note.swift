import Foundation

/// A free-text note, optionally linked to one or more people.
struct Note: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var personIds: [UUID]
    var text: String
    /// When the thing being noted happened. Shown and sorted on; user-editable.
    var date: Date
    /// When the text or links last changed.
    var modifiedDate: Date

    init(id: UUID = UUID(), personIds: [UUID] = [], text: String, date: Date = Date(), modifiedDate: Date? = nil) {
        self.id = id
        self.personIds = personIds
        self.text = text
        self.date = date
        self.modifiedDate = modifiedDate ?? date
    }

    private enum CodingKeys: String, CodingKey { case id, personIds, text, date, modifiedDate }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        personIds = try container.decodeIfPresent([UUID].self, forKey: .personIds) ?? []
        text = try container.decode(String.self, forKey: .text)
        date = try container.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        // Notes written before this field existed count as last edited when they happened.
        modifiedDate = try container.decodeIfPresent(Date.self, forKey: .modifiedDate) ?? date
    }

    func isLinked(to personID: UUID) -> Bool {
        personIds.contains(personID)
    }

    var wasEdited: Bool { modifiedDate > date.addingTimeInterval(1) }
}
