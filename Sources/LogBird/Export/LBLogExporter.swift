//
//  LBLogExporter.swift
//  LogBird
//
//  Created by Javier Manzo on 28/07/2026.
//

import Foundation

enum LBLogExporter {

    private static let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let jsonLinesEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    static func data(for logs: [LBLog], format: LBExportFormat, identifier: String? = nil) -> Data {
        switch format {
        case .json:
            return (try? jsonEncoder.encode(logs)) ?? Data()
        case .jsonLines:
            let lines = logs.compactMap { log -> String? in
                (try? jsonLinesEncoder.encode(log)).map { String(decoding: $0, as: UTF8.self) }
            }
            return Data(lines.joined(separator: "\n").utf8)
        case .plainText:
            let text = logs
                .map { LBManager.formattedMessage(for: $0, identifier: identifier) }
                .joined(separator: "\n\n")
            return Data(text.utf8)
        }
    }
}
