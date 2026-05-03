@testable import JellyfinClient
import XCTest

final class PersonDetailTests: XCTestCase {
    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    // MARK: - PersonDetail decoding

    func testDecode_fullPayload_populatesAllFields() throws {
        let json = Data("""
        {
          "Id": "person-123",
          "Name": "Jane Doe",
          "Overview": "An award-winning actor.",
          "PremiereDate": "1980-04-15T00:00:00.000Z",
          "EndDate": "2050-01-01T00:00:00.000Z",
          "ProductionLocations": ["Los Angeles, CA"],
          "ImageTags": { "Primary": "abc123" }
        }
        """.utf8)

        let person = try makeDecoder().decode(PersonDetail.self, from: json)

        XCTAssertEqual(person.id, "person-123")
        XCTAssertEqual(person.name, "Jane Doe")
        XCTAssertEqual(person.overview, "An award-winning actor.")
        XCTAssertEqual(person.productionLocations, ["Los Angeles, CA"])
        XCTAssertEqual(person.imageTag, "abc123")
        XCTAssertNotNil(person.premiereDate)
        XCTAssertNotNil(person.endDate)
    }

    func testDecode_minimalPayload_optionalsAreNil() throws {
        let json = Data("""
        {"Id": "p1", "Name": "John Doe"}
        """.utf8)

        let person = try makeDecoder().decode(PersonDetail.self, from: json)

        XCTAssertEqual(person.id, "p1")
        XCTAssertEqual(person.name, "John Doe")
        XCTAssertNil(person.overview)
        XCTAssertNil(person.premiereDate)
        XCTAssertNil(person.endDate)
        XCTAssertNil(person.productionLocations)
        XCTAssertNil(person.imageTag)
    }

    func testDecode_imageTagsWithoutPrimary_returnsNil() throws {
        let json = Data("""
        {"Id": "p1", "Name": "X", "ImageTags": {"Backdrop": "xyz"}}
        """.utf8)

        let person = try makeDecoder().decode(PersonDetail.self, from: json)
        XCTAssertNil(person.imageTag)
    }

    func testEncodeDecode_roundTrip_preservesImageTag() throws {
        let original = PersonDetail(
            id: "p1",
            name: "Jane",
            overview: "Bio",
            productionLocations: ["NY"],
            imageTag: "tag-1"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PersonDetail.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.overview, original.overview)
        XCTAssertEqual(decoded.productionLocations, original.productionLocations)
        XCTAssertEqual(decoded.imageTag, original.imageTag)
    }

    // MARK: - MediaItem.Person decoding

    func testDecodeMediaItemPerson_includesImageTag() throws {
        let json = Data("""
        {
          "Id": "movie-1",
          "Name": "A Movie",
          "Type": "Movie",
          "People": [
            {
              "Name": "Jane Doe",
              "Id": "person-123",
              "Role": "Lead",
              "Type": "Actor",
              "PrimaryImageTag": "tag-abc"
            },
            {
              "Name": "John Director",
              "Id": "person-456",
              "Type": "Director"
            }
          ]
        }
        """.utf8)

        let item = try JSONDecoder().decode(MediaItem.self, from: json)
        let people = try XCTUnwrap(item.people)

        XCTAssertEqual(people.count, 2)
        XCTAssertEqual(people[0].name, "Jane Doe")
        XCTAssertEqual(people[0].id, "person-123")
        XCTAssertEqual(people[0].role, "Lead")
        XCTAssertEqual(people[0].type, "Actor")
        XCTAssertEqual(people[0].imageTag, "tag-abc")

        XCTAssertEqual(people[1].name, "John Director")
        XCTAssertNil(people[1].imageTag)
        XCTAssertNil(people[1].role)
    }
}
