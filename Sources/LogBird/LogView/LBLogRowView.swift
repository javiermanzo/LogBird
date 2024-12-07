//
//  LBLogRowView.swift
//  LogBird
//
//  Created by Javier Manzo on 16/11/2024.
//

import SwiftUI

struct LogRowView: View {
    let log: LBLog

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Header(createdAt: log.createdAt, level: log.level)

            if let message = log.message, !message.isEmpty {
                Message(message)
            }

            if let error = log.error {
                LogError(error)
            }

            if let additionalInfo = log.additionalInfo, !additionalInfo.isEmpty {
                AdditionalInfo(additionalInfo)
            }

            Location(file: log.file, function: log.function, line: log.line)

            Source(log.source)
        }
        .padding()
        .background(backgroundColor(for: log.level))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
    }

    // Función para obtener el color de fondo según el nivel del log
    private func backgroundColor(for level: LBLogLevel) -> Color {
        switch level {
        case .debug:
            return Color.gray.opacity(0.1)
        case .info:
            return Color.blue.opacity(0.1)
        case .warning:
            return Color.yellow.opacity(0.1)
        case .error:
            return Color.orange.opacity(0.1)
        case .critical:
            return Color.red.opacity(0.1)
        }
    }
}

private extension LogRowView {
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
        SectionView(title: "Message") {
            Text(message)
        }
    }

    @ViewBuilder
    func AdditionalInfo(_ additionalInfo: [String: String]) -> some View {
        SectionView(title: "Additional Info") {
            ForEach(additionalInfo.keys.sorted(), id: \.self) { key in
                Text("\(key): \(additionalInfo[key] ?? "")")
            }
        }
    }

    @ViewBuilder
    func LogError(_ error: LBError) -> some View {
        SectionView(title: "Error") {
            InfoRow(label: "Domain:", value: error.domain)

            InfoRow(label: "Code:", value: "\(error.code)")

            if let userInfo = error.userInfo {
                ForEach(userInfo.keys.sorted(), id: \.self) { key in
                    InfoRow(label: "\(key)", value: userInfo[key] ?? "")
                }
            }

        }
    }

    @ViewBuilder
    func Location(file: String?, function: String?, line: Int?) -> some View {
        SectionView(title: "Location") {
            if let file = file {
                InfoRow(label: "File:", value: file)
            }
            if let function = function {
                InfoRow(label: "Function:", value: function)
            }
            if let line = line {
                InfoRow(label: "Line:", value: "\(line)")
            }
        }
    }

    @ViewBuilder
    func Source(_ source: LBSource) -> some View {
        SectionView(title: "Source") {
            InfoRow(label: "Subsystem:", value: source.subsystem)
            InfoRow(label: "Category:", value: source.category)
        }
    }

    @ViewBuilder
    func SectionView(title: String, @ViewBuilder content: () -> some View) -> some View {
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
