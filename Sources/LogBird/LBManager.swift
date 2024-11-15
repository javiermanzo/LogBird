//
//  LBManager.swift
//  LogBird
//
//  Created by Javier Manzo on 15/11/2024.
//

import Foundation
import OSLog

final class LBManager: @unchecked Sendable  {

    private let logger: Logger
    private var identifier: String?
    private let dispatchQueue: DispatchQueue = DispatchQueue(label: "com.logbird.accessQueue")

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS ZZZZ"
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale.current
        return formatter
    }()

    init(subsystem: String, category: String) {
        self.logger = Logger(subsystem: subsystem, category: category)
    }

    func log(_ message: String, additionalInfo: [String: Any]? = nil, error: Error? = nil, level: LBLogLevel = .debug, file: String = #fileID, function: String = #function, line: Int = #line) {

        var stringIdentifier = ""
        if let identifier {
            dispatchQueue.sync {
                stringIdentifier = identifier
            }
        }

        let data = logBuilder(message: message, additionalInfo: additionalInfo, error: error, level: level, file: file, function: function, line: line)
        let log = dictionaryToPrettyJSON(data)

        logger.log(level: level.osLogType, "\(stringIdentifier) \(level.emoji) \n\(log, privacy: .public)")
    }

    func setIdentifier(_ value: String?) {
        dispatchQueue.async { [weak self] in
            guard let self = self else { return }
            self.identifier = value
        }
    }

    func logBuilder(message: String? = nil, additionalInfo: [String: Any]? = nil, error: Error? = nil, level: LBLogLevel, file: String, function: String, line: Int) -> [String: Any] {
        var data: [String: Any] = [:]

        data["level"] = level.rawValue

        if let message {
            data["message"] = message
        }

        if let additionalInfo {
            data["additionalInfo"] = additionalInfo
        }

        if let error {
            data["error"] = errorToDictionary(error)
        }

        data["file"] = file
        data["function"] = function
        data["line"] = line
        data["createdAt"] = dateFormatter.string(from: Date())

        return data
    }

    func dictionaryToPrettyJSON(_ dictionary: [String: Any]) -> String {
        guard JSONSerialization.isValidJSONObject(dictionary) else { return "" }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: dictionary, options: [.prettyPrinted])
            return String(data: jsonData, encoding: .utf8) ?? ""
        } catch {
            print("Error serializing dictionary to JSON:", error)
            return ""
        }
    }

    func errorToDictionary(_ error: Error) -> [String: Any] {
        let nsError = error as NSError
        return [
            "domain": nsError.domain,
            "code": nsError.code,
            "localizedDescription": nsError.localizedDescription,
            "userInfo": nsError.userInfo
        ]
    }
}
