//
//  LBExportContent.swift
//  LogBird
//
//  Created by Javier Manzo on 30/07/2026.
//

import Foundation

/// The logs to include in an export.
public enum LBExportContent: Sendable {
    /// The recorded history, in recording order (oldest first).
    case all
    /// An arbitrary selection of entries, in the order they should appear —
    /// e.g. the result of filtering the history.
    case logs([LBLog])
}
