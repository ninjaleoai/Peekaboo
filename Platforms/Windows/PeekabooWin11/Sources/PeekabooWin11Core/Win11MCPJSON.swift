import Foundation

public enum Win11MCPJSONValue: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([Win11MCPJSONValue])
    case object([String: Win11MCPJSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([Win11MCPJSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: Win11MCPJSONValue].self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .null:
            try container.encodeNil()
        case let .bool(value):
            try container.encode(value)
        case let .int(value):
            try container.encode(value)
        case let .double(value):
            try container.encode(value)
        case let .string(value):
            try container.encode(value)
        case let .array(value):
            try container.encode(value)
        case let .object(value):
            try container.encode(value)
        }
    }
}

extension Win11MCPJSONValue {
    public var stringValue: String? {
        if case let .string(value) = self {
            value
        } else {
            nil
        }
    }

    public var intValue: Int? {
        switch self {
        case let .int(value):
            value
        case let .double(value) where value.rounded() == value:
            Int(value)
        case let .string(value):
            Int(value)
        default:
            nil
        }
    }

    public var doubleValue: Double? {
        switch self {
        case let .double(value):
            value
        case let .int(value):
            Double(value)
        case let .string(value):
            Double(value)
        default:
            nil
        }
    }

    public var boolValue: Bool? {
        switch self {
        case let .bool(value):
            value
        case let .string(value):
            switch value.lowercased() {
            case "true", "yes", "1":
                true
            case "false", "no", "0":
                false
            default:
                nil
            }
        default:
            nil
        }
    }

    public var objectValue: [String: Win11MCPJSONValue]? {
        if case let .object(value) = self {
            value
        } else {
            nil
        }
    }

    public var arrayValue: [Win11MCPJSONValue]? {
        if case let .array(value) = self {
            value
        } else {
            nil
        }
    }

    public static func fromEncodable<T: Encodable>(_ value: T) throws -> Win11MCPJSONValue {
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        return try JSONDecoder().decode(Win11MCPJSONValue.self, from: data)
    }
}

struct Win11MCPJSONRPCRequest: Decodable {
    let jsonrpc: String?
    let id: Win11MCPJSONValue?
    let hasID: Bool
    let method: String
    let params: Win11MCPJSONValue?

    private enum CodingKeys: String, CodingKey {
        case jsonrpc
        case id
        case method
        case params
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.jsonrpc = try container.decodeIfPresent(String.self, forKey: .jsonrpc)
        self.hasID = container.contains(.id)
        self.id = self.hasID ? try container.decode(Win11MCPJSONValue.self, forKey: .id) : nil
        self.method = try container.decode(String.self, forKey: .method)
        self.params = try container.decodeIfPresent(Win11MCPJSONValue.self, forKey: .params)
    }
}

enum Win11MCPJSONRPC {
    static func result(id: Win11MCPJSONValue, _ result: Win11MCPJSONValue) throws -> String {
        try self.encode([
            "jsonrpc": .string("2.0"),
            "id": id,
            "result": result,
        ])
    }

    static func error(id: Win11MCPJSONValue, code: Int, message: String) throws -> String {
        try self.encode([
            "jsonrpc": .string("2.0"),
            "id": id,
            "error": .object([
                "code": .int(code),
                "message": .string(message),
            ]),
        ])
    }

    private static func encode(_ object: [String: Win11MCPJSONValue]) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(Win11MCPJSONValue.object(object))
        return String(decoding: data, as: UTF8.self)
    }
}
