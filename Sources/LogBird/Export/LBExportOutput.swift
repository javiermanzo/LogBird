//
//  LBExportOutput.swift
//  LogBird
//
//  Created by Javier Manzo on 30/07/2026.
//

import Foundation

/// The result of `LogBird.export(_:format:destination:)`.
public enum LBExportOutput: Sendable, Equatable {
    /// The encoded logs delivered as in-memory `Data`.
    case data(Data)
    /// The encoded logs written to a file, along with the file's `URL` and `Data`.
    case file(URL, data: Data)

    /// The encoded logs data, regardless of destination.
    public var data: Data {
        switch self {
        case .data(let data), .file(_, let data):
            return data
        }
    }

    /// The written file URL when the destination is `.file`, `nil` when `.data`.
    public var fileURL: URL? {
        switch self {
        case .data:
            return nil
        case .file(let url, _):
            return url
        }
    }
}
