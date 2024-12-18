//
//  LBLogsView.swift
//  LogBird
//
//  Created by Javier Manzo on 16/11/2024.
//

import SwiftUI

public struct LBLogsView: View {
    
    @StateObject private var viewModel: LogsViewModel
    
    public init(logBird: LogBird = LogBird.shared) {
        _viewModel = StateObject(wrappedValue: LogsViewModel(logBird: logBird))
    }
    
    public var body: some View {
        NavigationView {
            VStack {
                List(viewModel.logs) { log in
                    LogRowView(log: log)
                }
                .listStyle(PlainListStyle())
                .onAppear {
                    viewModel.startLogging()
                }
            }
            .navigationTitle("Logs")
        }
    }
}
