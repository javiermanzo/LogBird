//
//  LBExtraMessage.swift
//  LogBird
//
//  Created by Javier Manzo on 30/07/2026.
//

import Foundation

/// A labeled string shown as its own section within a log entry.
public struct LBExtraMessage: Codable, Identifiable, Sendable {
    /// Stable unique identifier for list rendering.
    public let id: UUID
    /// Section label.
    public let key: String
    /// Section contents.
    public let value: String

    /// Creates a sectioned extra message entry.
    ///
    /// - Parameters:
    ///   - id: `UUID` — Unique section identifier. Defaults to a fresh UUID.
    ///   - key: `String` — Section label header.
    ///   - value: `String` — Section body content.
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
