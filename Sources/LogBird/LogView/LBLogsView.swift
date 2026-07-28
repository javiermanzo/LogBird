//
//  LBLogsView.swift
//  LogBird
//
//  Created by Javier Manzo on 16/11/2024.
//

import SwiftUI

@MainActor
public struct LBLogsView: View {

    @StateObject private var viewModel: LogsViewModel

    #if os(iOS)
    @State private var exportFile: ExportFile?
    #endif

    /// Creates a logs view backed by the given `LogBird` instance.
    ///
    /// The instance is captured when the view is first created. Passing a
    /// different instance later does not replace the underlying view model.
    public init(logBird: LogBird = LogBird.shared) {
        _viewModel = StateObject(wrappedValue: LogsViewModel(logBird: logBird))
    }

    public var body: some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            NavigationStack {
                content
            }
        } else {
            NavigationView {
                content
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        List(viewModel.filteredLogs) { log in
            LBLogRowView(log: log)
        }
        .listStyle(.plain)
        .accessibilityLabel("Logs list")
        .accessibilityHint("Displays the recorded log entries")
        .searchable(text: $viewModel.searchText, prompt: "Search logs")
        .navigationTitle("Logs")
        .toolbar {
            toolbarContent
        }
        #if os(iOS)
        .sheet(item: $exportFile) { file in
            LBActivityView(activityItems: [file.url])
        }
        #endif
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Picker("Level", selection: $viewModel.levelFilter) {
                    Text("All levels").tag(LBLogLevel?.none)
                    ForEach(LBLogLevel.allCases, id: \.self) { level in
                        Label(level.rawValue.capitalized, systemImage: level.symbolName)
                            .tag(LBLogLevel?.some(level))
                    }
                }

                Divider()

                Button {
                    exportLogs()
                } label: {
                    Label("Export Logs", systemImage: "square.and.arrow.up")
                }

                Button(role: .destructive) {
                    viewModel.clearLogs()
                } label: {
                    Label("Clear Logs", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("Log options")
            .accessibilityHint("Filters, exports or clears the logs")
        }
    }

    private func exportLogs() {
        guard let data = viewModel.exportData() else { return }
        #if os(iOS)
        if let url = LBLogExport.writeTemporaryFile(data: data) {
            exportFile = ExportFile(url: url)
        }
        #elseif os(macOS)
        LBLogExport.presentSavePanel(data: data)
        #endif
    }
}

#if os(iOS)
private struct ExportFile: Identifiable {
    let id = UUID()
    let url: URL
}
#endif

#Preview("Light") {
    LBLogsView()
}

#Preview("Dark") {
    LBLogsView()
        .preferredColorScheme(.dark)
}
