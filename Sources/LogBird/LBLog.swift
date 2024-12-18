//
//  LBLog.swift
//  LogBird
//
//  Created by Javier Manzo on 16/11/2024.
//

import Foundation

public struct LBLog: Codable, Identifiable {
    public let id: String = UUID().uuidString
    public let level: LBLogLevel
    public let message: String?
    public let extraMessages: [LBExtraMessage]?
    public let additionalInfo: [String: String]?
    public let error: LBError?
    public let createdAt: Double
    public let location: LBLocation
    public let source: LBSource
}

public struct LBSource: Codable {
    public let subsystem: String
    public let category: String
}

public struct LBLocation: Codable {
    public let file: String
    public let function: String
    public let line: Int
}

public struct LBError: Codable {
    public let domain: String
    public let code: Int
    public let localizedDescription: String
    public let userInfo: [String: String]?
}

public struct LBExtraMessage: Codable, Hashable {
    let title: String
    let message: String

    public init(title: String, message: String) {
        self.title = title
        self.message = message
    }
}

public extension LBLog {
    func prettyJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        do {
            let jsonData = try encoder.encode(self)
            return String(data: jsonData, encoding: .utf8) ?? ""
        } catch {
            print("Error encoding LBLog to JSON:", error)
            return nil
        }
    }
}
