import XCTest
@testable import LogBird

final class LBConfigTests: XCTestCase {

    func testConfigInitDefaults() {
        let config = LBConfig()

        XCTAssertEqual(config.maxLogs, 1000)
        XCTAssertEqual(config.isEnabled, LogBird.defaultIsEnabled)
        XCTAssertEqual(config.minLogLevel, .debug)
        XCTAssertTrue(config.redactSensitiveFields)
        XCTAssertEqual(config.sensitiveKeys, LBRedactor.defaultSensitiveKeys)
        XCTAssertNil(config.identifier)
    }

    func testConfigCustomValues() {
        let customKeys: Set<String> = ["ssn", "creditcard"]
        let config = LBConfig(
            maxLogs: 500,
            isEnabled: true,
            minLogLevel: .warning,
            redactSensitiveFields: false,
            sensitiveKeys: customKeys,
            identifier: "SESSION-123"
        )

        XCTAssertEqual(config.maxLogs, 500)
        XCTAssertTrue(config.isEnabled)
        XCTAssertEqual(config.minLogLevel, .warning)
        XCTAssertFalse(config.redactSensitiveFields)
        XCTAssertEqual(config.sensitiveKeys, customKeys)
        XCTAssertEqual(config.identifier, "SESSION-123")
    }

    func testConfigSanitizesMaxLogs() {
        let config = LBConfig(maxLogs: -50)
        XCTAssertEqual(config.maxLogs, 0)
    }

    func testConfigSensitiveKeysActions() {
        var config = LBConfig()

        config.sensitiveKeys(.set(["customkey"]))
        XCTAssertEqual(config.sensitiveKeys, ["customkey"])

        config.sensitiveKeys(.add(["anotherkey"]))
        XCTAssertEqual(config.sensitiveKeys, ["customkey", "anotherkey"])

        config.sensitiveKeys(.clear)
        XCTAssertTrue(config.sensitiveKeys.isEmpty)

        config.sensitiveKeys(.default)
        XCTAssertEqual(config.sensitiveKeys, LogBird.defaultSensitiveKeys)

        config.sensitiveKeys(.default(["customdefault"]))
        XCTAssertEqual(config.sensitiveKeys, ["customdefault"])
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
}
