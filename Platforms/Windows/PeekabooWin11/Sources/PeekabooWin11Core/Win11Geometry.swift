import Foundation

public struct Win11Point: Codable, Equatable, Sendable {
    public let x: Int
    public let y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
}

public struct Win11Size: Codable, Equatable, Sendable {
    public let width: Int
    public let height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

public struct Win11Rect: Codable, Equatable, Sendable {
    public let x: Int
    public let y: Int
    public let width: Int
    public let height: Int

    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var origin: Win11Point {
        Win11Point(x: self.x, y: self.y)
    }

    public var size: Win11Size {
        Win11Size(width: self.width, height: self.height)
    }

    public var isEmpty: Bool {
        self.width <= 0 || self.height <= 0
    }
}
