//
//  LBLogMessage.swift
//  LogBird
//
//  Created by Javier Manzo on 29/07/2026.
//

import Foundation

/// Privacy level of an interpolated value in an `LBLogMessage`.
public enum LBPrivacy: Sendable {
    /// The value is rendered as-is.
    case `public`
    /// The value is replaced by a placeholder while the message is built.
    case `private`
}

/// A log message built through string interpolation with per-value privacy.
///
/// Interpolated values are public by default. Mark sensitive values with
/// `privacy: .private` and they are replaced by `<redacted>` while the message
/// is being built, so the original value never reaches the stored log, OSLog,
/// or any exported output:
///
///     logBird.log("User \(username, privacy: .private) logged in")
///     // Stored as: "User <redacted> logged in"
public struct LBLogMessage: ExpressibleByStringInterpolation, Hashable, Sendable {

    /// The message with every private interpolation already replaced by the placeholder.
    public let value: String

    public init(stringInterpolation: StringInterpolation) {
        value = stringInterpolation.output
    }

    public init(stringLiteral value: String) {
        self.value = value
    }
}

extension LBLogMessage: CustomStringConvertible {
    public var description: String { value }
}

extension LBLogMessage {
    public struct StringInterpolation: StringInterpolationProtocol {
        var output: String

        public init(literalCapacity: Int, interpolationCount: Int) {
            output = String()
            output.reserveCapacity(literalCapacity)
        }

        public mutating func appendLiteral(_ literal: String) {
            output.append(literal)
        }

        public mutating func appendInterpolation<T>(_ value: T) {
            output.append(String(describing: value))
        }

        public mutating func appendInterpolation<T>(_ value: T, privacy: LBPrivacy) {
            switch privacy {
            case .public:
                output.append(String(describing: value))
            case .private:
                output.append(LBRedactor.placeholder)
            }
        }
    }
}
