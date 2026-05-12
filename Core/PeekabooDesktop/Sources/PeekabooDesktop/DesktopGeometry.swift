import Foundation

public struct DesktopPoint: Codable, Equatable, Sendable {
    public let x: Int
    public let y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
}

public struct DesktopSize: Codable, Equatable, Sendable {
    public let width: Int
    public let height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

public struct DesktopRect: Codable, Equatable, Sendable {
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

    public var origin: DesktopPoint {
        DesktopPoint(x: self.x, y: self.y)
    }

    public var size: DesktopSize {
        DesktopSize(width: self.width, height: self.height)
    }

    public var isEmpty: Bool {
        self.width <= 0 || self.height <= 0
    }
}

