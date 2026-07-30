import XCTest
@testable import LogBird

final class LBManagerTests: XCTestCase {

    func testMaxLogsDiscardsOldestEntries() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "maxlogs", maxLogs: 100)

        for index in 0..<1000 {
            logBird.log("log-\(index)")
        }

        XCTAssertEqual(logBird.logs.count, 100)
        XCTAssertEqual(logBird.logs.first?.message, "log-900")
        XCTAssertEqual(logBird.logs.last?.message, "log-999")
    }

    func testMaxLogsSetterTrimsExistingHistory() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "maxlogs-setter")

        for index in 0..<50 {
            logBird.log("log-\(index)")
        }
        XCTAssertEqual(logBird.logs.count, 50)

        logBird.maxLogs = 10

        XCTAssertEqual(logBird.logs.count, 10)
        XCTAssertEqual(logBird.logs.first?.message, "log-40")
        XCTAssertEqual(logBird.logs.last?.message, "log-49")
    }

    func testMaxLogsZeroDisablesRetention() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "maxlogs-zero", maxLogs: 0)
        XCTAssertEqual(logBird.maxLogs, 0)

        logBird.log("first")
        logBird.log("second")

        XCTAssertTrue(logBird.logs.isEmpty)
    }

    func testMaxLogsZeroStillPublishesEvents() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "maxlogs-zero-events", maxLogs: 0)

        let expectation = expectation(description: "entries published without retention")
        var published: [LBLog] = []
        let cancellable = logBird.logsPublisher.sink { event in
            guard case .recorded(let log) = event else { return }
            published.append(log)
            if published.count == 2 {
                expectation.fulfill()
            }
        }

        logBird.log("first")
        logBird.log("second")

        wait(for: [expectation], timeout: 5)
        cancellable.cancel()
        XCTAssertEqual(published.map(\.message), ["first", "second"])
        XCTAssertTrue(logBird.logs.isEmpty)
    }

    func testNegativeMaxLogsIsClampedToZero() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "maxlogs-negative")

        logBird.maxLogs = -5

        XCTAssertEqual(logBird.maxLogs, 0)

        logBird.log("first")

        XCTAssertTrue(logBird.logs.isEmpty)
    }

    func testLogWithoutMessage() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "no-message")

        logBird.log(level: .error)

        XCTAssertNil(logBird.logs.first?.message)
        XCTAssertEqual(logBird.logs.first?.level, .error)
    }

    func testLogCapturesCallSiteLocationAndSource() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "location")

        logBird.log("located")

        let log = logBird.logs.first
        XCTAssertEqual(log?.level, .debug)
        XCTAssertEqual(log?.location.fileName, "LBManagerTests.swift")
        XCTAssertEqual(log?.location.function, "testLogCapturesCallSiteLocationAndSource()")
        XCTAssertGreaterThan(log?.location.line ?? 0, 0)
        XCTAssertEqual(log?.source.subsystem, "com.logbird.tests")
        XCTAssertEqual(log?.source.category, "location")
        XCTAssertEqual(log?.createdAt ?? 0, Date().timeIntervalSince1970, accuracy: 5)
    }

    func testLogWithExtraMessagesPreservesOrderAndContent() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "extra-messages")

        logBird.log("request", extraMessages: [
            LBExtraMessage(key: "method", value: "GET"),
            LBExtraMessage(key: "endpoint", value: "/login")
        ])

        let extraMessages = logBird.logs.first?.extraMessages
        XCTAssertEqual(extraMessages?.map(\.key), ["method", "endpoint"])
        XCTAssertEqual(extraMessages?.map(\.value), ["GET", "/login"])
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

    func testUserInfoStringConvertsEachSupportedKind() {
        let underlying = NSError(domain: "com.test.inner", code: 42, userInfo: [NSLocalizedDescriptionKey: "inner failure"])

        XCTAssertEqual(LBManager.userInfoString(from: "plain"), "plain")
        XCTAssertEqual(LBManager.userInfoString(from: true), "true")
        XCTAssertEqual(LBManager.userInfoString(from: false), "false")
        XCTAssertEqual(LBManager.userInfoString(from: 3), "3")
        XCTAssertEqual(LBManager.userInfoString(from: URL(string: "https://example.com")!), "https://example.com")
        XCTAssertEqual(LBManager.userInfoString(from: underlying), "com.test.inner (42): inner failure")
        XCTAssertEqual(LBManager.userInfoString(from: NSObject()), "<non-string>")
    }

    func testDecodingErrorKeyNotFoundReportsMissingKey() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "decoding-key")
        struct Payload: Decodable { let required: String }

        do {
            _ = try JSONDecoder().decode(Payload.self, from: Data("{}".utf8))
            XCTFail("Decoding should fail")
        } catch {
            logBird.log(error: error, level: .error)
        }

        let error = logBird.logs.first?.error
        XCTAssertEqual(error?.type, "DecodingError")
        XCTAssertEqual(error?.userInfo?["missingKey"], "required")
    }

    func testFormattedMessageIncludesAllSections() throws {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "format")
        let error = NSError(domain: "com.test.network", code: 401, userInfo: ["endpoint": "/login"])

        logBird.identifier = "session-7"
        logBird.log(
            "request failed",
            extraMessages: [LBExtraMessage(key: "latency", value: "240ms")],
            additionalInfo: ["retries": .int(2)],
            error: error,
            level: .error
        )

        let message = LBManager.formattedMessage(for: try XCTUnwrap(logBird.logs.first), identifier: logBird.identifier)

        XCTAssertTrue(message.contains("session-7"))
        XCTAssertTrue(message.contains("ERROR LogBird:"))
        XCTAssertTrue(message.contains("Message:\n    request failed"))
        XCTAssertTrue(message.contains("latency:\n    240ms"))
        XCTAssertTrue(message.contains("Additional Info:\n     retries: 2"))
        XCTAssertTrue(message.contains("Error:"))
        XCTAssertTrue(message.contains("Domain: com.test.network"))
        XCTAssertTrue(message.contains("Code: 401"))
        XCTAssertTrue(message.contains("User Info:"))
        XCTAssertTrue(message.contains("endpoint: /login"))
        XCTAssertTrue(message.contains("Subsystem: com.logbird.tests"))
        XCTAssertTrue(message.contains("Category: format"))
        XCTAssertTrue(message.contains("File: LBManagerTests.swift"))
    }

    func testFormattedMessageOmitsAbsentSections() throws {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "format-minimal")

        logBird.log("just a message")

        let message = LBManager.formattedMessage(for: try XCTUnwrap(logBird.logs.first), identifier: nil)

        XCTAssertTrue(message.contains("Message:"))
        XCTAssertFalse(message.contains("Additional Info:"))
        XCTAssertFalse(message.contains("Error:"))
        XCTAssertFalse(message.contains("User Info:"))
        XCTAssertTrue(message.contains("Source:"))
        XCTAssertTrue(message.contains("Location:"))
    }

    func testFormattedMessageWithErrorWithoutUserInfoOmitsUserInfoSection() throws {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "format-error")

        logBird.log(error: NSError(domain: "com.test.empty", code: 1), level: .error)

        let message = LBManager.formattedMessage(for: try XCTUnwrap(logBird.logs.first), identifier: nil)

        XCTAssertTrue(message.contains("Error:"))
        XCTAssertTrue(message.contains("Domain: com.test.empty"))
        XCTAssertFalse(message.contains("User Info:"))
    }

    func testExportJSONProducesDecodableArray() throws {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "export-json")

        for index in 0..<5 {
            logBird.log("export-\(index)")
        }

        let decoded = try JSONDecoder().decode([LBLog].self, from: logBird.export(format: .json).data)
        XCTAssertEqual(decoded.count, 5)
    }

    func testExportJSONLinesProducesOneObjectPerLine() throws {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "export-jsonlines")

        for index in 0..<5 {
            logBird.log("export-\(index)")
        }

        let text = String(decoding: try logBird.export(format: .jsonLines).data, as: UTF8.self)
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

        let text = String(decoding: try logBird.export(format: .plainText).data, as: UTF8.self)
        XCTAssertTrue(text.contains("plain-text-marker"))
        XCTAssertTrue(text.contains("LogBird:"))
        XCTAssertTrue(text.contains("WARNING"))
    }

    func testExportPlainTextIncludesIdentifier() throws {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "export-identifier")
        logBird.identifier = "session-42"

        logBird.log("identified")

        let text = String(decoding: try logBird.export(format: .plainText).data, as: UTF8.self)
        XCTAssertTrue(text.contains("session-42"))
    }

    func testExportEmptyHistory() throws {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "export-empty")

        let json = try logBird.export(format: .json).data
        XCTAssertEqual(try JSONDecoder().decode([LBLog].self, from: json).count, 0)

        XCTAssertTrue(try logBird.export(format: .jsonLines).data.isEmpty)
        XCTAssertTrue(try logBird.export(format: .plainText).data.isEmpty)
    }

    func testExportThrowsOnNonFiniteDouble() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "export-nan")
        logBird.log("nan", additionalInfo: ["ratio": .double(.nan)])

        XCTAssertThrowsError(try logBird.export(format: .json))
        XCTAssertThrowsError(try logBird.export(format: .jsonLines))
    }

    func testExportToFileWritesFile() throws {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "write-logs")
        logBird.log("written")

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("logbird-test-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let output = try logBird.export(.all, format: .json, destination: .file(url))

        XCTAssertEqual(output.fileURL, url)
        XCTAssertEqual(output.data, try Data(contentsOf: url))

        let decoded = try JSONDecoder().decode([LBLog].self, from: output.data)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded.first?.message, "written")
    }

    func testExportToNilFileWritesTemporaryFile() throws {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "write-logs-temp")
        logBird.log("temporary")

        let output = try logBird.export(.all, format: .json, destination: .file(nil))
        let url = try XCTUnwrap(output.fileURL)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertEqual(url.deletingLastPathComponent().standardizedFileURL,
                       FileManager.default.temporaryDirectory.standardizedFileURL)
        XCTAssertEqual(url.pathExtension, "json")
        XCTAssertEqual(output.data, try Data(contentsOf: url))

        let decoded = try JSONDecoder().decode([LBLog].self, from: output.data)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded.first?.message, "temporary")
    }

    func testExportToNilFileProducesUniqueTemporaryFiles() throws {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "write-logs-unique")
        logBird.log("unique")

        let first = try logBird.export(.all, format: .json, destination: .file(nil)).fileURL
        let second = try logBird.export(.all, format: .json, destination: .file(nil)).fileURL
        defer {
            if let first { try? FileManager.default.removeItem(at: first) }
            if let second { try? FileManager.default.removeItem(at: second) }
        }

        XCTAssertNotEqual(first, second)
    }
}
