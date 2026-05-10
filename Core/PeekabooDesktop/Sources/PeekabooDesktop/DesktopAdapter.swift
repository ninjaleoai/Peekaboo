import Foundation

public protocol DesktopAdapter: Sendable {
    func platformInfo() -> DesktopPlatformInfo
    func listDisplays() throws -> [DesktopDisplay]
    func listWindows(includeInvisible: Bool) throws -> [DesktopWindow]
    func listApplications() throws -> [DesktopApplication]
    func captureScreen(displayIndex: Int?, outputPath: String) throws -> DesktopCaptureResult
    func captureArea(_ rect: DesktopRect, outputPath: String) throws -> DesktopCaptureResult
    func captureWindow(windowIdentifier: UInt64, outputPath: String) throws -> DesktopCaptureResult
    func captureFrontmost(outputPath: String) throws -> DesktopCaptureResult
    func cursorPosition() throws -> DesktopPoint
    func moveCursor(to point: DesktopPoint) throws -> DesktopPoint
}

public protocol DesktopAsyncAdapter: Sendable {
    func platformInfo() async -> DesktopPlatformInfo
    func listDisplays() async throws -> [DesktopDisplay]
    func listWindows(includeInvisible: Bool) async throws -> [DesktopWindow]
    func listApplications() async throws -> [DesktopApplication]
    func captureScreen(displayIndex: Int?, outputPath: String) async throws -> DesktopCaptureResult
    func captureArea(_ rect: DesktopRect, outputPath: String) async throws -> DesktopCaptureResult
    func captureWindow(windowIdentifier: UInt64, outputPath: String) async throws -> DesktopCaptureResult
    func captureFrontmost(outputPath: String) async throws -> DesktopCaptureResult
    func cursorPosition() async throws -> DesktopPoint
    func moveCursor(to point: DesktopPoint) async throws -> DesktopPoint
}

public struct DesktopAdapterAsyncBridge<Adapter: DesktopAdapter>: DesktopAsyncAdapter {
    public let adapter: Adapter

    public init(_ adapter: Adapter) {
        self.adapter = adapter
    }

    public func platformInfo() async -> DesktopPlatformInfo {
        self.adapter.platformInfo()
    }

    public func listDisplays() async throws -> [DesktopDisplay] {
        try self.adapter.listDisplays()
    }

    public func listWindows(includeInvisible: Bool) async throws -> [DesktopWindow] {
        try self.adapter.listWindows(includeInvisible: includeInvisible)
    }

    public func listApplications() async throws -> [DesktopApplication] {
        try self.adapter.listApplications()
    }

    public func captureScreen(displayIndex: Int?, outputPath: String) async throws -> DesktopCaptureResult {
        try self.adapter.captureScreen(displayIndex: displayIndex, outputPath: outputPath)
    }

    public func captureArea(_ rect: DesktopRect, outputPath: String) async throws -> DesktopCaptureResult {
        try self.adapter.captureArea(rect, outputPath: outputPath)
    }

    public func captureWindow(windowIdentifier: UInt64, outputPath: String) async throws -> DesktopCaptureResult {
        try self.adapter.captureWindow(windowIdentifier: windowIdentifier, outputPath: outputPath)
    }

    public func captureFrontmost(outputPath: String) async throws -> DesktopCaptureResult {
        try self.adapter.captureFrontmost(outputPath: outputPath)
    }

    public func cursorPosition() async throws -> DesktopPoint {
        try self.adapter.cursorPosition()
    }

    public func moveCursor(to point: DesktopPoint) async throws -> DesktopPoint {
        try self.adapter.moveCursor(to: point)
    }
}

public enum DesktopAdapterError: Error, Equatable, Sendable {
    case unsupportedPlatform(String)
    case invalidArgument(String)
    case nativeCallFailed(String)
    case displayNotFound(Int)
    case emptyCaptureRegion(DesktopRect)
    case outputPathRequired
}

extension DesktopAdapterError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .unsupportedPlatform(message):
            return message
        case let .invalidArgument(message):
            return message
        case let .nativeCallFailed(call):
            return "Native desktop call failed: \(call)"
        case let .displayNotFound(index):
            return "Display not found at index \(index)"
        case let .emptyCaptureRegion(rect):
            return "Capture region is empty: \(rect)"
        case .outputPathRequired:
            return "An output path is required for capture"
        }
    }
}
