import XCTest
@testable import LogBird

final class LBLogMessageTests: XCTestCase {

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

    func testPlainLiteralKeepsContent() {
        let message: LBLogMessage = "User logged in"
        XCTAssertEqual(message.value, "User logged in")
    }

    func testInterpolationIsPublicByDefault() {
        let attempts = 3
        let message: LBLogMessage = "Retrying (attempt \(attempts))"
        XCTAssertEqual(message.value, "Retrying (attempt 3)")
    }

    func testPrivateInterpolationIsRedacted() {
        let username = "javier.manzo"
        let message: LBLogMessage = "User \(username, privacy: .private) logged in"
        XCTAssertEqual(message.value, "User <redacted> logged in")
    }

    func testMixedPrivacyInterpolations() {
        let username = "javier"
        let ip = "192.168.1.10"
        let message: LBLogMessage = "User \(username, privacy: .private) connected from \(ip, privacy: .public)"
        XCTAssertEqual(message.value, "User <redacted> connected from 192.168.1.10")
    }

    func testPrivateInterpolationRedactsNonStringValues() {
        let userID = 42
        let message: LBLogMessage = "User id: \(userID, privacy: .private)"
        XCTAssertEqual(message.value, "User id: <redacted>")
    }

    func testDescriptionMatchesValue() {
        let message: LBLogMessage = "Hello \("world")"
        XCTAssertEqual(message.description, "Hello world")
    }

    func testLoggedMessageIsStoredRedacted() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "privacy-message")
        let token = "secret-token"

        logBird.log("auth with \(token, privacy: .private)")

        XCTAssertEqual(waitForLogs(of: logBird, count: 1).first?.message, "auth with <redacted>")
    }

    func testExportDoesNotContainPrivateInterpolation() throws {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "privacy-export")
        let token = "secret-token"

        logBird.log("auth with \(token, privacy: .private)")

        let json = String(decoding: try logBird.exportLogs(format: .json), as: UTF8.self)
        XCTAssertFalse(json.contains(token))
        XCTAssertTrue(json.contains("<redacted>"))
    }
}
