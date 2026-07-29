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

    func testEveryLevelDefinesDistinctUIPresentation() {
        var emojis: Set<String> = []
        var symbols: Set<String> = []

        for level in LBLogLevel.allCases {
            XCTAssertFalse(level.emoji.isEmpty)
            XCTAssertFalse(level.symbolName.isEmpty)
            emojis.insert(level.emoji)
            symbols.insert(level.symbolName)
            _ = level.color
        }

        XCTAssertEqual(emojis.count, LBLogLevel.allCases.count)
        XCTAssertEqual(symbols.count, LBLogLevel.allCases.count)
    }
}
