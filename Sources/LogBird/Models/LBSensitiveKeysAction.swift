//
//  LBSensitiveKeysAction.swift
//  LogBird
//
//  Created by Javier Manzo on 01/08/2026.
//

import Foundation

/// Action used to configure the sensitive key patterns for automatic field redaction.
public enum LBSensitiveKeysAction: Hashable, Sendable {
    /// Replaces all sensitive key patterns with the specified set.
    case set(Set<String>)

    /// Adds the specified key patterns to the existing set of sensitive keys.
    case add(Set<String>)

    /// Resets sensitive key patterns to default needles (or a custom default set).
    case `default`(Set<String>)

    /// Clears all sensitive keys so no key-based redaction is performed.
    case clear

    /// Resets sensitive keys back to standard default curated needles.
    public static var `default`: LBSensitiveKeysAction {
        .default(LBRedactor.defaultSensitiveKeys)
    }
}

