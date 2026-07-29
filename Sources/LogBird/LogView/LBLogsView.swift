//
//  LBLogsView.swift
//  LogBird
//
//  Created by Javier Manzo on 16/11/2024.
//

import SwiftUI

/// SwiftUI view that lists the recorded history, with search, level filter,
/// export and clear actions.
///
/// The view observes `logsPublisher` through an internal view model, so it
/// updates as new entries are recorded. By default it backs onto `LogBird.shared`;
/// pass a custom instance to `init(logBird:)` to scope it differently.
@MainActor
public struct LBLogsView: View {

    @StateObject private var viewModel: LogsViewModel

    @State private var exportError: String?

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
        if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) {
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
        #if os(iOS) || os(macOS)
        .toolbar {
            toolbarContent
        }
        #endif
        #if os(iOS)
        .sheet(item: $exportFile) { file in
            LBActivityView(activityItems: [file.url])
        }
        #endif
        .alert("Export Failed", isPresented: exportErrorPresented, presenting: exportError) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error)
        }
    }

    private var exportErrorPresented: Binding<Bool> {
        Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )
    }

    #if os(iOS) || os(macOS)
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

                Menu {
                    ForEach(LBExportFormat.allCases, id: \.self) { format in
                        Button(format.menuTitle) {
                            exportLogs(format: format)
                        }
                    }
                } label: {
                    Label(exportMenuTitle, systemImage: "square.and.arrow.up")
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

    /// The export covers what the list currently shows; the title says so when
    /// a search query or level filter narrows the visible entries.
    private var exportMenuTitle: String {
        guard viewModel.isFiltering else { return "Export Logs" }
        let count = viewModel.filteredLogs.count
        return count == 1 ? "Export 1 Filtered Log" : "Export \(count) Filtered Logs"
    }

    private func exportLogs(format: LBExportFormat) {
        do {
            let data = try viewModel.exportData(format: format)
            #if os(iOS)
            exportFile = ExportFile(url: try LBLogExport.writeTemporaryFile(data: data, format: format))
            #elseif os(macOS)
            LBLogExport.presentSavePanel(data: data, format: format) { error in
                exportError = error.localizedDescription
            }
            #endif
        } catch {
            exportError = error.localizedDescription
        }
    }
    #endif
}

private extension LBExportFormat {
    var menuTitle: String {
        switch self {
        case .json: return "JSON"
        case .jsonLines: return "JSON Lines"
        case .plainText: return "Plain Text"
        }
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
