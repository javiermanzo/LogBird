import XCTest
@testable import LogBirdUI
import LogBird

@MainActor
final class LogsViewModelTests: XCTestCase {

    private func makeLog(message: String?, level: LBLogLevel, file: String = "LogBird/LBManager.swift", extraMessages: [LBExtraMessage]? = nil, additionalInfo: [String: LBValue]? = nil, error: LBError? = nil) -> LBLog {
        LBLog(
            level: level,
            message: message,
            extraMessages: extraMessages,
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

    func testViewModelSeedsExistingHistory() throws {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "seed")
        logBird.log("already-there")

        let viewModel = LogsViewModel(logBird: logBird)

        XCTAssertEqual(viewModel.logs.map(\.message), ["already-there"])

        // A redelivery of an entry that is already seeded is not duplicated.
        viewModel.handle(.recorded(try XCTUnwrap(logBird.logs.first)))
        XCTAssertEqual(viewModel.logs.count, 1)
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

    func testTrimmedLogCanBeRedelivered() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "trim-redeliver", maxLogs: 2)
        let viewModel = LogsViewModel(logBird: logBird)
        let trimmed = makeLog(message: "one", level: .info)

        viewModel.handle(.recorded(trimmed))
        viewModel.handle(.recorded(makeLog(message: "two", level: .info)))
        viewModel.handle(.recorded(makeLog(message: "three", level: .info)))
        viewModel.handle(.recorded(trimmed))

        XCTAssertEqual(viewModel.logs.map(\.message), ["one", "three"])
    }

    func testRecordedEventsAreIgnoredWhenRetentionIsDisabled() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "vm-zero-retention", maxLogs: 0)
        let viewModel = LogsViewModel(logBird: logBird)

        viewModel.handle(.recorded(makeLog(message: "dropped", level: .info)))

        XCTAssertTrue(viewModel.logs.isEmpty)
    }

    func testDisablingRetentionAtRuntimeEmptiesViewModelOnNextEvent() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "vm-runtime-zero", maxLogs: 10)
        let viewModel = LogsViewModel(logBird: logBird)

        viewModel.handle(.recorded(makeLog(message: "kept", level: .info)))
        XCTAssertEqual(viewModel.logs.count, 1)

        logBird.maxLogs = 0
        viewModel.handle(.recorded(makeLog(message: "dropped", level: .info)))

        XCTAssertTrue(viewModel.logs.isEmpty)
    }

    func testIsFilteringReflectsQueryAndLevelFilter() {
        let viewModel = LogsViewModel(logBird: LogBird(subsystem: "com.logbird.tests", category: "is-filtering"))

        XCTAssertFalse(viewModel.isFiltering)

        viewModel.searchText = "   "
        XCTAssertFalse(viewModel.isFiltering)

        viewModel.searchText = "network"
        XCTAssertTrue(viewModel.isFiltering)

        viewModel.searchText = ""
        viewModel.levelFilter = .error
        XCTAssertTrue(viewModel.isFiltering)
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

    func testSearchMatchesExtraMessages() {
        let viewModel = LogsViewModel(logBird: LogBird(subsystem: "com.logbird.tests", category: "search-extra"))
        viewModel.logs = [
            makeLog(message: "one", level: .info, extraMessages: [LBExtraMessage(key: "latency", value: "240ms")]),
            makeLog(message: "two", level: .info)
        ]

        viewModel.searchText = "latency"
        XCTAssertEqual(viewModel.filteredLogs.map(\.message), ["one"])

        viewModel.searchText = "240ms"
        XCTAssertEqual(viewModel.filteredLogs.map(\.message), ["one"])
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
        let error = LBError(domain: "com.test.networking", code: 401, type: "NSError", localizedDescription: "Unauthorized", userInfo: ["endpoint": "/login"])
        viewModel.logs = [
            makeLog(message: "one", level: .error, error: error),
            makeLog(message: "two", level: .info)
        ]

        viewModel.searchText = "networking"
        XCTAssertEqual(viewModel.filteredLogs.map(\.message), ["one"])

        viewModel.searchText = "401"
        XCTAssertEqual(viewModel.filteredLogs.map(\.message), ["one"])

        viewModel.searchText = "endpoint"
        XCTAssertEqual(viewModel.filteredLogs.map(\.message), ["one"])

        viewModel.searchText = "unauthorized"
        XCTAssertEqual(viewModel.filteredLogs.map(\.message), ["one"])
    }

    func testSearchMatchesLocationFile() {
        let viewModel = LogsViewModel(logBird: LogBird(subsystem: "com.logbird.tests", category: "search-location"))
        viewModel.logs = [
            makeLog(message: "one", level: .info, file: "LogBird/NetworkMonitor.swift"),
            makeLog(message: "two", level: .info)
        ]

        viewModel.searchText = "networkmonitor"
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
}
