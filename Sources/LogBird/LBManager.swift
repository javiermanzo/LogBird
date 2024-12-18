//
//  LBManager.swift
//  LogBird
//
//  Created by Javier Manzo on 15/11/2024.
//

import Foundation
import OSLog
import Combine

final class LBManager: @unchecked Sendable  {
    
    private let logger: Logger
    private var identifier: String?
    private let dispatchQueue: DispatchQueue = DispatchQueue(label: "com.logbird.accessQueue")
    
    private let source: LBSource
    
    private var logs: [LBLog] = []
    private let logsSubject = CurrentValueSubject<[LBLog], Never>([])
    var logsPublisher: AnyPublisher<[LBLog], Never> {
        logsSubject.eraseToAnyPublisher()
    }
    
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS ZZZZ"
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale.current
        return formatter
    }()
    
    init(subsystem: String, category: String) {
        let source = LBSource(subsystem: subsystem, category: category)
        self.logger = Logger(subsystem: source.subsystem, category: source.category)
        self.source = source
    }
    
    func setIdentifier(_ value: String?) {
        dispatchQueue.async { [weak self] in
            guard let self = self else { return }
            self.identifier = value
        }
    }
    
    func log(_ message: String? = nil,
             extraMessages: [LBExtraMessage]? = nil,
             additionalInfo: [String: Any]? = nil,
             error: Error? = nil,
             level: LBLogLevel = .debug,
             file: String = #fileID,
             function: String = #function,
             line: Int = #line) {
        
        let log = buildLogData(message: message,
                               extraMessages: extraMessages,
                               additionalInfo: additionalInfo,
                               error: error,
                               level: level,
                               file: file,
                               function: function,
                               line: line)
        
        let logMessage = generateLogMessage(log)
        
        logger.log(level: level.osLogType, "\(logMessage)")
        
        self.logs.insert(log, at: 0)
        self.logsSubject.send(self.logs)
    }
    
    private func buildLogData(message: String? = nil,
                              extraMessages: [LBExtraMessage]? = nil,
                              additionalInfo: [String: Any]? = nil,
                              error: Error? = nil,
                              level: LBLogLevel,
                              file: String,
                              function: String,
                              line: Int) -> LBLog {
        
        let errorData: LBError? = errorToLBError(error) ?? nil
        
        let additionalInfoString = additionalInfo?.compactMapValues { "\($0)" }
        
        let log = LBLog(
            level: level,
            message: message,
            extraMessages: extraMessages,
            additionalInfo: additionalInfoString,
            error: errorData,
            createdAt: Date().timeIntervalSince1970,
            location: LBLocation(file: file, function: function, line: line),
            source: LBSource(subsystem: source.subsystem, category: source.category)
        )
        
        return log
    }
    
    private func errorToLBError(_ error: Error?) -> LBError? {
        guard let error else { return nil }
        let nsError = error as NSError
        let userInfoString = nsError.userInfo.compactMapValues { "\($0)" }
        
        return LBError(
            domain: nsError.domain,
            code: nsError.code,
            localizedDescription: nsError.localizedDescription,
            userInfo: userInfoString
        )
    }
    
    private func generateLogMessage(_ log: LBLog) -> String {
        var logMessage: String = ""
        let spacing: String = "    "
        
        // Header
        var header: String = "\(log.level.emoji) \(log.level.rawValue.uppercased()) LogBird: \n"
        if let identifier {
            header = "\(identifier) \(header)"
        }
        
        logMessage = "\(logMessage)\(header)"
        
        // Created At
        let createdAt: String = "Created at:\n\(spacing)\(LBManager.dateFormatter.string(from: Date(timeIntervalSince1970: log.createdAt)))\n"
        logMessage = "\(logMessage)\(createdAt)"
        
        // Message
        if let message = log.message {
            let info: String = "Message:\n\(spacing)\(message)\n"
            logMessage = "\(logMessage)\(info)"
        }
        
        // Extra Messages
        if let extraMessages = log.extraMessages {
            for extraMessage in extraMessages {
                let message: String = "\(extraMessage.title):\n\(spacing)\(extraMessage.message)\n"
                logMessage = "\(logMessage)\(message)"
            }
        }
        
        // Additional Info
        if let additionalInfo = log.additionalInfo {
            var info: String = "Additional Info:\n"
            for key in additionalInfo.keys {
                if let value = additionalInfo[key] {
                    info = "\(info)\(spacing) \(key): \(value)\n"
                }
            }
            logMessage = "\(logMessage)\(info)"
        }
        
        // Error
        if let error = log.error {
            let domain: String = "Domain: \(error.domain)\n"
            let code: String = "Code: \(error.code)\n"
            var userInfoString: String = ""
            
            if let userInfo = error.userInfo {
                userInfoString = "User Info:\n"
                for key in userInfo.keys {
                    if let value = userInfo[key] {
                        userInfoString = "\(userInfoString)\(spacing)\(spacing)\(key): \(value)\n"
                    }
                }
            }
            
            var errorString: String = "Error:\n\(spacing)\(domain)\(spacing)\(code)"
            if !userInfoString.isEmpty {
                errorString = "\(errorString)\(spacing)\(userInfoString)"
            }
            
            logMessage = "\(logMessage)\(errorString)"
        }
        
        // Source
        let subsystem: String = "Subsystem: \(log.source.subsystem)\n"
        let category: String = "Category: \(log.source.category)\n"
        let source: String = "Source: \n\(spacing)\(subsystem)\(spacing)\(category)"
        logMessage = "\(logMessage)\(source)"
        
        // Location
        let file: String = "File: \(log.location.file)\n"
        let function: String = "Function: \(log.location.function)\n"
        let line: String = "Line: \(log.location.line)\n"
        let location: String = "Location:\n\(spacing)\(file)\(spacing)\(function)\(spacing)\(line)"
        logMessage = "\(logMessage)\(location)"
        
        return logMessage
    }
}
