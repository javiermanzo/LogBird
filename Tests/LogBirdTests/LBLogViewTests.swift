import XCTest
@testable import LogBird

final class LBLogViewTests: XCTestCase {

    private func makeLog(message: String? = nil, extraMessages: [LBExtraMessage]? = nil, additionalInfo: [String: LBValue]? = nil, error: LBError? = nil) -> LBLog {
        LBLog(
            level: .info,
            message: message,
            extraMessages: extraMessages,
            additionalInfo: additionalInfo,
            error: error,
            createdAt: Date().timeIntervalSince1970,
            location: LBLocation(file: "LogBird/LBManager.swift", function: "log(_:)", line: 42),
            source: LBSource(subsystem: "com.logbird.tests", category: "views")
        )
    }

    /// Evaluating the body exercises every conditional section of the row:
    /// message, extra messages, error with user info and additional info.
    func testRowViewEvaluatesEverySection() {
        let log = makeLog(
            message: "request finished",
            extraMessages: [LBExtraMessage(key: "latency", value: "240ms")],
            additionalInfo: ["status": .int(200)],
            error: LBError(domain: "com.test", code: 1, type: "NSError", localizedDescription: "failure", userInfo: ["endpoint": "/login"])
        )

        _ = LBLogRowView(log: log).body
    }

    func testRowViewEvaluatesMinimalLog() {
        _ = LBLogRowView(log: makeLog()).body
    }

    @MainActor
    func testLogsViewEvaluatesContent() {
        _ = LBLogsView(logBird: LogBird(subsystem: "com.logbird.tests", category: "logs-view")).body
    }
}
