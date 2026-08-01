import XCTest
import Combine
@testable import LogBird

final class LBLoggingModeTests: XCTestCase {

    // MARK: defaultIsEnabled

    /// `defaultIsEnabled` mirrors the build configuration: it is `true` while
    /// the test target compiles under `DEBUG`.
    func testDefaultIsEnabledReflectsDebugBuild() {
        #if DEBUG
        XCTAssertTrue(LogBird.defaultIsEnabled)
        #else
        XCTAssertFalse(LogBird.defaultIsEnabled)
        #endif
    }

    // MARK: isEnabled - init & defaults

    /// A logger constructed without explicit flags starts with the build
    /// default for `isEnabled` and the lowest severity floor.
    func testInitDefaultsMatchBuildConfiguration() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "defaults")

        XCTAssertEqual(logBird.isEnabled, LogBird.defaultIsEnabled)
        XCTAssertEqual(logBird.minLogLevel, .debug)
    }

    /// Explicit `isEnabled` at construction is honored.
    func testInitExplicitIsEnabledIsHonored() {
        let onByForce = LogBird(subsystem: "com.logbird.tests", category: "force-on", isEnabled: true)
        let offByForce = LogBird(subsystem: "com.logbird.tests", category: "force-off", isEnabled: false)

        XCTAssertTrue(onByForce.isEnabled)
        XCTAssertFalse(offByForce.isEnabled)
    }

    /// Explicit `minLogLevel` at construction is honored.
    func testInitExplicitMinLogLevelIsHonored() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "floor", minLogLevel: .warning)

        XCTAssertEqual(logBird.minLogLevel, .warning)
    }

    // MARK: isEnabled - gating behavior

    /// When disabled, `log(...)` records nothing, forwards nothing to OSLog
    /// and publishes no Combine event.
    func testDisabledLoggerRecordsAndPublishesNothing() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "disabled")
        logBird.isEnabled = false

        let noEvent = expectation(description: "no event published while disabled")
        noEvent.isInverted = true
        let cancellable = logBird.logsPublisher.sink { _ in noEvent.fulfill() }

        logBird.log("should-be-silenced")
        logBird.log("another", level: .critical)

        wait(for: [noEvent], timeout: 1)
        cancellable.cancel()

        XCTAssertTrue(logBird.logs.isEmpty)
    }

    /// Re-enabling recording restores normal behavior on the very next call.
    func testReEnablingAtRuntimeResumesRecording() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "toggle")
        logBird.isEnabled = false

        logBird.log("while-off")
        XCTAssertTrue(logBird.logs.isEmpty)

        logBird.isEnabled = true
        logBird.log("while-on")

        XCTAssertEqual(logBird.logs.map(\.message), ["while-on"])
    }

    /// `isEnabled` is applied synchronously: the value set before a call is
    /// the one that call observes.
    func testIsEnabledChangesApplySynchronously() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "sync")

        logBird.isEnabled = false
        logBird.log("first")            // dropped
        logBird.isEnabled = true
        logBird.log("second")           // kept
        logBird.isEnabled = false
        logBird.log("third")            // dropped

        XCTAssertEqual(logBird.logs.map(\.message), ["second"])
    }

    // MARK: minLogLevel - threshold filtering

    /// Setting `minLogLevel = .warning` keeps warning, error and critical while
    /// dropping debug and info.
    func testMinLogLevelFiltersLowerSeverities() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "threshold")
        logBird.isEnabled = true
        logBird.minLogLevel = .warning

        logBird.log("d", level: .debug)
        logBird.log("i", level: .info)
        logBird.log("w", level: .warning)
        logBird.log("e", level: .error)
        logBird.log("c", level: .critical)

        XCTAssertEqual(logBird.logs.map { $0.message }, ["w", "e", "c"])
        XCTAssertEqual(logBird.logs.map { $0.level }, [.warning, .error, .critical])
    }

    /// The threshold is inclusive: an entry at exactly `minLogLevel` is kept.
    func testMinLogLevelIsInclusive() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "inclusive")
        logBird.isEnabled = true
        logBird.minLogLevel = .error

        logBird.log("at-floor", level: .error)

        XCTAssertEqual(logBird.logs.map(\.message), ["at-floor"])
    }

    /// `.debug` (the default) lets every level through.
    func testDefaultMinLogLevelAllowsEverything() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "allow-all")
        logBird.isEnabled = true

        for level in LBLogLevel.allCases {
            logBird.log(level.rawValue, level: level)
        }

        XCTAssertEqual(logBird.logs.map { $0.level }, LBLogLevel.allCases)
    }

    /// Raising the floor at runtime takes effect on subsequent calls.
    func testMinLogLevelChangesApplySynchronously() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "raise-floor")
        logBird.isEnabled = true
        logBird.minLogLevel = .debug

        logBird.log("debug-1", level: .debug)   // kept
        logBird.minLogLevel = .info
        logBird.log("debug-2", level: .debug)   // dropped
        logBird.log("info-1", level: .info)     // kept

        XCTAssertEqual(logBird.logs.map(\.message), ["debug-1", "info-1"])
    }

    // MARK: isEnabled + minLogLevel interaction

    /// The master switch wins: with `isEnabled = false` nothing is recorded
    /// regardless of the level floor.
    func testDisabledSwitchOverridesMinLogLevel() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "switch-wins")
        logBird.isEnabled = false
        logBird.minLogLevel = .debug

        for level in LBLogLevel.allCases {
            logBird.log(level.rawValue, level: level)
        }

        XCTAssertTrue(logBird.logs.isEmpty)
    }

    // MARK: clearLogs / export are not gated

    /// `clearLogs()` works while disabled so an integrator can reset history
    /// regardless of the recording state.
    func testClearLogsWorksWhileDisabled() {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "clear-while-off")
        logBird.isEnabled = true
        logBird.log("one")
        logBird.log("two")
        XCTAssertEqual(logBird.logs.count, 2)

        logBird.isEnabled = false
        logBird.clearLogs()

        XCTAssertTrue(logBird.logs.isEmpty)
    }

    /// `export()` returns previously recorded history even while disabled.
    func testExportWorksWhileDisabled() throws {
        let logBird = LogBird(subsystem: "com.logbird.tests", category: "export-while-off")
        logBird.isEnabled = true
        logBird.log("kept")

        logBird.isEnabled = false
        let decoded = try JSONDecoder().decode([LBLog].self, from: logBird.export(format: .json).data)

        XCTAssertEqual(decoded.map(\.message), ["kept"])
    }

    // MARK: Static facade

    /// The static API routes `isEnabled` / `minLogLevel` to `shared`, and
    /// changes are observable through `shared`.
    func testStaticFacadeRoutesModeToSharedInstance() {
        let previousEnabled = LogBird.shared.isEnabled
        let previousFloor = LogBird.shared.minLogLevel
        defer {
            LogBird.shared.isEnabled = previousEnabled
            LogBird.shared.minLogLevel = previousFloor
            LogBird.clearLogs()
        }

        LogBird.isEnabled = true
        LogBird.minLogLevel = .warning
        XCTAssertTrue(LogBird.shared.isEnabled)
        XCTAssertEqual(LogBird.shared.minLogLevel, .warning)

        LogBird.log("drops", level: .debug)
        LogBird.log("keeps", level: .error)

        XCTAssertEqual(LogBird.shared.logs.map(\.message), ["keeps"])
    }
}
