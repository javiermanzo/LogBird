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
        LogBird.setIdentifier("🏀")
        for level in LBLogLevel.allCases {
            LogBird.log("Log Message", additionalInfo: ["test":"value"], level: level)
        }

        let someError = NSError(domain: "com.myapp.error", code: 500, userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
        LogBird.log("Log Error", error: someError, level: .error)
    }

    var body: some Scene {
        WindowGroup {
            LBLogsView()
        }
    }
}
