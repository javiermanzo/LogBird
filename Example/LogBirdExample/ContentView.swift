//
//  ContentView.swift
//  LogBirdExample
//
//  Created by Javier Manzo on 13/11/2024.
//

import SwiftUI
import LogBird
import OSLog

struct ContentView: View {

    let email = "javier.r.manzo@gmail.com"

    init() {
        let value = "asddasdasd"
        LogBird.setIdentifier("🔥")
        let someError = NSError(domain: "com.harbor.error", code: 500, userInfo: [NSLocalizedDescriptionKey: "Unknown error"])

        for level in LBLogLevel.allCases {
            LogBird.log("HOOLLLAAA ", additionalInfo: ["test":"value"], error: someError, level: level)
        }

        let customLogger = LogBird(subsystem: "com.custom", category: "general")
        customLogger.setIdentifier("🏀")
        for level in LBLogLevel.allCases {
            customLogger.log("HOOLLLAAA", additionalInfo: ["test":"value"], level: level)
        }


        customLogger.log("My email is \(email)")
    }
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}

