//
//  LogBird.swift
//  LogBird
//
//  Created by Javier Manzo on 14/11/2024.
//

import Foundation
import Combine

public class LogBird: @unchecked Sendable {

    private let manager: LBManager

    public init(subsystem: String, category: String, maxLogs: Int = 1000) {
        manager = LBManager(subsystem: subsystem, category: category, maxLogs: maxLogs)
    }
}

// MARK: Public Static methods
extension LogBird {
    static public let shared = LogBird(subsystem: Bundle.main.bundleIdentifier ?? "", category: "general")

    static public var logsPublisher: AnyPublisher<[LBLog], Never> {
        shared.logsPublisher
    }

    /// The maximum number of entries kept in memory by `shared`.
    static public var maxLogs: Int {
        get { shared.maxLogs }
        set { shared.maxLogs = newValue }
    }

    static public func setIdentifier(_ identifier: String?) {
        shared.setIdentifier(identifier)
    }

    static public func log(_ message: String? = nil, extraMessages: [LBExtraMessage]? = nil, additionalInfo: [String: LBValue]? = nil, error: Error? = nil, level: LBLogLevel = .debug, file: String = #fileID, function: String = #function, line: Int = #line) {
        shared.log(message, extraMessages: extraMessages, additionalInfo: additionalInfo, error: error, level: level, file: file, function: function, line: line)
    }

    static public func clearLogs() {
        shared.clearLogs()
    }

    static public func exportLogs(format: LBExportFormat = .json) throws -> Data {
        try shared.exportLogs(format: format)
    }

    static public func writeLogs(to url: URL, format: LBExportFormat = .json) throws {
        try shared.writeLogs(to: url, format: format)
    }
}

// MARK: Public Methods
extension LogBird {

    public var logsPublisher: AnyPublisher<[LBLog], Never> {
        manager.logsPublisher
    }

    /// The maximum number of entries kept in memory. Once the limit is reached,
    /// the oldest entries are discarded. Lowering the value trims the existing
    /// history immediately and cannot be undone.
    public var maxLogs: Int {
        get { manager.maxLogs }
        set { manager.maxLogs = newValue }
    }

    public func setIdentifier(_ value: String?) {
        manager.setIdentifier(value)
    }

    public func log(_ message: String? = nil, extraMessages: [LBExtraMessage]? = nil, additionalInfo: [String: LBValue]? = nil, error: Error? = nil, level: LBLogLevel = .debug, file: String = #fileID, function: String = #function, line: Int = #line) {
        manager.log(message, extraMessages: extraMessages, additionalInfo: additionalInfo, error: error, level: level, file: file, function: function, line: line)
    }

    public func clearLogs() {
        manager.clearLogs()
    }

    var currentIdentifier: String? {
        manager.currentIdentifier
    }

    /// Exports the recorded history in the given format.
    ///
    /// - Throws: an `EncodingError` if a log value cannot be encoded
    ///   (e.g. a non-finite double in `additionalInfo`).
    public func exportLogs(format: LBExportFormat = .json) throws -> Data {
        try manager.exportLogs(format: format)
    }

    /// Writes the recorded history to a file in the given format.
    public func writeLogs(to url: URL, format: LBExportFormat = .json) throws {
        try manager.writeLogs(to: url, format: format)
    }
}
