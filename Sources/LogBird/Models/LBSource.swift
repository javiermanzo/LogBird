//
//  LBSource.swift
//  LogBird
//
//  Created by Javier Manzo on 30/07/2026.
//

import Foundation

/// The OSLog subsystem and category an entry was recorded under.
public struct LBSource: Codable, Hashable, Sendable {
    /// Reverse-DNS identifier used by OSLog (e.g. `com.example.myapp`).
    public let subsystem: String
    /// OSLog category used to scope entries in Console.app.
    public let category: String

    /// Creates a log source record.
    ///
    /// - Parameters:
    ///   - subsystem: `String` — Reverse-DNS subsystem identifier (e.g. `com.example.myapp`).
    ///   - category: `String` — OSLog category scoping entries in Console.app.
    package init(subsystem: String, category: String) {
        self.subsystem = subsystem
        self.category = category
    }
}
