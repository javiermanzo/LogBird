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

    /// Collects published entries until `expectedCount` arrive and returns them
    /// in publish order. Publishing is asynchronous, so tests must wait for
    /// delivery instead of reading the stream right away.
    private func waitForPublishedLogs(of logBird: LogBird, count expectedCount: Int, timeout: TimeInterval = 5) -> [LBLog] {
        let expectation = expectation(description: "\(expectedCount) logs published")
        var collected: [LBLog] = []
        var fulfilled = false
        let cancellable = logBird.logsPublisher.sink { log in
            collected.append(log)
            if !fulfilled, collected.count >= expectedCount {
                fulfilled = true
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: timeout)
        cancellable.cancel()
        return collected
    }

    /// 1.000 logs across 10 concurrent tasks must all be preserved and published.
    /// Intended to run with Thread Sanitizer enabled.
    func testConcurrentLoggingPreservesAllEntries() async {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "concurrency")

        let tasksCount = 10
        let logsPerTask = 100
        let total = tasksCount * logsPerTask

        let publishedExpectation = expectation(description: "all logs published")
        var published: [LBLog] = []
        published.reserveCapacity(total)
        let cancellable = logBird.logsPublisher.sink { log in
            published.append(log)
            if published.count == total {
                publishedExpectation.fulfill()
            }
        }

        await withTaskGroup(of: Void.self) { group in
            for taskIndex in 0..<tasksCount {
                group.addTask {
                    for index in 0..<logsPerTask {
                        logBird.log("concurrent-log-\(taskIndex)-\(index)")
                    }
                }
            }
        }

        XCTAssertEqual(logBird.logs.count, total, "Concurrent logging lost entries — data race present.")

        await fulfillment(of: [publishedExpectation], timeout: 10)
        cancellable.cancel()
        XCTAssertEqual(published.count, total)
    }

    /// Subscribers receive each entry exactly once, in the order the entries
    /// were recorded.
    func testPublisherEmitsEachEntryOnceInOrder() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "stream")

        let expectation = expectation(description: "logs published in order")
        var published: [LBLog] = []
        let cancellable = logBird.logsPublisher.sink { log in
            published.append(log)
            if published.count == 3 {
                expectation.fulfill()
            }
        }

        logBird.log("first")
        logBird.log("second")
        logBird.log("third")

        wait(for: [expectation], timeout: 5)
        cancellable.cancel()
        XCTAssertEqual(published.map(\.message), ["first", "second", "third"])
        XCTAssertEqual(logBird.logs.map(\.message), ["third", "second", "first"])
    }

    /// `setIdentifier` applies synchronously, so the value is visible to the
    /// very next `log(...)` call.
    func testSetIdentifierIsImmediatelyVisible() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "identifier")

        logBird.setIdentifier("session-42")
        XCTAssertEqual(logBird.currentIdentifier, "session-42")

        logBird.log("hello")
        XCTAssertEqual(logBird.logs.count, 1)

        logBird.setIdentifier(nil)
        XCTAssertNil(logBird.currentIdentifier)
    }

    /// `clearLogs()` must empty the history immediately.
    func testClearLogsEmptiesHistory() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "clear")

        logBird.log("first")
        logBird.log("second")
        XCTAssertEqual(logBird.logs.count, 2)

        logBird.clearLogs()
        XCTAssertTrue(logBird.logs.isEmpty)
    }

    /// The shared instance needs a stable subsystem even where the host bundle
    /// has no identifier.
    func testSubsystemResolutionFallsBackToDefault() {
        XCTAssertEqual(LogBird.resolvedSubsystem(bundleIdentifier: nil), "com.logbird.unknown")
        XCTAssertEqual(LogBird.resolvedSubsystem(bundleIdentifier: "com.example.app"), "com.example.app")
    }
}
