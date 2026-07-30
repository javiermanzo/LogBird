//
//  LBError.swift
//  LogBird
//
//  Created by Javier Manzo on 30/07/2026.
//

import Foundation

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

    package init(domain: String, code: Int, type: String, localizedDescription: String, userInfo: [String: String]? = nil) {
        self.domain = domain
        self.code = code
        self.type = type
        self.localizedDescription = localizedDescription
        self.userInfo = userInfo
    }
}
