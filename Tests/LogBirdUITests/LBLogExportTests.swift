import XCTest
@testable import LogBirdUI
import LogBird

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

    func testWriteTemporaryFileKeepsExistingFiles() throws {
        let first = Data("first".utf8)
        let second = Data("second".utf8)

        let firstURL = try LBLogExport.writeTemporaryFile(data: first, format: .json)
        let secondURL = try LBLogExport.writeTemporaryFile(data: second, format: .json)
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
        }

        XCTAssertNotEqual(firstURL, secondURL)
        XCTAssertEqual(try Data(contentsOf: firstURL), first)
        XCTAssertEqual(try Data(contentsOf: secondURL), second)
    }
}
