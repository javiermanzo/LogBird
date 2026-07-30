//
//  LBExportFile.swift
//  LogBird
//
//  Created by Javier Manzo on 30/07/2026.
//

import Foundation

/// Naming and temporary-location helpers for exported log files.
public enum LBExportFile {

    /// A readable, sortable name such as `logbird-logs-20260729-143052.json`.
    public static func fileName(for format: LBExportFormat, date: Date = Date()) -> String {
        "\(timestampBase(for: date)).\(format.fileExtension)"
    }

    /// A unique URL inside the temporary directory for the given format.
    static func temporaryURL(for format: LBExportFormat) -> URL {
        let directory = FileManager.default.temporaryDirectory
        let base = timestampBase(for: Date())
        var name = "\(base).\(format.fileExtension)"
        var copy = 2
        while FileManager.default.fileExists(atPath: directory.appendingPathComponent(name).path) {
            name = "\(base)-\(copy).\(format.fileExtension)"
            copy += 1
        }
        return directory.appendingPathComponent(name)
    }

    private static func timestampBase(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "logbird-logs-\(formatter.string(from: date))"
    }
}
