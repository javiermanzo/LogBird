//
//  LBLogExporter.swift
//  LogBird
//
//  Created by Javier Manzo on 28/07/2026.
//

import Foundation

public enum LBLogExporter {

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
    public static func data(for logs: [LBLog], format: LBExportFormat, identifier: String? = nil) throws -> Data {
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
}
