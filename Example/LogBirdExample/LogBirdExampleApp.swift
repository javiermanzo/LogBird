//
//  LogBirdExampleApp.swift
//  LogBirdExample
//
//  Created by Javier Manzo on 13/11/2024.
//

import SwiftUI
import LogBird
import LogBirdUI

@main
struct LogBirdExampleApp: App {

    init() {
        LogBird.clearLogs()

        let extraMessages: [LBExtraMessage] = [
            LBExtraMessage(key: "Extra key", value: "Extra value")
        ]

        for level in LBLogLevel.allCases {
            LogBird.log("Log Message with extra messages", extraMessages: extraMessages, additionalInfo: ["test":"value"], level: level)
        }

        let someError = NSError(domain: "com.myapp.error", code: 500, userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
        LogBird.log("Log Error", error: someError, level: .error)

        LogBird.identifier = "🏀"
        LogBird.log("Log With Console Identifier")
    }

    var body: some Scene {
        WindowGroup {
            LBLogsView()
        }
    }
}
