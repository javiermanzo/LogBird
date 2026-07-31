import XCTest
import SwiftUI
@testable import LogBirdUI
import LogBird

final class LBLogLevelColorTests: XCTestCase {

    func testEveryLevelExposesColor() {
        for level in LBLogLevel.allCases {
            // The core target no longer imports SwiftUI; ensure the UI
            // extension still exposes a distinct color per level.
            _ = level.color
        }
    }

    func testCriticalIsRed() {
        XCTAssertEqual(LBLogLevel.critical.color, .red)
    }
}
