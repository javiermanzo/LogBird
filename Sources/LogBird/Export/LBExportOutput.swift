//
//  LBExportOutput.swift
//  LogBird
//
//  Created by Javier Manzo on 30/07/2026.
//

import Foundation

/// The result of `LogBird.export(_:format:destination:)`.
public struct LBExportOutput: Sendable {
    /// The encoded logs.
    public let data: Data
    /// The file the logs were written to when the destination is `.file`,
    /// `nil` when it is `.data`.
    public let fileURL: URL?
}
