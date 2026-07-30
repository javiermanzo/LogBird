//
//  LBLocation.swift
//  LogBird
//
//  Created by Javier Manzo on 30/07/2026.
//

import Foundation

/// The source location where an entry was recorded.
public struct LBLocation: Codable, Hashable, Sendable {
    /// `#fileID` value at the call site (module/file path).
    public let file: String
    /// `#function` value at the call site.
    public let function: String
    /// `#line` value at the call site.
    public let line: Int

    /// Creates a source location record.
    ///
    /// - Parameters:
    ///   - file: `String` — `#fileID` value at call site (module/file path).
    ///   - function: `String` — `#function` name at call site.
    ///   - line: `Int` — `#line` number at call site.
    package init(file: String, function: String, line: Int) {
        self.file = file
        self.function = function
        self.line = line
    }

    /// The file name component of `file`, without the module path that `#fileID` includes.
    public var fileName: String {
        file.split(separator: "/").last.map(String.init) ?? file
    }
}
