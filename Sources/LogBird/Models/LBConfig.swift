//
//  LBConfig.swift
//  LogBird
//
//  Created by Javier Manzo on 01/08/2026.
//

import Foundation

/// State tracking whether sensitive keys inherit global defaults or use an explicit custom set.
public enum LBSensitiveKeysState: Hashable, Sendable {
    /// Inherits global default sensitive key patterns plus optional custom additions.
    case inheritingDefaults(custom: Set<String>)

    /// Custom explicit override set (bypasses global defaults).
    case explicit(Set<String>)
}

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

    /// Internal state tracking sensitive keys mode.
    private var sensitiveKeysState: LBSensitiveKeysState

    /// Key patterns matched when redacting sensitive fields on this logger instance.
    public var sensitiveKeys: Set<String> {
        get {
            switch sensitiveKeysState {
            case .inheritingDefaults(let custom):
                return LBRedactor.globalDefaultSensitiveKeys.union(custom)
            case .explicit(let explicitSet):
                return explicitSet
            }
        }
        set {
            self.sensitiveKeysState = .explicit(Set(newValue.map(LBRedactor.normalize).filter { !$0.isEmpty }))
        }
    }

    /// Optional identifier prepended to each OSLog line.
    public var identifier: String?

    /// Creates a configuration instance with sensible defaults.
    ///
    /// - Parameters:
    ///   - maxLogs: `Int` — Maximum history entries kept in memory. Defaults to `1000`.
    ///   - isEnabled: `Bool` — Whether recording starts active. Defaults to `true` under `DEBUG`, `false` otherwise.
    ///   - minLogLevel: `LBLogLevel` — Minimum severity recorded. Defaults to `.debug`.
    ///   - redactSensitiveFields: `Bool` — Whether to redact sensitive fields. Defaults to `true`.
    ///   - sensitiveKeys: `[String]?` — Custom key patterns considered sensitive. Pass `nil` to inherit global defaults.
    ///   - identifier: `String?` — Optional header identifier string. Defaults to `nil`.
    public init(
        maxLogs: Int = 1000,
        isEnabled: Bool = {
            #if DEBUG
            return true
            #else
            return false
            #endif
        }(),
        minLogLevel: LBLogLevel = .debug,
        redactSensitiveFields: Bool = true,
        sensitiveKeys: [String]? = nil,
        identifier: String? = nil
    ) {
        self.maxLogs = max(0, maxLogs)
        self.isEnabled = isEnabled
        self.minLogLevel = minLogLevel
        self.redactSensitiveFields = redactSensitiveFields
        if let customKeys = sensitiveKeys {
            self.sensitiveKeysState = .explicit(Set(customKeys.map(LBRedactor.normalize).filter { !$0.isEmpty }))
        } else {
            self.sensitiveKeysState = .inheritingDefaults(custom: [])
        }
        self.identifier = identifier
    }

    /// Reconfigures sensitive keys using the specified action.
    ///
    /// - Parameter action: `LBSensitiveKeysAction` — `.add(keys)`, `.set(keys)`, `.reset`, or `.clear`.
    public mutating func sensitiveKeys(_ action: LBSensitiveKeysAction) {
        switch action {
        case .add(let keys):
            let normalizedNew = Set(keys.map(LBRedactor.normalize).filter { !$0.isEmpty })
            switch sensitiveKeysState {
            case .inheritingDefaults(let custom):
                self.sensitiveKeysState = .inheritingDefaults(custom: custom.union(normalizedNew))
            case .explicit(let current):
                self.sensitiveKeysState = .explicit(current.union(normalizedNew))
            }
        case .set(let keys):
            let normalizedKeys = Set(keys.map(LBRedactor.normalize).filter { !$0.isEmpty })
            self.sensitiveKeysState = .explicit(normalizedKeys)
        case .reset:
            self.sensitiveKeysState = .inheritingDefaults(custom: [])
        case .clear:
            self.sensitiveKeysState = .explicit([])
        }
    }
}
