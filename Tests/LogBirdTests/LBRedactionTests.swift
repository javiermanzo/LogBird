import XCTest
@testable import LogBird

final class LBRedactionTests: XCTestCase {

    /// Waits until `logsPublisher` reports at least `expectedCount` entries and
    /// returns the latest snapshot.
    private func waitForLogs(of logBird: LogBird, count expectedCount: Int, timeout: TimeInterval = 5) -> [LBLog] {
        let expectation = expectation(description: "logs reach \(expectedCount)")
        var latest: [LBLog] = []
        var fulfilled = false
        let cancellable = logBird.logsPublisher.sink { logs in
            latest = logs
            if !fulfilled, logs.count >= expectedCount {
                fulfilled = true
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: timeout)
        cancellable.cancel()
        return latest
    }

    func testAdditionalInfoRedactsDefaultKeys() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "redaction-defaults")

        logBird.log("login", additionalInfo: [
            "username": .string("javier"),
            "password": .string("123456"),
            "Authorization": .string("Bearer abc123"),
            "retries": .int(2)
        ])

        let info = waitForLogs(of: logBird, count: 1).first?.additionalInfo
        XCTAssertEqual(info?["username"], .string("javier"))
        XCTAssertEqual(info?["password"], .string("<redacted>"))
        XCTAssertEqual(info?["Authorization"], .string("<redacted>"))
        XCTAssertEqual(info?["retries"], .int(2))
    }

    func testSensitiveKeyMatchingIsCaseInsensitiveSubstring() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "redaction-matching")

        logBird.log("matching", additionalInfo: [
            "accessToken": .string("a"),
            "AUTH_TOKEN": .string("b"),
            "apiKey": .string("c"),
            "mySecret": .string("d"),
            "sessionId": .string("e")
        ])

        let info = waitForLogs(of: logBird, count: 1).first?.additionalInfo
        XCTAssertEqual(info?["accessToken"], .string("<redacted>"))
        XCTAssertEqual(info?["AUTH_TOKEN"], .string("<redacted>"))
        XCTAssertEqual(info?["apiKey"], .string("<redacted>"))
        XCTAssertEqual(info?["mySecret"], .string("<redacted>"))
        XCTAssertEqual(info?["sessionId"], .string("e"))
    }

    func testRedactedValueBecomesStringRegardlessOfOriginalType() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "redaction-type")

        logBird.log("typed", additionalInfo: ["token": .int(12345)])

        let info = waitForLogs(of: logBird, count: 1).first?.additionalInfo
        XCTAssertEqual(info?["token"], .string("<redacted>"))
    }

    func testRedactionCanBeDisabled() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "redaction-disabled")
        logBird.redactSensitiveFields = false

        logBird.log("raw", additionalInfo: ["token": .string("abc123")])

        let info = waitForLogs(of: logBird, count: 1).first?.additionalInfo
        XCTAssertEqual(info?["token"], .string("abc123"))
    }

    func testCustomSensitiveKeysReplaceDefaults() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "redaction-custom")
        logBird.sensitiveKeys = ["session"]

        logBird.log("custom", additionalInfo: [
            "sessionId": .string("xyz"),
            "token": .string("abc123")
        ])

        let info = waitForLogs(of: logBird, count: 1).first?.additionalInfo
        XCTAssertEqual(info?["sessionId"], .string("<redacted>"))
        XCTAssertEqual(info?["token"], .string("abc123"))
    }

    func testRedactionConfigIsPerInstance() {
        let first = LogBird(subsystem: "com.logbird.tests", category: "redaction-first")
        let second = LogBird(subsystem: "com.logbird.tests", category: "redaction-second")

        first.redactSensitiveFields = false

        XCTAssertFalse(first.redactSensitiveFields)
        XCTAssertTrue(second.redactSensitiveFields)
        XCTAssertEqual(second.sensitiveKeys, LogBird.defaultSensitiveKeys)
    }

    func testErrorUserInfoIsRedacted() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "redaction-error")
        let error = NSError(domain: "com.test.networking", code: 401, userInfo: [
            "Authorization": "Bearer abc123",
            "url": "https://api.example.com/login"
        ])

        logBird.log("request failed", error: error, level: .error)

        let userInfo = waitForLogs(of: logBird, count: 1).first?.error?.userInfo
        XCTAssertEqual(userInfo?["Authorization"], "<redacted>")
        XCTAssertEqual(userInfo?["url"], "https://api.example.com/login")
    }

    func testExportDoesNotLeakSensitiveValues() throws {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "redaction-export")
        let error = NSError(domain: "com.test", code: 1, userInfo: ["secret": "shhh"])

        logBird.log("auth", additionalInfo: ["token": .string("Bearer abc123")], error: error)

        let json = String(decoding: try logBird.exportLogs(format: .json), as: UTF8.self)
        XCTAssertFalse(json.contains("Bearer abc123"))
        XCTAssertFalse(json.contains("shhh"))
        XCTAssertTrue(json.contains("<redacted>"))
    }

    func testDefaultKeysIncludePasswordAndAuthorization() {
        XCTAssertTrue(LogBird.defaultSensitiveKeys.contains("password"))
        XCTAssertTrue(LogBird.defaultSensitiveKeys.contains("authorization"))
    }
}
