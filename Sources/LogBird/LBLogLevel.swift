//
//  LBLogLevel.swift
//  LogBird
//
//  Created by Javier Manzo on 15/11/2024.
//

import Foundation
import OSLog

public enum LBLogLevel: String, Codable, CaseIterable {
    case debug, info, warning, error, critical
    
    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .critical: return .fault
        }
    }
    
    public var emoji: String {
        switch self {
        case .debug: return "🐞"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🚨"
        }
    }
}
