//
//  LogsViewModel.swift
//  LogBirdExample
//
//  Created by Javier Manzo on 16/11/2024.
//

import Foundation
import Combine
import LogBird

class LogsViewModel: ObservableObject {

    @Published var logs: [LBLog] = []

    private var subscribers = Set<AnyCancellable>()
    private let logBird: LogBird
    private var timer: AnyCancellable?

    init(logBird: LogBird = LogBird.shared) {
        self.logBird = logBird
    }

    func startLogging() {
        logBird.logsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newLogs in
                self?.logs = newLogs
            }
            .store(in: &subscribers)
    }

    deinit {
        timer?.cancel()
    }
}
