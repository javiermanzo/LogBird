//
//  LBManager.swift
//  LogBird
//
//  Created by Javier Manzo on 15/11/2024.
//

import Foundation
import OSLog
import Combine

final class LBManager: @unchecked Sendable {

    private let logger: Logger
    private var identifier: String?
    private let dispatchQueue: DispatchQueue = DispatchQueue(label: "com.logbird.accessQueue")
    // Publishing runs on its own serial queue so subscriber callbacks never execute
    // while the state queue is held (avoids re-entrancy deadlocks).
    private let publishQueue: DispatchQueue = DispatchQueue(label: "com.logbird.publishQueue")

    private let source: LBSource

    private var logs: [LBLog] = []
    private let logsSubject = PassthroughSubject<LBLogEvent, Never>()
    var logsPublisher: AnyPublisher<LBLogEvent, Never> {
        logsSubject.eraseToAnyPublisher()
    }

    /// The recorded history, newest first. Reading is serialized with mutations.
    var logsSnapshot: [LBLog] {
        dispatchQueue.sync { logs }
    }

    static let dateStyle: Date.ISO8601FormatStyle = {
        var style = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        style.timeZone = .current
        return style
    }()

    private var storedMaxLogs: Int
    private var storedRedactSensitiveFields: Bool = true
    private var storedSensitiveKeys: [String] = LBRedactor.defaultSensitiveKeys

    /// The maximum number of entries kept in memory. Once the limit is reached,
    /// the oldest entries are discarded. A value of 0 disables retention: the
    /// history stays empty while published events keep flowing. Negative values
    /// are treated as 0.
    var maxLogs: Int {
        get {
            dispatchQueue.sync { storedMaxLogs }
        }
        set {
            dispatchQueue.sync {
                self.storedMaxLogs = max(0, newValue)
                self.trimLogs()
            }
        }
    }

    var currentIdentifier: String? {
        dispatchQueue.sync { identifier }
    }

    /// Whether values under sensitive keys are redacted before a log is stored.
    var redactSensitiveFields: Bool {
        get { dispatchQueue.sync { storedRedactSensitiveFields } }
        set { dispatchQueue.sync { storedRedactSensitiveFields = newValue } }
    }

    /// The keys considered sensitive when redacting. See `LBRedactor` for the
    /// matching rules.
    var sensitiveKeys: [String] {
        get { dispatchQueue.sync { storedSensitiveKeys } }
        set { dispatchQueue.sync { storedSensitiveKeys = newValue } }
    }

    init(subsystem: String, category: String, maxLogs: Int = 1000) {
        let source = LBSource(subsystem: subsystem, category: category)
        self.logger = Logger(subsystem: source.subsystem, category: source.category)
        self.source = source
        self.storedMaxLogs = max(0, maxLogs)
    }

    func setIdentifier(_ value: String?) {
        dispatchQueue.sync {
            self.identifier = value
        }
    }

    func log(_ message: String? = nil,
             extraMessages: [LBExtraMessage]? = nil,
             additionalInfo: [String: LBValue]? = nil,
             error: Error? = nil,
             level: LBLogLevel = .debug,
             file: String = #fileID,
             function: String = #function,
             line: Int = #line) {

        // Snapshot the redaction config so `buildLogData` stays off the state queue.
        let redactor = dispatchQueue.sync {
            LBRedactor(isEnabled: self.storedRedactSensitiveFields, sensitiveKeys: self.storedSensitiveKeys)
        }

        // `buildLogData` only reads immutable `source` and the supplied parameters.
        let log = buildLogData(message: message,
                               extraMessages: extraMessages,
                               additionalInfo: additionalInfo,
                               error: error,
                               level: level,
                               file: file,
                               function: function,
                               line: line,
                               redactor: redactor)

        // Serialize identifier read and log mutation to keep state consistent.
        dispatchQueue.sync {
            let logMessage = Self.formattedMessage(for: log, identifier: self.identifier)
            self.logger.log(level: level.osLogType, "\(logMessage, privacy: .public)")
            self.logs.insert(log, at: 0)
            self.trimLogs()
            self.publishQueue.async { self.logsSubject.send(.recorded(log)) }
        }
    }

    func clearLogs() {
        dispatchQueue.sync {
            self.logs = []
            self.publishQueue.async { self.logsSubject.send(.cleared) }
        }
    }

    func exportLogs(format: LBExportFormat) throws -> Data {
        let (logs, identifier) = dispatchQueue.sync { (self.logs, self.identifier) }
        return try LBLogExporter.data(for: logs, format: format, identifier: identifier)
    }

    func writeLogs(to url: URL, format: LBExportFormat) throws {
        try exportLogs(format: format).write(to: url, options: .atomic)
    }

    /// Keeps only the newest `storedMaxLogs` entries. Must be called on `dispatchQueue`.
    private func trimLogs() {
        if logs.count > storedMaxLogs {
            logs.removeLast(logs.count - storedMaxLogs)
        }
    }

    private func buildLogData(message: String? = nil,
                              extraMessages: [LBExtraMessage]? = nil,
                              additionalInfo: [String: LBValue]? = nil,
                              error: Error? = nil,
                              level: LBLogLevel,
                              file: String,
                              function: String,
                              line: Int,
                              redactor: LBRedactor) -> LBLog {

        let errorData: LBError? = errorToLBError(error, redactor: redactor) ?? nil

        let log = LBLog(
            level: level,
            message: message,
            extraMessages: redactor.redact(extraMessages),
            additionalInfo: redactor.redact(additionalInfo),
            error: errorData,
            createdAt: Date().timeIntervalSince1970,
            location: LBLocation(file: file, function: function, line: line),
            source: LBSource(subsystem: source.subsystem, category: source.category)
        )

        return log
    }

    private func errorToLBError(_ error: Error?, redactor: LBRedactor) -> LBError? {
        guard let error else { return nil }
        let nsError = error as NSError

        var userInfo = nsError.userInfo
        if let decodingError = error as? DecodingError {
            userInfo.merge(Self.contextInfo(for: decodingError)) { _, new in new }
        } else if let encodingError = error as? EncodingError {
            userInfo.merge(Self.contextInfo(for: encodingError)) { _, new in new }
        }

        // The extracted context replaces the bridged keys, which would stringify poorly.
        if error is DecodingError || error is EncodingError {
            userInfo.removeValue(forKey: "NSCodingPath")
            userInfo.removeValue(forKey: "NSDebugDescription")
        }

        let userInfoString = userInfo.isEmpty ? nil : userInfo.mapValues(Self.userInfoString(from:))

        return LBError(
            domain: nsError.domain,
            code: nsError.code,
            type: String(describing: Swift.type(of: error)),
            localizedDescription: nsError.localizedDescription,
            userInfo: redactor.redact(userInfoString)
        )
    }

    private static func contextInfo(for error: DecodingError) -> [String: Any] {
        var info: [String: Any] = [:]
        let context: DecodingError.Context

        switch error {
        case .typeMismatch(_, let errorContext),
             .valueNotFound(_, let errorContext),
             .dataCorrupted(let errorContext):
            context = errorContext
        case .keyNotFound(let codingKey, let errorContext):
            info["missingKey"] = codingKey.stringValue
            context = errorContext
        @unknown default:
            return info
        }

        info["codingPath"] = context.codingPath.map(\.stringValue).joined(separator: ".")
        info["debugDescription"] = context.debugDescription
        if let underlyingError = context.underlyingError {
            info["underlyingError"] = underlyingError
        }
        return info
    }

    private static func contextInfo(for error: EncodingError) -> [String: Any] {
        switch error {
        case .invalidValue(_, let context):
            var info: [String: Any] = [
                "codingPath": context.codingPath.map(\.stringValue).joined(separator: "."),
                "debugDescription": context.debugDescription
            ]
            if let underlyingError = context.underlyingError {
                info["underlyingError"] = underlyingError
            }
            return info
        @unknown default:
            return [:]
        }
    }

    /// Converts a `userInfo` value into a readable string. Objects without a
    /// meaningful description are replaced by a placeholder instead of the
    /// default `<ClassName: 0x...>` representation.
    static func userInfoString(from value: Any) -> String {
        switch value {
        case let string as String:
            return string
        case let error as NSError:
            return "\(error.domain) (\(error.code)): \(error.localizedDescription)"
        case let url as URL:
            return url.absoluteString
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return number.boolValue ? "true" : "false"
            }
            return number.stringValue
        default:
            let description = String(describing: value)
            // The default NSObject description carries no information (`<ClassName: 0x...>`).
            if description.hasPrefix("<"), description.contains(": 0x") {
                return "<non-string>"
            }
            return description
        }
    }

    static func formattedMessage(for log: LBLog, identifier: String?) -> String {
        var logMessage: String = ""
        let spacing: String = "    "

        // Header
        var header: String = "\(log.level.emoji) \(log.level.rawValue.uppercased()) LogBird: \n"
        if let identifier {
            header = "\(identifier) \(header)"
        }

        logMessage = "\(logMessage)\(header)"

        // Created At
        let createdAt: String = "Created at:\n\(spacing)\(LBManager.dateStyle.format(Date(timeIntervalSince1970: log.createdAt)))\n"
        logMessage = "\(logMessage)\(createdAt)"

        // Message
        if let message = log.message {
            let info: String = "Message:\n\(spacing)\(message)\n"
            logMessage = "\(logMessage)\(info)"
        }

        // Extra Messages
        if let extraMessages = log.extraMessages {
            for extraMessage in extraMessages {
                let message: String = "\(extraMessage.key):\n\(spacing)\(extraMessage.value)\n"
                logMessage = "\(logMessage)\(message)"
            }
        }

        // Additional Info
        if let additionalInfo = log.additionalInfo {
            var info: String = "Additional Info:\n"
            for key in additionalInfo.keys.sorted() {
                if let value = additionalInfo[key] {
                    info = "\(info)\(spacing) \(key): \(value)\n"
                }
            }
            logMessage = "\(logMessage)\(info)"
        }

        // Error
        if let error = log.error {
            let domain: String = "Domain: \(error.domain)\n"
            let code: String = "Code: \(error.code)\n"
            let type: String = "Type: \(error.type)\n"
            var userInfoString: String = ""

            if let userInfo = error.userInfo {
                userInfoString = "User Info:\n"
                for key in userInfo.keys.sorted() {
                    if let value = userInfo[key] {
                        userInfoString = "\(userInfoString)\(spacing)\(spacing)\(key): \(value)\n"
                    }
                }
            }

            var errorString: String = "Error:\n\(spacing)\(type)\(spacing)\(domain)\(spacing)\(code)"
            if !userInfoString.isEmpty {
                errorString = "\(errorString)\(spacing)\(userInfoString)"
            }

            logMessage = "\(logMessage)\(errorString)"
        }

        // Source
        let subsystem: String = "Subsystem: \(log.source.subsystem)\n"
        let category: String = "Category: \(log.source.category)\n"
        let source: String = "Source: \n\(spacing)\(subsystem)\(spacing)\(category)"
        logMessage = "\(logMessage)\(source)"

        // Location
        let file: String = "File: \(log.location.fileName)\n"
        let function: String = "Function: \(log.location.function)\n"
        let line: String = "Line: \(log.location.line)\n"
        let location: String = "Location:\n\(spacing)\(file)\(spacing)\(function)\(spacing)\(line)"
        logMessage = "\(logMessage)\(location)"

        return logMessage
    }
}
