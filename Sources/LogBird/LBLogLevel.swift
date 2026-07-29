//
//  LBLogLevel.swift
//  LogBird
//
//  Created by Javier Manzo on 15/11/2024.
//

import Foundation
import OSLog
import SwiftUI

/// Severity of a log entry. Cases are ordered from least to most severe.
public enum LBLogLevel: String, Codable, CaseIterable, Sendable {
    case debug, info, warning, error, critical
}

// MARK: Public
public extension LBLogLevel {

    /// Emoji prefix used in the OSLog header and the SwiftUI row.
    var emoji: String {
        switch self {
        case .debug: return "🐞"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🚨"
        }
    }

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

    /// SF Symbol name used by `LBLogsView` for the level filter.
    var symbolName: String {
        switch self {
        case .debug: return "ant"
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.octagon"
        case .critical: return "flame"
        }
    }
}

// MARK: CustomStringConvertible
extension LBLogLevel: CustomStringConvertible {

    public var description: String {
        rawValue
    }
}

// MARK: Internal
extension LBLogLevel {

    /// Matching `OSLogType` used when forwarding the entry to OSLog.
    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .critical: return .fault
        }
    }
}
