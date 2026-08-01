//
//  LBConfig.swift
//  LogBird
//
//  Created by Javier Manzo on 01/08/2026.
//

import Foundation

/// Centralized configuration shaping a `LogBird` logger instance.
public struct LBConfig: Hashable, Sendable {

    /// The maximum number of history entries kept in memory. Once the limit is reached,
    /// the oldest entries are discarded. `0` disables history retention.
    public var maxLogs: Int {
        didSet { maxLogs = max(0, maxLogs) }
    }

    /// Whether recording is active. When `false`, `log(...)` is a no-op.
    public var isEnabled: Bool

    /// Minimum severity recorded. Entries below this threshold are dropped.
    public var minLogLevel: LBLogLevel

    /// Whether values under sensitive keys are redacted before storing.
    public var redactSensitiveFields: Bool

    /// Key patterns matched when redacting sensitive fields.
    public var sensitiveKeys: Set<String> {
        didSet {
            sensitiveKeys = Set(sensitiveKeys.map(LBRedactor.normalize).filter { !$0.isEmpty })
        }
    }

    /// Optional identifier prepended to each OSLog line.
    public var identifier: String?

    /// Creates a configuration instance with sensible defaults.
    ///
    /// - Parameters:
    ///   - maxLogs: `Int` — Maximum history entries kept in memory. Defaults to `1000`.
    ///   - isEnabled: `Bool` — Whether recording starts active. Defaults to `LogBird.defaultIsEnabled`.
    ///   - minLogLevel: `LBLogLevel` — Minimum severity recorded. Defaults to `.debug`.
    ///   - redactSensitiveFields: `Bool` — Whether to redact sensitive fields. Defaults to `true`.
    ///   - sensitiveKeys: `Set<String>` — Key patterns considered sensitive. Defaults to `LogBird.defaultSensitiveKeys`.
    ///   - identifier: `String?` — Optional header identifier string. Defaults to `nil`.
    public init(
        maxLogs: Int = 1000,
        isEnabled: Bool = LogBird.defaultIsEnabled,
        minLogLevel: LBLogLevel = .debug,
        redactSensitiveFields: Bool = true,
        sensitiveKeys: Set<String> = LogBird.defaultSensitiveKeys,
        identifier: String? = nil
    ) {
        self.maxLogs = max(0, maxLogs)
        self.isEnabled = isEnabled
        self.minLogLevel = minLogLevel
        self.redactSensitiveFields = redactSensitiveFields
        self.sensitiveKeys = Set(sensitiveKeys.map(LBRedactor.normalize).filter { !$0.isEmpty })
        self.identifier = identifier
    }

    /// Reconfigures sensitive keys using the specified action.
    ///
    /// - Parameter action: `LBSensitiveKeysAction` — `.set(keys)`, `.add(keys)`, `.default`, or `.clear`.
    public mutating func sensitiveKeys(_ action: LBSensitiveKeysAction) {
        switch action {
        case .set(let keys):
            self.sensitiveKeys = keys
        case .add(let keys):
            self.sensitiveKeys.formUnion(keys)
        case .default(let keys):
            self.sensitiveKeys = keys
        case .clear:
            self.sensitiveKeys.removeAll()
        }
    }
}
