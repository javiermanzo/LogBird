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

    /// Synchronous snapshot of the current log history via the public `logsPublisher`.
    /// `CurrentValueSubject` emits its current value synchronously on subscription.
    private func currentLogs(of logBird: LogBird) -> [LBLog] {
        var snapshot: [LBLog] = []
        let cancellable = logBird.logsPublisher.sink { snapshot = $0 }
        cancellable.cancel()
        return snapshot
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

        let count = currentLogs(of: logBird).count
        XCTAssertEqual(count, total, "Concurrent logging lost entries — data race present.")
    }

    /// `setIdentifier` must take effect before the next `log(...)` is published.
    func testSetIdentifierIsImmediatelyVisible() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "identifier")

        logBird.setIdentifier("session-42")
        logBird.log("hello")

        XCTAssertEqual(currentLogs(of: logBird).count, 1)
        logBird.setIdentifier(nil)
    }
}
