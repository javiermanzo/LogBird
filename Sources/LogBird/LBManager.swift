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
    
    private let dateFormatter: DateFormatter = {
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
             additionalInfo: [String: Any]? = nil,
             error: Error? = nil,
             level: LBLogLevel = .debug,
             file: String = #fileID,
             function: String = #function,
             line: Int = #line) {
        
        let logData = buildLogData(message: message,
                                   additionalInfo: additionalInfo,
                                   error: error,
                                   level: level,
                                   file: file,
                                   function: function,
                                   line: line)
        
        let logJSON = logToPrettyJSON(logData)

        var log: String = "\(logData.level.emoji) LogBird: \n\(logJSON)"
        
        if let identifier {
            log = "\(identifier) \(log)"
        }

        var stringIdentifier = ""
                if let identifier {
                    dispatchQueue.sync {
                        stringIdentifier = identifier
                    }
                }

        logger.log(level: level.osLogType, "\(log)")

        
        self.logs.insert(logData, at: 0)
        self.logsSubject.send(self.logs)
    }
    
    private func buildLogData(message: String? = nil,
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
            additionalInfo: additionalInfoString,
            error: errorData,
            file: file,
            function: function,
            line: line,
            createdAt: dateFormatter.string(from: Date()),
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
    
    private func logToPrettyJSON(_ log: LBLog) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let jsonData = try encoder.encode(log)
            return String(data: jsonData, encoding: .utf8) ?? ""
        } catch {
            print("Error encoding LBLog to JSON:", error)
            return ""
        }
    }
    
    private func errorToDictionary(_ error: Error) -> [String: Any] {
        let nsError = error as NSError
        return [
            "domain": nsError.domain,
            "code": nsError.code,
            "localizedDescription": nsError.localizedDescription,
            "userInfo": nsError.userInfo
        ]
    }
}
