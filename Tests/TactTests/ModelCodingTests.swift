import XCTest
@testable import Tact

final class ModelCodingTests: XCTestCase {
    func testDecodesLegacyPersonJSON() throws {
        // Shape written by version 1.0, including keys the model no longer has.
        let json = """
        [{"id":"6D1A4F7E-1C0B-4E8B-9D6A-1234567890AB","name":"Ada","imageSection":7,
          "gameType":"art","gameSettings":{"randomColorSettings":{"palette":"Ocean"},
          "peopleSettings":{},"flashcardSettings":{},"artSettings":{"tileCount":3}},
          "photoData":null,"contactIdentifier":"ABC:123"}]
        """.data(using: .utf8)!
        let people = try JSONDecoder().decode([Person].self, from: json)
        XCTAssertEqual(people.count, 1)
        XCTAssertEqual(people[0].name, "Ada")
        XCTAssertEqual(people[0].colorSeed, 7)
        XCTAssertEqual(people[0].contactIdentifier, "ABC:123")
        XCTAssertNil(people[0].photoData)
        XCTAssertNil(people[0].contact)
    }

    func testPersonRoundTripsWithContactSnapshot() throws {
        let snapshot = ContactSnapshot(name: "Ada Lovelace", phones: ["+1 555 0100"], emails: ["ada@example.com"],
                                       addresses: ["1 Analytical Way"], birthday: "December 10", organization: "Babbage & Co",
                                       jobTitle: "Mathematician", urls: ["example.com"])
        let person = Person(name: "Ada", colorSeed: 3, photoData: Data([1, 2, 3]), contactIdentifier: "X", contact: snapshot)
        let data = try JSONEncoder().encode(person)
        let decoded = try JSONDecoder().decode(Person.self, from: data)
        XCTAssertEqual(decoded, person)
    }

    func testPhotoDataCanBeExcludedFromEncoding() throws {
        let person = Person(name: "Ada", photoData: Data(repeating: 9, count: 100))
        let encoder = JSONEncoder()
        encoder.userInfo[.excludesPhotoData] = true
        let data = try encoder.encode(person)
        let decoded = try JSONDecoder().decode(Person.self, from: data)
        XCTAssertNil(decoded.photoData)
        XCTAssertEqual(decoded.id, person.id)
    }

    func testSettingsDecodeToleratesMissingAndUnknownValues() throws {
        let json = #"{"randomColorSettings":{"palette":"Not A Palette"},"peopleSettings":{}}"#.data(using: .utf8)!
        let settings = try JSONDecoder().decode(GameTypeSettings.self, from: json)
        XCTAssertEqual(settings.randomColorSettings.palette, .vibrant)
        XCTAssertNil(settings.artSettings.imageData)
    }

    func testDataFingerprintDistinguishesContent() {
        let a = Data(repeating: 1, count: 5000)
        var b = a
        b[2500] = 2
        XCTAssertEqual(a.fingerprint, Data(repeating: 1, count: 5000).fingerprint)
        XCTAssertNotEqual(a.fingerprint, b.fingerprint)
        XCTAssertNotEqual(a.fingerprint, Data(repeating: 1, count: 5001).fingerprint)
    }
}
