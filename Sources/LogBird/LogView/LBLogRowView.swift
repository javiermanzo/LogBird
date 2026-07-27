//
//  LBLogRowView.swift
//  LogBird
//
//  Created by Javier Manzo on 16/11/2024.
//

import SwiftUI

public struct LBLogRowView: View {
    public let log: LBLog

    public init(log: LBLog) {
        self.log = log
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            let date = LBManager.dateFormatter.string(from: Date(timeIntervalSince1970: log.createdAt))
            Header(createdAt: date, level: log.level)

            if let message = log.message, !message.isEmpty {
                Message(message)
            }

            if let extraMessages = log.extraMessages, !extraMessages.isEmpty {
                ExtraMessages(extraMessages)
            }

            if let error = log.error {
                LogError(error)
            }

            if let additionalInfo = log.additionalInfo, !additionalInfo.isEmpty {
                AdditionalInfo(additionalInfo)
            }

            Location(log.location)

            Source(log.source)
        }
        .padding()
        .background(log.level.color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rowAccessibilityLabel)
        .accessibilityHint("Shows the location and source details")
    }
}

private extension LBLogRowView {
    var rowAccessibilityLabel: String {
        var label = "\(log.level.rawValue.capitalized) log entry"
        if let message = log.message, !message.isEmpty {
            label += ": \(message)"
        }
        return label
    }

    @ViewBuilder
    func Header(createdAt: String, level: LBLogLevel) -> some View {
        HStack {
            Text(createdAt)
                .font(.caption)
                .foregroundColor(.gray)
            Spacer()
            Text(level.emoji)
                .font(.title2)
        }
    }

    @ViewBuilder
    func Message(_ message: String) -> some View {
        LogSection(title: "Message") {
            Text(message)
        }
    }

    @ViewBuilder
    func ExtraMessages(_ extraMessages: [LBExtraMessage]) -> some View {
        ForEach(extraMessages, id: \.self) { value in
            LogSection(title: value.title) {
                Text(value.message)
            }
        }
    }

    @ViewBuilder
    func AdditionalInfo(_ additionalInfo: [String: String]) -> some View {
        LogSection(title: "Additional Info") {
            ForEach(additionalInfo.keys.sorted(), id: \.self) { key in
                if let value = additionalInfo[key] {
                    InfoRow(label: "\(key):", value: value)
                }
            }
        }
    }

    @ViewBuilder
    func LogError(_ error: LBError) -> some View {
        LogSection(title: "Error") {
            InfoRow(label: "Domain:", value: error.domain)

            InfoRow(label: "Code:", value: "\(error.code)")

            if let userInfo = error.userInfo {
                ForEach(userInfo.keys.sorted(), id: \.self) { key in
                    if let value = userInfo[key] {
                        InfoRow(label: "\(key):", value: value)
                    }
                }
            }
        }
    }

    @ViewBuilder
    func Location(_ location: LBLocation) -> some View {
        LogSection(title: "Location") {
            InfoRow(label: "File:", value: location.fileName)
            InfoRow(label: "Function:", value: location.function)
            InfoRow(label: "Line:", value: "\(location.line)")
        }
    }

    @ViewBuilder
    func Source(_ source: LBSource) -> some View {
        LogSection(title: "Source") {
            InfoRow(label: "Subsystem:", value: source.subsystem)
            InfoRow(label: "Category:", value: source.category)
        }
    }

    @ViewBuilder
    func LogSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(title):")
                .font(.subheadline)
            content()
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    func InfoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .bold()
            Text(value)
        }
    }
}

#Preview("Light") {
    LBLogRowView(log: .previewSample)
}

#Preview("Dark") {
    LBLogRowView(log: .previewSample)
        .preferredColorScheme(.dark)
}

private extension LBLog {
    static var previewSample: LBLog {
        LBLog(
            level: .info,
            message: "Network request finished",
            additionalInfo: ["statusCode": "200"],
            createdAt: Date().timeIntervalSince1970,
            location: LBLocation(file: "LogBird/LBManager.swift", function: "log(_:)", line: 42),
            source: LBSource(subsystem: "com.logbird.preview", category: "network")
        )
    }
}
