//
//  LBLogLevel+Color.swift
//  LogBirdUI
//
//  Extracted from LBLogLevel to keep SwiftUI out of the core LogBird target.
//

import SwiftUI
import LogBird

extension LBLogLevel {

    /// Background tint used by `LBLogRowView` for the level.
    var color: Color {
        switch self {
        case .debug: return .secondary
        case .info: return .blue
        case .warning: return .yellow
        case .error: return .orange
        case .critical: return .red
        }
    }
}
