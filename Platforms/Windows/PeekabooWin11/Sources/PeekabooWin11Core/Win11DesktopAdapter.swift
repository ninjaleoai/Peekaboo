import PeekabooDesktop

public typealias Win11DesktopAdapter = DesktopAdapter
public typealias Win11DesktopError = DesktopAdapterError

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
        Win11PlatformInfo(
            name: "Windows",
            minimumSystemVersion: "Windows 11",
            nativeBackend: "Win32",
            capabilities: [])
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

    public func captureArea(_ rect: Win11Rect, outputPath: String) throws -> Win11CaptureResult {
        throw self.unsupported()
    }

    public func captureWindow(windowIdentifier: UInt64, outputPath: String) throws -> Win11CaptureResult {
        throw self.unsupported()
    }

    private func unsupported() -> Win11DesktopError {
        Win11DesktopError.unsupportedPlatform(
            "PeekabooWin11 requires Swift on Windows and the WinSDK module.")
    }
}
