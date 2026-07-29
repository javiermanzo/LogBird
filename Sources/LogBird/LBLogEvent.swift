//
//  LBLogEvent.swift
//  LogBird
//
//  Created by Javier Manzo on 29/07/2026.
//

import Foundation

/// An event in the recorded log history.
public enum LBLogEvent: Equatable, Sendable {
    /// A new entry was recorded.
    case recorded(LBLog)
    /// The recorded history was emptied.
    case cleared
}
