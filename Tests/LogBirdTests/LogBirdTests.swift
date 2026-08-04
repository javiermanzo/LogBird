import XCTest
import Combine
@testable import LogBird

final class LogBirdTests: XCTestCase {

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

    /// `identifier` applies synchronously, so the value is visible to the
    /// very next `log(...)` call.
    func testIdentifierIsImmediatelyVisible() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "identifier")

        logBird.identifier = "session-42"
        XCTAssertEqual(logBird.identifier, "session-42")

        logBird.log("hello")
        XCTAssertEqual(logBird.logs.count, 1)

        logBird.identifier = nil
        XCTAssertNil(logBird.identifier)

        LogBird.identifier = "shared-session"
        XCTAssertEqual(LogBird.identifier, "shared-session")
        LogBird.identifier = nil
        XCTAssertNil(LogBird.identifier)
    }

    /// The shared instance needs a stable subsystem even where the host bundle
    /// has no identifier.
    func testSubsystemResolutionFallsBackToDefault() {
        XCTAssertEqual(LogBird.resolvedSubsystem(bundleIdentifier: nil), "com.logbird.default")
        XCTAssertEqual(LogBird.resolvedSubsystem(bundleIdentifier: "com.example.app"), "com.example.app")
    }

    /// `defaultCategory(fileID:)` returns the module component of `#fileID`,
    /// so a package or app gets a category that reflects who owns the logger.
    func testDefaultCategoryDerivesModuleFromFileID() {
        XCTAssertEqual(LogBird.defaultCategory(fileID: "LogBird/LogBird.swift"), "LogBird")
        XCTAssertEqual(LogBird.defaultCategory(fileID: "Network/Client.swift"), "Network")
        XCTAssertEqual(LogBird.defaultCategory(fileID: "MyApp/AppDelegate.swift"), "MyApp")
    }

    /// When `#fileID` has no module separator, the whole value is returned as
    /// the category rather than crashing or returning empty.
    func testDefaultCategoryFallsBackToWholeValueWithoutSeparator() {
        XCTAssertEqual(LogBird.defaultCategory(fileID: "AppDelegate.swift"), "AppDelegate.swift")
        XCTAssertEqual(LogBird.defaultCategory(fileID: ""), "")
    }

    /// `LogBird()` uses the host bundle identifier as the subsystem default,
    /// whatever the host bundle happens to be in the test runner.
    func testInitDefaultsInferSubsystemFromMainBundle() {
        let logBird = LogBird()
        logBird.log("default-init-subsystem")

        XCTAssertEqual(
            logBird.logs.first?.source.subsystem,
            LogBird.resolvedSubsystem(bundleIdentifier: Bundle.main.bundleIdentifier)
        )
    }

    /// `LogBird()` infers the category from the caller's module. Called from
    /// this file, `#fileID` is `LogBirdTests/LogBirdTests.swift`, so the
    /// category is the test module's name.
    func testInitDefaultsInferCategoryFromCallerModule() {
        let logBird = LogBird()
        logBird.log("default-init-category")

        XCTAssertEqual(logBird.logs.first?.source.category, "LogBirdTests")
    }

    /// Explicit `subsystem`/`category` always win over the inferred defaults.
    func testInitExplicitArgumentsOverrideDefaults() {
        let logBird = LogBird(subsystem: "com.network.lib", category: "auth")
        logBird.log("explicit-override")

        let source = logBird.logs.first?.source
        XCTAssertEqual(source?.subsystem, "com.network.lib")
        XCTAssertEqual(source?.category, "auth")
    }

    /// Partial override is supported: passing only `category` keeps the
    /// inferred subsystem default.
    func testInitPartialOverrideKeepsInferredSubsystem() {
        let logBird = LogBird(category: "payments")
        logBird.log("partial-override")

        let source = logBird.logs.first?.source
        XCTAssertEqual(source?.subsystem, LogBird.resolvedSubsystem(bundleIdentifier: Bundle.main.bundleIdentifier))
        XCTAssertEqual(source?.category, "payments")
    }

    /// The static API forwards to `shared`: logging, history, configuration,
    /// publisher and export all operate on the same instance.
    func testStaticFacadeRoutesCallsToSharedInstance() throws {
        defer {
            LogBird.clearLogs()
            LogBird.identifier = nil
        }

        XCTAssertEqual(LogBird.sensitiveKeys, LBRedactor.initialDefaultSensitiveKeys)
        XCTAssertTrue(LogBird.redactSensitiveFields)
        XCTAssertEqual(LogBird.maxLogs, 1000)

        let publishedExpectation = expectation(description: "static publisher forwards shared events")
        let cancellable = LogBird.logsPublisher.sink { event in
            guard case .recorded(let log) = event, log.message == "static-facade-message" else { return }
            publishedExpectation.fulfill()
        }

        LogBird.identifier = "static-facade"
        LogBird.log("static-facade-message", additionalInfo: ["count": .int(1)], level: .info)

        let secret = "static-secret"
        LogBird.log("token: \(secret, privacy: .private)")

        wait(for: [publishedExpectation], timeout: 5)
        cancellable.cancel()

        let logged = LogBird.logs.first { $0.message == "static-facade-message" }
        XCTAssertEqual(logged?.additionalInfo?["count"], .int(1))
        XCTAssertEqual(LogBird.shared.identifier, "static-facade")
        XCTAssertTrue(LogBird.logs.contains { $0.message == "token: <redacted>" })

        XCTAssertFalse(try LogBird.export().data.isEmpty)

        let exportURL = FileManager.default.temporaryDirectory.appendingPathComponent("logbird-static-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: exportURL) }
        try LogBird.export(.all, destination: .file(exportURL))
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportURL.path))

        LogBird.clearLogs()
        XCTAssertFalse(LogBird.logs.contains { $0.message == "static-facade-message" })
    }
}
