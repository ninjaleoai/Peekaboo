import Foundation

public enum DesktopPlatformCapability: String, CaseIterable, Codable, Sendable {
    case enumerateApplications
    case enumerateDisplays
    case enumerateWindows
    case captureScreenBMP
    case captureScreenPNG
    case captureAreaBMP
    case captureAreaPNG
    case captureWindowBMP
    case captureWindowPNG
    case captureFrontmostBMP
    case captureFrontmostPNG
    case readCursorPosition
    case moveCursor
    case clickMouse
    case scrollMouse
    case dragMouse
    case sendHotkey
    case typeText
    case inspectUIAutomation
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
    public let name: String?
    public let bounds: DesktopRect
    public let workArea: DesktopRect
    public let isPrimary: Bool
    public let scaleFactor: Double

    public init(
        id: UInt64,
        index: Int,
        bounds: DesktopRect,
        workArea: DesktopRect,
        isPrimary: Bool,
        name: String? = nil,
        scaleFactor: Double = 1.0)
    {
        self.id = id
        self.index = index
        self.name = name
        self.bounds = bounds
        self.workArea = workArea
        self.isPrimary = isPrimary
        self.scaleFactor = scaleFactor
    }
}

public struct DesktopApplication: Codable, Equatable, Sendable {
    public let processIdentifier: UInt32
    public let executableName: String
    public let executablePath: String?
    public let bundleIdentifier: String?
    public let isActive: Bool
    public let isHidden: Bool
    public let visibleWindowCount: Int

    public init(
        processIdentifier: UInt32,
        executableName: String,
        executablePath: String?,
        isActive: Bool,
        visibleWindowCount: Int,
        bundleIdentifier: String? = nil,
        isHidden: Bool = false)
    {
        self.processIdentifier = processIdentifier
        self.executableName = executableName
        self.executablePath = executablePath
        self.bundleIdentifier = bundleIdentifier
        self.isActive = isActive
        self.isHidden = isHidden
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
    public let index: Int
    public let screenIndex: Int?
    public let screenName: String?
    public let isOffScreen: Bool
    public let layer: Int
    public let isOnScreen: Bool
    public let isShareable: Bool
    public let alpha: Double
    public let spaceID: UInt64?
    public let spaceName: String?

    public init(
        windowIdentifier: UInt64,
        processIdentifier: UInt32,
        title: String,
        bounds: DesktopRect,
        isVisible: Bool,
        isMinimized: Bool,
        isForeground: Bool,
        executableName: String?,
        index: Int = 0,
        screenIndex: Int? = nil,
        screenName: String? = nil,
        isOffScreen: Bool = false,
        layer: Int = 0,
        isOnScreen: Bool = true,
        isShareable: Bool = true,
        alpha: Double = 1.0,
        spaceID: UInt64? = nil,
        spaceName: String? = nil)
    {
        self.windowIdentifier = windowIdentifier
        self.processIdentifier = processIdentifier
        self.title = title
        self.bounds = bounds
        self.isVisible = isVisible
        self.isMinimized = isMinimized
        self.isForeground = isForeground
        self.executableName = executableName
        self.index = index
        self.screenIndex = screenIndex
        self.screenName = screenName
        self.isOffScreen = isOffScreen
        self.layer = layer
        self.isOnScreen = isOnScreen
        self.isShareable = isShareable
        self.alpha = alpha
        self.spaceID = spaceID
        self.spaceName = spaceName
    }

    private enum CodingKeys: String, CodingKey {
        case windowIdentifier
        case processIdentifier
        case title
        case bounds
        case isVisible
        case isMinimized
        case isForeground
        case executableName
        case index
        case screenIndex
        case screenName
        case isOffScreen
        case layer
        case isOnScreen
        case isShareable
        case alpha
        case spaceID
        case spaceName
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.windowIdentifier = try container.decode(UInt64.self, forKey: .windowIdentifier)
        self.processIdentifier = try container.decode(UInt32.self, forKey: .processIdentifier)
        self.title = try container.decode(String.self, forKey: .title)
        self.bounds = try container.decode(DesktopRect.self, forKey: .bounds)
        self.isVisible = try container.decode(Bool.self, forKey: .isVisible)
        self.isMinimized = try container.decode(Bool.self, forKey: .isMinimized)
        self.isForeground = try container.decode(Bool.self, forKey: .isForeground)
        self.executableName = try container.decodeIfPresent(String.self, forKey: .executableName)
        self.index = try container.decode(Int.self, forKey: .index)
        self.screenIndex = try container.decodeIfPresent(Int.self, forKey: .screenIndex)
        self.screenName = try container.decodeIfPresent(String.self, forKey: .screenName)
        self.isOffScreen = try container.decode(Bool.self, forKey: .isOffScreen)
        self.layer = try container.decode(Int.self, forKey: .layer)
        self.isOnScreen = try container.decode(Bool.self, forKey: .isOnScreen)
        self.isShareable = try container.decodeIfPresent(Bool.self, forKey: .isShareable) ?? true
        self.alpha = try container.decode(Double.self, forKey: .alpha)
        self.spaceID = try container.decodeIfPresent(UInt64.self, forKey: .spaceID)
        self.spaceName = try container.decodeIfPresent(String.self, forKey: .spaceName)
    }
}

public enum DesktopCaptureFormat: String, Codable, Sendable {
    case bmp
    case png
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

public enum DesktopMouseButton: String, CaseIterable, Codable, Sendable {
    case left
    case right
    case middle
}

public struct DesktopClickResult: Codable, Equatable, Sendable {
    public let point: DesktopPoint
    public let button: DesktopMouseButton
    public let clickCount: Int

    public init(point: DesktopPoint, button: DesktopMouseButton, clickCount: Int) {
        self.point = point
        self.button = button
        self.clickCount = clickCount
    }
}

public enum DesktopScrollDirection: String, CaseIterable, Codable, Sendable {
    case up
    case down
    case left
    case right
}

public struct DesktopScrollResult: Codable, Equatable, Sendable {
    public let point: DesktopPoint
    public let direction: DesktopScrollDirection
    public let amount: Int

    public init(point: DesktopPoint, direction: DesktopScrollDirection, amount: Int) {
        self.point = point
        self.direction = direction
        self.amount = amount
    }
}

public struct DesktopDragResult: Codable, Equatable, Sendable {
    public let startPoint: DesktopPoint
    public let endPoint: DesktopPoint
    public let button: DesktopMouseButton
    public let steps: Int

    public init(startPoint: DesktopPoint, endPoint: DesktopPoint, button: DesktopMouseButton, steps: Int) {
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.button = button
        self.steps = steps
    }
}

public struct DesktopHotkeyResult: Codable, Equatable, Sendable {
    public let keys: [String]
    public let holdDurationMilliseconds: Int

    public init(keys: [String], holdDurationMilliseconds: Int) {
        self.keys = keys
        self.holdDurationMilliseconds = holdDurationMilliseconds
    }
}

public struct DesktopTypingResult: Codable, Equatable, Sendable {
    public let text: String
    public let characterCount: Int
    public let delayMilliseconds: Int

    public init(text: String, characterCount: Int, delayMilliseconds: Int) {
        self.text = text
        self.characterCount = characterCount
        self.delayMilliseconds = delayMilliseconds
    }
}

public struct DesktopUIAutomationStatus: Codable, Equatable, Sendable {
    public let nativeBackend: String
    public let isAvailable: Bool
    public let rootElementAvailable: Bool
    public let error: String?

    public init(
        nativeBackend: String,
        isAvailable: Bool,
        rootElementAvailable: Bool,
        error: String? = nil)
    {
        self.nativeBackend = nativeBackend
        self.isAvailable = isAvailable
        self.rootElementAvailable = rootElementAvailable
        self.error = error
    }
}

public enum DesktopUIAutomationSnapshotScope: String, CaseIterable, Codable, Sendable {
    case root
    case foreground
}

public struct DesktopUIAutomationElementSnapshot: Codable, Equatable, Sendable {
    public let index: Int
    public let parentIndex: Int?
    public let depth: Int
    public let name: String?
    public let automationIdentifier: String?
    public let className: String?
    public let localizedControlType: String?
    public let controlType: Int
    public let processIdentifier: UInt32?
    public let nativeWindowHandle: UInt64?
    public let bounds: DesktopRect?
    public let childCount: Int

    public init(
        index: Int,
        parentIndex: Int?,
        depth: Int,
        name: String? = nil,
        automationIdentifier: String? = nil,
        className: String? = nil,
        localizedControlType: String? = nil,
        controlType: Int = 0,
        processIdentifier: UInt32? = nil,
        nativeWindowHandle: UInt64? = nil,
        bounds: DesktopRect? = nil,
        childCount: Int = 0)
    {
        self.index = index
        self.parentIndex = parentIndex
        self.depth = depth
        self.name = name
        self.automationIdentifier = automationIdentifier
        self.className = className
        self.localizedControlType = localizedControlType
        self.controlType = controlType
        self.processIdentifier = processIdentifier
        self.nativeWindowHandle = nativeWindowHandle
        self.bounds = bounds
        self.childCount = childCount
    }
}

public struct DesktopUIAutomationSnapshot: Codable, Equatable, Sendable {
    public let nativeBackend: String
    public let scope: DesktopUIAutomationSnapshotScope
    public let maxDepth: Int
    public let maxElements: Int
    public let elementCount: Int
    public let didTruncate: Bool
    public let elements: [DesktopUIAutomationElementSnapshot]
    public let error: String?

    public init(
        nativeBackend: String,
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementCount: Int,
        didTruncate: Bool,
        elements: [DesktopUIAutomationElementSnapshot],
        error: String? = nil)
    {
        self.nativeBackend = nativeBackend
        self.scope = scope
        self.maxDepth = maxDepth
        self.maxElements = maxElements
        self.elementCount = elementCount
        self.didTruncate = didTruncate
        self.elements = elements
        self.error = error
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
