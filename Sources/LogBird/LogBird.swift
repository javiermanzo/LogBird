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
    /// Uses the host bundle identifier as subsystem, or a stable default where
    /// the bundle provides none (e.g. tests or command-line tools).
    static public let shared = LogBird(subsystem: resolvedSubsystem(bundleIdentifier: Bundle.main.bundleIdentifier), category: "general")

    /// Returns the bundle identifier to use as subsystem, or a stable default
    /// when the host bundle has none.
    static func resolvedSubsystem(bundleIdentifier: String?) -> String {
        bundleIdentifier ?? "com.logbird.default"
    }

    /// Publishes history events as they happen: `recorded` for each new entry
    /// and `cleared` when the history is emptied. Earlier events are not
    /// replayed to new subscribers; use `logs` for the recorded history.
    static public var logsPublisher: AnyPublisher<LBLogEvent, Never> {
        shared.logsPublisher
    }

    /// The recorded history of `shared`, newest first.
    static public var logs: [LBLog] {
        shared.logs
    }

    /// The maximum number of entries kept in memory by `shared`. A value of 0
    /// disables the in-memory history while events keep publishing.
    static public var maxLogs: Int {
        get { shared.maxLogs }
        set { shared.maxLogs = newValue }
    }

    /// Keys matched by default when redacting sensitive fields.
    static public let defaultSensitiveKeys: [String] = LBRedactor.defaultSensitiveKeys

    /// The string that replaces a redacted value.
    static public let redactionPlaceholder: String = LBRedactor.placeholder

    /// Whether values under sensitive keys in `additionalInfo`, `extraMessages`
    /// and `error.userInfo` are replaced by the redaction placeholder before a
    /// log is stored. Default: `true`.
    ///
    /// A redacted value is always stored as a string, regardless of its
    /// original type. `message` and an error's `localizedDescription` are not
    /// scanned; mark sensitive values at the call site with `LBLogMessage`
    /// instead.
    static public var redactSensitiveFields: Bool {
        get { shared.redactSensitiveFields }
        set { shared.redactSensitiveFields = newValue }
    }

    /// The keys considered sensitive when redacting. A key is sensitive when it
    /// contains any of these values; matching is case-insensitive and ignores
    /// underscores, hyphens and whitespace, so `accessToken` and `ACCESS-TOKEN`
    /// match `token`.
    ///
    /// Setting this property replaces the default keys; append to
    /// `defaultSensitiveKeys` to extend them.
    static public var sensitiveKeys: [String] {
        get { shared.sensitiveKeys }
        set { shared.sensitiveKeys = newValue }
    }

    static public func setIdentifier(_ identifier: String?) {
        shared.setIdentifier(identifier)
    }

    static public func log(_ message: String? = nil, extraMessages: [LBExtraMessage]? = nil, additionalInfo: [String: LBValue]? = nil, error: Error? = nil, level: LBLogLevel = .debug, file: String = #fileID, function: String = #function, line: Int = #line) {
        shared.log(message, extraMessages: extraMessages, additionalInfo: additionalInfo, error: error, level: level, file: file, function: function, line: line)
    }

    static public func log(_ message: LBLogMessage, extraMessages: [LBExtraMessage]? = nil, additionalInfo: [String: LBValue]? = nil, error: Error? = nil, level: LBLogLevel = .debug, file: String = #fileID, function: String = #function, line: Int = #line) {
        shared.log(message, extraMessages: extraMessages, additionalInfo: additionalInfo, error: error, level: level, file: file, function: function, line: line)
    }

    /// Empties the recorded history. Subscribers receive a `cleared` event.
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

    /// Publishes history events as they happen: `recorded` for each new entry
    /// and `cleared` when the history is emptied. Earlier events are not
    /// replayed to new subscribers; use `logs` for the recorded history.
    public var logsPublisher: AnyPublisher<LBLogEvent, Never> {
        manager.logsPublisher
    }

    /// The recorded history, newest first. The number of entries is capped at
    /// `maxLogs`.
    public var logs: [LBLog] {
        manager.logsSnapshot
    }

    /// The maximum number of entries kept in memory. Once the limit is reached,
    /// the oldest entries are discarded. A value of 0 disables the in-memory
    /// history while events keep publishing. Lowering the value trims the
    /// existing history immediately and cannot be undone.
    public var maxLogs: Int {
        get { manager.maxLogs }
        set { manager.maxLogs = newValue }
    }

    /// Whether values under sensitive keys in `additionalInfo`, `extraMessages`
    /// and `error.userInfo` are replaced by the redaction placeholder before a
    /// log is stored. Default: `true`.
    ///
    /// A redacted value is always stored as a string, regardless of its
    /// original type. `message` and an error's `localizedDescription` are not
    /// scanned; mark sensitive values at the call site with `LBLogMessage`
    /// instead.
    public var redactSensitiveFields: Bool {
        get { manager.redactSensitiveFields }
        set { manager.redactSensitiveFields = newValue }
    }

    /// The keys considered sensitive when redacting. A key is sensitive when it
    /// contains any of these values; matching is case-insensitive and ignores
    /// underscores, hyphens and whitespace, so `accessToken` and `ACCESS-TOKEN`
    /// match `token`.
    ///
    /// Setting this property replaces the default keys; append to
    /// `LogBird.defaultSensitiveKeys` to extend them.
    public var sensitiveKeys: [String] {
        get { manager.sensitiveKeys }
        set { manager.sensitiveKeys = newValue }
    }

    public func setIdentifier(_ value: String?) {
        manager.setIdentifier(value)
    }

    public func log(_ message: String? = nil, extraMessages: [LBExtraMessage]? = nil, additionalInfo: [String: LBValue]? = nil, error: Error? = nil, level: LBLogLevel = .debug, file: String = #fileID, function: String = #function, line: Int = #line) {
        manager.log(message, extraMessages: extraMessages, additionalInfo: additionalInfo, error: error, level: level, file: file, function: function, line: line)
    }

    public func log(_ message: LBLogMessage, extraMessages: [LBExtraMessage]? = nil, additionalInfo: [String: LBValue]? = nil, error: Error? = nil, level: LBLogLevel = .debug, file: String = #fileID, function: String = #function, line: Int = #line) {
        manager.log(message.value, extraMessages: extraMessages, additionalInfo: additionalInfo, error: error, level: level, file: file, function: function, line: line)
    }

    /// Empties the recorded history. Subscribers receive a `cleared` event.
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
