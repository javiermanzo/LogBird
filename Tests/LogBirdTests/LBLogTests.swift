import XCTest
@testable import LogBird

final class LBLogTests: XCTestCase {

    private func makeLog(id: String = "fixed-id", additionalInfo: [String: LBValue]? = nil) -> LBLog {
        LBLog(
            id: id,
            level: .warning,
            message: "hello",
            additionalInfo: additionalInfo,
            createdAt: 123.25,
            location: LBLocation(file: "LogBird/LBManager.swift", function: "log(_:)", line: 42),
            source: LBSource(subsystem: "com.logbird.tests", category: "models")
        )
    }

    func testLBValuePreservesTypesWhenEncodedToJSON() throws {
        let values: [String: LBValue] = [
            "count": .int(12),
            "ratio": .double(1.5),
            "flag": .bool(true),
            "name": .string("twelve"),
            "site": .url(URL(string: "https://example.com")!)
        ]

        let data = try JSONEncoder().encode(values)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(object["count"] as? Int, 12)
        XCTAssertEqual(object["ratio"] as? Double, 1.5)
        XCTAssertEqual(object["flag"] as? Bool, true)
        XCTAssertEqual(object["name"] as? String, "twelve")
        XCTAssertEqual(object["site"] as? String, "https://example.com")
    }

    func testLBValueCodableRoundTrip() throws {
        let values: [String: LBValue] = [
            "count": .int(12),
            "ratio": .double(1.5),
            "flag": .bool(true),
            "name": .string("twelve")
        ]

        let data = try JSONEncoder().encode(values)
        let decoded = try JSONDecoder().decode([String: LBValue].self, from: data)

        XCTAssertEqual(decoded, values)
    }

    /// JSON has no distinct URL or whole-number-double type: both decode back
    /// as `.string` and `.int` respectively. This pins that documented contract.
    func testLBValueRoundTripLossyCases() throws {
        let values: [String: LBValue] = [
            "wholeDouble": .double(12.0),
            "site": .url(URL(string: "https://example.com")!)
        ]

        let data = try JSONEncoder().encode(values)
        let decoded = try JSONDecoder().decode([String: LBValue].self, from: data)

        XCTAssertEqual(decoded["wholeDouble"], .int(12))
        XCTAssertEqual(decoded["site"], .string("https://example.com"))
    }

    func testLBValueNestedValuesCodableRoundTrip() throws {
        let values: [String: LBValue] = [
            "tags": .array([.string("swift"), .int(6), .bool(true)]),
            "context": .dictionary([
                "screen": .string("checkout"),
                "attempt": .int(2),
                "ids": .array([.int(1), .int(2)])
            ])
        ]

        let data = try JSONEncoder().encode(values)
        let decoded = try JSONDecoder().decode([String: LBValue].self, from: data)

        XCTAssertEqual(decoded, values)
    }

    func testLBValueNestedDescription() {
        XCTAssertEqual(LBValue.array([.int(1), .string("two")]).description, "[1, two]")
        XCTAssertEqual(LBValue.dictionary(["b": .int(2), "a": .int(1)]).description, "{a: 1, b: 2}")
    }

    func testLBValueSingleValueDescriptions() {
        XCTAssertEqual(LBValue.string("hello").description, "hello")
        XCTAssertEqual(LBValue.int(12).description, "12")
        XCTAssertEqual(LBValue.double(1.5).description, "1.5")
        XCTAssertEqual(LBValue.bool(true).description, "true")
        XCTAssertEqual(LBValue.url(URL(string: "https://example.com")!).description, "https://example.com")
    }

    func testLBValueDecodeFailsForUnsupportedPayloads() {
        XCTAssertThrowsError(try JSONDecoder().decode(LBValue.self, from: Data("null".utf8)))
    }

    func testLBValueExpressibleByLiterals() {
        let values: [String: LBValue] = ["count": 12, "ratio": 1.5, "flag": true, "name": "twelve"]

        XCTAssertEqual(values["count"], .int(12))
        XCTAssertEqual(values["ratio"], .double(1.5))
        XCTAssertEqual(values["flag"], .bool(true))
        XCTAssertEqual(values["name"], .string("twelve"))
    }

    func testLBLogEqualityAndHashingIncludeID() {
        let first = makeLog()
        let sameID = makeLog()
        let differentID = makeLog(id: "other-id")

        XCTAssertEqual(first, sameID)
        XCTAssertEqual(first.hashValue, sameID.hashValue)
        XCTAssertNotEqual(first, differentID)
        XCTAssertEqual(Set([first, sameID, differentID]).count, 2)
    }

    func testLBExtraMessageHasUniqueIdentityWithContentEquality() {
        let first = LBExtraMessage(key: "key", value: "value")
        let second = LBExtraMessage(key: "key", value: "value")

        XCTAssertEqual(first, second)
        XCTAssertNotEqual(first.id, second.id)
    }

    func testLBLogLevelDescription() {
        XCTAssertEqual(LBLogLevel.debug.description, "debug")
        XCTAssertEqual(LBLogLevel.critical.description, "critical")
        XCTAssertEqual(String(describing: LBLogLevel.warning), "warning")
    }

    func testPrettyJSONRoundTrips() throws {
        let log = makeLog(additionalInfo: ["count": .int(3)])

        let json = try log.prettyJSON()
        let decoded = try JSONDecoder().decode(LBLog.self, from: Data(json.utf8))

        XCTAssertEqual(decoded, log)
    }

    func testLocationFileNameStripsModulePath() {
        let location = LBLocation(file: "LogBird/LBManager.swift", function: "log(_:)", line: 42)

        XCTAssertEqual(location.fileName, "LBManager.swift")
        XCTAssertEqual(LBLocation(file: "NoSeparator.swift", function: "f()", line: 1).fileName, "NoSeparator.swift")
    }

    func testPrettyJSONHasSortedKeys() throws {
        let json = try makeLog(additionalInfo: ["count": .int(3)]).prettyJSON()

        let additionalInfoIndex = try XCTUnwrap(json.range(of: "\"additionalInfo\"")).lowerBound
        let createdAtIndex = try XCTUnwrap(json.range(of: "\"createdAt\"")).lowerBound
        let idIndex = try XCTUnwrap(json.range(of: "\"id\"")).lowerBound

        XCTAssertLessThan(additionalInfoIndex, createdAtIndex)
        XCTAssertLessThan(createdAtIndex, idIndex)
    }

    func testDateFormatterProducesISO8601Output() {
        let formatted = LBLog.dateFormatter.format(Date(timeIntervalSince1970: 1_700_000_000))

        let pattern = #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}(Z|[+-]\d{2}:?\d{2})$"#
        XCTAssertNotNil(formatted.range(of: pattern, options: .regularExpression), "Unexpected date format: \(formatted)")
    }
}
