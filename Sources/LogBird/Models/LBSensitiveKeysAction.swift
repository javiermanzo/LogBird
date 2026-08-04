//
//  LBSensitiveKeysAction.swift
//  LogBird
//
//  Created by Javier Manzo on 01/08/2026.
//

import Foundation

/// Action used to configure sensitive key patterns for automatic field redaction on a logger instance.
public enum LBSensitiveKeysAction: Hashable, Sendable {

    /// Adds specified key patterns to the existing sensitive keys of this logger instance
    /// while preserving inherited global defaults.
    case add([String])

    /// Replaces sensitive key patterns for this logger instance with the specified array,
    /// bypassing global defaults for this instance.
    case set([String])

    /// Resets sensitive key patterns for this logger instance back to pure global defaults.
    case reset

    /// Clears all sensitive key patterns for this logger instance so no key-based redaction is performed.
    case clear
}
