import Foundation

public protocol Win11DesktopAdapter: Sendable {
    func platformInfo() -> Win11PlatformInfo
    func listDisplays() throws -> [Win11Display]
    func listWindows(includeInvisible: Bool) throws -> [Win11Window]
    func listApplications() throws -> [Win11Application]
    func captureScreen(displayIndex: Int?, outputPath: String) throws -> Win11CaptureResult
}

public enum Win11DesktopError: Error, Equatable, Sendable {
    case unsupportedPlatform(String)
    case invalidArgument(String)
    case win32CallFailed(String)
    case displayNotFound(Int)
    case emptyCaptureRegion(Win11Rect)
    case outputPathRequired
}

extension Win11DesktopError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .unsupportedPlatform(message):
            return message
        case let .invalidArgument(message):
            return message
        case let .win32CallFailed(call):
            return "Win32 call failed: \(call)"
        case let .displayNotFound(index):
            return "Display not found at index \(index)"
        case let .emptyCaptureRegion(rect):
            return "Capture region is empty: \(rect)"
        case .outputPathRequired:
            return "An output path is required for screen capture"
        }
    }
}

public enum Win11DesktopAdapterFactory {
    public static func makeDefault() -> any Win11DesktopAdapter {
        #if os(Windows)
        return Win32DesktopAdapter()
        #else
        return UnsupportedWin11DesktopAdapter()
        #endif
    }
}

public struct UnsupportedWin11DesktopAdapter: Win11DesktopAdapter {
    public init() {}

    public func platformInfo() -> Win11PlatformInfo {
        Win11PlatformInfo(capabilities: [])
    }

    public func listDisplays() throws -> [Win11Display] {
        throw self.unsupported()
    }

    public func listWindows(includeInvisible: Bool) throws -> [Win11Window] {
        throw self.unsupported()
    }

    public func listApplications() throws -> [Win11Application] {
        throw self.unsupported()
    }

    public func captureScreen(displayIndex: Int?, outputPath: String) throws -> Win11CaptureResult {
        throw self.unsupported()
    }

    private func unsupported() -> Win11DesktopError {
        Win11DesktopError.unsupportedPlatform(
            "PeekabooWin11 requires Swift on Windows and the WinSDK module.")
    }
}
