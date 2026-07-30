//
//  LogBird.swift
//  LogBird
//
//  Created by Javier Manzo on 14/11/2024.
//

import Foundation
import Combine

/// A logger that keeps a bounded in-memory history, mirrors entries to OSLog
/// and publishes history events through Combine.
///
/// Use the static API (`LogBird.log(_:)`, `LogBird.logs`, ...) for a shared
/// instance, or create one with `init(subsystem:category:maxLogs:)` for an
/// isolated subsystem/category pair and history. Both `subsystem` and
/// `category` default to sensible, caller-aware values, so `LogBird()` is
/// usually enough. Instances are thread-safe.
public class LogBird: @unchecked Sendable {

    private let manager: LBManager

    /// Creates a logger that records under the given `subsystem` and `category`.
    ///
    /// Both default to caller-aware values so that `LogBird()` works out of the
    /// box:
    ///
    /// - `subsystem` defaults to `Bundle.main.bundleIdentifier` (falling back
    ///   to `"com.logbird.default"` where the host bundle provides none). This
    ///   follows the OSLog convention of one subsystem per app.
    /// - `category` defaults to the module name of the call site, derived from
    ///   `fileID` (e.g. a call from `Network/Client.swift` uses `Network`, one
    ///   from `MyApp/AppDelegate.swift` uses `MyApp`). This scopes entries in
    ///   Console.app to whoever created the logger, instead of a generic label.
    ///
    /// Packages that need a stable, isolated subsystem regardless of host
    /// (e.g. an SDK) should pass `subsystem` explicitly at a single,
    /// package-internal call site.
    ///
    /// - Parameters:
    ///   - subsystem: `String` — Reverse-DNS identifier used by OSLog (e.g. `com.example.myapp`). Defaults to host bundle identifier.
    ///   - category: `String?` — OSLog category scoping entries in Console.app. Pass `nil` to infer caller module from `fileID`.
    ///   - fileID: `String` — `#fileID` string at call site, used to infer `category` when `nil`.
    ///   - maxLogs: `Int` — Maximum history entries kept in memory. `0` disables history retention. Defaults to `1000`.
    public init(
        subsystem: String = resolvedSubsystem(bundleIdentifier: Bundle.main.bundleIdentifier),
        category: String? = nil,
        fileID: String = #fileID,
        maxLogs: Int = 1000
    ) {
        let resolvedCategory = category ?? Self.defaultCategory(fileID: fileID)
        manager = LBManager(subsystem: subsystem, category: resolvedCategory, maxLogs: maxLogs)
    }
}

// MARK: Public Static
public extension LogBird {

    /// A shared logger that uses the host bundle identifier as subsystem and
    /// `general` as category, or a stable default where the bundle provides
    /// none (e.g. tests or command-line tools).
    static let shared = LogBird(subsystem: resolvedSubsystem(bundleIdentifier: Bundle.main.bundleIdentifier), category: "general")

    /// Publishes history events as they happen: `recorded` for each new entry
    /// and `cleared` when the history is emptied. Earlier events are not
    /// replayed to new subscribers; use `logs` for the recorded history.
    static var logsPublisher: AnyPublisher<LBLogEvent, Never> {
        shared.logsPublisher
    }

    /// The recorded history of `shared`, in recording order (oldest first).
    static var logs: [LBLog] {
        shared.logs
    }

    /// The maximum number of entries kept in memory by `shared`. A value of 0
    /// disables the in-memory history while events keep publishing.
    static var maxLogs: Int {
        get { shared.maxLogs }
        set { shared.maxLogs = newValue }
    }

    /// Keys matched by default when redacting sensitive fields.
    static let defaultSensitiveKeys: [String] = LBRedactor.defaultSensitiveKeys

    /// The string that replaces a redacted value.
    static let redactionPlaceholder: String = LBRedactor.placeholder

    /// Whether values under sensitive keys in `additionalInfo`, `extraMessages`
    /// and `error.userInfo` are replaced by the redaction placeholder before a
    /// log is stored. Default: `true`.
    ///
    /// A redacted value is always stored as a string, regardless of its
    /// original type. `message` and an error's `localizedDescription` are not
    /// scanned; mark sensitive values at the call site with `LBLogMessage`
    /// instead.
    static var redactSensitiveFields: Bool {
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
    static var sensitiveKeys: [String] {
        get { shared.sensitiveKeys }
        set { shared.sensitiveKeys = newValue }
    }

    /// An optional identifier prepended to each OSLog line for the shared
    /// instance, such as a session or user id. Set to `nil` to clear.
    static var identifier: String? {
        get { shared.identifier }
        set { shared.identifier = newValue }
    }

    /// Records a log entry on the shared instance.
    ///
    /// - Parameters:
    ///   - message: `String?` — free-text message. Use `LBLogMessage` to redact sensitive content.
    ///   - extraMessages: `[LBExtraMessage]?` — labeled strings shown as separate sections.
    ///   - additionalInfo: `[String: LBValue]?` — typed metadata keyed by name.
    ///   - error: `Error?` — error to capture (includes `DecodingError`/`EncodingError` context).
    ///   - level: `LBLogLevel` — severity. Defaults to `.debug`.
    ///   - file: `String` — source file. Defaults to `#fileID`.
    ///   - function: `String` — source function. Defaults to `#function`.
    ///   - line: `Int` — source line. Defaults to `#line`.
    /// Records a log entry on the shared instance.
    ///
    /// - Parameters:
    ///   - message: `String?` — free-text message. Use `LBLogMessage` to redact sensitive content.
    ///   - extraMessages: `[LBExtraMessage]?` — labeled strings shown as separate sections.
    ///   - additionalInfo: `[String: LBValue]?` — typed metadata keyed by name.
    ///   - error: `Error?` — error to capture.
    ///   - level: `LBLogLevel` — severity. Defaults to `.debug`.
    ///   - file: `String` — source file. Defaults to `#fileID`.
    ///   - function: `String` — source function. Defaults to `#function`.
    ///   - line: `Int` — source line. Defaults to `#line`.
    static func log(_ message: String? = nil, extraMessages: [LBExtraMessage]? = nil, additionalInfo: [String: LBValue]? = nil, error: Error? = nil, level: LBLogLevel = .debug, file: String = #fileID, function: String = #function, line: Int = #line) {
        shared.log(message, extraMessages: extraMessages, additionalInfo: additionalInfo, error: error, level: level, file: file, function: function, line: line)
    }

    /// Records a log entry built from a privacy-aware `LBLogMessage` on the shared instance.
    ///
    /// - Parameters:
    ///   - message: `LBLogMessage` — privacy-aware interpolated message string.
    ///   - extraMessages: `[LBExtraMessage]?` — labeled strings shown as separate sections.
    ///   - additionalInfo: `[String: LBValue]?` — typed metadata keyed by name.
    ///   - error: `Error?` — error to capture.
    ///   - level: `LBLogLevel` — severity. Defaults to `.debug`.
    ///   - file: `String` — source file. Defaults to `#fileID`.
    ///   - function: `String` — source function. Defaults to `#function`.
    ///   - line: `Int` — source line. Defaults to `#line`.
    static func log(_ message: LBLogMessage, extraMessages: [LBExtraMessage]? = nil, additionalInfo: [String: LBValue]? = nil, error: Error? = nil, level: LBLogLevel = .debug, file: String = #fileID, function: String = #function, line: Int = #line) {
        shared.log(message, extraMessages: extraMessages, additionalInfo: additionalInfo, error: error, level: level, file: file, function: function, line: line)
    }

    /// Empties the recorded history. Subscribers receive a `cleared` event.
    static func clearLogs() {
        shared.clearLogs()
    }

    /// Exports logs of the shared instance in the given format and delivers
    /// them to `destination`.
    ///
    /// - Parameters:
    ///   - content: `LBExportContent` — `.all` (default) exports the recorded
    ///     history; `.logs` exports an arbitrary selection, e.g. filtered entries.
    ///   - format: `LBExportFormat` — encoding to use. Defaults to `.json`.
    ///   - destination: `LBExportDestination` — `.data` (default) only encodes;
    ///     `.file(url)` also writes atomically to `url`, or to a temporary file
    ///     named `logbird-logs-<timestamp>.<ext>` when `url` is `nil`.
    /// - Throws: `EncodingError` if a log value cannot be encoded (e.g. non-finite double), or the file-system error if writing fails.
    /// - Returns: `LBExportOutput` with the encoded data and, for `.file`, the written URL.
    @discardableResult
    static func export(_ content: LBExportContent = .all, format: LBExportFormat = .json, destination: LBExportDestination = .data) throws -> LBExportOutput {
        try shared.export(content, format: format, destination: destination)
    }
}

// MARK: Public
public extension LogBird {

    /// Publishes history events as they happen: `recorded` for each new entry
    /// and `cleared` when the history is emptied. Earlier events are not
    /// replayed to new subscribers; use `logs` for the recorded history.
    var logsPublisher: AnyPublisher<LBLogEvent, Never> {
        manager.logsPublisher
    }

    /// The recorded history, in recording order (oldest first). The number of
    /// entries is capped at `maxLogs`.
    var logs: [LBLog] {
        manager.logsSnapshot
    }

    /// The maximum number of entries kept in memory. Once the limit is reached,
    /// the oldest entries are discarded. A value of 0 disables the in-memory
    /// history while events keep publishing. Lowering the value trims the
    /// existing history immediately and cannot be undone.
    var maxLogs: Int {
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
    var redactSensitiveFields: Bool {
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
    var sensitiveKeys: [String] {
        get { manager.sensitiveKeys }
        set { manager.sensitiveKeys = newValue }
    }

    /// An optional identifier prepended to each OSLog line for this instance,
    /// such as a session or user id. Set to `nil` to clear.
    var identifier: String? {
        get { manager.identifier }
        set { manager.identifier = newValue }
    }

    /// Records a log entry on this instance.
    ///
    /// - Parameters:
    ///   - message: `String?` — free-text message. Use `LBLogMessage` to redact sensitive content.
    ///   - extraMessages: `[LBExtraMessage]?` — labeled strings shown as separate sections.
    ///   - additionalInfo: `[String: LBValue]?` — typed metadata keyed by name.
    ///   - error: `Error?` — error to capture (includes `DecodingError`/`EncodingError` context).
    ///   - level: `LBLogLevel` — severity. Defaults to `.debug`.
    ///   - file: `String` — source file. Defaults to `#fileID`.
    ///   - function: `String` — source function. Defaults to `#function`.
    ///   - line: `Int` — source line. Defaults to `#line`.
    func log(_ message: String? = nil, extraMessages: [LBExtraMessage]? = nil, additionalInfo: [String: LBValue]? = nil, error: Error? = nil, level: LBLogLevel = .debug, file: String = #fileID, function: String = #function, line: Int = #line) {
        manager.log(message, extraMessages: extraMessages, additionalInfo: additionalInfo, error: error, level: level, file: file, function: function, line: line)
    }

    /// Records a log entry built from a privacy-aware `LBLogMessage` on this instance.
    ///
    /// - Parameters:
    ///   - message: `LBLogMessage` — privacy-aware interpolated message string.
    ///   - extraMessages: `[LBExtraMessage]?` — labeled strings shown as separate sections.
    ///   - additionalInfo: `[String: LBValue]?` — typed metadata keyed by name.
    ///   - error: `Error?` — error to capture (includes `DecodingError`/`EncodingError` context).
    ///   - level: `LBLogLevel` — severity. Defaults to `.debug`.
    ///   - file: `String` — source file. Defaults to `#fileID`.
    ///   - function: `String` — source function. Defaults to `#function`.
    ///   - line: `Int` — source line. Defaults to `#line`.
    func log(_ message: LBLogMessage, extraMessages: [LBExtraMessage]? = nil, additionalInfo: [String: LBValue]? = nil, error: Error? = nil, level: LBLogLevel = .debug, file: String = #fileID, function: String = #function, line: Int = #line) {
        manager.log(message.value, extraMessages: extraMessages, additionalInfo: additionalInfo, error: error, level: level, file: file, function: function, line: line)
    }

    /// Empties the recorded history. Subscribers receive a `cleared` event.
    func clearLogs() {
        manager.clearLogs()
    }

    /// Exports logs in the given format and delivers them to `destination`.
    ///
    /// - Parameters:
    ///   - content: `LBExportContent` — `.all` (default) exports the recorded
    ///     history; `.logs` exports an arbitrary selection, e.g. filtered entries.
    ///   - format: `LBExportFormat` — encoding to use. Defaults to `.json`.
    ///   - destination: `LBExportDestination` — `.data` (default) only encodes;
    ///     `.file(url)` also writes atomically to `url`, or to a temporary file
    ///     named `logbird-logs-<timestamp>.<ext>` when `url` is `nil`.
    /// - Throws: `EncodingError` if a log value cannot be encoded (e.g. non-finite double), or the file-system error if writing fails.
    /// - Returns: `LBExportOutput` with the encoded data and, for `.file`, the written URL.
    @discardableResult
    func export(_ content: LBExportContent = .all, format: LBExportFormat = .json, destination: LBExportDestination = .data) throws -> LBExportOutput {
        try manager.export(content, format: format, destination: destination)
    }
}

// MARK: Internal
extension LogBird {

    /// Returns the bundle identifier to use as subsystem, or a stable default
    /// when the host bundle has none.
    @usableFromInline
    static func resolvedSubsystem(bundleIdentifier: String?) -> String {
        bundleIdentifier ?? "com.logbird.default"
    }

    /// Derives a default OSLog category from a `#fileID` value by taking its
    /// module component. `#fileID` has the form `Module/File.swift`, so the
    /// result reflects whoever creates the logger instead of a generic label.
    /// When the value has no module separator the whole string is returned.
    static func defaultCategory(fileID: String) -> String {
        if let slash = fileID.firstIndex(of: "/") {
            return String(fileID[..<slash])
        }
        return fileID
    }
}


