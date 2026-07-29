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
    public let id: String
    public let level: LBLogLevel
    public let message: String?
    public let extraMessages: [LBExtraMessage]?
    public let additionalInfo: [String: LBValue]?
    public let error: LBError?
    public let createdAt: Double
    public let location: LBLocation
    public let source: LBSource

    init(
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

public struct LBSource: Codable, Hashable, Sendable {
    public let subsystem: String
    public let category: String

    init(subsystem: String, category: String) {
        self.subsystem = subsystem
        self.category = category
    }
}

public struct LBLocation: Codable, Hashable, Sendable {
    public let file: String
    public let function: String
    public let line: Int

    init(file: String, function: String, line: Int) {
        self.file = file
        self.function = function
        self.line = line
    }

    /// The file name component of `file`, without the module path that `#fileID` includes.
    public var fileName: String {
        file.split(separator: "/").last.map(String.init) ?? file
    }
}

public struct LBError: Codable, Hashable, Sendable {
    public let domain: String
    public let code: Int
    public let type: String
    public let localizedDescription: String
    public let userInfo: [String: String]?

    init(domain: String, code: Int, type: String, localizedDescription: String, userInfo: [String: String]? = nil) {
        self.domain = domain
        self.code = code
        self.type = type
        self.localizedDescription = localizedDescription
        self.userInfo = userInfo
    }
}

public struct LBExtraMessage: Codable, Identifiable, Sendable {
    public let id: UUID
    public let key: String
    public let value: String

    public init(id: UUID = UUID(), key: String, value: String) {
        self.id = id
        self.key = key
        self.value = value
    }
}

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

public extension LBLog {
    private static let prettyJSONEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    /// Returns a deterministic, pretty-printed JSON representation of the log.
    func prettyJSON() throws -> String {
        let data = try Self.prettyJSONEncoder.encode(self)
        return String(decoding: data, as: UTF8.self)
    }
}
