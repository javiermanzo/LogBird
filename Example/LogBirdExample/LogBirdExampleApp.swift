//
//  LogBirdExampleApp.swift
//  LogBirdExample
//
//  Created by Javier Manzo on 13/11/2024.
//

import SwiftUI
import LogBird

@main
struct LogBirdExampleApp: App {

    init() {
        let extraMessages: [LBExtraMessage] = [
            LBExtraMessage(title: "Title Extra", message: "Message extra")
        ]

        for level in LBLogLevel.allCases {
            LogBird.log("Log Message with extra messages", extraMessages: extraMessages, additionalInfo: ["test":"value"], level: level)
        }

        let someError = NSError(domain: "com.myapp.error", code: 500, userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
        LogBird.log("Log Error", error: someError, level: .error)

        LogBird.setIdentifier("🏀")
        LogBird.log("Log With Console Identifier")
    }

    var body: some Scene {
        WindowGroup {
            LBLogsView()
        }
    }
}
