import Foundation

public enum Win11PlatformCapability: String, CaseIterable, Codable, Sendable {
    case enumerateApplications
    case enumerateDisplays
    case enumerateWindows
    case captureScreenBMP
}

public struct Win11PlatformInfo: Codable, Equatable, Sendable {
    public let name: String
    public let minimumWindowsVersion: String
    public let nativeBackend: String
    public let capabilities: [Win11PlatformCapability]

    public init(
        name: String = "Windows",
        minimumWindowsVersion: String = "Windows 11",
        nativeBackend: String = "Win32",
        capabilities: [Win11PlatformCapability] = Win11PlatformCapability.allCases)
    {
        self.name = name
        self.minimumWindowsVersion = minimumWindowsVersion
        self.nativeBackend = nativeBackend
        self.capabilities = capabilities
    }
}

public struct Win11Display: Codable, Equatable, Sendable {
    public let id: UInt64
    public let index: Int
    public let bounds: Win11Rect
    public let workArea: Win11Rect
    public let isPrimary: Bool

    public init(id: UInt64, index: Int, bounds: Win11Rect, workArea: Win11Rect, isPrimary: Bool) {
        self.id = id
        self.index = index
        self.bounds = bounds
        self.workArea = workArea
        self.isPrimary = isPrimary
    }
}

public struct Win11Application: Codable, Equatable, Sendable {
    public let processIdentifier: UInt32
    public let executableName: String
    public let executablePath: String?
    public let isActive: Bool
    public let visibleWindowCount: Int

    public init(
        processIdentifier: UInt32,
        executableName: String,
        executablePath: String?,
        isActive: Bool,
        visibleWindowCount: Int)
    {
        self.processIdentifier = processIdentifier
        self.executableName = executableName
        self.executablePath = executablePath
        self.isActive = isActive
        self.visibleWindowCount = visibleWindowCount
    }
}

public struct Win11Window: Codable, Equatable, Sendable {
    public let windowIdentifier: UInt64
    public let processIdentifier: UInt32
    public let title: String
    public let bounds: Win11Rect
    public let isVisible: Bool
    public let isMinimized: Bool
    public let isForeground: Bool
    public let executableName: String?

    public init(
        windowIdentifier: UInt64,
        processIdentifier: UInt32,
        title: String,
        bounds: Win11Rect,
        isVisible: Bool,
        isMinimized: Bool,
        isForeground: Bool,
        executableName: String?)
    {
        self.windowIdentifier = windowIdentifier
        self.processIdentifier = processIdentifier
        self.title = title
        self.bounds = bounds
        self.isVisible = isVisible
        self.isMinimized = isMinimized
        self.isForeground = isForeground
        self.executableName = executableName
    }
}

public enum Win11CaptureFormat: String, Codable, Sendable {
    case bmp
}

public struct Win11CaptureResult: Codable, Equatable, Sendable {
    public let path: String
    public let bounds: Win11Rect
    public let format: Win11CaptureFormat
    public let byteCount: Int

    public init(path: String, bounds: Win11Rect, format: Win11CaptureFormat, byteCount: Int) {
        self.path = path
        self.bounds = bounds
        self.format = format
        self.byteCount = byteCount
    }
}

public struct Win11CommandEnvelope<Payload: Encodable>: Encodable {
    public let ok: Bool
    public let data: Payload?
    public let error: String?

    public init(ok: Bool, data: Payload?, error: String?) {
        self.ok = ok
        self.data = data
        self.error = error
    }
}
