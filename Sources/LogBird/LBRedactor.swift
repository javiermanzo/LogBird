//
//  LBRedactor.swift
//  LogBird
//
//  Created by Javier Manzo on 29/07/2026.
//

import Foundation

/// Replaces values under sensitive keys with a fixed placeholder.
///
/// A key is sensitive when it contains any of the configured keys. Matching is
/// case-insensitive and ignores underscores, hyphens and whitespace, so
/// `accessToken`, `access-token` and `ACCESS_TOKEN` all match `token`.
struct LBRedactor: Sendable {

    static let placeholder = "<redacted>"

    static let defaultSensitiveKeys = ["password", "token", "authorization", "secret", "apiKey", "cookie"]

    let isEnabled: Bool
    private let needles: [String]

    init(isEnabled: Bool, sensitiveKeys: [String]) {
        self.isEnabled = isEnabled
        self.needles = sensitiveKeys.map(Self.normalize).filter { !$0.isEmpty }
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

    func redact(_ extraMessages: [LBExtraMessage]?) -> [LBExtraMessage]? {
        guard let extraMessages, isEnabled else { return extraMessages }
        return extraMessages.map { message in
            guard isSensitive(message.key) else { return message }
            return LBExtraMessage(id: message.id, key: message.key, value: Self.placeholder)
        }
    }

    private func isSensitive(_ key: String) -> Bool {
        let key = Self.normalize(key)
        return needles.contains { key.contains($0) }
    }

    /// Lowercases and strips separators, so written variants of the same key
    /// (`api_key`, `x-api-key`, `API KEY`) compare equal.
    private static func normalize(_ key: String) -> String {
        key.lowercased().filter { $0 != "_" && $0 != "-" && !$0.isWhitespace }
    }
}
