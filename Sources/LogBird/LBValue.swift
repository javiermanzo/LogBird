//
//  LBValue.swift
//  LogBird
//
//  Created by Javier Manzo on 28/07/2026.
//

import Foundation

/// A typed value for `additionalInfo` metadata.
///
/// Values keep their original type when encoded to JSON, so exported logs
/// contain real numbers, booleans and strings instead of stringified output.
/// Arrays and dictionaries nest values arbitrarily deep.
///
/// Decoding is best-effort: JSON has no distinct URL type, so URLs decode as
/// `.string`, and whole-number doubles (e.g. `12.0`, encoded as `12`) decode
/// as `.int`. Encoding a non-finite double (NaN or infinity) throws, as with
/// any `JSONEncoder`.
public enum LBValue: Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case url(URL)
    indirect case array([LBValue])
    indirect case dictionary([String: LBValue])
}

extension LBValue: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([LBValue].self) {
            self = .array(array)
        } else if let dictionary = try? container.decode([String: LBValue].self) {
            self = .dictionary(dictionary)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported additional info value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let string): try container.encode(string)
        case .int(let int): try container.encode(int)
        case .double(let double): try container.encode(double)
        case .bool(let bool): try container.encode(bool)
        case .url(let url): try container.encode(url.absoluteString)
        case .array(let array): try container.encode(array)
        case .dictionary(let dictionary): try container.encode(dictionary)
        }
    }
}

extension LBValue: Hashable {}

extension LBValue: CustomStringConvertible {
    public var description: String {
        switch self {
        case .string(let string): return string
        case .int(let int): return String(int)
        case .double(let double): return String(double)
        case .bool(let bool): return String(bool)
        case .url(let url): return url.absoluteString
        case .array(let array): return "[\(array.map(\.description).joined(separator: ", "))]"
        case .dictionary(let dictionary):
            let pairs = dictionary.keys.sorted().map { "\($0): \(dictionary[$0]!)" }
            return "{\(pairs.joined(separator: ", "))}"
        }
    }
}

extension LBValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension LBValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .int(value)
    }
}

extension LBValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .double(value)
    }
}

extension LBValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}
