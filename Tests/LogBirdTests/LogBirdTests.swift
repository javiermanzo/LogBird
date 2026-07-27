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

    /// Snapshot sincrónico del histórico a través de la API pública `logsPublisher`.
    /// `CurrentValueSubject` emite su valor actual de forma sincrónica al suscribirse.
    private func currentLogs(of logBird: LogBird) -> [LBLog] {
        var snapshot: [LBLog] = []
        let cancellable = logBird.logsPublisher.sink { snapshot = $0 }
        cancellable.cancel()
        return snapshot
    }

    /// Verificación de #1 (data race en `logs.insert`) y #2 (`@unchecked Sendable`):
    /// 1.000 logs desde 10 `Task` concurrentes deben conservarse todos, sin pérdidas
    /// ni corrupción del array. Pensado para correr con Thread Sanitizer activo.
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

    /// `setIdentifier` (ahora sincrónico) debe ser visible inmediatamente en el
    /// histórico publicado por el siguiente `log(...)`, sin necesidad de `await`.
    func testSetIdentifierIsImmediatelyVisible() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "identifier")

        logBird.setIdentifier("session-42")
        logBird.log("hello")

        XCTAssertEqual(currentLogs(of: logBird).count, 1)
        logBird.setIdentifier(nil)
    }
}
