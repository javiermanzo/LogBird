//
//  LBRedactor.swift
//  LogBird
//
//  Created by Javier Manzo on 29/07/2026.
//

import Foundation

/// Replaces values under sensitive keys with a fixed placeholder.
///
/// A key is sensitive when it contains any of the configured keys; matching is
/// case-insensitive and applies to both sides, so `accessToken` and
/// `AUTH_TOKEN` both match `token`.
struct LBRedactor: Sendable {

    static let placeholder = "<redacted>"

    static let defaultSensitiveKeys = ["password", "token", "authorization", "secret", "apiKey", "cookie"]

    let isEnabled: Bool
    private let needles: [String]

    init(isEnabled: Bool, sensitiveKeys: [String]) {
        self.isEnabled = isEnabled
        self.needles = sensitiveKeys.map { $0.lowercased() }
    }

    func redact(_ info: [String: LBValue]?) -> [String: LBValue]? {
        guard let info, isEnabled else { return info }
        var redacted = info
        for key in info.keys where isSensitive(key) {
            redacted[key] = .string(Self.placeholder)
        }
        return redacted
    }

    func redact(_ userInfo: [String: String]?) -> [String: String]? {
        guard let userInfo, isEnabled else { return userInfo }
        var redacted = userInfo
        for key in userInfo.keys where isSensitive(key) {
            redacted[key] = Self.placeholder
        }
        return redacted
    }

    private func isSensitive(_ key: String) -> Bool {
        let key = key.lowercased()
        return needles.contains { key.contains($0) }
    }
}
