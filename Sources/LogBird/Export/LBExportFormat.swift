//
//  LBExportFormat.swift
//  LogBird
//
//  Created by Javier Manzo on 28/07/2026.
//

import Foundation

/// The available formats for exporting recorded logs.
public enum LBExportFormat: String, Codable, CaseIterable, Sendable {
    /// A single pretty-printed JSON array of `LBLog` entries.
    case json
    /// One compact JSON `LBLog` per line, for log ingestion tools.
    case jsonLines
    /// The same human-readable text that is sent to OSLog.
    case plainText

    public var fileExtension: String {
        switch self {
        case .json: return "json"
        case .jsonLines: return "jsonl"
        case .plainText: return "log"
        }
    }

    /// A readable, sortable file name for this format (e.g. `logbird-logs-20260729-143052.json`).
    public func suggestedFileName(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "logbird-logs-\(formatter.string(from: date)).\(fileExtension)"
    }
}
