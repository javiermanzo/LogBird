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

    static let fileName = "logbird-logs.json"

    static func writeTemporaryFile(data: Data) -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("logbird-logs-\(UUID().uuidString).json")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    #if os(macOS)
    @MainActor
    static func presentSavePanel(data: Data) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = fileName
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? data.write(to: url)
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
