import XCTest
@testable import LogBird

final class LBExportTests: XCTestCase {

    func testExportAllIncludesWholeHistory() throws {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "export-all")

        for index in 0..<3 {
            logBird.log("log-\(index)")
        }

        let decoded = try JSONDecoder().decode([LBLog].self, from: logBird.export(.all).data)
        XCTAssertEqual(decoded.map(\.message), ["log-0", "log-1", "log-2"])
    }

    func testExportLogsContentEncodesOnlyTheSelection() throws {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "export-selection")
        logBird.log("keep", level: .warning)
        logBird.log("drop", level: .info)

        let selection = logBird.logs.filter { $0.level == .warning }
        let decoded = try JSONDecoder().decode([LBLog].self, from: logBird.export(.logs(selection)).data)

        XCTAssertEqual(decoded.map(\.message), ["keep"])
    }

    func testExportDefaultsToAllJSONData() throws {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "export-defaults")
        logBird.log("default")

        let output = try logBird.export()

        XCTAssertNil(output.fileURL)
        XCTAssertEqual(try JSONDecoder().decode([LBLog].self, from: output.data).count, 1)
    }

    func testExportPlainTextAppliesIdentifierToArbitrarySelections() throws {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "export-identifier-selection")
        logBird.setIdentifier("session-42")
        logBird.log("identified")

        let text = String(decoding: try logBird.export(.logs(logBird.logs), format: .plainText).data, as: UTF8.self)
        XCTAssertTrue(text.contains("identified"))
        XCTAssertTrue(text.contains("session-42"))
    }

    func testExportThrowsOnNonFiniteDouble() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "export-nan-selection")
        logBird.log("nan", additionalInfo: ["ratio": .double(.nan)])

        XCTAssertThrowsError(try logBird.export(.all, format: .json))
        XCTAssertThrowsError(try logBird.export(.all, format: .jsonLines))
    }

    func testSuggestedFileNameUsesReadableTimestamp() {
        let name = LBExportFormat.json.suggestedFileName(date: Date(timeIntervalSince1970: 1_700_000_000))

        XCTAssertNotNil(
            name.range(of: #"^logbird-logs-\d{8}-\d{6}\.json$"#, options: .regularExpression),
            "Unexpected file name: \(name)"
        )
    }

    func testSuggestedFileNameUsesFormatExtension() {
        XCTAssertTrue(LBExportFormat.jsonLines.suggestedFileName().hasSuffix(".jsonl"))
        XCTAssertTrue(LBExportFormat.plainText.suggestedFileName().hasSuffix(".log"))
    }

    func testExportOutputEnumCases() throws {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "export-enum")
        logBird.log("enum-test")

        let dataOutput = try logBird.export(.all, destination: .data)
        if case .data(let data) = dataOutput {
            XCTAssertFalse(data.isEmpty)
        } else {
            XCTFail("Expected .data case")
        }

        let fileOutput = try logBird.export(.all, destination: .file(nil))
        if case .file(let url, let data) = fileOutput {
            defer { try? FileManager.default.removeItem(at: url) }
            XCTAssertFalse(data.isEmpty)
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        } else {
            XCTFail("Expected .file case")
        }
    }
}
