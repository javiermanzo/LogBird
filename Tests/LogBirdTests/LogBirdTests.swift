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
        let cancellable = logBird.logsPublisher.sink { event in
            guard case .recorded(let log) = event else { return }
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
        let cancellable = logBird.logsPublisher.sink { event in
            guard case .recorded(let log) = event else { return }
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
        XCTAssertEqual(logBird.logs.map(\.message), ["first", "second", "third"])
    }

    /// Events published before a subscription are not replayed: a subscriber
    /// that attaches later only receives what is recorded afterwards.
    func testLateSubscriberReceivesOnlyNewEvents() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "replay")

        // Drain the first entry's publication through an early subscriber so
        // nothing is left queued when the late subscriber attaches.
        let earlyExpectation = expectation(description: "early subscriber receives first entry")
        let earlyCancellable = logBird.logsPublisher.sink { _ in
            earlyExpectation.fulfill()
        }
        logBird.log("before-late-subscribe")
        wait(for: [earlyExpectation], timeout: 5)
        earlyCancellable.cancel()

        let lateExpectation = expectation(description: "late subscriber receives new entry")
        var received: [LBLogEvent] = []
        let lateCancellable = logBird.logsPublisher.sink { event in
            received.append(event)
            lateExpectation.fulfill()
        }

        logBird.log("after-late-subscribe")

        wait(for: [lateExpectation], timeout: 5)
        lateCancellable.cancel()
        XCTAssertEqual(received.count, 1)
        guard case .recorded(let log) = received.first else {
            return XCTFail("Expected a recorded event, got \(String(describing: received.first))")
        }
        XCTAssertEqual(log.message, "after-late-subscribe")
    }

    /// `clearLogs()` empties the history immediately and notifies subscribers.
    func testClearLogsEmptiesHistory() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "clear")

        let expectation = expectation(description: "clear event published")
        var events: [LBLogEvent] = []
        let cancellable = logBird.logsPublisher.sink { event in
            events.append(event)
            if event == .cleared {
                expectation.fulfill()
            }
        }

        logBird.log("first")
        logBird.log("second")
        XCTAssertEqual(logBird.logs.count, 2)

        logBird.clearLogs()
        XCTAssertTrue(logBird.logs.isEmpty)

        wait(for: [expectation], timeout: 5)
        cancellable.cancel()

        let recordedMessages = events.compactMap { event -> String? in
            guard case .recorded(let log) = event else { return nil }
            return log.message
        }
        XCTAssertEqual(recordedMessages, ["first", "second"])
        XCTAssertEqual(events.last, .cleared)
        XCTAssertEqual(events.count, 3)
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

    /// The shared instance needs a stable subsystem even where the host bundle
    /// has no identifier.
    func testSubsystemResolutionFallsBackToDefault() {
        XCTAssertEqual(LogBird.resolvedSubsystem(bundleIdentifier: nil), "com.logbird.default")
        XCTAssertEqual(LogBird.resolvedSubsystem(bundleIdentifier: "com.example.app"), "com.example.app")
    }
}
