//
//  LogsViewModel.swift
//  LogBirdUI
//
//  Created by Javier Manzo on 16/11/2024.
//

import Foundation
import Combine
import LogBird

/// View model behind `LBLogsView`: mirrors the recorded history (newest
/// first), applies the search query and level filter, and forwards actions
/// (clear, export) to the backing `LogBird` instance.
@MainActor
final class LogsViewModel: ObservableObject {

    /// The mirrored history, newest first, capped at `maxLogs`.
    @Published var logs: [LBLog] = []
    /// The current search query; matched against message, metadata, error,
    /// source and location fields.
    @Published var searchText: String = ""
    /// The selected level filter, or `nil` to show all levels.
    @Published var levelFilter: LBLogLevel?

    private let logBird: LogBird
    private var logsCancellable: AnyCancellable?
    private var logIDs: Set<String> = []

    /// Creates a view model backed by `logBird`, seeding the current history
    /// and subscribing to new history events.
    init(logBird: LogBird = LogBird.shared) {
        self.logBird = logBird
        subscribeToLogs()
        logs = Array(logBird.logs.reversed())
        logIDs = Set(logs.map(\.id))
    }

    /// The entries matching the current level filter and search query.
    var filteredLogs: [LBLog] {
        logs.filter { log in
            matchesLevelFilter(log) && matchesSearchText(log)
        }
    }

    /// Whether the visible logs are narrowed by a search query or a level filter.
    var isFiltering: Bool {
        levelFilter != nil || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Empties the history on the backing `LogBird` and the local mirror.
    func clearLogs() {
        logBird.clearLogs()
        logs = []
        logIDs = []
    }

    /// Encodes `filteredLogs` in the given format — the export covers what the
    /// list currently shows, not the full history.
    func exportData(format: LBExportFormat = .json) throws -> Data {
        try logBird.export(.logs(filteredLogs), format: format).data
    }

    /// Subscribes to `logsPublisher`, redelivering events on the main actor.
    private func subscribeToLogs() {
        logsCancellable = logBird.logsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                Task { @MainActor [weak self] in
                    self?.handle(event)
                }
            }
    }

    /// Applies a history event to the mirrored logs, ignoring duplicate
    /// deliveries and keeping the mirror capped at `maxLogs`.
    func handle(_ event: LBLogEvent) {
        switch event {
        case .recorded(let log):
            let maxLogs = logBird.maxLogs
            guard maxLogs > 0 else {
                // Retention is disabled; the view mirrors the empty history.
                if !logs.isEmpty {
                    logs = []
                    logIDs = []
                }
                return
            }
            guard logIDs.insert(log.id).inserted else { return }
            logs.insert(log, at: 0)
            let overflow = logs.count - maxLogs
            if overflow > 0 {
                logIDs.subtract(logs.suffix(overflow).map(\.id))
                logs.removeLast(overflow)
            }
        case .cleared:
            logs = []
            logIDs = []
        }
    }

    /// Whether the log passes the selected level filter.
    private func matchesLevelFilter(_ log: LBLog) -> Bool {
        guard let levelFilter else { return true }
        return log.level == levelFilter
    }

    /// Whether the log contains the search query in its message, metadata,
    /// error, source or location fields. Matching is case-insensitive and
    /// ignores surrounding whitespace.
    private func matchesSearchText(_ log: LBLog) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }

        if let message = log.message, message.localizedCaseInsensitiveContains(query) {
            return true
        }

        if let extraMessages = log.extraMessages,
           extraMessages.contains(where: { $0.key.localizedCaseInsensitiveContains(query) || $0.value.localizedCaseInsensitiveContains(query) }) {
            return true
        }

        if let additionalInfo = log.additionalInfo,
           additionalInfo.contains(where: { $0.key.localizedCaseInsensitiveContains(query) || $0.value.description.localizedCaseInsensitiveContains(query) }) {
            return true
        }

        if let error = log.error,
           error.localizedDescription.localizedCaseInsensitiveContains(query)
            || error.domain.localizedCaseInsensitiveContains(query)
            || String(error.code).localizedCaseInsensitiveContains(query)
            || (error.userInfo?.contains(where: { $0.key.localizedCaseInsensitiveContains(query) || $0.value.localizedCaseInsensitiveContains(query) }) ?? false) {
            return true
        }

        if log.source.subsystem.localizedCaseInsensitiveContains(query)
            || log.source.category.localizedCaseInsensitiveContains(query) {
            return true
        }

        return log.location.file.localizedCaseInsensitiveContains(query)
    }
}
