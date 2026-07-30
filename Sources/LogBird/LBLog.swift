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

    /// Creates an entry. `id` defaults to a fresh UUID string; the other
    /// parameters map one-to-one to the stored properties.
    public init(
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

/// The OSLog subsystem and category an entry was recorded under.
public struct LBSource: Codable, Hashable, Sendable {
    /// Reverse-DNS identifier used by OSLog (e.g. `com.example.myapp`).
    public let subsystem: String
    /// OSLog category used to scope entries in Console.app.
    public let category: String

    public init(subsystem: String, category: String) {
        self.subsystem = subsystem
        self.category = category
    }
}

/// The source location where an entry was recorded.
public struct LBLocation: Codable, Hashable, Sendable {
    /// `#fileID` value at the call site (module/file path).
    public let file: String
    /// `#function` value at the call site.
    public let function: String
    /// `#line` value at the call site.
    public let line: Int

    public init(file: String, function: String, line: Int) {
        self.file = file
        self.function = function
        self.line = line
    }

    /// The file name component of `file`, without the module path that `#fileID` includes.
    public var fileName: String {
        file.split(separator: "/").last.map(String.init) ?? file
    }
}

/// Captured details of an `Error` recorded with a log entry.
public struct LBError: Codable, Hashable, Sendable {
    /// `NSError.domain` of the captured error.
    public let domain: String
    /// `NSError.code` of the captured error.
    public let code: Int
    /// Concrete Swift type of the captured error.
    public let type: String
    /// `localizedDescription` of the captured error.
    public let localizedDescription: String
    /// Stringified `userInfo`, with decoding/encoding context merged in for
    /// `DecodingError` / `EncodingError`. `nil` when empty.
    public let userInfo: [String: String]?

    public init(domain: String, code: Int, type: String, localizedDescription: String, userInfo: [String: String]? = nil) {
        self.domain = domain
        self.code = code
        self.type = type
        self.localizedDescription = localizedDescription
        self.userInfo = userInfo
    }
}

/// A labeled string shown as its own section within a log entry.
public struct LBExtraMessage: Codable, Identifiable, Sendable {
    /// Stable unique identifier for list rendering.
    public let id: UUID
    /// Section label.
    public let key: String
    /// Section contents.
    public let value: String

    /// Creates an extra message. `id` defaults to a fresh UUID.
    public init(id: UUID = UUID(), key: String, value: String) {
        self.id = id
        self.key = key
        self.value = value
    }
}

// MARK: Hashable
extension LBExtraMessage: Hashable {
    /// Equality and hashing are content-based; `id` only gives each instance a
    /// unique identity for list rendering.
    public static func == (lhs: LBExtraMessage, rhs: LBExtraMessage) -> Bool {
        lhs.key == rhs.key && lhs.value == rhs.value
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(key)
        hasher.combine(value)
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
