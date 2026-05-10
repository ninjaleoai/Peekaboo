import Foundation

public enum DesktopPlatformCapability: String, CaseIterable, Codable, Sendable {
    case enumerateApplications
    case enumerateDisplays
    case enumerateWindows
    case captureScreenBMP
}

public struct DesktopPlatformInfo: Codable, Equatable, Sendable {
    public let name: String
    public let minimumSystemVersion: String
    public let nativeBackend: String
    public let capabilities: [DesktopPlatformCapability]

    public init(
        name: String,
        minimumSystemVersion: String,
        nativeBackend: String,
        capabilities: [DesktopPlatformCapability])
    {
        self.name = name
        self.minimumSystemVersion = minimumSystemVersion
        self.nativeBackend = nativeBackend
        self.capabilities = capabilities
    }
}

public struct DesktopDisplay: Codable, Equatable, Sendable {
    public let id: UInt64
    public let index: Int
    public let bounds: DesktopRect
    public let workArea: DesktopRect
    public let isPrimary: Bool

    public init(id: UInt64, index: Int, bounds: DesktopRect, workArea: DesktopRect, isPrimary: Bool) {
        self.id = id
        self.index = index
        self.bounds = bounds
        self.workArea = workArea
        self.isPrimary = isPrimary
    }
}

public struct DesktopApplication: Codable, Equatable, Sendable {
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

public struct DesktopWindow: Codable, Equatable, Sendable {
    public let windowIdentifier: UInt64
    public let processIdentifier: UInt32
    public let title: String
    public let bounds: DesktopRect
    public let isVisible: Bool
    public let isMinimized: Bool
    public let isForeground: Bool
    public let executableName: String?

    public init(
        windowIdentifier: UInt64,
        processIdentifier: UInt32,
        title: String,
        bounds: DesktopRect,
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

public enum DesktopCaptureFormat: String, Codable, Sendable {
    case bmp
}

public struct DesktopCaptureResult: Codable, Equatable, Sendable {
    public let path: String
    public let bounds: DesktopRect
    public let format: DesktopCaptureFormat
    public let byteCount: Int

    public init(path: String, bounds: DesktopRect, format: DesktopCaptureFormat, byteCount: Int) {
        self.path = path
        self.bounds = bounds
        self.format = format
        self.byteCount = byteCount
    }
}

public struct DesktopCommandEnvelope<Payload: Encodable>: Encodable {
    public let ok: Bool
    public let data: Payload?
    public let error: String?

    public init(ok: Bool, data: Payload?, error: String?) {
        self.ok = ok
        self.data = data
        self.error = error
    }
}

