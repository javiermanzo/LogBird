//
//  LogsViewModel.swift
//  LogBirdUI
//
//  Created by Javier Manzo on 16/11/2024.
//

import Foundation
import Combine
import LogBird

@MainActor
final class LogsViewModel: ObservableObject {

    @Published var logs: [LBLog] = []
    @Published var searchText: String = ""
    @Published var levelFilter: LBLogLevel?

    private let logBird: LogBird
    private var logsCancellable: AnyCancellable?
    private var logIDs: Set<String> = []

    init(logBird: LogBird = LogBird.shared) {
        self.logBird = logBird
        subscribeToLogs()
        logs = Array(logBird.logs.reversed())
        logIDs = Set(logs.map(\.id))
    }

    var filteredLogs: [LBLog] {
        logs.filter { log in
            matchesLevelFilter(log) && matchesSearchText(log)
        }
    }

    /// Whether the visible logs are narrowed by a search query or a level filter.
    var isFiltering: Bool {
        levelFilter != nil || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func clearLogs() {
        logBird.clearLogs()
        logs = []
        logIDs = []
    }

    func exportData(format: LBExportFormat = .json) throws -> Data {
        try LBLogExporter.data(for: filteredLogs, format: format, identifier: logBird.currentIdentifier)
    }

    private func subscribeToLogs() {
        logsCancellable = logBird.logsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                // Delivery is on the main queue, so the main actor hop is guaranteed.
                MainActor.assumeIsolated {
                    self?.handle(event)
                }
            }
    }

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

    private func matchesLevelFilter(_ log: LBLog) -> Bool {
        guard let levelFilter else { return true }
        return log.level == levelFilter
    }

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
