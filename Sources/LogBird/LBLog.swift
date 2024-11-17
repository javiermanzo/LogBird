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
    public let additionalInfo: [String: String]?
    public let error: LBError?
    public let file: String
    public let function: String
    public let line: Int
    public let createdAt: String
    public let source: LBSource
}

public struct LBSource: Codable {
    public let subsystem: String
    public let category: String
}

public struct LBError: Codable {
    public let domain: String
    public let code: Int
    public let localizedDescription: String
    public let userInfo: [String: String]?
}
