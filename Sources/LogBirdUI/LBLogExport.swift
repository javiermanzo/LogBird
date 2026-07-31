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

/// UI presentation helpers behind `LBLogsView` export flow: macOS save panel
/// and iOS activity view.
enum LBLogExport {

    #if os(macOS)
    /// Presents an `NSSavePanel` with a suggested file name for the format,
    /// invoking `onSave` with the selected `URL`. Write failures are reported
    /// through `onError`.
    @MainActor
    static func presentSavePanel(
        format: LBExportFormat,
        onSave: @escaping (URL) throws -> Void,
        onError: @escaping (Error) -> Void
    ) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [contentType(for: format)]
        panel.nameFieldStringValue = format.fileName()
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try onSave(url)
            } catch {
                onError(error)
            }
        }
    }

    /// The content type the save panel uses to filter and complete the file name.
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
/// Share sheet presenting the exported log file.
struct LBActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
