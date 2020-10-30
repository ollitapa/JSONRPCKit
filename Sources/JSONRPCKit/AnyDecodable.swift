//
//  AnyDecodable.swift
//  
//
//  Created by Olli Tapaninen on 30.10.2020.
//

import Foundation

/// Generic JSON value. Quite inefficient decoding. Used mainly for Kotlin value
/// serializations. Should be replace the second Kotlin native offers
/// support for Codable.
///
/// - number: Number. Does not make difference between int and double
/// - text: Text value.
/// - none: Null
/// - keyed:: Object of keys and JSON values.
/// - sequence:: Sequence of JSON values
/// - object:: Single JSON object
public enum JsonValue: Codable, Hashable {

    indirect case keyed([AnyCodingKey: JsonValue])
    indirect case sequence([JsonValue])
    indirect case object(JsonValue)
    case number(Decimal)
    case text(String)
    case bool(Bool)
    case none

    public init(from decoder: Decoder) throws {

        // Try if the value is a single value.
        if let singleContainer = try? decoder.singleValueContainer() {
            if let decimal = try? singleContainer.decode(Decimal.self) {
                self = .number(decimal)
                return
            } else if let text = try? singleContainer.decode(String.self) {
                self = .text(text)
                return
            } else if singleContainer.decodeNil() {
                self = .none
                return
            } else if let b = try? singleContainer.decode(Bool.self) {
                self = .bool(b)
                return
            } else if let anyObjSequence = try? singleContainer.decode([JsonValue].self) {
                self = .sequence(anyObjSequence)
                return
            }
        }

        // Check if the value is a keyed container.
        if let keyedCont = try? decoder.container(keyedBy: AnyCodingKey.self) {
            self = .keyed(
                try Dictionary(
                    keyedCont.allKeys
                        .map { ($0, try keyedCont.decode(JsonValue.self, forKey: $0)) },
                    uniquingKeysWith: { (val1, _) in val1 })
            )
            return
        }

        // Check if we are encoding unkeyed container.
        if (try? decoder.unkeyedContainer()) != nil {
            self = .sequence(try [JsonValue].init(from: decoder))
            return
        }

        // Could not decode anything.
        throw DecodingError.valueNotFound(JsonValue.self, DecodingError.Context.init(codingPath: decoder.codingPath, debugDescription: "Could not decode any meaningful json."))
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case let .keyed(keysAndValues):
            var cont = encoder.container(keyedBy: AnyCodingKey.self)
            try keysAndValues.forEach {
                try cont.encode($0.value, forKey: $0.key)
            }
        case let .sequence(s):
            var cont = encoder.singleValueContainer()
            try cont.encode(s)
        case let .object(obj):
            var cont = encoder.singleValueContainer()
            try cont.encode(obj)
        case let .number(n):
            var cont = encoder.singleValueContainer()
            try cont.encode(n)
        case let .text(t):
            var cont = encoder.singleValueContainer()
            try cont.encode(t)
        case let .bool(t):
            var cont = encoder.singleValueContainer()
            try cont.encode(t)
        case .none:
            var cont = encoder.singleValueContainer()
            try cont.encodeNil()
        }
    }

}

/// Any coding key. Accepts any string or int key.
public struct AnyCodingKey: CodingKey, Hashable, CustomStringConvertible {
    public var stringValue: String
    public var intValue: Int?

    public init?(stringValue: String) {
        self.stringValue = stringValue
    }

    public init?(intValue: Int) {
        self.intValue = intValue
        self.stringValue = String(intValue)
    }

    public var description: String {
        return intValue.map { "(int key: \($0))" } ?? "(key: \(stringValue))"
    }
}

extension JsonValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .text(value)
    }
}

extension JsonValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension JsonValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .number(Decimal(value))
    }
}

extension JsonValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .number(Decimal(value))
    }
}

extension AnyCodingKey: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(stringValue: value)!
    }
}
