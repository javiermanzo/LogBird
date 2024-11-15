//
//  LogBird.swift
//  LogBird
//
//  Created by Javier Manzo on 14/11/2024.
//

import Foundation

public class LogBird: @unchecked Sendable {

    private let manager: LBManager

    public init(subsystem: String, category: String) {
        manager = LBManager(subsystem: subsystem, category: category)
    }
}

// MARK: Public Static methods
extension LogBird {
    private static let shared = LogBird(subsystem: Bundle.main.bundleIdentifier ?? "", category: "general")

    static public func setIdentifier(_ identifier: String?) {
        shared.setIdentifier(identifier)
    }

    static public func log(_ message: String, additionalInfo: [String: Any]? = nil, error: Error? = nil, level: LBLogLevel = .debug, file: String = #fileID, function: String = #function, line: Int = #line) {
        shared.log(message, additionalInfo: additionalInfo, error: error, level: level, file: file, function: function, line: line)
    }
}

// MARK: Public Methods
extension LogBird {
    public func setIdentifier(_ value: String?) {
        manager.setIdentifier(value)
    }

    public func log(_ message: String, additionalInfo: [String: Any]? = nil, error: Error? = nil, level: LBLogLevel = .debug, file: String = #fileID, function: String = #function, line: Int = #line) {
        manager.log(message, additionalInfo: additionalInfo, error: error, level: level, file: file, function: function, line: line)
    }
}
