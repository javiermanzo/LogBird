//
//  LBLog.swift
//  LogBird
//
//  Created by Javier Manzo on 16/11/2024.
//

import Foundation

public struct LBLog: Codable, Identifiable {
    public let id: String
    public let level: LBLogLevel
    public let message: String?
    public let extraMessages: [LBExtraMessage]?
    public let additionalInfo: [String: String]?
    public let error: LBError?
    public let createdAt: Double
    public let location: LBLocation
    public let source: LBSource

    public init(
        id: String = UUID().uuidString,
        level: LBLogLevel,
        message: String? = nil,
        extraMessages: [LBExtraMessage]? = nil,
        additionalInfo: [String: String]? = nil,
        error: LBError? = nil,
        createdAt: Double,
        location: LBLocation,
        source: LBSource
    ) {
        self.id = id
        self.level = level
        self.message = message
        self.extraMessages = extraMessages
        self.additionalInfo = additionalInfo
        self.error = error
        self.createdAt = createdAt
        self.location = location
        self.source = source
    }
}

public struct LBSource: Codable {
    public let subsystem: String
    public let category: String

    public init(subsystem: String, category: String) {
        self.subsystem = subsystem
        self.category = category
    }
}

public struct LBLocation: Codable {
    public let file: String
    public let function: String
    public let line: Int

    public init(file: String, function: String, line: Int) {
        self.file = file
        self.function = function
        self.line = line
    }
}

public struct LBError: Codable {
    public let domain: String
    public let code: Int
    public let localizedDescription: String
    public let userInfo: [String: String]?

    public init(domain: String, code: Int, localizedDescription: String, userInfo: [String: String]? = nil) {
        self.domain = domain
        self.code = code
        self.localizedDescription = localizedDescription
        self.userInfo = userInfo
    }
}

public struct LBExtraMessage: Codable, Hashable {
    public let title: String
    public let message: String

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
