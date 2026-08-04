import XCTest
import OSLog
@testable import LogBird

final class LBLogLevelTests: XCTestCase {

    func testAllCasesAreDeclaredInSeverityOrder() {
        XCTAssertEqual(LBLogLevel.allCases, [.debug, .info, .warning, .error, .critical])
    }

    func testOSLogTypeMapping() {
        XCTAssertEqual(LBLogLevel.debug.osLogType, .debug)
        XCTAssertEqual(LBLogLevel.info.osLogType, .info)
        XCTAssertEqual(LBLogLevel.warning.osLogType, .default)
        XCTAssertEqual(LBLogLevel.error.osLogType, .error)
        XCTAssertEqual(LBLogLevel.critical.osLogType, .fault)
    }

    func testEveryLevelDefinesDistinctEmojiAndSymbol() {
        var emojis: Set<String> = []
        var symbols: Set<String> = []

        for level in LBLogLevel.allCases {
            XCTAssertFalse(level.emoji.isEmpty)
            XCTAssertFalse(level.symbolName.isEmpty)
            emojis.insert(level.emoji)
            symbols.insert(level.symbolName)
        }

        XCTAssertEqual(emojis.count, LBLogLevel.allCases.count)
        XCTAssertEqual(symbols.count, LBLogLevel.allCases.count)
    }

    // MARK: Comparable

    func testComparableOrdersBySeverityNotAlphabetically() {
        // Severity order, not the alphabetical order of the raw values
        // (which would be critical < debug < error < info < warning).
        XCTAssertTrue(LBLogLevel.debug < .info)
        XCTAssertTrue(LBLogLevel.info < .warning)
        XCTAssertTrue(LBLogLevel.warning < .error)
        XCTAssertTrue(LBLogLevel.error < .critical)
        XCTAssertTrue(LBLogLevel.debug < .critical)

        XCTAssertFalse(LBLogLevel.critical < .debug)
        XCTAssertFalse(LBLogLevel.warning < .info)
    }

    func testComparableEqualityAndReflexivity() {
        XCTAssertEqual(LBLogLevel.error, .error)
        XCTAssertFalse(LBLogLevel.error < .error)
        XCTAssertFalse(LBLogLevel.error > LBLogLevel.error)
        // Transitivity spot-check across the whole range.
        let ordered: [LBLogLevel] = [.debug, .info, .warning, .error, .critical]
        for i in 0..<ordered.count {
            for j in 0..<ordered.count {
                if i < j {
                    XCTAssertLessThan(ordered[i], ordered[j])
                } else if i == j {
                    XCTAssertEqual(ordered[i], ordered[j])
                } else {
                    XCTAssertGreaterThan(ordered[i], ordered[j])
                }
            }
        }
    }
}
