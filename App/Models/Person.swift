import Foundation

/// A person the user keeps notes about.
struct Person: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String
    /// Stable per-person seed used to derive a colour in the Random Colors view.
    var colorSeed: Int
    var photoData: Data?
    var contactIdentifier: String?
    /// Details copied from the linked Contacts entry so they can be shown
    /// without re-requesting Contacts access on every launch.
    var contact: ContactSnapshot?

    init(
        id: UUID = UUID(),
        name: String,
        colorSeed: Int? = nil,
        photoData: Data? = nil,
        contactIdentifier: String? = nil,
        contact: ContactSnapshot? = nil
    ) {
        self.id = id
        self.name = name
        self.colorSeed = colorSeed ?? Int.random(in: 0..<360)
        self.photoData = photoData
        self.contactIdentifier = contactIdentifier
        self.contact = contact
    }

    var hasLinkedContact: Bool { contactIdentifier != nil }

    // The on-disk keys are kept compatible with data written by earlier versions,
    // which stored the colour seed as `imageSection` and ignored unknown keys.
    enum CodingKeys: String, CodingKey {
        case id, name
        case colorSeed = "imageSection"
        case photoData, contactIdentifier, contact
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        colorSeed = try container.decodeIfPresent(Int.self, forKey: .colorSeed) ?? Int.random(in: 0..<360)
        photoData = try container.decodeIfPresent(Data.self, forKey: .photoData)
        contactIdentifier = try container.decodeIfPresent(String.self, forKey: .contactIdentifier)
        contact = try? container.decodeIfPresent(ContactSnapshot.self, forKey: .contact)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(colorSeed, forKey: .colorSeed)
        if encoder.userInfo[.excludesPhotoData] as? Bool != true {
            try container.encodeIfPresent(photoData, forKey: .photoData)
        }
        try container.encodeIfPresent(contactIdentifier, forKey: .contactIdentifier)
        try container.encodeIfPresent(contact, forKey: .contact)
    }
}

extension CodingUserInfoKey {
    /// When set to `true` on an encoder, `Person.photoData` is left out of the output.
    /// The persistence layer stores photos as separate files instead.
    static let excludesPhotoData = CodingUserInfoKey(rawValue: "app.tact.excludesPhotoData")!
}

/// The subset of a Contacts entry that Tact displays.
struct ContactSnapshot: Codable, Equatable, Hashable {
    var name: String
    var phones: [String] = []
    var emails: [String] = []
    var addresses: [String] = []
    var birthday: String?
    var organization: String?
    var jobTitle: String?
    var urls: [String] = []
}
