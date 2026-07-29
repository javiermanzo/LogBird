import XCTest
@testable import LogBird

final class LBLogExportTests: XCTestCase {

    func testFileNameUsesReadableTimestamp() {
        let name = LBLogExport.fileName(for: .json, date: Date(timeIntervalSince1970: 1_700_000_000))

        XCTAssertNotNil(
            name.range(of: #"^logbird-logs-\d{8}-\d{6}\.json$"#, options: .regularExpression),
            "Unexpected file name: \(name)"
        )
    }

    func testFileNameUsesFormatExtension() {
        XCTAssertTrue(LBLogExport.fileName(for: .jsonLines).hasSuffix(".jsonl"))
        XCTAssertTrue(LBLogExport.fileName(for: .plainText).hasSuffix(".log"))
    }

    func testWriteTemporaryFileWritesData() throws {
        let data = Data("exported logs".utf8)

        let url = try LBLogExport.writeTemporaryFile(data: data, format: .plainText)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertEqual(try Data(contentsOf: url), data)
        XCTAssertTrue(url.lastPathComponent.hasPrefix("logbird-logs-"))
        XCTAssertTrue(url.lastPathComponent.hasSuffix(".log"))
    }
}
