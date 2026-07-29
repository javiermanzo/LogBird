//
//  LogsViewModel.swift
//  LogBird
//
//  Created by Javier Manzo on 16/11/2024.
//

import Foundation
import Combine

@MainActor
final class LogsViewModel: ObservableObject {

    @Published var logs: [LBLog] = []
    @Published var searchText: String = ""
    @Published var levelFilter: LBLogLevel?

    private let logBird: LogBird
    private var logsCancellable: AnyCancellable?

    init(logBird: LogBird = LogBird.shared) {
        self.logBird = logBird
        subscribeToLogs()
        logs = logBird.logs
    }

    var filteredLogs: [LBLog] {
        logs.filter { log in
            matchesLevelFilter(log) && matchesSearchText(log)
        }
    }

    func clearLogs() {
        logBird.clearLogs()
        logs = []
    }

    func exportData(format: LBExportFormat = .json) -> Data? {
        try? LBLogExporter.data(for: filteredLogs, format: format, identifier: logBird.currentIdentifier)
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
            guard !logs.contains(where: { $0.id == log.id }) else { return }
            logs.insert(log, at: 0)
            let overflow = logs.count - logBird.maxLogs
            if overflow > 0 {
                logs.removeLast(overflow)
            }
        case .cleared:
            logs = []
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
           extraMessages.contains(where: { $0.title.localizedCaseInsensitiveContains(query) || $0.message.localizedCaseInsensitiveContains(query) }) {
            return true
        }

        if let error = log.error, error.localizedDescription.localizedCaseInsensitiveContains(query) {
            return true
        }

        return log.location.file.localizedCaseInsensitiveContains(query)
    }
}
