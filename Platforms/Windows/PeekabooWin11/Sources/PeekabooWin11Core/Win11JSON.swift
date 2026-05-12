import PeekabooDesktop

public enum Win11JSON {
    public static func encode<T: Encodable>(_ value: T) throws -> String {
        try DesktopJSON.encode(value)
    }
}
