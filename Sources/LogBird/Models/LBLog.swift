//
//  LBLog.swift
//  LogBird
//
//  Created by Javier Manzo on 16/11/2024.
//

import Foundation

/// A single recorded log entry.
///
/// Equality and hashing include `id`, so two entries are equal only when they
/// represent the same recorded log.
public struct LBLog: Codable, Identifiable, Hashable, Sendable {
    /// Stable unique identifier for the entry.
    public let id: String
    /// Severity of the entry.
    public let level: LBLogLevel
    /// Free-text message, if any.
    public let message: String?
    /// Labeled strings shown as separate sections, if any.
    public let extraMessages: [LBExtraMessage]?
    /// Typed metadata keyed by name, if any.
    public let additionalInfo: [String: LBValue]?
    /// Captured error details, if any.
    public let error: LBError?
    /// Creation time, as seconds since the Unix epoch.
    public let createdAt: Double
    /// Where the entry was recorded in source.
    public let location: LBLocation
    /// OSLog subsystem and category the entry was recorded under.
    public let source: LBSource

    /// Creates a recorded log entry.
    ///
    /// - Parameters:
    ///   - id: `String` — Unique entry identifier. Defaults to a fresh UUID string.
    ///   - level: `LBLogLevel` — Severity level of the entry.
    ///   - message: `String?` — Free-text message string, if any.
    ///   - extraMessages: `[LBExtraMessage]?` — Sectioned extra messages array, if any.
    ///   - additionalInfo: `[String: LBValue]?` — Typed metadata dictionary, if any.
    ///   - error: `LBError?` — Captured error details, if any.
    ///   - createdAt: `Double` — Creation timestamp in seconds since Unix epoch.
    ///   - location: `LBLocation` — Call-site source location record.
    ///   - source: `LBSource` — Subsystem and category source record.
    package init(
        id: String = UUID().uuidString,
        level: LBLogLevel,
        message: String? = nil,
        extraMessages: [LBExtraMessage]? = nil,
        additionalInfo: [String: LBValue]? = nil,
        error: LBError? = nil,
        createdAt: Double,
        location: LBLocation,
        source: LBSource
    ) {
        self.id = id
        self.level = level
        self.message = message
        self.extraMessages = extraMessages
        self.additionalInfo = additionalInfo
        self.error = error
        self.createdAt = createdAt
        self.location = location
        self.source = source
    }
}

// MARK: Encoding
public extension LBLog {

    /// Returns a deterministic, pretty-printed JSON representation of the log.
    func prettyJSON() throws -> String {
        let data = try Self.prettyJSONEncoder.encode(self)
        return String(decoding: data, as: UTF8.self)
    }

    /// ISO8601 date format used to render `createdAt` for display and OSLog
    /// output, including fractional seconds and the current time zone.
    static let dateFormatter: Date.ISO8601FormatStyle = {
        var style = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        style.timeZone = .current
        return style
    }()
}

// MARK: Private
private extension LBLog {

    static let prettyJSONEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
}
