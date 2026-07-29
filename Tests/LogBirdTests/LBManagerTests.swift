import XCTest
@testable import LogBird

final class LBManagerTests: XCTestCase {

    func testMaxLogsDiscardsOldestEntries() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "maxlogs", maxLogs: 100)

        for index in 0..<1000 {
            logBird.log("log-\(index)")
        }

        XCTAssertEqual(logBird.logs.count, 100)
        XCTAssertEqual(logBird.logs.first?.message, "log-999")
        XCTAssertEqual(logBird.logs.last?.message, "log-900")
    }

    func testMaxLogsSetterTrimsExistingHistory() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "maxlogs-setter")

        for index in 0..<50 {
            logBird.log("log-\(index)")
        }
        XCTAssertEqual(logBird.logs.count, 50)

        logBird.maxLogs = 10

        XCTAssertEqual(logBird.logs.count, 10)
        XCTAssertEqual(logBird.logs.first?.message, "log-49")
        XCTAssertEqual(logBird.logs.last?.message, "log-40")
    }

    func testMaxLogsBelowOneIsClamped() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "maxlogs-clamp", maxLogs: 0)
        XCTAssertEqual(logBird.maxLogs, 1)

        logBird.maxLogs = -5
        XCTAssertEqual(logBird.maxLogs, 1)

        logBird.log("first")
        logBird.log("second")

        XCTAssertEqual(logBird.logs.count, 1)
        XCTAssertEqual(logBird.logs.first?.message, "second")
    }

    func testLogWithoutMessage() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "no-message")

        logBird.log(level: .error)

        XCTAssertNil(logBird.logs.first?.message)
        XCTAssertEqual(logBird.logs.first?.level, .error)
    }

    func testLogPreservesAdditionalInfoTypes() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "additional-info")

        logBird.log("typed", additionalInfo: [
            "count": .int(12),
            "ratio": .double(1.5),
            "flag": .bool(true),
            "name": .string("twelve"),
            "site": .url(URL(string: "https://example.com")!)
        ])

        let info = logBird.logs.first?.additionalInfo
        XCTAssertEqual(info?["count"], .int(12))
        XCTAssertEqual(info?["ratio"], .double(1.5))
        XCTAssertEqual(info?["flag"], .bool(true))
        XCTAssertEqual(info?["name"], .string("twelve"))
        XCTAssertEqual(info?["site"], .url(URL(string: "https://example.com")!))
    }

    func testDecodingErrorKeepsContextAndType() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "decoding-error")
        let json = Data(#"{"count": "not-a-number"}"#.utf8)

        do {
            _ = try JSONDecoder().decode([String: Int].self, from: json)
            XCTFail("Decoding should fail")
        } catch {
            logBird.log(error: error, level: .error)
        }

        let error = logBird.logs.first?.error
        XCTAssertEqual(error?.type, "DecodingError")
        XCTAssertEqual(error?.userInfo?["codingPath"], "count")
        XCTAssertNotNil(error?.userInfo?["debugDescription"])
        XCTAssertNil(error?.userInfo?["NSCodingPath"])
        XCTAssertNil(error?.userInfo?["NSDebugDescription"])
    }

    func testEncodingErrorKeepsContextAndType() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "encoding-error")

        do {
            _ = try JSONEncoder().encode(["ratio": Double.nan])
            XCTFail("Encoding should fail")
        } catch {
            logBird.log(error: error, level: .error)
        }

        let error = logBird.logs.first?.error
        XCTAssertEqual(error?.type, "EncodingError")
        XCTAssertEqual(error?.userInfo?["codingPath"], "ratio")
        XCTAssertNotNil(error?.userInfo?["debugDescription"])
    }

    func testNSErrorUserInfoProducesReadableStrings() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "nserror")
        let underlying = NSError(domain: "com.test.inner", code: 42, userInfo: [NSLocalizedDescriptionKey: "inner failure"])
        let error = NSError(domain: "com.test.outer", code: 7, userInfo: [
            NSUnderlyingErrorKey: underlying,
            "object": NSObject(),
            "null": NSNull(),
            "retries": 3,
            "flag": true,
            "site": URL(string: "https://example.com")!
        ])

        logBird.log(error: error, level: .error)

        let lbError = logBird.logs.first?.error
        XCTAssertEqual(lbError?.type, "NSError")
        XCTAssertEqual(lbError?.domain, "com.test.outer")
        XCTAssertEqual(lbError?.code, 7)
        XCTAssertEqual(lbError?.userInfo?["NSUnderlyingError"], "com.test.inner (42): inner failure")
        XCTAssertEqual(lbError?.userInfo?["object"], "<non-string>")
        XCTAssertEqual(lbError?.userInfo?["null"], "<null>")
        XCTAssertEqual(lbError?.userInfo?["retries"], "3")
        XCTAssertEqual(lbError?.userInfo?["flag"], "true")
        XCTAssertEqual(lbError?.userInfo?["site"], "https://example.com")
    }

    func testExportJSONProducesDecodableArray() throws {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "export-json")

        for index in 0..<5 {
            logBird.log("export-\(index)")
        }

        let decoded = try JSONDecoder().decode([LBLog].self, from: logBird.exportLogs(format: .json))
        XCTAssertEqual(decoded.count, 5)
    }

    func testExportJSONLinesProducesOneObjectPerLine() throws {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "export-jsonlines")

        for index in 0..<5 {
            logBird.log("export-\(index)")
        }

        let text = String(decoding: try logBird.exportLogs(format: .jsonLines), as: UTF8.self)
        XCTAssertTrue(text.hasSuffix("\n"))

        let lines = text.split(separator: "\n")
        XCTAssertEqual(lines.count, 5)

        for line in lines {
            XCTAssertNoThrow(try JSONDecoder().decode(LBLog.self, from: Data(line.utf8)))
        }
    }

    func testExportPlainTextContainsFormattedMessages() throws {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "export-plaintext")

        logBird.log("plain-text-marker", level: .warning)

        let text = String(decoding: try logBird.exportLogs(format: .plainText), as: UTF8.self)
        XCTAssertTrue(text.contains("plain-text-marker"))
        XCTAssertTrue(text.contains("LogBird:"))
        XCTAssertTrue(text.contains("WARNING"))
    }

    func testExportPlainTextIncludesIdentifier() throws {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "export-identifier")
        logBird.setIdentifier("session-42")

        logBird.log("identified")

        let text = String(decoding: try logBird.exportLogs(format: .plainText), as: UTF8.self)
        XCTAssertTrue(text.contains("session-42"))
    }

    func testExportEmptyHistory() throws {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "export-empty")

        let json = try logBird.exportLogs(format: .json)
        XCTAssertEqual(try JSONDecoder().decode([LBLog].self, from: json).count, 0)

        XCTAssertTrue(try logBird.exportLogs(format: .jsonLines).isEmpty)
        XCTAssertTrue(try logBird.exportLogs(format: .plainText).isEmpty)
    }

    func testExportThrowsOnNonFiniteDouble() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "export-nan")
        logBird.log("nan", additionalInfo: ["ratio": .double(.nan)])

        XCTAssertThrowsError(try logBird.exportLogs(format: .json))
        XCTAssertThrowsError(try logBird.exportLogs(format: .jsonLines))
    }

    func testWriteLogsWritesFile() throws {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "write-logs")
        logBird.log("written")

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("logbird-test-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        try logBird.writeLogs(to: url, format: .json)

        let decoded = try JSONDecoder().decode([LBLog].self, from: Data(contentsOf: url))
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded.first?.message, "written")
    }
}
