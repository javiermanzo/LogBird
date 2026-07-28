//
//  LBLogExport.swift
//  LogBird
//
//  Created by Javier Manzo on 27/07/2026.
//

import Foundation
#if os(iOS)
import SwiftUI
import UIKit
#elseif os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

enum LBLogExport {

    static func fileName(for format: LBExportFormat) -> String {
        "logbird-logs.\(format.fileExtension)"
    }

    static func writeTemporaryFile(data: Data, format: LBExportFormat) -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("logbird-logs-\(UUID().uuidString).\(format.fileExtension)")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    #if os(macOS)
    @MainActor
    static func presentSavePanel(data: Data, format: LBExportFormat) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [contentType(for: format)]
        panel.nameFieldStringValue = fileName(for: format)
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? data.write(to: url, options: .atomic)
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
