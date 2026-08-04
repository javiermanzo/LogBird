import XCTest
@testable import LogBird

final class LBConfigTests: XCTestCase {

    func testConfigInitDefaults() {
        let config = LBConfig()

        XCTAssertEqual(config.maxLogs, 1000)
        #if DEBUG
        XCTAssertTrue(config.isEnabled)
        #else
        XCTAssertFalse(config.isEnabled)
        #endif
        XCTAssertEqual(config.minLogLevel, .debug)
        XCTAssertTrue(config.redactSensitiveFields)
        XCTAssertEqual(config.sensitiveKeys, LBRedactor.initialDefaultSensitiveKeys)
        XCTAssertNil(config.identifier)
    }

    func testConfigCustomValues() {
        let customKeys: [String] = ["ssn", "creditcard"]
        let config = LBConfig(
            maxLogs: 500,
            isEnabled: true,
            minLogLevel: LBLogLevel.warning,
            redactSensitiveFields: false,
            sensitiveKeys: customKeys,
            identifier: "SESSION-123"
        )

        XCTAssertEqual(config.maxLogs, 500)
        XCTAssertTrue(config.isEnabled)
        XCTAssertEqual(config.minLogLevel, LBLogLevel.warning)
        XCTAssertFalse(config.redactSensitiveFields)
        XCTAssertEqual(config.sensitiveKeys, Set(customKeys))
        XCTAssertEqual(config.identifier, "SESSION-123")
    }

    func testConfigSanitizesMaxLogs() {
        let config = LBConfig(maxLogs: -50)
        XCTAssertEqual(config.maxLogs, 0)
    }

    func testConfigSensitiveKeysActions() {
        defer {
            LogBird.setDefaultSensitiveKeys(Array(LBRedactor.initialDefaultSensitiveKeys))
        }

        var config = LBConfig()

        config.sensitiveKeys(.add(["anotherkey"]))
        XCTAssertEqual(config.sensitiveKeys, LBRedactor.initialDefaultSensitiveKeys.union(["anotherkey"]))

        config.sensitiveKeys(.set(["customkey"]))
        XCTAssertEqual(config.sensitiveKeys, ["customkey"])

        config.sensitiveKeys(.clear)
        XCTAssertTrue(config.sensitiveKeys.isEmpty)

        config.sensitiveKeys(.reset)
        XCTAssertEqual(config.sensitiveKeys, LBRedactor.initialDefaultSensitiveKeys)

        LogBird.setDefaultSensitiveKeys(["globaldefault"])
        XCTAssertEqual(config.sensitiveKeys, ["globaldefault"])
    }

    func testLogBirdConfigPropertyMutation() {
        let logger = LogBird(subsystem: "com.logbird.tests", category: "config-test")

        var newConfig = LBConfig(
            maxLogs: 200,
            isEnabled: false,
            minLogLevel: .error,
            identifier: "CUSTOM-ID"
        )
        newConfig.sensitiveKeys(.set(["secrettoken"]))

        logger.config = newConfig

        XCTAssertEqual(logger.config.maxLogs, 200)
        XCTAssertFalse(logger.config.isEnabled)
        XCTAssertEqual(logger.config.minLogLevel, .error)
        XCTAssertEqual(logger.config.identifier, "CUSTOM-ID")
        XCTAssertEqual(logger.config.sensitiveKeys, ["secrettoken"])

        // Property forwarders match config
        XCTAssertEqual(logger.maxLogs, 200)
        XCTAssertFalse(logger.isEnabled)
        XCTAssertEqual(logger.minLogLevel, .error)
        XCTAssertEqual(logger.identifier, "CUSTOM-ID")
        XCTAssertEqual(logger.sensitiveKeys, ["secrettoken"])
    }

    func testStaticFacadeConfigMutation() {
        let previousConfig = LogBird.config
        defer {
            LogBird.config = previousConfig
        }

        LogBird.config.minLogLevel = .critical
        XCTAssertEqual(LogBird.minLogLevel, .critical)
        XCTAssertEqual(LogBird.shared.config.minLogLevel, .critical)
    }

    /// Forwarded property setters mutate a single field atomically: writing one
    /// field must never clobber another field previously set on the same logger.
    /// This locks in the fix for the read-modify-write TOCTOU race where a
    /// concurrent change between the getter and setter hops could be reverted.
    func testForwardedPropertySettersDoNotClobberOtherFields() {
        let logger = LogBird(subsystem: "com.logbird.tests", category: "atomic-setters")
        logger.config = LBConfig(
            maxLogs: 100,
            isEnabled: false,
            minLogLevel: .error,
            redactSensitiveFields: false,
            identifier: "ORIGINAL"
        )

        // Toggle each forwarded field independently; the others must remain intact.
        logger.isEnabled = true
        XCTAssertEqual(logger.isEnabled, true)
        XCTAssertEqual(logger.maxLogs, 100)
        XCTAssertEqual(logger.minLogLevel, .error)
        XCTAssertFalse(logger.redactSensitiveFields)
        XCTAssertEqual(logger.identifier, "ORIGINAL")

        logger.maxLogs = 25
        XCTAssertEqual(logger.maxLogs, 25)
        XCTAssertTrue(logger.isEnabled)
        XCTAssertEqual(logger.minLogLevel, .error)
        XCTAssertFalse(logger.redactSensitiveFields)
        XCTAssertEqual(logger.identifier, "ORIGINAL")

        logger.minLogLevel = .warning
        XCTAssertEqual(logger.minLogLevel, .warning)
        XCTAssertEqual(logger.maxLogs, 25)
        XCTAssertTrue(logger.isEnabled)
        XCTAssertEqual(logger.identifier, "ORIGINAL")

        logger.redactSensitiveFields = true
        XCTAssertTrue(logger.redactSensitiveFields)
        XCTAssertEqual(logger.maxLogs, 25)
        XCTAssertEqual(logger.minLogLevel, .warning)

        logger.identifier = "UPDATED"
        XCTAssertEqual(logger.identifier, "UPDATED")
        XCTAssertEqual(logger.maxLogs, 25)
        XCTAssertEqual(logger.minLogLevel, .warning)
        XCTAssertTrue(logger.redactSensitiveFields)
    }

    /// `maxLogs` setter trims existing history immediately, matching the
    /// behavior of the `config` setter.
    func testMaxLogsSetterTrimsHistory() {
        let logger = LogBird(subsystem: "com.logbird.tests", category: "trim")
        logger.isEnabled = true
        logger.maxLogs = 1000
        for index in 0..<10 {
            logger.log("\(index)")
        }
        XCTAssertEqual(logger.logs.count, 10)

        logger.maxLogs = 3
        XCTAssertEqual(logger.logs.count, 3)
        XCTAssertEqual(logger.logs.map(\.message), ["7", "8", "9"])
    }
}
