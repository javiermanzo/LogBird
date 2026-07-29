import XCTest
@testable import LogBird

@MainActor
final class LogsViewModelTests: XCTestCase {

    private func makeLog(message: String?, level: LBLogLevel, file: String = "LogBird/LBManager.swift") -> LBLog {
        LBLog(
            level: level,
            message: message,
            createdAt: Date().timeIntervalSince1970,
            location: LBLocation(file: file, function: "log(_:)", line: 42),
            source: LBSource(subsystem: "com.logbird.tests", category: "viewmodel")
        )
    }

    func testViewModelReceivesPublishedLogs() async throws {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "publish")
        let viewModel = LogsViewModel(logBird: logBird)

        logBird.log("viewmodel-publishes")

        for _ in 0..<50 where viewModel.logs.isEmpty {
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        XCTAssertEqual(viewModel.logs.first?.message, "viewmodel-publishes")
    }

    func testViewModelSeedsExistingHistory() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "seed")
        logBird.log("already-there")

        let viewModel = LogsViewModel(logBird: logBird)

        XCTAssertEqual(viewModel.logs.map(\.message), ["already-there"])
    }

    func testViewModelKeepsEachEntryOnce() async throws {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "dedupe")
        logBird.log("before-init")

        let viewModel = LogsViewModel(logBird: logBird)

        // Allow any queued delivery for the seeded entry to arrive.
        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertEqual(viewModel.logs.map(\.message), ["before-init"])
    }

    func testViewModelCapsHistoryAtMaxLogs() async throws {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "cap", maxLogs: 2)
        let viewModel = LogsViewModel(logBird: logBird)

        logBird.log("one")
        logBird.log("two")
        logBird.log("three")

        for _ in 0..<50 where viewModel.logs.count < 2 {
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        XCTAssertEqual(viewModel.logs.map(\.message), ["three", "two"])
    }

    func testClearLogsEmptiesViewModel() async throws {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "vm-clear")
        let viewModel = LogsViewModel(logBird: logBird)

        logBird.log("to-be-cleared")

        for _ in 0..<50 where viewModel.logs.isEmpty {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTAssertEqual(viewModel.logs.count, 1)

        viewModel.clearLogs()

        XCTAssertTrue(viewModel.logs.isEmpty)
        XCTAssertTrue(logBird.logs.isEmpty)
    }

    func testFilteredLogsAppliesLevelFilter() {
        let viewModel = LogsViewModel(logBird: LogBird(subsystem: "com.logbird.tests", category: "level-filter"))
        viewModel.logs = [
            makeLog(message: "a debug message", level: .debug),
            makeLog(message: "an error message", level: .error)
        ]

        viewModel.levelFilter = .error

        XCTAssertEqual(viewModel.filteredLogs.count, 1)
        XCTAssertEqual(viewModel.filteredLogs.first?.message, "an error message")
    }

    func testFilteredLogsAppliesSearchText() {
        let viewModel = LogsViewModel(logBird: LogBird(subsystem: "com.logbird.tests", category: "search"))
        viewModel.logs = [
            makeLog(message: "Network request finished", level: .info),
            makeLog(message: "Cache invalidated", level: .debug)
        ]

        viewModel.searchText = "network"

        XCTAssertEqual(viewModel.filteredLogs.count, 1)
        XCTAssertEqual(viewModel.filteredLogs.first?.message, "Network request finished")
    }

    func testExportDataEncodesFilteredLogs() throws {
        let viewModel = LogsViewModel(logBird: LogBird(subsystem: "com.logbird.tests", category: "export"))
        viewModel.logs = [
            makeLog(message: "exported", level: .warning)
        ]

        let data = try XCTUnwrap(viewModel.exportData())
        let decoded = try JSONDecoder().decode([LBLog].self, from: data)

        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded.first?.message, "exported")
    }

    func testLocationFileNameStripsModulePath() {
        let location = LBLocation(file: "LogBird/LBManager.swift", function: "log(_:)", line: 42)

        XCTAssertEqual(location.fileName, "LBManager.swift")
        XCTAssertEqual(LBLocation(file: "NoSeparator.swift", function: "f()", line: 1).fileName, "NoSeparator.swift")
    }
}
