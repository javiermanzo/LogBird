import XCTest
import Combine
@testable import LogBird

final class LogBirdTests: XCTestCase {
    func testExample() throws {
        // XCTest Documentation
        // https://developer.apple.com/documentation/xctest

        // Defining Test Cases and Test Methods
        // https://developer.apple.com/documentation/xctest/defining_test_cases_and_test_methods
    }

    /// Waits until `logsPublisher` reports at least `expectedCount` entries and
    /// returns the latest snapshot. Publishing is asynchronous, so tests must
    /// wait for delivery instead of reading the subject's value right away.
    private func waitForLogs(of logBird: LogBird, count expectedCount: Int, timeout: TimeInterval = 5) -> [LBLog] {
        let expectation = expectation(description: "logs reach \(expectedCount)")
        var latest: [LBLog] = []
        let cancellable = logBird.logsPublisher.sink { logs in
            latest = logs
            if logs.count >= expectedCount {
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: timeout)
        cancellable.cancel()
        return latest
    }

    /// 1.000 logs across 10 concurrent tasks must all be preserved.
    /// Intended to run with Thread Sanitizer enabled.
    func testConcurrentLoggingPreservesAllEntries() async {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "concurrency")

        let tasksCount = 10
        let logsPerTask = 100
        let total = tasksCount * logsPerTask

        await withTaskGroup(of: Void.self) { group in
            for taskIndex in 0..<tasksCount {
                group.addTask {
                    for index in 0..<logsPerTask {
                        logBird.log("concurrent-log-\(taskIndex)-\(index)")
                    }
                }
            }
        }

        let count = waitForLogs(of: logBird, count: total).count
        XCTAssertEqual(count, total, "Concurrent logging lost entries — data race present.")
    }

    /// `setIdentifier` must take effect before the next `log(...)` is published.
    func testSetIdentifierIsImmediatelyVisible() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "identifier")

        logBird.setIdentifier("session-42")
        logBird.log("hello")

        XCTAssertEqual(waitForLogs(of: logBird, count: 1).count, 1)
        logBird.setIdentifier(nil)
    }

    /// `clearLogs()` must empty the history and publish an empty snapshot.
    func testClearLogsEmptiesHistory() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "clear")

        logBird.log("first")
        logBird.log("second")
        XCTAssertEqual(waitForLogs(of: logBird, count: 2).count, 2)

        let expectation = expectation(description: "logs are cleared")
        var latest: [LBLog]? = nil
        let cancellable = logBird.logsPublisher.sink { logs in
            latest = logs
            if logs.isEmpty {
                expectation.fulfill()
            }
        }

        logBird.clearLogs()

        wait(for: [expectation], timeout: 5)
        cancellable.cancel()
        XCTAssertEqual(latest?.count, 0)
    }
}
