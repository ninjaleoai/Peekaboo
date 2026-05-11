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
    case focusUIAutomationElement
    case invokeUIAutomation
    case performUIAutomationLegacyDefaultAction
    case setUIAutomationLegacyValue
    case setUIAutomationValue
    case toggleUIAutomation
    case expandCollapseUIAutomation
    case selectUIAutomationItem
    case addUIAutomationItemToSelection
    case removeUIAutomationItemFromSelection
    case setUIAutomationRangeValue
    case setUIAutomationScrollPercent
    case setUIAutomationWindowVisualState
    case closeUIAutomationWindow
    case waitForUIAutomationWindowInputIdle
    case setUIAutomationDockPosition
    case moveUIAutomationElement
    case resizeUIAutomationElement
    case rotateUIAutomationElement
    case scrollUIAutomationItemIntoView
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
    case focused
    case cursor
}

public enum DesktopUIAutomationPattern: String, CaseIterable, Codable, Sendable {
    case invoke
    case value
    case rangeValue
    case scroll
    case expandCollapse
    case window
    case dock
    case selection
    case selectionItem
    case text
    case toggle
    case legacyIAccessible
    case grid
    case gridItem
    case transform
    case scrollItem
}

public enum DesktopUIAutomationAction: String, Codable, Equatable, Sendable {
    case focus
    case invoke
    case performLegacyDefaultAction
    case setLegacyValue
    case setValue
    case toggle
    case expand
    case collapse
    case select
    case addToSelection
    case removeFromSelection
    case setRangeValue
    case setScrollPercent
    case setWindowVisualState
    case closeWindow
    case waitForWindowInputIdle
    case setDockPosition
    case move
    case resize
    case rotate
    case scrollIntoView
}

public enum DesktopUIAutomationToggleState: String, Codable, Equatable, Sendable {
    case off
    case on
    case indeterminate
}

public enum DesktopUIAutomationExpandCollapseState: String, Codable, Equatable, Sendable {
    case collapsed
    case expanded
    case partiallyExpanded
    case leafNode
}

public enum DesktopUIAutomationWindowVisualState: String, Codable, Equatable, Sendable {
    case normal
    case maximized
    case minimized
}

public enum DesktopUIAutomationWindowInteractionState: String, Codable, Equatable, Sendable {
    case running
    case closing
    case readyForUserInteraction
    case blockedByModalWindow
    case notResponding
}

public enum DesktopUIAutomationDockPosition: String, Codable, Equatable, Sendable {
    case top
    case left
    case bottom
    case right
    case fill
    case none
}

public enum DesktopUIAutomationSupportedTextSelection: String, Codable, Equatable, Sendable {
    case none
    case single
    case multiple
}

public struct DesktopUIAutomationElementSnapshot: Codable, Equatable, Sendable {
    public let index: Int
    public let parentIndex: Int?
    public let depth: Int
    public let name: String?
    public let automationIdentifier: String?
    public let className: String?
    public let localizedControlType: String?
    public let accessKey: String?
    public let acceleratorKey: String?
    public let frameworkId: String?
    public let helpText: String?
    public let itemStatus: String?
    public let itemType: String?
    public let controlType: Int
    public let controlTypeName: String?
    public let processIdentifier: UInt32?
    public let nativeWindowHandle: UInt64?
    public let bounds: DesktopRect?
    public let isEnabled: Bool?
    public let isKeyboardFocusable: Bool?
    public let hasKeyboardFocus: Bool?
    public let isOffscreen: Bool?
    public let supportedPatterns: [DesktopUIAutomationPattern]
    public let availableActions: [DesktopUIAutomationAction]
    public let value: String?
    public let isValueReadOnly: Bool?
    public let rangeValue: Double?
    public let rangeMinimum: Double?
    public let rangeMaximum: Double?
    public let rangeSmallChange: Double?
    public let rangeLargeChange: Double?
    public let isRangeValueReadOnly: Bool?
    public let horizontalScrollPercent: Double?
    public let verticalScrollPercent: Double?
    public let horizontalScrollViewSize: Double?
    public let verticalScrollViewSize: Double?
    public let isHorizontallyScrollable: Bool?
    public let isVerticallyScrollable: Bool?
    public let toggleState: DesktopUIAutomationToggleState?
    public let expandCollapseState: DesktopUIAutomationExpandCollapseState?
    public let windowVisualState: DesktopUIAutomationWindowVisualState?
    public let windowInteractionState: DesktopUIAutomationWindowInteractionState?
    public let canMaximizeWindow: Bool?
    public let canMinimizeWindow: Bool?
    public let isModalWindow: Bool?
    public let isTopmostWindow: Bool?
    public let dockPosition: DesktopUIAutomationDockPosition?
    public let text: String?
    public let selectedText: String?
    public let selectedTextRangeCount: Int?
    public let visibleText: String?
    public let visibleTextRangeCount: Int?
    public let supportedTextSelection: DesktopUIAutomationSupportedTextSelection?
    public let gridRowCount: Int?
    public let gridColumnCount: Int?
    public let gridItemRow: Int?
    public let gridItemColumn: Int?
    public let gridItemRowSpan: Int?
    public let gridItemColumnSpan: Int?
    public let selectionCanSelectMultiple: Bool?
    public let selectionIsRequired: Bool?
    public let selectionSelectedItemCount: Int?
    public let canMove: Bool?
    public let canResize: Bool?
    public let canRotate: Bool?
    public let legacyChildId: Int?
    public let legacyName: String?
    public let legacyValue: String?
    public let legacyDescription: String?
    public let legacyHelp: String?
    public let legacyKeyboardShortcut: String?
    public let legacyDefaultAction: String?
    public let legacyRole: Int?
    public let legacyState: Int?
    public let isSelected: Bool?
    public let childCount: Int

    public init(
        index: Int,
        parentIndex: Int?,
        depth: Int,
        name: String? = nil,
        automationIdentifier: String? = nil,
        className: String? = nil,
        localizedControlType: String? = nil,
        accessKey: String? = nil,
        acceleratorKey: String? = nil,
        frameworkId: String? = nil,
        helpText: String? = nil,
        itemStatus: String? = nil,
        itemType: String? = nil,
        controlType: Int = 0,
        controlTypeName: String? = nil,
        processIdentifier: UInt32? = nil,
        nativeWindowHandle: UInt64? = nil,
        bounds: DesktopRect? = nil,
        isEnabled: Bool? = nil,
        isKeyboardFocusable: Bool? = nil,
        hasKeyboardFocus: Bool? = nil,
        isOffscreen: Bool? = nil,
        supportedPatterns: [DesktopUIAutomationPattern] = [],
        availableActions: [DesktopUIAutomationAction] = [],
        value: String? = nil,
        isValueReadOnly: Bool? = nil,
        rangeValue: Double? = nil,
        rangeMinimum: Double? = nil,
        rangeMaximum: Double? = nil,
        rangeSmallChange: Double? = nil,
        rangeLargeChange: Double? = nil,
        isRangeValueReadOnly: Bool? = nil,
        horizontalScrollPercent: Double? = nil,
        verticalScrollPercent: Double? = nil,
        horizontalScrollViewSize: Double? = nil,
        verticalScrollViewSize: Double? = nil,
        isHorizontallyScrollable: Bool? = nil,
        isVerticallyScrollable: Bool? = nil,
        toggleState: DesktopUIAutomationToggleState? = nil,
        expandCollapseState: DesktopUIAutomationExpandCollapseState? = nil,
        windowVisualState: DesktopUIAutomationWindowVisualState? = nil,
        windowInteractionState: DesktopUIAutomationWindowInteractionState? = nil,
        canMaximizeWindow: Bool? = nil,
        canMinimizeWindow: Bool? = nil,
        isModalWindow: Bool? = nil,
        isTopmostWindow: Bool? = nil,
        dockPosition: DesktopUIAutomationDockPosition? = nil,
        text: String? = nil,
        selectedText: String? = nil,
        selectedTextRangeCount: Int? = nil,
        visibleText: String? = nil,
        visibleTextRangeCount: Int? = nil,
        supportedTextSelection: DesktopUIAutomationSupportedTextSelection? = nil,
        gridRowCount: Int? = nil,
        gridColumnCount: Int? = nil,
        gridItemRow: Int? = nil,
        gridItemColumn: Int? = nil,
        gridItemRowSpan: Int? = nil,
        gridItemColumnSpan: Int? = nil,
        selectionCanSelectMultiple: Bool? = nil,
        selectionIsRequired: Bool? = nil,
        selectionSelectedItemCount: Int? = nil,
        canMove: Bool? = nil,
        canResize: Bool? = nil,
        canRotate: Bool? = nil,
        legacyChildId: Int? = nil,
        legacyName: String? = nil,
        legacyValue: String? = nil,
        legacyDescription: String? = nil,
        legacyHelp: String? = nil,
        legacyKeyboardShortcut: String? = nil,
        legacyDefaultAction: String? = nil,
        legacyRole: Int? = nil,
        legacyState: Int? = nil,
        isSelected: Bool? = nil,
        childCount: Int = 0)
    {
        self.index = index
        self.parentIndex = parentIndex
        self.depth = depth
        self.name = name
        self.automationIdentifier = automationIdentifier
        self.className = className
        self.localizedControlType = localizedControlType
        self.accessKey = accessKey
        self.acceleratorKey = acceleratorKey
        self.frameworkId = frameworkId
        self.helpText = helpText
        self.itemStatus = itemStatus
        self.itemType = itemType
        self.controlType = controlType
        self.controlTypeName = controlTypeName
        self.processIdentifier = processIdentifier
        self.nativeWindowHandle = nativeWindowHandle
        self.bounds = bounds
        self.isEnabled = isEnabled
        self.isKeyboardFocusable = isKeyboardFocusable
        self.hasKeyboardFocus = hasKeyboardFocus
        self.isOffscreen = isOffscreen
        self.supportedPatterns = supportedPatterns
        self.availableActions = availableActions
        self.value = value
        self.isValueReadOnly = isValueReadOnly
        self.rangeValue = rangeValue
        self.rangeMinimum = rangeMinimum
        self.rangeMaximum = rangeMaximum
        self.rangeSmallChange = rangeSmallChange
        self.rangeLargeChange = rangeLargeChange
        self.isRangeValueReadOnly = isRangeValueReadOnly
        self.horizontalScrollPercent = horizontalScrollPercent
        self.verticalScrollPercent = verticalScrollPercent
        self.horizontalScrollViewSize = horizontalScrollViewSize
        self.verticalScrollViewSize = verticalScrollViewSize
        self.isHorizontallyScrollable = isHorizontallyScrollable
        self.isVerticallyScrollable = isVerticallyScrollable
        self.toggleState = toggleState
        self.expandCollapseState = expandCollapseState
        self.windowVisualState = windowVisualState
        self.windowInteractionState = windowInteractionState
        self.canMaximizeWindow = canMaximizeWindow
        self.canMinimizeWindow = canMinimizeWindow
        self.isModalWindow = isModalWindow
        self.isTopmostWindow = isTopmostWindow
        self.dockPosition = dockPosition
        self.text = text
        self.selectedText = selectedText
        self.selectedTextRangeCount = selectedTextRangeCount
        self.visibleText = visibleText
        self.visibleTextRangeCount = visibleTextRangeCount
        self.supportedTextSelection = supportedTextSelection
        self.gridRowCount = gridRowCount
        self.gridColumnCount = gridColumnCount
        self.gridItemRow = gridItemRow
        self.gridItemColumn = gridItemColumn
        self.gridItemRowSpan = gridItemRowSpan
        self.gridItemColumnSpan = gridItemColumnSpan
        self.selectionCanSelectMultiple = selectionCanSelectMultiple
        self.selectionIsRequired = selectionIsRequired
        self.selectionSelectedItemCount = selectionSelectedItemCount
        self.canMove = canMove
        self.canResize = canResize
        self.canRotate = canRotate
        self.legacyChildId = legacyChildId
        self.legacyName = legacyName
        self.legacyValue = legacyValue
        self.legacyDescription = legacyDescription
        self.legacyHelp = legacyHelp
        self.legacyKeyboardShortcut = legacyKeyboardShortcut
        self.legacyDefaultAction = legacyDefaultAction
        self.legacyRole = legacyRole
        self.legacyState = legacyState
        self.isSelected = isSelected
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

public struct DesktopUIAutomationElementLookup: Codable, Equatable, Sendable {
    public let nativeBackend: String
    public let scope: DesktopUIAutomationSnapshotScope
    public let maxDepth: Int
    public let maxElements: Int
    public let elementCount: Int
    public let didTruncate: Bool
    public let elementIndex: Int
    public let element: DesktopUIAutomationElementSnapshot

    public init(
        nativeBackend: String,
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementCount: Int,
        didTruncate: Bool,
        elementIndex: Int,
        element: DesktopUIAutomationElementSnapshot)
    {
        self.nativeBackend = nativeBackend
        self.scope = scope
        self.maxDepth = maxDepth
        self.maxElements = maxElements
        self.elementCount = elementCount
        self.didTruncate = didTruncate
        self.elementIndex = elementIndex
        self.element = element
    }
}

public struct DesktopUIAutomationActionResult: Codable, Equatable, Sendable {
    public let nativeBackend: String
    public let action: DesktopUIAutomationAction
    public let scope: DesktopUIAutomationSnapshotScope
    public let maxDepth: Int
    public let maxElements: Int
    public let elementIndex: Int
    public let element: DesktopUIAutomationElementSnapshot
    public let value: String?
    public let postActionElement: DesktopUIAutomationElementSnapshot?
    public let valueWasVerified: Bool?

    public init(
        nativeBackend: String,
        action: DesktopUIAutomationAction,
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        element: DesktopUIAutomationElementSnapshot,
        value: String? = nil,
        postActionElement: DesktopUIAutomationElementSnapshot? = nil,
        valueWasVerified: Bool? = nil)
    {
        self.nativeBackend = nativeBackend
        self.action = action
        self.scope = scope
        self.maxDepth = maxDepth
        self.maxElements = maxElements
        self.elementIndex = elementIndex
        self.element = element
        self.value = value
        self.postActionElement = postActionElement
        self.valueWasVerified = valueWasVerified
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
