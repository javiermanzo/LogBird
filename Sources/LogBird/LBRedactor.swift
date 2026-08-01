//
//  LBRedactor.swift
//  LogBird
//
//  Created by Javier Manzo on 29/07/2026.
//

import Foundation

/// Replaces values under sensitive keys with a fixed placeholder.
///
/// A key is sensitive when its normalized representation contains any of the
/// configured sensitive key needles. Normalization converts strings to lowercase
/// and strips hyphens (`-`), underscores (`_`), and whitespace characters. For example,
/// `accessToken`, `access-token`, `ACCESS_TOKEN`, and `Access Token` all normalize
/// to `accesstoken`, matching the needle `token`.
struct LBRedactor: Sendable {

    /// The string that replaces a redacted value.
    static let placeholder = "<redacted>"

    /// Keys matched by default when redacting sensitive fields.
    ///
    /// Includes curated needles: `"password"`, `"token"`, `"authorization"`, `"auth"`,
    /// `"secret"`, `"apiKey"`, `"cookie"`, `"bearer"`, `"credentials"`, and `"privateKey"`.
    ///
    /// Due to normalization (lowercasing and removal of `-`, `_`, and whitespace) and
    /// substring matching, variants like `access_token`, `refresh_token`, `set-cookie`,
    /// `x-api-key`, and `private_key` are automatically matched.
    static let defaultSensitiveKeys: Set<String> = [
        "password", "token", "authorization", "auth", "secret",
        "apiKey", "cookie", "bearer", "credentials", "privateKey"
    ]

    /// Whether redaction is applied; when `false`, values pass through unchanged.
    let isEnabled: Bool
    private let needles: Set<String>

    /// Creates a redactor instance.
    ///
    /// - Parameters:
    ///   - isEnabled: `Bool` — Whether sensitive field redaction is active.
    ///   - sensitiveKeys: `Set<String>` — Key substrings matched during redaction.
    init(isEnabled: Bool, sensitiveKeys: Set<String>) {
        self.isEnabled = isEnabled
        self.needles = Set(sensitiveKeys.map(Self.normalize).filter { !$0.isEmpty })
    }

    /// Replaces values under sensitive keys in `additionalInfo` metadata.
    /// Returns the input unchanged when redaction is disabled.
    func redact(_ info: [String: LBValue]?) -> [String: LBValue]? {
        guard let info, isEnabled else { return info }
        var redacted = info
        for key in info.keys where isSensitive(key) {
            redacted[key] = .string(Self.placeholder)
        }
        return redacted
    }

    /// Replaces values under sensitive keys in a stringified `userInfo`.
    /// Returns the input unchanged when redaction is disabled.
    func redact(_ userInfo: [String: String]?) -> [String: String]? {
        guard let userInfo, isEnabled else { return userInfo }
        var redacted = userInfo
        for key in userInfo.keys where isSensitive(key) {
            redacted[key] = Self.placeholder
        }
        return redacted
    }

    /// Replaces the value of every extra message whose key is sensitive.
    /// Returns the input unchanged when redaction is disabled.
    func redact(_ extraMessages: [LBExtraMessage]?) -> [LBExtraMessage]? {
        guard let extraMessages, isEnabled else { return extraMessages }
        return extraMessages.map { message in
            guard isSensitive(message.key) else { return message }
            return LBExtraMessage(id: message.id, key: message.key, value: Self.placeholder)
        }
    }

    /// Whether `key` contains any of the configured sensitive keys, compared
    /// after normalizing both sides.
    private func isSensitive(_ key: String) -> Bool {
        let key = Self.normalize(key)
        return needles.contains { key.contains($0) }
    }

    /// Lowercases and strips separators (`-`, `_`, whitespace), so written variants
    /// of the same key (`api_key`, `x-api-key`, `API KEY`) compare equal.
    private static func normalize(_ key: String) -> String {
        key.lowercased().filter { $0 != "_" && $0 != "-" && !$0.isWhitespace }
    }
}
