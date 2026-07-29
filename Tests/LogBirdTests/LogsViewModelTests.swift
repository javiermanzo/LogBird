import XCTest
@testable import LogBird

@MainActor
final class LogsViewModelTests: XCTestCase {

    private func makeLog(message: String?, level: LBLogLevel, file: String = "LogBird/LBManager.swift", additionalInfo: [String: LBValue]? = nil, error: LBError? = nil) -> LBLog {
        LBLog(
            level: level,
            message: message,
            additionalInfo: additionalInfo,
            error: error,
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

    func testViewModelIgnoresDuplicateDeliveries() {
        let viewModel = LogsViewModel(logBird: LogBird(subsystem: "com.logbird.tests", category: "dedupe"))
        let log = makeLog(message: "same-entry", level: .info)

        viewModel.handle(.recorded(log))
        viewModel.handle(.recorded(log))

        XCTAssertEqual(viewModel.logs.count, 1)
    }

    func testViewModelCapsHistoryAtMaxLogs() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "cap", maxLogs: 2)
        let viewModel = LogsViewModel(logBird: logBird)

        viewModel.handle(.recorded(makeLog(message: "one", level: .info)))
        viewModel.handle(.recorded(makeLog(message: "two", level: .info)))
        viewModel.handle(.recorded(makeLog(message: "three", level: .info)))

        XCTAssertEqual(viewModel.logs.map(\.message), ["three", "two"])
    }

    func testClearedEventEmptiesViewModel() {
        let viewModel = LogsViewModel(logBird: LogBird(subsystem: "com.logbird.tests", category: "cleared-event"))
        viewModel.handle(.recorded(makeLog(message: "to-be-cleared", level: .info)))

        viewModel.handle(.cleared)

        XCTAssertTrue(viewModel.logs.isEmpty)
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

    func testSearchMatchesAdditionalInfoKeysAndValues() {
        let viewModel = LogsViewModel(logBird: LogBird(subsystem: "com.logbird.tests", category: "search-info"))
        viewModel.logs = [
            makeLog(message: "one", level: .info, additionalInfo: ["endpoint": .string("/checkout")]),
            makeLog(message: "two", level: .info)
        ]

        viewModel.searchText = "checkout"
        XCTAssertEqual(viewModel.filteredLogs.map(\.message), ["one"])

        viewModel.searchText = "endpoint"
        XCTAssertEqual(viewModel.filteredLogs.map(\.message), ["one"])
    }

    func testSearchMatchesErrorDomainAndCode() {
        let viewModel = LogsViewModel(logBird: LogBird(subsystem: "com.logbird.tests", category: "search-error"))
        let error = LBError(domain: "com.test.networking", code: 401, type: "NSError", localizedDescription: "Unauthorized")
        viewModel.logs = [
            makeLog(message: "one", level: .error, error: error),
            makeLog(message: "two", level: .info)
        ]

        viewModel.searchText = "networking"
        XCTAssertEqual(viewModel.filteredLogs.map(\.message), ["one"])

        viewModel.searchText = "401"
        XCTAssertEqual(viewModel.filteredLogs.map(\.message), ["one"])
    }

    func testSearchMatchesSource() {
        let viewModel = LogsViewModel(logBird: LogBird(subsystem: "com.logbird.tests", category: "search-source"))
        viewModel.logs = [
            makeLog(message: "one", level: .info)
        ]

        viewModel.searchText = "logbird.tests"
        XCTAssertEqual(viewModel.filteredLogs.map(\.message), ["one"])

        viewModel.searchText = "viewmodel"
        XCTAssertEqual(viewModel.filteredLogs.map(\.message), ["one"])
    }

    func testExportDataEncodesFilteredLogs() throws {
        let viewModel = LogsViewModel(logBird: LogBird(subsystem: "com.logbird.tests", category: "export"))
        viewModel.logs = [
            makeLog(message: "exported", level: .warning)
        ]

        let data = try viewModel.exportData()
        let decoded = try JSONDecoder().decode([LBLog].self, from: data)

        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded.first?.message, "exported")
    }

    func testExportDataThrowsOnNonFiniteValues() {
        let viewModel = LogsViewModel(logBird: LogBird(subsystem: "com.logbird.tests", category: "export-error"))
        viewModel.logs = [
            makeLog(message: "nan", level: .info, additionalInfo: ["ratio": .double(.nan)])
        ]

        XCTAssertThrowsError(try viewModel.exportData())
    }

    func testLocationFileNameStripsModulePath() {
        let location = LBLocation(file: "LogBird/LBManager.swift", function: "log(_:)", line: 42)

        XCTAssertEqual(location.fileName, "LBManager.swift")
        XCTAssertEqual(LBLocation(file: "NoSeparator.swift", function: "f()", line: 1).fileName, "NoSeparator.swift")
    }
}
