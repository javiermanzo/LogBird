//
//  LBLogExporter.swift
//  LogBird
//
//  Created by Javier Manzo on 28/07/2026.
//

import Foundation

/// Encodes `[LBLog]` arrays into each `LBExportFormat`. Implementation detail
/// behind `LogBird.export(_:format:destination:)`.
enum LBLogExporter {

    // Shared across threads — do not mutate after initialization.
    private static let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    // Shared across threads — do not mutate after initialization.
    private static let jsonLinesEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    /// Encodes the given logs in the requested format.
    ///
    /// - Parameters:
    ///   - logs: `LBLog` entries to encode, in the order they should appear.
    ///   - format: `LBExportFormat` — encoding to use.
    ///   - identifier: `String?` — optional identifier prepended to each
    ///     entry in `.plainText`, mirroring the OSLog header.
    /// - Throws: `EncodingError` if a log value cannot be encoded (e.g. non-finite double).
    /// - Returns: `Data` containing the encoded logs.
    static func data(for logs: [LBLog], format: LBExportFormat, identifier: String? = nil) throws -> Data {
        switch format {
        case .json:
            return try jsonEncoder.encode(logs)
        case .jsonLines:
            let lines = try logs.map { log in
                String(decoding: try jsonLinesEncoder.encode(log), as: UTF8.self)
            }
            let text = lines.isEmpty ? "" : lines.joined(separator: "\n") + "\n"
            return Data(text.utf8)
        case .plainText:
            let text = logs
                .map { LBManager.formattedMessage(for: $0, identifier: identifier) }
                .joined(separator: "\n\n")
            return Data(text.utf8)
        }
    }

    /// A unique URL inside the temporary directory for the given format.
    static func temporaryURL(for format: LBExportFormat) -> URL {
        let directory = FileManager.default.temporaryDirectory
        let name = format.fileName()
        let base = (name as NSString).deletingPathExtension
        let ext = format.fileExtension
        var candidate = name
        var copy = 2
        while FileManager.default.fileExists(atPath: directory.appendingPathComponent(candidate).path) {
            candidate = "\(base)-\(copy).\(ext)"
            copy += 1
        }
        return directory.appendingPathComponent(candidate)
    }
}
