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
}
