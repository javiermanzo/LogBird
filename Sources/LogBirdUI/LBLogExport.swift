//
//  LBLogExport.swift
//  LogBirdUI
//
//  Created by Javier Manzo on 27/07/2026.
//

import Foundation
import LogBird
#if os(iOS)
import SwiftUI
import UIKit
#elseif os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

enum LBLogExport {

    /// A readable, sortable name such as `logbird-logs-20260729-143052.json`.
    static func fileName(for format: LBExportFormat, date: Date = Date()) -> String {
        "\(timestampBase(for: date)).\(format.fileExtension)"
    }

    static func writeTemporaryFile(data: Data, format: LBExportFormat) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
        let base = timestampBase(for: Date())
        var name = "\(base).\(format.fileExtension)"
        var copy = 2
        while FileManager.default.fileExists(atPath: directory.appendingPathComponent(name).path) {
            name = "\(base)-\(copy).\(format.fileExtension)"
            copy += 1
        }
        let url = directory.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func timestampBase(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "logbird-logs-\(formatter.string(from: date))"
    }

    #if os(macOS)
    @MainActor
    static func presentSavePanel(data: Data, format: LBExportFormat, onError: @escaping (Error) -> Void) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [contentType(for: format)]
        panel.nameFieldStringValue = fileName(for: format)
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                onError(error)
            }
        }
    }

    private static func contentType(for format: LBExportFormat) -> UTType {
        switch format {
        case .json:
            return .json
        case .jsonLines:
            // No system type claims the .jsonl extension; declaring it as plain
            // text keeps the save panel from appending .txt to the file name.
            return UTType(filenameExtension: format.fileExtension, conformingTo: .plainText) ?? .plainText
        case .plainText:
            return .plainText
        }
    }
    #endif
}

#if os(iOS)
struct LBActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
