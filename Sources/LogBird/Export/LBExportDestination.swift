//
//  LBExportDestination.swift
//  LogBird
//
//  Created by Javier Manzo on 30/07/2026.
//

import Foundation

/// Where an export is delivered.
public enum LBExportDestination: Sendable {
    /// The encoded logs are only returned in `LBExportOutput.data`; nothing
    /// is written.
    case data
    /// The encoded logs are also written atomically. A `nil` URL writes to a
    /// temporary file named `logbird-logs-<timestamp>.<ext>`; the resulting
    /// location is reported in `LBExportOutput.fileURL`.
    case file(URL?)
}
