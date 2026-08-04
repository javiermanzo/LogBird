//
//  LBLogLevel.swift
//  LogBird
//
//  Created by Javier Manzo on 15/11/2024.
//

import Foundation
import OSLog

/// Severity of a log entry. Cases are ordered from least to most severe.
public enum LBLogLevel: String, Codable, CaseIterable, Sendable {
    case debug, info, warning, error, critical
}

// MARK: Comparable
extension LBLogLevel: Comparable {

    /// Orders levels by severity, from `.debug` (lowest) to `.critical`
    /// (highest). The comparison uses the declaration order of the cases, not
    /// the raw string value (which would sort alphabetically and is
    /// meaningless for severity).
    public static func < (lhs: LBLogLevel, rhs: LBLogLevel) -> Bool {
        lhs.severityRank < rhs.severityRank
    }
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

    /// Numeric severity used only for ordering (`Comparable`) and threshold
    /// checks (`minLogLevel`). The value mirrors the declaration order of the
    /// cases so that `.debug < .info < .warning < .error < .critical`.
    var severityRank: Int {
        switch self {
        case .debug: return 0
        case .info: return 1
        case .warning: return 2
        case .error: return 3
        case .critical: return 4
        }
    }

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
