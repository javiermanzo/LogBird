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

        let data = viewModel.exportData()
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
