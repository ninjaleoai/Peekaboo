#if os(Windows)
import Foundation
import PeekabooDesktop
import PeekabooWin11Interop
import WinSDK

public struct Win32DesktopAdapter: Win11DesktopAdapter {
    public init() {}

    public func platformInfo() -> Win11PlatformInfo {
        Win11PlatformInfo(
            name: "Windows",
            minimumSystemVersion: "Windows 11",
            nativeBackend: "Win32",
            capabilities: [
                .enumerateApplications,
                .enumerateDisplays,
                .enumerateWindows,
                .captureScreenBMP,
                .captureAreaBMP,
                .captureWindowBMP,
                .captureFrontmostBMP,
                .readCursorPosition,
                .moveCursor,
                .clickMouse,
                .scrollMouse,
                .dragMouse,
                .sendHotkey,
                .typeText,
                .inspectUIAutomation,
                .focusUIAutomationElement,
                .invokeUIAutomation,
                .performUIAutomationLegacyDefaultAction,
                .setUIAutomationLegacyValue,
                .setUIAutomationValue,
                .getUIAutomationText,
                .toggleUIAutomation,
                .expandCollapseUIAutomation,
                .selectUIAutomationItem,
                .addUIAutomationItemToSelection,
                .removeUIAutomationItemFromSelection,
                .setUIAutomationRangeValue,
                .setUIAutomationScrollPercent,
                .setUIAutomationWindowVisualState,
                .closeUIAutomationWindow,
                .waitForUIAutomationWindowInputIdle,
                .setUIAutomationDockPosition,
                .setUIAutomationCurrentView,
                .setUIAutomationZoomLevel,
                .zoomUIAutomationElementByUnit,
                .startUIAutomationSynchronizedInput,
                .cancelUIAutomationSynchronizedInput,
                .navigateUIAutomationCustom,
                .findUIAutomationItemByProperty,
                .getUIAutomationSpreadsheetItemByName,
                .getUIAutomationGridItem,
                .moveUIAutomationElement,
                .resizeUIAutomationElement,
                .rotateUIAutomationElement,
                .realizeUIAutomationVirtualizedItem,
                .scrollUIAutomationItemIntoView,
            ])
    }

    public func listDisplays() throws -> [Win11Display] {
        let collector = DisplayCollector()
        let context = Unmanaged.passUnretained(collector).toOpaque()

        guard EnumDisplayMonitors(nil, nil, displayEnumerationCallback, LPARAM(Int(bitPattern: context))) else {
            throw Win11DesktopError.nativeCallFailed("EnumDisplayMonitors")
        }

        return collector.displays
    }

    public func listWindows(includeInvisible: Bool = false) throws -> [Win11Window] {
        let collector = WindowCollector(includeInvisible: includeInvisible)
        let context = Unmanaged.passUnretained(collector).toOpaque()

        guard EnumWindows(windowEnumerationCallback, LPARAM(Int(bitPattern: context))) else {
            throw Win11DesktopError.nativeCallFailed("EnumWindows")
        }

        return collector.windows
    }

    public func listApplications() throws -> [Win11Application] {
        let foregroundWindow = GetForegroundWindow()
        let windows = try self.listWindows(includeInvisible: false)
        let grouped = Dictionary(grouping: windows, by: \.processIdentifier)

        return grouped.map { pid, windows in
            let executablePath = Self.executablePath(processIdentifier: pid)
            let executableName = executablePath.map(Self.lastPathComponent) ??
                windows.compactMap(\.executableName).first ??
                "pid-\(pid)"
            let foregroundPid = Self.processIdentifier(for: foregroundWindow)
            return Win11Application(
                processIdentifier: pid,
                executableName: executableName,
                executablePath: executablePath,
                isActive: foregroundPid == pid,
                visibleWindowCount: windows.count)
        }
        .sorted { lhs, rhs in
            lhs.executableName.lowercased() < rhs.executableName.lowercased()
        }
    }

    public func captureScreen(displayIndex: Int?, outputPath: String) throws -> Win11CaptureResult {
        let bounds: Win11Rect
        if let displayIndex {
            let displays = try self.listDisplays()
            guard let display = displays.first(where: { $0.index == displayIndex }) else {
                throw Win11DesktopError.displayNotFound(displayIndex)
            }
            bounds = display.bounds
        } else {
            bounds = Self.virtualScreenBounds()
        }

        guard !bounds.isEmpty else {
            throw Win11DesktopError.emptyCaptureRegion(bounds)
        }

        return try Self.captureRegion(bounds: bounds, outputPath: outputPath)
    }

    public func captureArea(_ rect: Win11Rect, outputPath: String) throws -> Win11CaptureResult {
        guard !rect.isEmpty else {
            throw Win11DesktopError.emptyCaptureRegion(rect)
        }

        return try Self.captureRegion(bounds: rect, outputPath: outputPath)
    }

    public func captureWindow(windowIdentifier: UInt64, outputPath: String) throws -> Win11CaptureResult {
        let windows = try self.listWindows(includeInvisible: true)
        guard let window = windows.first(where: { $0.windowIdentifier == windowIdentifier }) else {
            throw Win11DesktopError.invalidArgument("Window not found: \(windowIdentifier)")
        }
        guard !window.bounds.isEmpty else {
            throw Win11DesktopError.emptyCaptureRegion(window.bounds)
        }

        return try self.captureArea(window.bounds, outputPath: outputPath)
    }

    public func captureFrontmost(outputPath: String) throws -> Win11CaptureResult {
        guard let hwnd = GetForegroundWindow() else {
            throw Win11DesktopError.invalidArgument("No foreground window is available")
        }

        var rect = RECT()
        guard GetWindowRect(hwnd, &rect) else {
            throw Win11DesktopError.nativeCallFailed("GetWindowRect")
        }

        let bounds = Self.rect(from: rect)
        guard !bounds.isEmpty else {
            throw Win11DesktopError.emptyCaptureRegion(bounds)
        }

        return try self.captureArea(bounds, outputPath: outputPath)
    }

    public func cursorPosition() throws -> DesktopPoint {
        var point = POINT()
        guard GetCursorPos(&point) else {
            throw Win11DesktopError.nativeCallFailed("GetCursorPos")
        }

        return DesktopPoint(x: Int(point.x), y: Int(point.y))
    }

    public func moveCursor(to point: DesktopPoint) throws -> DesktopPoint {
        guard SetCursorPos(Int32(clamping: point.x), Int32(clamping: point.y)) else {
            throw Win11DesktopError.nativeCallFailed("SetCursorPos")
        }

        return try self.cursorPosition()
    }

    public func click(
        at point: DesktopPoint,
        button: DesktopMouseButton,
        clickCount: Int) throws -> DesktopClickResult
    {
        guard clickCount > 0 else {
            throw Win11DesktopError.invalidArgument("Click count must be a positive integer")
        }

        _ = try self.moveCursor(to: point)
        let flags = Self.mouseButtonFlags(for: button)

        for _ in 0..<clickCount {
            mouse_event(flags.down, 0, 0, 0, 0)
            mouse_event(flags.up, 0, 0, 0, 0)
        }

        return DesktopClickResult(
            point: try self.cursorPosition(),
            button: button,
            clickCount: clickCount)
    }

    private static func mouseButtonFlags(for button: DesktopMouseButton) -> (down: DWORD, up: DWORD) {
        switch button {
        case .left:
            return (DWORD(MOUSEEVENTF_LEFTDOWN), DWORD(MOUSEEVENTF_LEFTUP))
        case .right:
            return (DWORD(MOUSEEVENTF_RIGHTDOWN), DWORD(MOUSEEVENTF_RIGHTUP))
        case .middle:
            return (DWORD(MOUSEEVENTF_MIDDLEDOWN), DWORD(MOUSEEVENTF_MIDDLEUP))
        }
    }

    public func scroll(
        at point: DesktopPoint,
        direction: DesktopScrollDirection,
        amount: Int) throws -> DesktopScrollResult
    {
        guard amount > 0 else {
            throw Win11DesktopError.invalidArgument("Amount must be a positive integer")
        }

        _ = try self.moveCursor(to: point)
        let scroll = Self.mouseScrollEvent(direction: direction, amount: amount)
        mouse_event(scroll.flags, 0, 0, DWORD(bitPattern: scroll.delta), 0)

        return DesktopScrollResult(
            point: try self.cursorPosition(),
            direction: direction,
            amount: amount)
    }

    private static func mouseScrollEvent(
        direction: DesktopScrollDirection,
        amount: Int) -> (flags: DWORD, delta: Int32)
    {
        let wheelDelta = 120
        let detents = min(amount, Int(Int32.max) / wheelDelta)
        let delta = Int32(detents * wheelDelta)

        switch direction {
        case .up:
            return (DWORD(MOUSEEVENTF_WHEEL), delta)
        case .down:
            return (DWORD(MOUSEEVENTF_WHEEL), -delta)
        case .right:
            return (DWORD(MOUSEEVENTF_HWHEEL), delta)
        case .left:
            return (DWORD(MOUSEEVENTF_HWHEEL), -delta)
        }
    }

    public func drag(
        from startPoint: DesktopPoint,
        to endPoint: DesktopPoint,
        button: DesktopMouseButton,
        steps: Int) throws -> DesktopDragResult
    {
        guard steps > 0 else {
            throw Win11DesktopError.invalidArgument("Steps must be a positive integer")
        }

        _ = try self.moveCursor(to: startPoint)
        let flags = Self.mouseButtonFlags(for: button)
        mouse_event(flags.down, 0, 0, 0, 0)
        defer {
            mouse_event(flags.up, 0, 0, 0, 0)
        }

        for step in 1...steps {
            let point = Self.dragPoint(
                from: startPoint,
                to: endPoint,
                step: step,
                steps: steps)
            _ = try self.moveCursor(to: point)
        }

        return DesktopDragResult(
            startPoint: startPoint,
            endPoint: try self.cursorPosition(),
            button: button,
            steps: steps)
    }

    private static func dragPoint(
        from startPoint: DesktopPoint,
        to endPoint: DesktopPoint,
        step: Int,
        steps: Int) -> DesktopPoint
    {
        let progress = Double(step) / Double(steps)
        let x = Double(startPoint.x) + (Double(endPoint.x - startPoint.x) * progress)
        let y = Double(startPoint.y) + (Double(endPoint.y - startPoint.y) * progress)
        return DesktopPoint(x: Int(x.rounded()), y: Int(y.rounded()))
    }

    public func hotkey(keys: [String], holdDurationMilliseconds: Int) throws -> DesktopHotkeyResult {
        guard !keys.isEmpty else {
            throw Win11DesktopError.invalidArgument("Hotkey requires at least one key")
        }
        guard holdDurationMilliseconds >= 0 else {
            throw Win11DesktopError.invalidArgument("Hold duration must be a non-negative integer")
        }

        let resolvedKeys = try keys.map { try Self.virtualKey(for: $0) }
        for key in resolvedKeys {
            Self.sendKey(key, flags: 0)
        }
        defer {
            for key in resolvedKeys.reversed() {
                Self.sendKey(key, flags: DWORD(KEYEVENTF_KEYUP))
            }
        }

        if holdDurationMilliseconds > 0 {
            Thread.sleep(forTimeInterval: Double(holdDurationMilliseconds) / 1_000)
        }

        return DesktopHotkeyResult(
            keys: resolvedKeys.map(\.name),
            holdDurationMilliseconds: holdDurationMilliseconds)
    }

    private static func sendKey(_ key: Win32VirtualKey, flags: DWORD) {
        keybd_event(key.virtualKey, 0, flags, 0)
    }

    private static func virtualKey(for name: String) throws -> Win32VirtualKey {
        let normalized = name
            .lowercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")

        if let key = Self.namedVirtualKey(normalized) {
            return key
        }

        if normalized.count == 1, let scalar = normalized.unicodeScalars.first {
            let value = scalar.value
            if (48...57).contains(value) || (65...90).contains(value) {
                return Win32VirtualKey(name: normalized, virtualKey: BYTE(value))
            }
            if (97...122).contains(value) {
                return Win32VirtualKey(name: normalized, virtualKey: BYTE(value - 32))
            }
        }

        if normalized.first == "f",
           let number = Int(normalized.dropFirst()),
           (1...24).contains(number)
        {
            return Win32VirtualKey(name: normalized, virtualKey: BYTE(0x70 + number - 1))
        }

        throw Win11DesktopError.invalidArgument("Unsupported hotkey: \(name)")
    }

    private static func namedVirtualKey(_ normalized: String) -> Win32VirtualKey? {
        switch normalized {
        case "ctrl", "control":
            return Win32VirtualKey(name: "ctrl", virtualKey: 0x11)
        case "shift":
            return Win32VirtualKey(name: "shift", virtualKey: 0x10)
        case "alt", "option":
            return Win32VirtualKey(name: "alt", virtualKey: 0x12)
        case "win", "windows", "meta", "cmd", "command":
            return Win32VirtualKey(name: "win", virtualKey: 0x5B)
        case "enter", "return":
            return Win32VirtualKey(name: "enter", virtualKey: 0x0D)
        case "tab":
            return Win32VirtualKey(name: "tab", virtualKey: 0x09)
        case "esc", "escape":
            return Win32VirtualKey(name: "escape", virtualKey: 0x1B)
        case "space", "spacebar":
            return Win32VirtualKey(name: "space", virtualKey: 0x20)
        case "backspace", "bksp":
            return Win32VirtualKey(name: "backspace", virtualKey: 0x08)
        case "delete", "del":
            return Win32VirtualKey(name: "delete", virtualKey: 0x2E)
        case "insert", "ins":
            return Win32VirtualKey(name: "insert", virtualKey: 0x2D)
        case "home":
            return Win32VirtualKey(name: "home", virtualKey: 0x24)
        case "end":
            return Win32VirtualKey(name: "end", virtualKey: 0x23)
        case "pageup", "pgup":
            return Win32VirtualKey(name: "pageup", virtualKey: 0x21)
        case "pagedown", "pgdn":
            return Win32VirtualKey(name: "pagedown", virtualKey: 0x22)
        case "left", "arrowleft":
            return Win32VirtualKey(name: "left", virtualKey: 0x25)
        case "up", "arrowup":
            return Win32VirtualKey(name: "up", virtualKey: 0x26)
        case "right", "arrowright":
            return Win32VirtualKey(name: "right", virtualKey: 0x27)
        case "down", "arrowdown":
            return Win32VirtualKey(name: "down", virtualKey: 0x28)
        default:
            return nil
        }
    }

    public func typeText(_ text: String, delayMilliseconds: Int) throws -> DesktopTypingResult {
        guard !text.isEmpty else {
            throw Win11DesktopError.invalidArgument("Text must not be empty")
        }
        guard delayMilliseconds >= 0 else {
            throw Win11DesktopError.invalidArgument("Typing delay must be a non-negative integer")
        }

        for character in text {
            try Self.typeCharacter(character)
            if delayMilliseconds > 0 {
                Thread.sleep(forTimeInterval: Double(delayMilliseconds) / 1_000)
            }
        }

        return DesktopTypingResult(
            text: text,
            characterCount: text.count,
            delayMilliseconds: delayMilliseconds)
    }

    private static func typeCharacter(_ character: Character) throws {
        switch character {
        case "\n", "\r":
            Self.tapKey(Win32VirtualKey(name: "enter", virtualKey: 0x0D))
            return
        case "\t":
            Self.tapKey(Win32VirtualKey(name: "tab", virtualKey: 0x09))
            return
        default:
            break
        }

        let scalars = Array(character.unicodeScalars)
        guard scalars.count == 1, let scalar = scalars.first, scalar.value <= UInt16.max else {
            throw Win11DesktopError.invalidArgument("Unsupported text character: \(character)")
        }

        let translated = VkKeyScanW(WCHAR(scalar.value))
        guard translated != -1 else {
            throw Win11DesktopError.invalidArgument("Unsupported text character: \(character)")
        }

        let translatedBits = UInt16(bitPattern: translated)
        let virtualKey = Win32VirtualKey(
            name: String(character),
            virtualKey: BYTE(translatedBits & 0x00FF))
        let modifiers = try Self.modifierKeys(forShiftState: (translatedBits >> 8) & 0x00FF)

        for modifier in modifiers {
            Self.sendKey(modifier, flags: 0)
        }
        defer {
            for modifier in modifiers.reversed() {
                Self.sendKey(modifier, flags: DWORD(KEYEVENTF_KEYUP))
            }
        }

        Self.tapKey(virtualKey)
    }

    private static func modifierKeys(forShiftState shiftState: UInt16) throws -> [Win32VirtualKey] {
        guard (shiftState & 0xF8) == 0 else {
            throw Win11DesktopError.invalidArgument("Unsupported keyboard layout modifier state")
        }

        var modifiers: [Win32VirtualKey] = []
        if (shiftState & 0x01) != 0 {
            modifiers.append(Win32VirtualKey(name: "shift", virtualKey: 0x10))
        }
        if (shiftState & 0x02) != 0 {
            modifiers.append(Win32VirtualKey(name: "ctrl", virtualKey: 0x11))
        }
        if (shiftState & 0x04) != 0 {
            modifiers.append(Win32VirtualKey(name: "alt", virtualKey: 0x12))
        }
        return modifiers
    }

    private static func tapKey(_ key: Win32VirtualKey) {
        Self.sendKey(key, flags: 0)
        Self.sendKey(key, flags: DWORD(KEYEVENTF_KEYUP))
    }

    public func uiAutomationStatus() throws -> DesktopUIAutomationStatus {
        let probe = PeekabooWin11ProbeUIAutomation()
        return DesktopUIAutomationStatus(
            nativeBackend: "UIAutomation",
            isAvailable: probe.isAvailable != 0,
            rootElementAvailable: probe.rootElementAvailable != 0,
            error: Self.uiAutomationError(from: probe))
    }

    public func uiAutomationSnapshot(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int) throws -> DesktopUIAutomationSnapshot
    {
        guard (0...8).contains(maxDepth) else {
            throw Win11DesktopError.invalidArgument("UI Automation max depth must be between 0 and 8")
        }
        guard (1...512).contains(maxElements) else {
            throw Win11DesktopError.invalidArgument("UI Automation max elements must be between 1 and 512")
        }

        var nativeSnapshot = PeekabooWin11CopyUIAutomationSnapshot(
            Self.nativeUIAutomationScope(scope),
            Int32(maxDepth),
            Int32(maxElements))
        defer {
            PeekabooWin11FreeUIAutomationSnapshot(&nativeSnapshot)
        }

        return DesktopUIAutomationSnapshot(
            nativeBackend: "UIAutomation",
            scope: scope,
            maxDepth: Int(nativeSnapshot.maxDepth),
            maxElements: Int(nativeSnapshot.maxElements),
            elementCount: Int(nativeSnapshot.elementCount),
            didTruncate: nativeSnapshot.didTruncate != 0,
            elements: Self.uiAutomationElements(from: nativeSnapshot),
            error: Self.uiAutomationSnapshotError(from: nativeSnapshot))
    }

    public func invokeUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    {
        guard elementIndex >= 0 else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index must be a non-negative integer")
        }

        let snapshot = try self.uiAutomationSnapshot(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements)
        if let error = snapshot.error {
            throw Win11DesktopError.nativeCallFailed(error)
        }
        guard let element = snapshot.elements.first(where: { $0.index == elementIndex }) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) was not found in the bounded snapshot")
        }
        guard element.supportedPatterns.contains(.invoke) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) does not support invoke")
        }

        let nativeResult = PeekabooWin11InvokeUIAutomationElement(
            Self.nativeUIAutomationScope(scope),
            Int32(maxDepth),
            Int32(maxElements),
            Int32(elementIndex))
        try Self.validateUIAutomationInvoke(nativeResult)

        return DesktopUIAutomationActionResult(
            nativeBackend: snapshot.nativeBackend,
            action: .invoke,
            scope: snapshot.scope,
            maxDepth: snapshot.maxDepth,
            maxElements: snapshot.maxElements,
            elementIndex: elementIndex,
            element: element)
    }

    public func focusUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    {
        guard elementIndex >= 0 else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index must be a non-negative integer")
        }

        let snapshot = try self.uiAutomationSnapshot(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements)
        if let error = snapshot.error {
            throw Win11DesktopError.nativeCallFailed(error)
        }
        guard let element = snapshot.elements.first(where: { $0.index == elementIndex }) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) was not found in the bounded snapshot")
        }
        if element.isEnabled == false {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) is not enabled")
        }
        if element.isKeyboardFocusable == false {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) is not keyboard focusable")
        }

        let nativeResult = PeekabooWin11FocusUIAutomationElement(
            Self.nativeUIAutomationScope(scope),
            Int32(maxDepth),
            Int32(maxElements),
            Int32(elementIndex))
        try Self.validateUIAutomationFocus(nativeResult)

        let postActionElement = try? self.refreshedUIAutomationElement(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex)

        return DesktopUIAutomationActionResult(
            nativeBackend: snapshot.nativeBackend,
            action: .focus,
            scope: snapshot.scope,
            maxDepth: snapshot.maxDepth,
            maxElements: snapshot.maxElements,
            elementIndex: elementIndex,
            element: element,
            value: "focused=true",
            postActionElement: postActionElement,
            valueWasVerified: postActionElement?.hasKeyboardFocus.map { $0 == true })
    }

    public func performUIAutomationElementLegacyDefaultAction(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    {
        guard elementIndex >= 0 else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index must be a non-negative integer")
        }

        let snapshot = try self.uiAutomationSnapshot(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements)
        if let error = snapshot.error {
            throw Win11DesktopError.nativeCallFailed(error)
        }
        guard let element = snapshot.elements.first(where: { $0.index == elementIndex }) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) was not found in the bounded snapshot")
        }
        guard element.supportedPatterns.contains(.legacyIAccessible) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) does not support legacy default action")
        }
        guard let defaultAction = element.legacyDefaultAction, !defaultAction.isEmpty else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) has no legacy default action")
        }

        let nativeResult = PeekabooWin11PerformUIAutomationElementLegacyDefaultAction(
            Self.nativeUIAutomationScope(scope),
            Int32(maxDepth),
            Int32(maxElements),
            Int32(elementIndex))
        try Self.validateUIAutomationLegacyDefaultAction(nativeResult)

        let postActionElement = try? self.refreshedUIAutomationElement(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex)

        return DesktopUIAutomationActionResult(
            nativeBackend: snapshot.nativeBackend,
            action: .performLegacyDefaultAction,
            scope: snapshot.scope,
            maxDepth: snapshot.maxDepth,
            maxElements: snapshot.maxElements,
            elementIndex: elementIndex,
            element: element,
            value: defaultAction,
            postActionElement: postActionElement)
    }

    public func setUIAutomationElementLegacyValue(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        value: String) throws -> DesktopUIAutomationActionResult
    {
        guard elementIndex >= 0 else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index must be a non-negative integer")
        }

        let snapshot = try self.uiAutomationSnapshot(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements)
        if let error = snapshot.error {
            throw Win11DesktopError.nativeCallFailed(error)
        }
        guard let element = snapshot.elements.first(where: { $0.index == elementIndex }) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) was not found in the bounded snapshot")
        }
        if element.isEnabled == false {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) is not enabled")
        }
        guard element.supportedPatterns.contains(.legacyIAccessible) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) does not support legacy value")
        }
        guard element.legacyValue != nil else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) has no legacy value")
        }

        let nativeResult = value.withCString { valuePointer in
            PeekabooWin11SetUIAutomationElementLegacyValue(
                Self.nativeUIAutomationScope(scope),
                Int32(maxDepth),
                Int32(maxElements),
                Int32(elementIndex),
                valuePointer)
        }
        try Self.validateUIAutomationSetLegacyValue(nativeResult)

        let postActionElement = try? self.refreshedUIAutomationElement(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex)

        return DesktopUIAutomationActionResult(
            nativeBackend: snapshot.nativeBackend,
            action: .setLegacyValue,
            scope: snapshot.scope,
            maxDepth: snapshot.maxDepth,
            maxElements: snapshot.maxElements,
            elementIndex: elementIndex,
            element: element,
            value: value,
            postActionElement: postActionElement,
            valueWasVerified: postActionElement?.legacyValue.map { $0 == value })
    }

    public func setUIAutomationElementValue(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        value: String) throws -> DesktopUIAutomationActionResult
    {
        guard elementIndex >= 0 else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index must be a non-negative integer")
        }

        let snapshot = try self.uiAutomationSnapshot(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements)
        if let error = snapshot.error {
            throw Win11DesktopError.nativeCallFailed(error)
        }
        guard let element = snapshot.elements.first(where: { $0.index == elementIndex }) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) was not found in the bounded snapshot")
        }
        guard element.supportedPatterns.contains(.value) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) does not support value")
        }
        if element.isEnabled == false {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) value cannot be set because element is disabled")
        }
        if element.isValueReadOnly == true {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) value is read-only")
        }

        let nativeResult = value.withCString { valuePointer in
            PeekabooWin11SetUIAutomationElementValue(
                Self.nativeUIAutomationScope(scope),
                Int32(maxDepth),
                Int32(maxElements),
                Int32(elementIndex),
                valuePointer)
        }
        try Self.validateUIAutomationSetValue(nativeResult)

        let postActionElement = try? self.refreshedUIAutomationElement(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex)

        return DesktopUIAutomationActionResult(
            nativeBackend: snapshot.nativeBackend,
            action: .setValue,
            scope: snapshot.scope,
            maxDepth: snapshot.maxDepth,
            maxElements: snapshot.maxElements,
            elementIndex: elementIndex,
            element: element,
            value: value,
            postActionElement: postActionElement,
            valueWasVerified: postActionElement?.value.map { $0 == value })
    }

    public func getUIAutomationText(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        source: DesktopUIAutomationTextSource,
        maxLength: Int) throws -> DesktopUIAutomationActionResult
    {
        guard elementIndex >= 0 else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index must be a non-negative integer")
        }
        guard (1...4096).contains(maxLength) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation text max length must be between 1 and 4096")
        }

        let snapshot = try self.uiAutomationSnapshot(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements)
        if let error = snapshot.error {
            throw Win11DesktopError.nativeCallFailed(error)
        }
        guard let element = snapshot.elements.first(where: { $0.index == elementIndex }) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) was not found in the bounded snapshot")
        }
        guard element.supportedPatterns.contains(.text) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) does not support text")
        }

        var nativeResult = PeekabooWin11GetUIAutomationText(
            Self.nativeUIAutomationScope(scope),
            Int32(maxDepth),
            Int32(maxElements),
            Int32(elementIndex),
            Self.nativeTextSource(source),
            Int32(maxLength))
        try Self.validateUIAutomationGetText(nativeResult)

        let text = nativeResult.hasTextResult != 0
            ? Self.rawString(from: PeekabooWin11UIAutomationActionTextResult(&nativeResult))
            : ""

        return DesktopUIAutomationActionResult(
            nativeBackend: snapshot.nativeBackend,
            action: .getText,
            scope: snapshot.scope,
            maxDepth: snapshot.maxDepth,
            maxElements: snapshot.maxElements,
            elementIndex: elementIndex,
            element: element,
            value: text,
            valueWasVerified: Self.textResultWasVerified(
                result: text,
                maxLength: maxLength,
                source: source,
                element: element))
    }

    public func setUIAutomationElementRangeValue(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        value: Double) throws -> DesktopUIAutomationActionResult
    {
        guard elementIndex >= 0 else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index must be a non-negative integer")
        }
        guard value.isFinite else {
            throw Win11DesktopError.invalidArgument("UI Automation range value must be a finite number")
        }

        let snapshot = try self.uiAutomationSnapshot(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements)
        if let error = snapshot.error {
            throw Win11DesktopError.nativeCallFailed(error)
        }
        guard let element = snapshot.elements.first(where: { $0.index == elementIndex }) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) was not found in the bounded snapshot")
        }
        guard element.supportedPatterns.contains(.rangeValue) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) does not support range value")
        }
        if element.isRangeValueReadOnly == true {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) range value is read-only")
        }
        if let minimum = element.rangeMinimum, value < minimum {
            throw Win11DesktopError.invalidArgument(
                "UI Automation range value \(value) is below minimum \(minimum)")
        }
        if let maximum = element.rangeMaximum, value > maximum {
            throw Win11DesktopError.invalidArgument(
                "UI Automation range value \(value) is above maximum \(maximum)")
        }

        let nativeResult = PeekabooWin11SetUIAutomationElementRangeValue(
            Self.nativeUIAutomationScope(scope),
            Int32(maxDepth),
            Int32(maxElements),
            Int32(elementIndex),
            value)
        try Self.validateUIAutomationSetRangeValue(nativeResult)

        let postActionElement = try? self.refreshedUIAutomationElement(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex)

        return DesktopUIAutomationActionResult(
            nativeBackend: snapshot.nativeBackend,
            action: .setRangeValue,
            scope: snapshot.scope,
            maxDepth: snapshot.maxDepth,
            maxElements: snapshot.maxElements,
            elementIndex: elementIndex,
            element: element,
            value: Self.rangeValueString(value),
            postActionElement: postActionElement,
            valueWasVerified: postActionElement?.rangeValue.map {
                abs($0 - value) <= 0.000_001
            })
    }

    public func setUIAutomationElementScrollPercent(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        horizontalPercent: Double?,
        verticalPercent: Double?) throws -> DesktopUIAutomationActionResult
    {
        guard elementIndex >= 0 else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index must be a non-negative integer")
        }
        guard horizontalPercent != nil || verticalPercent != nil else {
            throw Win11DesktopError.invalidArgument(
                "At least one UI Automation scroll percent axis must be provided")
        }
        try Self.validateScrollPercent(horizontalPercent, axisName: "horizontal")
        try Self.validateScrollPercent(verticalPercent, axisName: "vertical")

        let snapshot = try self.uiAutomationSnapshot(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements)
        if let error = snapshot.error {
            throw Win11DesktopError.nativeCallFailed(error)
        }
        guard let element = snapshot.elements.first(where: { $0.index == elementIndex }) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) was not found in the bounded snapshot")
        }
        guard element.supportedPatterns.contains(.scroll) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) does not support scroll")
        }
        if horizontalPercent != nil, element.isHorizontallyScrollable == false {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) cannot scroll horizontally")
        }
        if verticalPercent != nil, element.isVerticallyScrollable == false {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) cannot scroll vertically")
        }

        let nativeResult = PeekabooWin11SetUIAutomationElementScrollPercent(
            Self.nativeUIAutomationScope(scope),
            Int32(maxDepth),
            Int32(maxElements),
            Int32(elementIndex),
            horizontalPercent ?? Self.noScrollPercent,
            verticalPercent ?? Self.noScrollPercent)
        try Self.validateUIAutomationSetScrollPercent(nativeResult)

        let postActionElement = try? self.refreshedUIAutomationElement(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex)

        return DesktopUIAutomationActionResult(
            nativeBackend: snapshot.nativeBackend,
            action: .setScrollPercent,
            scope: snapshot.scope,
            maxDepth: snapshot.maxDepth,
            maxElements: snapshot.maxElements,
            elementIndex: elementIndex,
            element: element,
            value: Self.scrollPercentString(
                horizontalPercent: horizontalPercent,
                verticalPercent: verticalPercent),
            postActionElement: postActionElement,
            valueWasVerified: Self.scrollPercentWasVerified(
                postActionElement: postActionElement,
                horizontalPercent: horizontalPercent,
                verticalPercent: verticalPercent))
    }

    public func setUIAutomationElementWindowVisualState(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        state: DesktopUIAutomationWindowVisualState) throws -> DesktopUIAutomationActionResult
    {
        guard elementIndex >= 0 else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index must be a non-negative integer")
        }

        let snapshot = try self.uiAutomationSnapshot(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements)
        if let error = snapshot.error {
            throw Win11DesktopError.nativeCallFailed(error)
        }
        guard let element = snapshot.elements.first(where: { $0.index == elementIndex }) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) was not found in the bounded snapshot")
        }
        guard element.supportedPatterns.contains(.window) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) does not support window state")
        }
        if state == .maximized, element.canMaximizeWindow == false {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) cannot be maximized")
        }
        if state == .minimized, element.canMinimizeWindow == false {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) cannot be minimized")
        }

        let nativeResult = PeekabooWin11SetUIAutomationElementWindowVisualState(
            Self.nativeUIAutomationScope(scope),
            Int32(maxDepth),
            Int32(maxElements),
            Int32(elementIndex),
            Self.nativeWindowVisualState(state))
        try Self.validateUIAutomationSetWindowVisualState(nativeResult)

        let postActionElement = try? self.refreshedUIAutomationElement(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex)

        return DesktopUIAutomationActionResult(
            nativeBackend: snapshot.nativeBackend,
            action: .setWindowVisualState,
            scope: snapshot.scope,
            maxDepth: snapshot.maxDepth,
            maxElements: snapshot.maxElements,
            elementIndex: elementIndex,
            element: element,
            value: state.rawValue,
            postActionElement: postActionElement,
            valueWasVerified: postActionElement?.windowVisualState.map { $0 == state })
    }

    public func closeUIAutomationWindow(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    {
        guard elementIndex >= 0 else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index must be a non-negative integer")
        }

        let snapshot = try self.uiAutomationSnapshot(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements)
        if let error = snapshot.error {
            throw Win11DesktopError.nativeCallFailed(error)
        }
        guard let element = snapshot.elements.first(where: { $0.index == elementIndex }) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) was not found in the bounded snapshot")
        }
        guard element.supportedPatterns.contains(.window) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) does not support window close")
        }

        let nativeResult = PeekabooWin11CloseUIAutomationWindow(
            Self.nativeUIAutomationScope(scope),
            Int32(maxDepth),
            Int32(maxElements),
            Int32(elementIndex))
        try Self.validateUIAutomationCloseWindow(nativeResult)

        let refreshedSnapshot = try? self.uiAutomationSnapshot(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements)
        let postActionSnapshot: DesktopUIAutomationSnapshot?
        if let refreshedSnapshot, refreshedSnapshot.error == nil {
            postActionSnapshot = refreshedSnapshot
        } else {
            postActionSnapshot = nil
        }
        let postActionElement = element.nativeWindowHandle.flatMap { nativeWindowHandle in
            postActionSnapshot?.elements.first { $0.nativeWindowHandle == nativeWindowHandle }
        }
        let valueWasVerified = element.nativeWindowHandle.flatMap { nativeWindowHandle in
            postActionSnapshot.map { snapshot in
                !snapshot.elements.contains { $0.nativeWindowHandle == nativeWindowHandle }
            }
        }

        return DesktopUIAutomationActionResult(
            nativeBackend: snapshot.nativeBackend,
            action: .closeWindow,
            scope: snapshot.scope,
            maxDepth: snapshot.maxDepth,
            maxElements: snapshot.maxElements,
            elementIndex: elementIndex,
            element: element,
            value: "closed=true",
            postActionElement: postActionElement,
            valueWasVerified: valueWasVerified)
    }

    public func waitForUIAutomationWindowInputIdle(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        timeoutMilliseconds: Int) throws -> DesktopUIAutomationActionResult
    {
        guard elementIndex >= 0 else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index must be a non-negative integer")
        }
        guard (0...60_000).contains(timeoutMilliseconds) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation timeout milliseconds must be between 0 and 60000")
        }

        let snapshot = try self.uiAutomationSnapshot(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements)
        if let error = snapshot.error {
            throw Win11DesktopError.nativeCallFailed(error)
        }
        guard let element = snapshot.elements.first(where: { $0.index == elementIndex }) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) was not found in the bounded snapshot")
        }
        guard element.supportedPatterns.contains(.window) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) does not support window input idle wait")
        }

        let nativeResult = PeekabooWin11WaitForUIAutomationWindowInputIdle(
            Self.nativeUIAutomationScope(scope),
            Int32(maxDepth),
            Int32(maxElements),
            Int32(elementIndex),
            Int32(timeoutMilliseconds))
        try Self.validateUIAutomationWaitForWindowInputIdle(nativeResult)

        let didBecomeIdle = nativeResult.boolResult != 0
        let postActionElement = try? self.refreshedUIAutomationElement(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex)

        return DesktopUIAutomationActionResult(
            nativeBackend: snapshot.nativeBackend,
            action: .waitForWindowInputIdle,
            scope: snapshot.scope,
            maxDepth: snapshot.maxDepth,
            maxElements: snapshot.maxElements,
            elementIndex: elementIndex,
            element: element,
            value: "timeoutMilliseconds=\(timeoutMilliseconds),idle=\(didBecomeIdle)",
            postActionElement: postActionElement,
            valueWasVerified: didBecomeIdle)
    }

    public func setUIAutomationElementDockPosition(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        position: DesktopUIAutomationDockPosition) throws -> DesktopUIAutomationActionResult
    {
        guard elementIndex >= 0 else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index must be a non-negative integer")
        }

        let snapshot = try self.uiAutomationSnapshot(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements)
        if let error = snapshot.error {
            throw Win11DesktopError.nativeCallFailed(error)
        }
        guard let element = snapshot.elements.first(where: { $0.index == elementIndex }) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) was not found in the bounded snapshot")
        }
        guard element.supportedPatterns.contains(.dock) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) does not support dock")
        }

        let nativeResult = PeekabooWin11SetUIAutomationElementDockPosition(
            Self.nativeUIAutomationScope(scope),
            Int32(maxDepth),
            Int32(maxElements),
            Int32(elementIndex),
            Self.nativeDockPosition(position))
        try Self.validateUIAutomationSetDockPosition(nativeResult)

        let postActionElement = try? self.refreshedUIAutomationElement(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex)

        return DesktopUIAutomationActionResult(
            nativeBackend: snapshot.nativeBackend,
            action: .setDockPosition,
            scope: snapshot.scope,
            maxDepth: snapshot.maxDepth,
            maxElements: snapshot.maxElements,
            elementIndex: elementIndex,
            element: element,
            value: position.rawValue,
            postActionElement: postActionElement,
            valueWasVerified: postActionElement?.dockPosition.map { $0 == position })
    }

    public func setUIAutomationElementCurrentView(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        viewId: Int) throws -> DesktopUIAutomationActionResult
    {
        guard elementIndex >= 0 else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index must be a non-negative integer")
        }
        guard viewId >= 0, viewId <= Int(Int32.max) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation view id must be a non-negative 32-bit integer")
        }

        let snapshot = try self.uiAutomationSnapshot(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements)
        if let error = snapshot.error {
            throw Win11DesktopError.nativeCallFailed(error)
        }
        guard let element = snapshot.elements.first(where: { $0.index == elementIndex }) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) was not found in the bounded snapshot")
        }
        guard element.supportedPatterns.contains(.multipleView) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) does not support multiple view")
        }

        let nativeResult = PeekabooWin11SetUIAutomationElementCurrentView(
            Self.nativeUIAutomationScope(scope),
            Int32(maxDepth),
            Int32(maxElements),
            Int32(elementIndex),
            Int32(viewId))
        try Self.validateUIAutomationSetCurrentView(nativeResult)

        let postActionElement = try? self.refreshedUIAutomationElement(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex)

        return DesktopUIAutomationActionResult(
            nativeBackend: snapshot.nativeBackend,
            action: .setCurrentView,
            scope: snapshot.scope,
            maxDepth: snapshot.maxDepth,
            maxElements: snapshot.maxElements,
            elementIndex: elementIndex,
            element: element,
            value: "viewId=\(viewId)",
            postActionElement: postActionElement,
            valueWasVerified: postActionElement?.multipleViewCurrentView.map { $0 == viewId })
    }

    public func setUIAutomationElementZoomLevel(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        zoomLevel: Double) throws -> DesktopUIAutomationActionResult
    {
        guard elementIndex >= 0 else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index must be a non-negative integer")
        }
        guard zoomLevel.isFinite else {
            throw Win11DesktopError.invalidArgument("UI Automation zoom level must be a finite number")
        }

        let snapshot = try self.uiAutomationSnapshot(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements)
        if let error = snapshot.error {
            throw Win11DesktopError.nativeCallFailed(error)
        }
        guard let element = snapshot.elements.first(where: { $0.index == elementIndex }) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) was not found in the bounded snapshot")
        }
        guard element.supportedPatterns.contains(.transform2) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) does not support transform2 zoom")
        }
        if element.canZoom == false {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) does not support zoom")
        }
        if let minimum = element.zoomMinimum, zoomLevel < minimum {
            throw Win11DesktopError.invalidArgument(
                "UI Automation zoom level \(zoomLevel) is below minimum \(minimum)")
        }
        if let maximum = element.zoomMaximum, zoomLevel > maximum {
            throw Win11DesktopError.invalidArgument(
                "UI Automation zoom level \(zoomLevel) is above maximum \(maximum)")
        }

        let nativeResult = PeekabooWin11SetUIAutomationElementZoomLevel(
            Self.nativeUIAutomationScope(scope),
            Int32(maxDepth),
            Int32(maxElements),
            Int32(elementIndex),
            zoomLevel)
        try Self.validateUIAutomationSetZoomLevel(nativeResult)

        let postActionElement = try? self.refreshedUIAutomationElement(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex)

        return DesktopUIAutomationActionResult(
            nativeBackend: snapshot.nativeBackend,
            action: .setZoomLevel,
            scope: snapshot.scope,
            maxDepth: snapshot.maxDepth,
            maxElements: snapshot.maxElements,
            elementIndex: elementIndex,
            element: element,
            value: "zoomLevel=\(zoomLevel)",
            postActionElement: postActionElement,
            valueWasVerified: postActionElement?.zoomLevel.map {
                abs($0 - zoomLevel) < 0.0001
            })
    }

    public func zoomUIAutomationElementByUnit(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        unit: DesktopUIAutomationZoomUnit) throws -> DesktopUIAutomationActionResult
    {
        guard elementIndex >= 0 else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index must be a non-negative integer")
        }

        let snapshot = try self.uiAutomationSnapshot(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements)
        if let error = snapshot.error {
            throw Win11DesktopError.nativeCallFailed(error)
        }
        guard let element = snapshot.elements.first(where: { $0.index == elementIndex }) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) was not found in the bounded snapshot")
        }
        guard element.supportedPatterns.contains(.transform2) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) does not support transform2 zoom")
        }
        if element.canZoom == false {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) does not support zoom")
        }

        let nativeResult = PeekabooWin11ZoomUIAutomationElementByUnit(
            Self.nativeUIAutomationScope(scope),
            Int32(maxDepth),
            Int32(maxElements),
            Int32(elementIndex),
            Self.nativeZoomUnit(unit))
        try Self.validateUIAutomationZoomByUnit(nativeResult)

        let postActionElement = try? self.refreshedUIAutomationElement(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex)

        return DesktopUIAutomationActionResult(
            nativeBackend: snapshot.nativeBackend,
            action: .zoomByUnit,
            scope: snapshot.scope,
            maxDepth: snapshot.maxDepth,
            maxElements: snapshot.maxElements,
            elementIndex: elementIndex,
            element: element,
            value: "unit=\(unit.rawValue)",
            postActionElement: postActionElement,
            valueWasVerified: Self.zoomByUnitWasVerified(
                previousZoomLevel: element.zoomLevel,
                postActionElement: postActionElement,
                unit: unit))
    }

    public func startUIAutomationSynchronizedInput(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        inputType: DesktopUIAutomationSynchronizedInputType) throws -> DesktopUIAutomationActionResult
    {
        guard elementIndex >= 0 else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index must be a non-negative integer")
        }

        let snapshot = try self.uiAutomationSnapshot(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements)
        if let error = snapshot.error {
            throw Win11DesktopError.nativeCallFailed(error)
        }
        guard let element = snapshot.elements.first(where: { $0.index == elementIndex }) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) was not found in the bounded snapshot")
        }
        guard element.supportedPatterns.contains(.synchronizedInput) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) does not support synchronized input")
        }

        let nativeResult = PeekabooWin11StartUIAutomationSynchronizedInput(
            Self.nativeUIAutomationScope(scope),
            Int32(maxDepth),
            Int32(maxElements),
            Int32(elementIndex),
            Self.nativeSynchronizedInputType(inputType))
        try Self.validateUIAutomationStartSynchronizedInput(nativeResult)

        return DesktopUIAutomationActionResult(
            nativeBackend: snapshot.nativeBackend,
            action: .startSynchronizedInput,
            scope: snapshot.scope,
            maxDepth: snapshot.maxDepth,
            maxElements: snapshot.maxElements,
            elementIndex: elementIndex,
            element: element,
            value: "inputType=\(inputType.rawValue)")
    }

    public func cancelUIAutomationSynchronizedInput(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    {
        guard elementIndex >= 0 else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index must be a non-negative integer")
        }

        let snapshot = try self.uiAutomationSnapshot(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements)
        if let error = snapshot.error {
            throw Win11DesktopError.nativeCallFailed(error)
        }
        guard let element = snapshot.elements.first(where: { $0.index == elementIndex }) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) was not found in the bounded snapshot")
        }
        guard element.supportedPatterns.contains(.synchronizedInput) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) does not support synchronized input")
        }

        let nativeResult = PeekabooWin11CancelUIAutomationSynchronizedInput(
            Self.nativeUIAutomationScope(scope),
            Int32(maxDepth),
            Int32(maxElements),
            Int32(elementIndex))
        try Self.validateUIAutomationCancelSynchronizedInput(nativeResult)

        return DesktopUIAutomationActionResult(
            nativeBackend: snapshot.nativeBackend,
            action: .cancelSynchronizedInput,
            scope: snapshot.scope,
            maxDepth: snapshot.maxDepth,
            maxElements: snapshot.maxElements,
            elementIndex: elementIndex,
            element: element,
            value: "cancelled=true")
    }

    public func navigateUIAutomationCustom(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        direction: DesktopUIAutomationNavigationDirection) throws -> DesktopUIAutomationActionResult
    {
        guard elementIndex >= 0 else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index must be a non-negative integer")
        }

        let snapshot = try self.uiAutomationSnapshot(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements)
        if let error = snapshot.error {
            throw Win11DesktopError.nativeCallFailed(error)
        }
        guard let element = snapshot.elements.first(where: { $0.index == elementIndex }) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) was not found in the bounded snapshot")
        }
        guard element.supportedPatterns.contains(.customNavigation) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) does not support custom navigation")
        }

        let nativeResult = PeekabooWin11NavigateUIAutomationCustom(
            Self.nativeUIAutomationScope(scope),
            Int32(maxDepth),
            Int32(maxElements),
            Int32(elementIndex),
            Self.nativeNavigationDirection(direction))
        try Self.validateUIAutomationNavigateCustom(nativeResult)
        let resultElement = Self.uiAutomationResultElement(from: nativeResult)

        return DesktopUIAutomationActionResult(
            nativeBackend: snapshot.nativeBackend,
            action: .navigateCustom,
            scope: snapshot.scope,
            maxDepth: snapshot.maxDepth,
            maxElements: snapshot.maxElements,
            elementIndex: elementIndex,
            element: element,
            value: "direction=\(direction.rawValue)",
            resultElement: resultElement,
            valueWasVerified: resultElement.map { _ in true })
    }

    public func getUIAutomationSpreadsheetItemByName(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        name: String) throws -> DesktopUIAutomationActionResult
    {
        guard !name.isEmpty else {
            throw Win11DesktopError.invalidArgument("UI Automation spreadsheet item name must not be empty")
        }
        guard elementIndex >= 0 else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index must be a non-negative integer")
        }

        let snapshot = try self.uiAutomationSnapshot(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements)
        if let error = snapshot.error {
            throw Win11DesktopError.nativeCallFailed(error)
        }
        guard let element = snapshot.elements.first(where: { $0.index == elementIndex }) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) was not found in the bounded snapshot")
        }
        guard element.supportedPatterns.contains(.spreadsheet) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) does not support spreadsheet")
        }

        let nativeResult = PeekabooWin11GetUIAutomationSpreadsheetItemByName(
            Self.nativeUIAutomationScope(scope),
            Int32(maxDepth),
            Int32(maxElements),
            Int32(elementIndex),
            name)
        try Self.validateUIAutomationGetSpreadsheetItem(nativeResult)

        let resultElement = Self.uiAutomationResultElement(from: nativeResult)

        return DesktopUIAutomationActionResult(
            nativeBackend: snapshot.nativeBackend,
            action: .getSpreadsheetItem,
            scope: snapshot.scope,
            maxDepth: snapshot.maxDepth,
            maxElements: snapshot.maxElements,
            elementIndex: elementIndex,
            element: element,
            value: "name=\(name)",
            resultElement: resultElement,
            valueWasVerified: Self.spreadsheetItemWasVerified(
                resultElement: resultElement,
                name: name))
    }

    public func findUIAutomationItemByProperty(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        property: DesktopUIAutomationItemContainerProperty,
        value: String) throws -> DesktopUIAutomationActionResult
    {
        guard !value.isEmpty else {
            throw Win11DesktopError.invalidArgument("UI Automation item container value must not be empty")
        }
        guard elementIndex >= 0 else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index must be a non-negative integer")
        }

        let snapshot = try self.uiAutomationSnapshot(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements)
        if let error = snapshot.error {
            throw Win11DesktopError.nativeCallFailed(error)
        }
        guard let element = snapshot.elements.first(where: { $0.index == elementIndex }) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) was not found in the bounded snapshot")
        }
        guard element.supportedPatterns.contains(.itemContainer) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) does not support item container")
        }

        let nativeResult = PeekabooWin11FindUIAutomationItemByProperty(
            Self.nativeUIAutomationScope(scope),
            Int32(maxDepth),
            Int32(maxElements),
            Int32(elementIndex),
            Self.nativeItemContainerProperty(property),
            value)
        try Self.validateUIAutomationFindItemByProperty(nativeResult)

        let resultElement = Self.uiAutomationResultElement(from: nativeResult)

        return DesktopUIAutomationActionResult(
            nativeBackend: snapshot.nativeBackend,
            action: .findItemByProperty,
            scope: snapshot.scope,
            maxDepth: snapshot.maxDepth,
            maxElements: snapshot.maxElements,
            elementIndex: elementIndex,
            element: element,
            value: "property=\(property.rawValue),value=\(value)",
            resultElement: resultElement,
            valueWasVerified: Self.itemContainerResultWasVerified(
                resultElement: resultElement,
                property: property,
                value: value))
    }

    public func getUIAutomationGridItem(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        row: Int,
        column: Int) throws -> DesktopUIAutomationActionResult
    {
        let nativeCoordinateRange = 0...Int(Int32.max)
        guard nativeCoordinateRange.contains(row), nativeCoordinateRange.contains(column) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation grid row and column must be non-negative integers")
        }
        guard elementIndex >= 0 else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index must be a non-negative integer")
        }

        let snapshot = try self.uiAutomationSnapshot(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements)
        if let error = snapshot.error {
            throw Win11DesktopError.nativeCallFailed(error)
        }
        guard let element = snapshot.elements.first(where: { $0.index == elementIndex }) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) was not found in the bounded snapshot")
        }
        guard element.supportedPatterns.contains(.grid) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) does not support grid")
        }
        if let rowCount = element.gridRowCount, row >= rowCount {
            throw Win11DesktopError.invalidArgument(
                "UI Automation grid row \(row) is outside the reported row count \(rowCount)")
        }
        if let columnCount = element.gridColumnCount, column >= columnCount {
            throw Win11DesktopError.invalidArgument(
                "UI Automation grid column \(column) is outside the reported column count \(columnCount)")
        }

        let nativeRow = Int32(row)
        let nativeColumn = Int32(column)
        let nativeResult = PeekabooWin11GetUIAutomationGridItem(
            Self.nativeUIAutomationScope(scope),
            Int32(maxDepth),
            Int32(maxElements),
            Int32(elementIndex),
            nativeRow,
            nativeColumn)
        try Self.validateUIAutomationGetGridItem(nativeResult)

        let resultElement = Self.uiAutomationResultElement(from: nativeResult)

        return DesktopUIAutomationActionResult(
            nativeBackend: snapshot.nativeBackend,
            action: .getGridItem,
            scope: snapshot.scope,
            maxDepth: snapshot.maxDepth,
            maxElements: snapshot.maxElements,
            elementIndex: elementIndex,
            element: element,
            value: "row=\(row),column=\(column)",
            resultElement: resultElement,
            valueWasVerified: Self.gridItemWasVerified(
                resultElement: resultElement,
                row: row,
                column: column))
    }

    public func moveUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        x: Double,
        y: Double) throws -> DesktopUIAutomationActionResult
    {
        guard x.isFinite, y.isFinite else {
            throw Win11DesktopError.invalidArgument("UI Automation move coordinates must be finite numbers")
        }
        return try self.performTransformUIAutomationElement(
            action: .move,
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex,
            firstValue: x,
            secondValue: y)
    }

    public func resizeUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        width: Double,
        height: Double) throws -> DesktopUIAutomationActionResult
    {
        guard width.isFinite, height.isFinite, width > 0, height > 0 else {
            throw Win11DesktopError.invalidArgument("UI Automation resize dimensions must be greater than 0")
        }
        return try self.performTransformUIAutomationElement(
            action: .resize,
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex,
            firstValue: width,
            secondValue: height)
    }

    public func rotateUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        degrees: Double) throws -> DesktopUIAutomationActionResult
    {
        guard degrees.isFinite else {
            throw Win11DesktopError.invalidArgument("UI Automation rotate degrees must be a finite number")
        }
        return try self.performTransformUIAutomationElement(
            action: .rotate,
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex,
            firstValue: degrees,
            secondValue: 0.0)
    }

    private func performTransformUIAutomationElement(
        action: DesktopUIAutomationAction,
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        firstValue: Double,
        secondValue: Double) throws -> DesktopUIAutomationActionResult
    {
        guard elementIndex >= 0 else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index must be a non-negative integer")
        }

        let snapshot = try self.uiAutomationSnapshot(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements)
        if let error = snapshot.error {
            throw Win11DesktopError.nativeCallFailed(error)
        }
        guard let element = snapshot.elements.first(where: { $0.index == elementIndex }) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) was not found in the bounded snapshot")
        }
        guard element.supportedPatterns.contains(.transform) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) does not support transform")
        }
        if action == .move, element.canMove == false {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) cannot be moved")
        }
        if action == .resize, element.canResize == false {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) cannot be resized")
        }
        if action == .rotate, element.canRotate == false {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) cannot be rotated")
        }

        let nativeResult: PeekabooWin11UIAutomationActionResult
        if action == .move {
            nativeResult = PeekabooWin11MoveUIAutomationElement(
                Self.nativeUIAutomationScope(scope),
                Int32(maxDepth),
                Int32(maxElements),
                Int32(elementIndex),
                firstValue,
                secondValue)
        } else if action == .resize {
            nativeResult = PeekabooWin11ResizeUIAutomationElement(
                Self.nativeUIAutomationScope(scope),
                Int32(maxDepth),
                Int32(maxElements),
                Int32(elementIndex),
                firstValue,
                secondValue)
        } else {
            nativeResult = PeekabooWin11RotateUIAutomationElement(
                Self.nativeUIAutomationScope(scope),
                Int32(maxDepth),
                Int32(maxElements),
                Int32(elementIndex),
                firstValue)
        }
        try Self.validateUIAutomationTransform(nativeResult, action: action)

        let postActionElement = try? self.refreshedUIAutomationElement(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex)

        return DesktopUIAutomationActionResult(
            nativeBackend: snapshot.nativeBackend,
            action: action,
            scope: snapshot.scope,
            maxDepth: snapshot.maxDepth,
            maxElements: snapshot.maxElements,
            elementIndex: elementIndex,
            element: element,
            value: Self.transformValueString(
                action: action,
                firstValue: firstValue,
                secondValue: secondValue),
            postActionElement: postActionElement,
            valueWasVerified: Self.transformWasVerified(
                action: action,
                postActionElement: postActionElement,
                firstValue: firstValue,
                secondValue: secondValue))
    }

    public func realizeUIAutomationVirtualizedItem(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    {
        guard elementIndex >= 0 else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index must be a non-negative integer")
        }

        let snapshot = try self.uiAutomationSnapshot(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements)
        if let error = snapshot.error {
            throw Win11DesktopError.nativeCallFailed(error)
        }
        guard let element = snapshot.elements.first(where: { $0.index == elementIndex }) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) was not found in the bounded snapshot")
        }
        guard element.supportedPatterns.contains(.virtualizedItem) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) does not support virtualized item")
        }

        let nativeResult = PeekabooWin11RealizeUIAutomationVirtualizedItem(
            Self.nativeUIAutomationScope(scope),
            Int32(maxDepth),
            Int32(maxElements),
            Int32(elementIndex))
        try Self.validateUIAutomationRealizeVirtualizedItem(nativeResult)

        let postActionElement = try? self.refreshedUIAutomationElement(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex)

        return DesktopUIAutomationActionResult(
            nativeBackend: snapshot.nativeBackend,
            action: .realize,
            scope: snapshot.scope,
            maxDepth: snapshot.maxDepth,
            maxElements: snapshot.maxElements,
            elementIndex: elementIndex,
            element: element,
            value: "realized=true",
            postActionElement: postActionElement,
            valueWasVerified: postActionElement.map { !$0.supportedPatterns.contains(.virtualizedItem) })
    }

    public func toggleUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    {
        guard elementIndex >= 0 else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index must be a non-negative integer")
        }

        let snapshot = try self.uiAutomationSnapshot(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements)
        if let error = snapshot.error {
            throw Win11DesktopError.nativeCallFailed(error)
        }
        guard let element = snapshot.elements.first(where: { $0.index == elementIndex }) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) was not found in the bounded snapshot")
        }
        guard element.supportedPatterns.contains(.toggle) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) does not support toggle")
        }

        let nativeResult = PeekabooWin11ToggleUIAutomationElement(
            Self.nativeUIAutomationScope(scope),
            Int32(maxDepth),
            Int32(maxElements),
            Int32(elementIndex))
        try Self.validateUIAutomationToggle(nativeResult)

        let postActionElement = try? self.refreshedUIAutomationElement(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex)

        return DesktopUIAutomationActionResult(
            nativeBackend: snapshot.nativeBackend,
            action: .toggle,
            scope: snapshot.scope,
            maxDepth: snapshot.maxDepth,
            maxElements: snapshot.maxElements,
            elementIndex: elementIndex,
            element: element,
            postActionElement: postActionElement,
            valueWasVerified: Self.toggleWasVerified(
                previousState: element.toggleState,
                postActionElement: postActionElement))
    }

    public func expandUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    {
        try self.performExpandCollapseUIAutomationElement(
            action: .expand,
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex)
    }

    public func collapseUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    {
        try self.performExpandCollapseUIAutomationElement(
            action: .collapse,
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex)
    }

    private func performExpandCollapseUIAutomationElement(
        action: DesktopUIAutomationAction,
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    {
        guard elementIndex >= 0 else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index must be a non-negative integer")
        }

        let snapshot = try self.uiAutomationSnapshot(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements)
        if let error = snapshot.error {
            throw Win11DesktopError.nativeCallFailed(error)
        }
        guard let element = snapshot.elements.first(where: { $0.index == elementIndex }) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) was not found in the bounded snapshot")
        }
        guard element.supportedPatterns.contains(.expandCollapse) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) does not support expand/collapse")
        }
        if element.expandCollapseState == .leafNode {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) is a leaf node")
        }

        let nativeResult: PeekabooWin11UIAutomationActionResult
        if action == .expand {
            nativeResult = PeekabooWin11ExpandUIAutomationElement(
                Self.nativeUIAutomationScope(scope),
                Int32(maxDepth),
                Int32(maxElements),
                Int32(elementIndex))
        } else {
            nativeResult = PeekabooWin11CollapseUIAutomationElement(
                Self.nativeUIAutomationScope(scope),
                Int32(maxDepth),
                Int32(maxElements),
                Int32(elementIndex))
        }
        try Self.validateUIAutomationExpandCollapse(nativeResult, action: action)

        let postActionElement = try? self.refreshedUIAutomationElement(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex)
        let targetState: DesktopUIAutomationExpandCollapseState = action == .expand ? .expanded : .collapsed

        return DesktopUIAutomationActionResult(
            nativeBackend: snapshot.nativeBackend,
            action: action,
            scope: snapshot.scope,
            maxDepth: snapshot.maxDepth,
            maxElements: snapshot.maxElements,
            elementIndex: elementIndex,
            element: element,
            value: targetState.rawValue,
            postActionElement: postActionElement,
            valueWasVerified: postActionElement?.expandCollapseState.map { $0 == targetState })
    }

    public func selectUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    {
        guard elementIndex >= 0 else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index must be a non-negative integer")
        }

        let snapshot = try self.uiAutomationSnapshot(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements)
        if let error = snapshot.error {
            throw Win11DesktopError.nativeCallFailed(error)
        }
        guard let element = snapshot.elements.first(where: { $0.index == elementIndex }) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) was not found in the bounded snapshot")
        }
        guard element.supportedPatterns.contains(.selectionItem) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) does not support selection item")
        }

        let nativeResult = PeekabooWin11SelectUIAutomationElement(
            Self.nativeUIAutomationScope(scope),
            Int32(maxDepth),
            Int32(maxElements),
            Int32(elementIndex))
        try Self.validateUIAutomationSelect(nativeResult)

        let postActionElement = try? self.refreshedUIAutomationElement(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex)

        return DesktopUIAutomationActionResult(
            nativeBackend: snapshot.nativeBackend,
            action: .select,
            scope: snapshot.scope,
            maxDepth: snapshot.maxDepth,
            maxElements: snapshot.maxElements,
            elementIndex: elementIndex,
            element: element,
            value: "selected=true",
            postActionElement: postActionElement,
            valueWasVerified: postActionElement?.isSelected.map { $0 })
    }

    public func addUIAutomationElementToSelection(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    {
        try self.performSelectionItemUIAutomationElement(
            action: .addToSelection,
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex)
    }

    public func removeUIAutomationElementFromSelection(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    {
        try self.performSelectionItemUIAutomationElement(
            action: .removeFromSelection,
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex)
    }

    private func performSelectionItemUIAutomationElement(
        action: DesktopUIAutomationAction,
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    {
        guard elementIndex >= 0 else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index must be a non-negative integer")
        }

        let snapshot = try self.uiAutomationSnapshot(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements)
        if let error = snapshot.error {
            throw Win11DesktopError.nativeCallFailed(error)
        }
        guard let element = snapshot.elements.first(where: { $0.index == elementIndex }) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) was not found in the bounded snapshot")
        }
        guard element.supportedPatterns.contains(.selectionItem) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) does not support selection item")
        }

        let nativeResult: PeekabooWin11UIAutomationActionResult
        if action == .addToSelection {
            nativeResult = PeekabooWin11AddUIAutomationElementToSelection(
                Self.nativeUIAutomationScope(scope),
                Int32(maxDepth),
                Int32(maxElements),
                Int32(elementIndex))
        } else {
            nativeResult = PeekabooWin11RemoveUIAutomationElementFromSelection(
                Self.nativeUIAutomationScope(scope),
                Int32(maxDepth),
                Int32(maxElements),
                Int32(elementIndex))
        }
        try Self.validateUIAutomationSelectionItem(nativeResult, action: action)

        let postActionElement = try? self.refreshedUIAutomationElement(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex)
        let targetSelection = action == .addToSelection

        return DesktopUIAutomationActionResult(
            nativeBackend: snapshot.nativeBackend,
            action: action,
            scope: snapshot.scope,
            maxDepth: snapshot.maxDepth,
            maxElements: snapshot.maxElements,
            elementIndex: elementIndex,
            element: element,
            value: "selected=\(targetSelection)",
            postActionElement: postActionElement,
            valueWasVerified: postActionElement?.isSelected.map { $0 == targetSelection })
    }

    public func scrollUIAutomationElementIntoView(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    {
        guard elementIndex >= 0 else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index must be a non-negative integer")
        }

        let snapshot = try self.uiAutomationSnapshot(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements)
        if let error = snapshot.error {
            throw Win11DesktopError.nativeCallFailed(error)
        }
        guard let element = snapshot.elements.first(where: { $0.index == elementIndex }) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) was not found in the bounded snapshot")
        }
        guard element.supportedPatterns.contains(.scrollItem) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(elementIndex) does not support scroll item")
        }

        let nativeResult = PeekabooWin11ScrollUIAutomationElementIntoView(
            Self.nativeUIAutomationScope(scope),
            Int32(maxDepth),
            Int32(maxElements),
            Int32(elementIndex))
        try Self.validateUIAutomationScrollIntoView(nativeResult)

        let postActionElement = try? self.refreshedUIAutomationElement(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex)

        return DesktopUIAutomationActionResult(
            nativeBackend: snapshot.nativeBackend,
            action: .scrollIntoView,
            scope: snapshot.scope,
            maxDepth: snapshot.maxDepth,
            maxElements: snapshot.maxElements,
            elementIndex: elementIndex,
            element: element,
            value: "visible=true",
            postActionElement: postActionElement,
            valueWasVerified: postActionElement?.isOffscreen.map { !$0 })
    }

    private func refreshedUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationElementSnapshot?
    {
        let snapshot = try self.uiAutomationSnapshot(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements)
        if let error = snapshot.error {
            throw Win11DesktopError.nativeCallFailed(error)
        }
        return snapshot.elements.first(where: { $0.index == elementIndex })
    }

    private static func uiAutomationError(
        from probe: PeekabooWin11UIAutomationProbeResult) -> String?
    {
        let didReachAutomation = probe.createResult != 0 ||
            probe.isAvailable != 0 ||
            probe.rootResult != 0
        if probe.initializeResult < 0, !didReachAutomation {
            return "CoInitialize failed: \(Self.hresultDescription(probe.initializeResult))"
        }
        if !Self.succeeded(probe.createResult) {
            return "CoCreateInstance(CUIAutomation) failed: \(Self.hresultDescription(probe.createResult))"
        }
        if probe.isAvailable != 0, !Self.succeeded(probe.rootResult) {
            return "IUIAutomation.GetRootElement failed: \(Self.hresultDescription(probe.rootResult))"
        }
        if probe.isAvailable != 0, probe.rootElementAvailable == 0 {
            return "IUIAutomation.GetRootElement did not return a root element"
        }
        return nil
    }

    private static func uiAutomationSnapshotError(
        from snapshot: PeekabooWin11UIAutomationSnapshotResult) -> String?
    {
        if snapshot.errorResult < 0 {
            return "UI Automation snapshot failed: \(Self.hresultDescription(snapshot.errorResult))"
        }

        let didReachAutomation = snapshot.createResult != 0 ||
            snapshot.rootResult != 0 ||
            snapshot.walkerResult != 0 ||
            snapshot.elementCount > 0
        if snapshot.initializeResult < 0, !didReachAutomation {
            return "CoInitialize failed: \(Self.hresultDescription(snapshot.initializeResult))"
        }
        if !Self.succeeded(snapshot.createResult) {
            return "CoCreateInstance(CUIAutomation) failed: \(Self.hresultDescription(snapshot.createResult))"
        }
        if !Self.succeeded(snapshot.rootResult) {
            return "UI Automation root lookup failed: \(Self.hresultDescription(snapshot.rootResult))"
        }
        if !Self.succeeded(snapshot.walkerResult) {
            return "UI Automation ControlViewWalker failed: \(Self.hresultDescription(snapshot.walkerResult))"
        }
        return nil
    }

    private static func validateUIAutomationInvoke(
        _ action: PeekabooWin11UIAutomationActionResult) throws
    {
        if action.errorResult < 0 {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation invoke failed: \(Self.hresultDescription(action.errorResult))")
        }

        let didReachAutomation = action.createResult != 0 ||
            action.rootResult != 0 ||
            action.walkerResult != 0 ||
            action.elementCount > 0
        if action.initializeResult < 0, !didReachAutomation {
            throw Win11DesktopError.nativeCallFailed(
                "CoInitialize failed: \(Self.hresultDescription(action.initializeResult))")
        }
        if !Self.succeeded(action.createResult) {
            throw Win11DesktopError.nativeCallFailed(
                "CoCreateInstance(CUIAutomation) failed: \(Self.hresultDescription(action.createResult))")
        }
        if !Self.succeeded(action.rootResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation root lookup failed: \(Self.hresultDescription(action.rootResult))")
        }
        if !Self.succeeded(action.walkerResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation ControlViewWalker failed: \(Self.hresultDescription(action.walkerResult))")
        }
        if action.foundElement == 0 {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) was not found in the bounded snapshot")
        }
        if !Self.succeeded(action.patternResult) {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) does not support invoke")
        }
        if !Self.succeeded(action.queryResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationInvokePattern query failed: \(Self.hresultDescription(action.queryResult))")
        }
        if !Self.succeeded(action.actionResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationInvokePattern.Invoke failed: \(Self.hresultDescription(action.actionResult))")
        }
    }

    private static func validateUIAutomationFocus(
        _ action: PeekabooWin11UIAutomationActionResult) throws
    {
        if action.errorResult < 0 {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation focus failed: \(Self.hresultDescription(action.errorResult))")
        }

        let didReachAutomation = action.createResult != 0 ||
            action.rootResult != 0 ||
            action.walkerResult != 0 ||
            action.elementCount > 0
        if action.initializeResult < 0, !didReachAutomation {
            throw Win11DesktopError.nativeCallFailed(
                "CoInitialize failed: \(Self.hresultDescription(action.initializeResult))")
        }
        if !Self.succeeded(action.createResult) {
            throw Win11DesktopError.nativeCallFailed(
                "CoCreateInstance(CUIAutomation) failed: \(Self.hresultDescription(action.createResult))")
        }
        if !Self.succeeded(action.rootResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation root lookup failed: \(Self.hresultDescription(action.rootResult))")
        }
        if !Self.succeeded(action.walkerResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation ControlViewWalker failed: \(Self.hresultDescription(action.walkerResult))")
        }
        if action.foundElement == 0 {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) was not found in the bounded snapshot")
        }
        if !Self.succeeded(action.actionResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationElement.SetFocus failed: \(Self.hresultDescription(action.actionResult))")
        }
    }

    private static func validateUIAutomationLegacyDefaultAction(
        _ action: PeekabooWin11UIAutomationActionResult) throws
    {
        if action.errorResult < 0 {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation legacy-default-action failed: " +
                    "\(Self.hresultDescription(action.errorResult))")
        }

        let didReachAutomation = action.createResult != 0 ||
            action.rootResult != 0 ||
            action.walkerResult != 0 ||
            action.elementCount > 0
        if action.initializeResult < 0, !didReachAutomation {
            throw Win11DesktopError.nativeCallFailed(
                "CoInitialize failed: \(Self.hresultDescription(action.initializeResult))")
        }
        if !Self.succeeded(action.createResult) {
            throw Win11DesktopError.nativeCallFailed(
                "CoCreateInstance(CUIAutomation) failed: \(Self.hresultDescription(action.createResult))")
        }
        if !Self.succeeded(action.rootResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation root lookup failed: \(Self.hresultDescription(action.rootResult))")
        }
        if !Self.succeeded(action.walkerResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation ControlViewWalker failed: \(Self.hresultDescription(action.walkerResult))")
        }
        if action.foundElement == 0 {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) was not found in the bounded snapshot")
        }
        if !Self.succeeded(action.patternResult) {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) does not support legacy default action")
        }
        if !Self.succeeded(action.queryResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationLegacyIAccessiblePattern query failed: " +
                    "\(Self.hresultDescription(action.queryResult))")
        }
        if !Self.succeeded(action.actionResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationLegacyIAccessiblePattern.DoDefaultAction failed: " +
                    "\(Self.hresultDescription(action.actionResult))")
        }
    }

    private static func validateUIAutomationSetValue(
        _ action: PeekabooWin11UIAutomationActionResult) throws
    {
        if action.errorResult < 0 {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation set-value failed: \(Self.hresultDescription(action.errorResult))")
        }

        let didReachAutomation = action.createResult != 0 ||
            action.rootResult != 0 ||
            action.walkerResult != 0 ||
            action.elementCount > 0
        if action.initializeResult < 0, !didReachAutomation {
            throw Win11DesktopError.nativeCallFailed(
                "CoInitialize failed: \(Self.hresultDescription(action.initializeResult))")
        }
        if !Self.succeeded(action.createResult) {
            throw Win11DesktopError.nativeCallFailed(
                "CoCreateInstance(CUIAutomation) failed: \(Self.hresultDescription(action.createResult))")
        }
        if !Self.succeeded(action.rootResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation root lookup failed: \(Self.hresultDescription(action.rootResult))")
        }
        if !Self.succeeded(action.walkerResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation ControlViewWalker failed: \(Self.hresultDescription(action.walkerResult))")
        }
        if action.foundElement == 0 {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) was not found in the bounded snapshot")
        }
        if !Self.succeeded(action.patternResult) {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) does not support value")
        }
        if !Self.succeeded(action.queryResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationValuePattern query failed: \(Self.hresultDescription(action.queryResult))")
        }
        if Self.succeeded(action.readOnlyResult), action.isReadOnly != 0 {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) value is read-only")
        }
        if !Self.succeeded(action.actionResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationValuePattern.SetValue failed: \(Self.hresultDescription(action.actionResult))")
        }
    }

    private static func validateUIAutomationSetLegacyValue(
        _ action: PeekabooWin11UIAutomationActionResult) throws
    {
        if action.errorResult < 0 {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation set-legacy-value failed: \(Self.hresultDescription(action.errorResult))")
        }

        let didReachAutomation = action.createResult != 0 ||
            action.rootResult != 0 ||
            action.walkerResult != 0 ||
            action.elementCount > 0
        if action.initializeResult < 0, !didReachAutomation {
            throw Win11DesktopError.nativeCallFailed(
                "CoInitialize failed: \(Self.hresultDescription(action.initializeResult))")
        }
        if !Self.succeeded(action.createResult) {
            throw Win11DesktopError.nativeCallFailed(
                "CoCreateInstance(CUIAutomation) failed: \(Self.hresultDescription(action.createResult))")
        }
        if !Self.succeeded(action.rootResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation root lookup failed: \(Self.hresultDescription(action.rootResult))")
        }
        if !Self.succeeded(action.walkerResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation ControlViewWalker failed: \(Self.hresultDescription(action.walkerResult))")
        }
        if action.foundElement == 0 {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) was not found in the bounded snapshot")
        }
        if !Self.succeeded(action.patternResult) {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) does not support legacy value")
        }
        if !Self.succeeded(action.queryResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationLegacyIAccessiblePattern query failed: " +
                    "\(Self.hresultDescription(action.queryResult))")
        }
        if !Self.succeeded(action.actionResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationLegacyIAccessiblePattern.SetValue failed: " +
                    "\(Self.hresultDescription(action.actionResult))")
        }
    }

    private static func validateUIAutomationGetText(
        _ action: PeekabooWin11UIAutomationActionResult) throws
    {
        if action.errorResult < 0 {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation get-text failed: \(Self.hresultDescription(action.errorResult))")
        }

        let didReachAutomation = action.createResult != 0 ||
            action.rootResult != 0 ||
            action.walkerResult != 0 ||
            action.elementCount > 0
        if action.initializeResult < 0, !didReachAutomation {
            throw Win11DesktopError.nativeCallFailed(
                "CoInitialize failed: \(Self.hresultDescription(action.initializeResult))")
        }
        if !Self.succeeded(action.createResult) {
            throw Win11DesktopError.nativeCallFailed(
                "CoCreateInstance(CUIAutomation) failed: \(Self.hresultDescription(action.createResult))")
        }
        if !Self.succeeded(action.rootResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation root lookup failed: \(Self.hresultDescription(action.rootResult))")
        }
        if !Self.succeeded(action.walkerResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation ControlViewWalker failed: \(Self.hresultDescription(action.walkerResult))")
        }
        if action.foundElement == 0 {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) was not found in the bounded snapshot")
        }
        if !Self.succeeded(action.patternResult) {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) does not support text")
        }
        if !Self.succeeded(action.queryResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationTextPattern query failed: \(Self.hresultDescription(action.queryResult))")
        }
        if !Self.succeeded(action.actionResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationTextPattern.GetText failed: \(Self.hresultDescription(action.actionResult))")
        }
        if action.hasTextResult == 0 {
            throw Win11DesktopError.nativeCallFailed("UI Automation text result was not available")
        }
    }

    private static func validateUIAutomationSetRangeValue(
        _ action: PeekabooWin11UIAutomationActionResult) throws
    {
        if action.errorResult < 0 {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation set-range-value failed: \(Self.hresultDescription(action.errorResult))")
        }

        let didReachAutomation = action.createResult != 0 ||
            action.rootResult != 0 ||
            action.walkerResult != 0 ||
            action.elementCount > 0
        if action.initializeResult < 0, !didReachAutomation {
            throw Win11DesktopError.nativeCallFailed(
                "CoInitialize failed: \(Self.hresultDescription(action.initializeResult))")
        }
        if !Self.succeeded(action.createResult) {
            throw Win11DesktopError.nativeCallFailed(
                "CoCreateInstance(CUIAutomation) failed: \(Self.hresultDescription(action.createResult))")
        }
        if !Self.succeeded(action.rootResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation root lookup failed: \(Self.hresultDescription(action.rootResult))")
        }
        if !Self.succeeded(action.walkerResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation ControlViewWalker failed: \(Self.hresultDescription(action.walkerResult))")
        }
        if action.foundElement == 0 {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) was not found in the bounded snapshot")
        }
        if !Self.succeeded(action.patternResult) {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) does not support range value")
        }
        if !Self.succeeded(action.queryResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationRangeValuePattern query failed: \(Self.hresultDescription(action.queryResult))")
        }
        if Self.succeeded(action.readOnlyResult), action.isReadOnly != 0 {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) range value is read-only")
        }
        if !Self.succeeded(action.actionResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationRangeValuePattern.SetValue failed: \(Self.hresultDescription(action.actionResult))")
        }
    }

    private static func validateUIAutomationSetScrollPercent(
        _ action: PeekabooWin11UIAutomationActionResult) throws
    {
        if action.errorResult < 0 {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation set-scroll-percent failed: \(Self.hresultDescription(action.errorResult))")
        }

        let didReachAutomation = action.createResult != 0 ||
            action.rootResult != 0 ||
            action.walkerResult != 0 ||
            action.elementCount > 0
        if action.initializeResult < 0, !didReachAutomation {
            throw Win11DesktopError.nativeCallFailed(
                "CoInitialize failed: \(Self.hresultDescription(action.initializeResult))")
        }
        if !Self.succeeded(action.createResult) {
            throw Win11DesktopError.nativeCallFailed(
                "CoCreateInstance(CUIAutomation) failed: \(Self.hresultDescription(action.createResult))")
        }
        if !Self.succeeded(action.rootResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation root lookup failed: \(Self.hresultDescription(action.rootResult))")
        }
        if !Self.succeeded(action.walkerResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation ControlViewWalker failed: \(Self.hresultDescription(action.walkerResult))")
        }
        if action.foundElement == 0 {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) was not found in the bounded snapshot")
        }
        if !Self.succeeded(action.patternResult) {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) does not support scroll")
        }
        if !Self.succeeded(action.queryResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationScrollPattern query failed: \(Self.hresultDescription(action.queryResult))")
        }
        if !Self.succeeded(action.actionResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationScrollPattern.SetScrollPercent failed: " +
                    "\(Self.hresultDescription(action.actionResult))")
        }
    }

    private static func validateUIAutomationSetWindowVisualState(
        _ action: PeekabooWin11UIAutomationActionResult) throws
    {
        if action.errorResult < 0 {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation set-window-state failed: \(Self.hresultDescription(action.errorResult))")
        }

        let didReachAutomation = action.createResult != 0 ||
            action.rootResult != 0 ||
            action.walkerResult != 0 ||
            action.elementCount > 0
        if action.initializeResult < 0, !didReachAutomation {
            throw Win11DesktopError.nativeCallFailed(
                "CoInitialize failed: \(Self.hresultDescription(action.initializeResult))")
        }
        if !Self.succeeded(action.createResult) {
            throw Win11DesktopError.nativeCallFailed(
                "CoCreateInstance(CUIAutomation) failed: \(Self.hresultDescription(action.createResult))")
        }
        if !Self.succeeded(action.rootResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation root lookup failed: \(Self.hresultDescription(action.rootResult))")
        }
        if !Self.succeeded(action.walkerResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation ControlViewWalker failed: \(Self.hresultDescription(action.walkerResult))")
        }
        if action.foundElement == 0 {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) was not found in the bounded snapshot")
        }
        if !Self.succeeded(action.patternResult) {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) does not support window state")
        }
        if !Self.succeeded(action.queryResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationWindowPattern query failed: \(Self.hresultDescription(action.queryResult))")
        }
        if !Self.succeeded(action.actionResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationWindowPattern.SetWindowVisualState failed: " +
                    "\(Self.hresultDescription(action.actionResult))")
        }
    }

    private static func validateUIAutomationCloseWindow(
        _ action: PeekabooWin11UIAutomationActionResult) throws
    {
        if action.errorResult < 0 {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation close-window failed: \(Self.hresultDescription(action.errorResult))")
        }

        let didReachAutomation = action.createResult != 0 ||
            action.rootResult != 0 ||
            action.walkerResult != 0 ||
            action.elementCount > 0
        if action.initializeResult < 0, !didReachAutomation {
            throw Win11DesktopError.nativeCallFailed(
                "CoInitialize failed: \(Self.hresultDescription(action.initializeResult))")
        }
        if !Self.succeeded(action.createResult) {
            throw Win11DesktopError.nativeCallFailed(
                "CoCreateInstance(CUIAutomation) failed: \(Self.hresultDescription(action.createResult))")
        }
        if !Self.succeeded(action.rootResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation root lookup failed: \(Self.hresultDescription(action.rootResult))")
        }
        if !Self.succeeded(action.walkerResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation ControlViewWalker failed: \(Self.hresultDescription(action.walkerResult))")
        }
        if action.foundElement == 0 {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) was not found in the bounded snapshot")
        }
        if !Self.succeeded(action.patternResult) {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) does not support window close")
        }
        if !Self.succeeded(action.queryResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationWindowPattern query failed: \(Self.hresultDescription(action.queryResult))")
        }
        if !Self.succeeded(action.actionResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationWindowPattern.Close failed: \(Self.hresultDescription(action.actionResult))")
        }
    }

    private static func validateUIAutomationWaitForWindowInputIdle(
        _ action: PeekabooWin11UIAutomationActionResult) throws
    {
        if action.errorResult < 0 {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation wait-window-idle failed: \(Self.hresultDescription(action.errorResult))")
        }

        let didReachAutomation = action.createResult != 0 ||
            action.rootResult != 0 ||
            action.walkerResult != 0 ||
            action.elementCount > 0
        if action.initializeResult < 0, !didReachAutomation {
            throw Win11DesktopError.nativeCallFailed(
                "CoInitialize failed: \(Self.hresultDescription(action.initializeResult))")
        }
        if !Self.succeeded(action.createResult) {
            throw Win11DesktopError.nativeCallFailed(
                "CoCreateInstance(CUIAutomation) failed: \(Self.hresultDescription(action.createResult))")
        }
        if !Self.succeeded(action.rootResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation root lookup failed: \(Self.hresultDescription(action.rootResult))")
        }
        if !Self.succeeded(action.walkerResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation ControlViewWalker failed: \(Self.hresultDescription(action.walkerResult))")
        }
        if action.foundElement == 0 {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) was not found in the bounded snapshot")
        }
        if !Self.succeeded(action.patternResult) {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) does not support window input idle wait")
        }
        if !Self.succeeded(action.queryResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationWindowPattern query failed: \(Self.hresultDescription(action.queryResult))")
        }
        if !Self.succeeded(action.actionResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationWindowPattern.WaitForInputIdle failed: " +
                    "\(Self.hresultDescription(action.actionResult))")
        }
        if action.hasBoolResult == 0 {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationWindowPattern.WaitForInputIdle did not return an idle result")
        }
    }

    private static func validateUIAutomationSetDockPosition(
        _ action: PeekabooWin11UIAutomationActionResult) throws
    {
        if action.errorResult < 0 {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation set-dock-position failed: \(Self.hresultDescription(action.errorResult))")
        }

        let didReachAutomation = action.createResult != 0 ||
            action.rootResult != 0 ||
            action.walkerResult != 0 ||
            action.elementCount > 0
        if action.initializeResult < 0, !didReachAutomation {
            throw Win11DesktopError.nativeCallFailed(
                "CoInitialize failed: \(Self.hresultDescription(action.initializeResult))")
        }
        if !Self.succeeded(action.createResult) {
            throw Win11DesktopError.nativeCallFailed(
                "CoCreateInstance(CUIAutomation) failed: \(Self.hresultDescription(action.createResult))")
        }
        if !Self.succeeded(action.rootResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation root lookup failed: \(Self.hresultDescription(action.rootResult))")
        }
        if !Self.succeeded(action.walkerResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation ControlViewWalker failed: \(Self.hresultDescription(action.walkerResult))")
        }
        if action.foundElement == 0 {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) was not found in the bounded snapshot")
        }
        if !Self.succeeded(action.patternResult) {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) does not support dock")
        }
        if !Self.succeeded(action.queryResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationDockPattern query failed: \(Self.hresultDescription(action.queryResult))")
        }
        if !Self.succeeded(action.actionResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationDockPattern.SetDockPosition failed: " +
                    "\(Self.hresultDescription(action.actionResult))")
        }
    }

    private static func validateUIAutomationSetCurrentView(
        _ action: PeekabooWin11UIAutomationActionResult) throws
    {
        if action.errorResult < 0 {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation set-current-view failed: \(Self.hresultDescription(action.errorResult))")
        }

        let didReachAutomation = action.createResult != 0 ||
            action.rootResult != 0 ||
            action.walkerResult != 0 ||
            action.elementCount > 0
        if action.initializeResult < 0, !didReachAutomation {
            throw Win11DesktopError.nativeCallFailed(
                "CoInitialize failed: \(Self.hresultDescription(action.initializeResult))")
        }
        if !Self.succeeded(action.createResult) {
            throw Win11DesktopError.nativeCallFailed(
                "CoCreateInstance(CUIAutomation) failed: \(Self.hresultDescription(action.createResult))")
        }
        if !Self.succeeded(action.rootResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation root lookup failed: \(Self.hresultDescription(action.rootResult))")
        }
        if !Self.succeeded(action.walkerResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation ControlViewWalker failed: \(Self.hresultDescription(action.walkerResult))")
        }
        if action.foundElement == 0 {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) was not found in the bounded snapshot")
        }
        if !Self.succeeded(action.patternResult) {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) does not support multiple view")
        }
        if !Self.succeeded(action.queryResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationMultipleViewPattern query failed: \(Self.hresultDescription(action.queryResult))")
        }
        if !Self.succeeded(action.actionResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationMultipleViewPattern.SetCurrentView failed: " +
                    "\(Self.hresultDescription(action.actionResult))")
        }
    }

    private static func validateUIAutomationSetZoomLevel(
        _ action: PeekabooWin11UIAutomationActionResult) throws
    {
        if action.errorResult < 0 {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation set-zoom failed: \(Self.hresultDescription(action.errorResult))")
        }

        let didReachAutomation = action.createResult != 0 ||
            action.rootResult != 0 ||
            action.walkerResult != 0 ||
            action.elementCount > 0
        if action.initializeResult < 0, !didReachAutomation {
            throw Win11DesktopError.nativeCallFailed(
                "CoInitialize failed: \(Self.hresultDescription(action.initializeResult))")
        }
        if !Self.succeeded(action.createResult) {
            throw Win11DesktopError.nativeCallFailed(
                "CoCreateInstance(CUIAutomation) failed: \(Self.hresultDescription(action.createResult))")
        }
        if !Self.succeeded(action.rootResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation root lookup failed: \(Self.hresultDescription(action.rootResult))")
        }
        if !Self.succeeded(action.walkerResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation ControlViewWalker failed: \(Self.hresultDescription(action.walkerResult))")
        }
        if action.foundElement == 0 {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) was not found in the bounded snapshot")
        }
        if !Self.succeeded(action.patternResult) {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) does not support transform2 zoom")
        }
        if !Self.succeeded(action.queryResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationTransformPattern2 query failed: \(Self.hresultDescription(action.queryResult))")
        }
        if !Self.succeeded(action.actionResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationTransformPattern2.Zoom failed: " +
                    "\(Self.hresultDescription(action.actionResult))")
        }
    }

    private static func validateUIAutomationZoomByUnit(
        _ action: PeekabooWin11UIAutomationActionResult) throws
    {
        if action.errorResult < 0 {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation zoom-by-unit failed: \(Self.hresultDescription(action.errorResult))")
        }

        let didReachAutomation = action.createResult != 0 ||
            action.rootResult != 0 ||
            action.walkerResult != 0 ||
            action.elementCount > 0
        if action.initializeResult < 0, !didReachAutomation {
            throw Win11DesktopError.nativeCallFailed(
                "CoInitialize failed: \(Self.hresultDescription(action.initializeResult))")
        }
        if !Self.succeeded(action.createResult) {
            throw Win11DesktopError.nativeCallFailed(
                "CoCreateInstance(CUIAutomation) failed: \(Self.hresultDescription(action.createResult))")
        }
        if !Self.succeeded(action.rootResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation root lookup failed: \(Self.hresultDescription(action.rootResult))")
        }
        if !Self.succeeded(action.walkerResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation ControlViewWalker failed: \(Self.hresultDescription(action.walkerResult))")
        }
        if action.foundElement == 0 {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) was not found in the bounded snapshot")
        }
        if !Self.succeeded(action.patternResult) {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) does not support transform2 zoom")
        }
        if !Self.succeeded(action.queryResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationTransformPattern2 query failed: \(Self.hresultDescription(action.queryResult))")
        }
        if !Self.succeeded(action.actionResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationTransformPattern2.ZoomByUnit failed: " +
                    "\(Self.hresultDescription(action.actionResult))")
        }
    }

    private static func validateUIAutomationStartSynchronizedInput(
        _ action: PeekabooWin11UIAutomationActionResult) throws
    {
        if action.errorResult < 0 {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation start-synchronized-input failed: " +
                    "\(Self.hresultDescription(action.errorResult))")
        }

        let didReachAutomation = action.createResult != 0 ||
            action.rootResult != 0 ||
            action.walkerResult != 0 ||
            action.elementCount > 0
        if action.initializeResult < 0, !didReachAutomation {
            throw Win11DesktopError.nativeCallFailed(
                "CoInitialize failed: \(Self.hresultDescription(action.initializeResult))")
        }
        if !Self.succeeded(action.createResult) {
            throw Win11DesktopError.nativeCallFailed(
                "CoCreateInstance(CUIAutomation) failed: \(Self.hresultDescription(action.createResult))")
        }
        if !Self.succeeded(action.rootResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation root lookup failed: \(Self.hresultDescription(action.rootResult))")
        }
        if !Self.succeeded(action.walkerResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation ControlViewWalker failed: \(Self.hresultDescription(action.walkerResult))")
        }
        if action.foundElement == 0 {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) was not found in the bounded snapshot")
        }
        if !Self.succeeded(action.patternResult) {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) does not support synchronized input")
        }
        if !Self.succeeded(action.queryResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationSynchronizedInputPattern query failed: " +
                    "\(Self.hresultDescription(action.queryResult))")
        }
        if !Self.succeeded(action.actionResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationSynchronizedInputPattern.StartListening failed: " +
                    "\(Self.hresultDescription(action.actionResult))")
        }
    }

    private static func validateUIAutomationCancelSynchronizedInput(
        _ action: PeekabooWin11UIAutomationActionResult) throws
    {
        if action.errorResult < 0 {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation cancel-synchronized-input failed: " +
                    "\(Self.hresultDescription(action.errorResult))")
        }

        let didReachAutomation = action.createResult != 0 ||
            action.rootResult != 0 ||
            action.walkerResult != 0 ||
            action.elementCount > 0
        if action.initializeResult < 0, !didReachAutomation {
            throw Win11DesktopError.nativeCallFailed(
                "CoInitialize failed: \(Self.hresultDescription(action.initializeResult))")
        }
        if !Self.succeeded(action.createResult) {
            throw Win11DesktopError.nativeCallFailed(
                "CoCreateInstance(CUIAutomation) failed: \(Self.hresultDescription(action.createResult))")
        }
        if !Self.succeeded(action.rootResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation root lookup failed: \(Self.hresultDescription(action.rootResult))")
        }
        if !Self.succeeded(action.walkerResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation ControlViewWalker failed: \(Self.hresultDescription(action.walkerResult))")
        }
        if action.foundElement == 0 {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) was not found in the bounded snapshot")
        }
        if !Self.succeeded(action.patternResult) {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) does not support synchronized input")
        }
        if !Self.succeeded(action.queryResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationSynchronizedInputPattern query failed: " +
                    "\(Self.hresultDescription(action.queryResult))")
        }
        if !Self.succeeded(action.actionResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationSynchronizedInputPattern.Cancel failed: " +
                    "\(Self.hresultDescription(action.actionResult))")
        }
    }

    private static func validateUIAutomationNavigateCustom(
        _ action: PeekabooWin11UIAutomationActionResult) throws
    {
        if action.errorResult < 0 {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation navigate-custom failed: \(Self.hresultDescription(action.errorResult))")
        }

        let didReachAutomation = action.createResult != 0 ||
            action.rootResult != 0 ||
            action.walkerResult != 0 ||
            action.elementCount > 0
        if action.initializeResult < 0, !didReachAutomation {
            throw Win11DesktopError.nativeCallFailed(
                "CoInitialize failed: \(Self.hresultDescription(action.initializeResult))")
        }
        if !Self.succeeded(action.createResult) {
            throw Win11DesktopError.nativeCallFailed(
                "CoCreateInstance(CUIAutomation) failed: \(Self.hresultDescription(action.createResult))")
        }
        if !Self.succeeded(action.rootResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation root lookup failed: \(Self.hresultDescription(action.rootResult))")
        }
        if !Self.succeeded(action.walkerResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation ControlViewWalker failed: \(Self.hresultDescription(action.walkerResult))")
        }
        if action.foundElement == 0 {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) was not found in the bounded snapshot")
        }
        if !Self.succeeded(action.patternResult) {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) does not support custom navigation")
        }
        if !Self.succeeded(action.queryResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationCustomNavigationPattern query failed: " +
                    "\(Self.hresultDescription(action.queryResult))")
        }
        if !Self.succeeded(action.actionResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationCustomNavigationPattern.Navigate failed: " +
                    "\(Self.hresultDescription(action.actionResult))")
        }
    }

    private static func validateUIAutomationGetSpreadsheetItem(
        _ action: PeekabooWin11UIAutomationActionResult) throws
    {
        if action.errorResult < 0 {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation get-spreadsheet-item failed: " +
                    "\(Self.hresultDescription(action.errorResult))")
        }

        let didReachAutomation = action.createResult != 0 ||
            action.rootResult != 0 ||
            action.walkerResult != 0 ||
            action.elementCount > 0
        if action.initializeResult < 0, !didReachAutomation {
            throw Win11DesktopError.nativeCallFailed(
                "CoInitialize failed: \(Self.hresultDescription(action.initializeResult))")
        }
        if !Self.succeeded(action.createResult) {
            throw Win11DesktopError.nativeCallFailed(
                "CoCreateInstance(CUIAutomation) failed: \(Self.hresultDescription(action.createResult))")
        }
        if !Self.succeeded(action.rootResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation root lookup failed: \(Self.hresultDescription(action.rootResult))")
        }
        if !Self.succeeded(action.walkerResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation ControlViewWalker failed: \(Self.hresultDescription(action.walkerResult))")
        }
        if action.foundElement == 0 {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) was not found in the bounded snapshot")
        }
        if !Self.succeeded(action.patternResult) {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) does not support spreadsheet")
        }
        if !Self.succeeded(action.queryResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationSpreadsheetPattern query failed: " +
                    "\(Self.hresultDescription(action.queryResult))")
        }
        if !Self.succeeded(action.actionResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationSpreadsheetPattern.GetItemByName failed: " +
                    "\(Self.hresultDescription(action.actionResult))")
        }
    }

    private static func validateUIAutomationGetGridItem(
        _ action: PeekabooWin11UIAutomationActionResult) throws
    {
        if action.errorResult < 0 {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation get-grid-item failed: \(Self.hresultDescription(action.errorResult))")
        }

        let didReachAutomation = action.createResult != 0 ||
            action.rootResult != 0 ||
            action.walkerResult != 0 ||
            action.elementCount > 0
        if action.initializeResult < 0, !didReachAutomation {
            throw Win11DesktopError.nativeCallFailed(
                "CoInitialize failed: \(Self.hresultDescription(action.initializeResult))")
        }
        if !Self.succeeded(action.createResult) {
            throw Win11DesktopError.nativeCallFailed(
                "CoCreateInstance(CUIAutomation) failed: \(Self.hresultDescription(action.createResult))")
        }
        if !Self.succeeded(action.rootResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation root lookup failed: \(Self.hresultDescription(action.rootResult))")
        }
        if !Self.succeeded(action.walkerResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation ControlViewWalker failed: \(Self.hresultDescription(action.walkerResult))")
        }
        if action.foundElement == 0 {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) was not found in the bounded snapshot")
        }
        if !Self.succeeded(action.patternResult) {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) does not support grid")
        }
        if !Self.succeeded(action.queryResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationGridPattern query failed: \(Self.hresultDescription(action.queryResult))")
        }
        if !Self.succeeded(action.actionResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationGridPattern.GetItem failed: \(Self.hresultDescription(action.actionResult))")
        }
    }

    private static func validateUIAutomationFindItemByProperty(
        _ action: PeekabooWin11UIAutomationActionResult) throws
    {
        if action.errorResult < 0 {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation find-item failed: \(Self.hresultDescription(action.errorResult))")
        }

        let didReachAutomation = action.createResult != 0 ||
            action.rootResult != 0 ||
            action.walkerResult != 0 ||
            action.elementCount > 0
        if action.initializeResult < 0, !didReachAutomation {
            throw Win11DesktopError.nativeCallFailed(
                "CoInitialize failed: \(Self.hresultDescription(action.initializeResult))")
        }
        if !Self.succeeded(action.createResult) {
            throw Win11DesktopError.nativeCallFailed(
                "CoCreateInstance(CUIAutomation) failed: \(Self.hresultDescription(action.createResult))")
        }
        if !Self.succeeded(action.rootResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation root lookup failed: \(Self.hresultDescription(action.rootResult))")
        }
        if !Self.succeeded(action.walkerResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation ControlViewWalker failed: \(Self.hresultDescription(action.walkerResult))")
        }
        if action.foundElement == 0 {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) was not found in the bounded snapshot")
        }
        if !Self.succeeded(action.patternResult) {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) does not support item container")
        }
        if !Self.succeeded(action.queryResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationItemContainerPattern query failed: " +
                    "\(Self.hresultDescription(action.queryResult))")
        }
        if !Self.succeeded(action.actionResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationItemContainerPattern.FindItemByProperty failed: " +
                    "\(Self.hresultDescription(action.actionResult))")
        }
        if action.hasResultElement == 0 {
            throw Win11DesktopError.invalidArgument(
                "UI Automation item container did not find a matching item")
        }
    }

    private static func validateUIAutomationToggle(
        _ action: PeekabooWin11UIAutomationActionResult) throws
    {
        if action.errorResult < 0 {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation toggle failed: \(Self.hresultDescription(action.errorResult))")
        }

        let didReachAutomation = action.createResult != 0 ||
            action.rootResult != 0 ||
            action.walkerResult != 0 ||
            action.elementCount > 0
        if action.initializeResult < 0, !didReachAutomation {
            throw Win11DesktopError.nativeCallFailed(
                "CoInitialize failed: \(Self.hresultDescription(action.initializeResult))")
        }
        if !Self.succeeded(action.createResult) {
            throw Win11DesktopError.nativeCallFailed(
                "CoCreateInstance(CUIAutomation) failed: \(Self.hresultDescription(action.createResult))")
        }
        if !Self.succeeded(action.rootResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation root lookup failed: \(Self.hresultDescription(action.rootResult))")
        }
        if !Self.succeeded(action.walkerResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation ControlViewWalker failed: \(Self.hresultDescription(action.walkerResult))")
        }
        if action.foundElement == 0 {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) was not found in the bounded snapshot")
        }
        if !Self.succeeded(action.patternResult) {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) does not support toggle")
        }
        if !Self.succeeded(action.queryResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationTogglePattern query failed: \(Self.hresultDescription(action.queryResult))")
        }
        if !Self.succeeded(action.actionResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationTogglePattern.Toggle failed: \(Self.hresultDescription(action.actionResult))")
        }
    }

    private static func validateUIAutomationExpandCollapse(
        _ actionResult: PeekabooWin11UIAutomationActionResult,
        action: DesktopUIAutomationAction) throws
    {
        let actionName = action == .expand ? "expand" : "collapse"
        let methodName = action == .expand ? "Expand" : "Collapse"
        if actionResult.errorResult < 0 {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation \(actionName) failed: \(Self.hresultDescription(actionResult.errorResult))")
        }

        let didReachAutomation = actionResult.createResult != 0 ||
            actionResult.rootResult != 0 ||
            actionResult.walkerResult != 0 ||
            actionResult.elementCount > 0
        if actionResult.initializeResult < 0, !didReachAutomation {
            throw Win11DesktopError.nativeCallFailed(
                "CoInitialize failed: \(Self.hresultDescription(actionResult.initializeResult))")
        }
        if !Self.succeeded(actionResult.createResult) {
            throw Win11DesktopError.nativeCallFailed(
                "CoCreateInstance(CUIAutomation) failed: \(Self.hresultDescription(actionResult.createResult))")
        }
        if !Self.succeeded(actionResult.rootResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation root lookup failed: \(Self.hresultDescription(actionResult.rootResult))")
        }
        if !Self.succeeded(actionResult.walkerResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation ControlViewWalker failed: \(Self.hresultDescription(actionResult.walkerResult))")
        }
        if actionResult.foundElement == 0 {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(actionResult.elementIndex) was not found in the bounded snapshot")
        }
        if !Self.succeeded(actionResult.patternResult) {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(actionResult.elementIndex) does not support expand/collapse")
        }
        if !Self.succeeded(actionResult.queryResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationExpandCollapsePattern query failed: \(Self.hresultDescription(actionResult.queryResult))")
        }
        if !Self.succeeded(actionResult.actionResult) {
            let description = Self.hresultDescription(actionResult.actionResult)
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationExpandCollapsePattern.\(methodName) failed: \(description)")
        }
    }

    private static func validateUIAutomationSelect(
        _ action: PeekabooWin11UIAutomationActionResult) throws
    {
        if action.errorResult < 0 {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation select failed: \(Self.hresultDescription(action.errorResult))")
        }

        let didReachAutomation = action.createResult != 0 ||
            action.rootResult != 0 ||
            action.walkerResult != 0 ||
            action.elementCount > 0
        if action.initializeResult < 0, !didReachAutomation {
            throw Win11DesktopError.nativeCallFailed(
                "CoInitialize failed: \(Self.hresultDescription(action.initializeResult))")
        }
        if !Self.succeeded(action.createResult) {
            throw Win11DesktopError.nativeCallFailed(
                "CoCreateInstance(CUIAutomation) failed: \(Self.hresultDescription(action.createResult))")
        }
        if !Self.succeeded(action.rootResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation root lookup failed: \(Self.hresultDescription(action.rootResult))")
        }
        if !Self.succeeded(action.walkerResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation ControlViewWalker failed: \(Self.hresultDescription(action.walkerResult))")
        }
        if action.foundElement == 0 {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) was not found in the bounded snapshot")
        }
        if !Self.succeeded(action.patternResult) {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) does not support selection item")
        }
        if !Self.succeeded(action.queryResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationSelectionItemPattern query failed: \(Self.hresultDescription(action.queryResult))")
        }
        if !Self.succeeded(action.actionResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationSelectionItemPattern.Select failed: \(Self.hresultDescription(action.actionResult))")
        }
    }

    private static func validateUIAutomationSelectionItem(
        _ actionResult: PeekabooWin11UIAutomationActionResult,
        action: DesktopUIAutomationAction) throws
    {
        let actionName = action == .addToSelection ? "add-to-selection" : "remove-from-selection"
        let methodName = action == .addToSelection ? "AddToSelection" : "RemoveFromSelection"
        if actionResult.errorResult < 0 {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation \(actionName) failed: \(Self.hresultDescription(actionResult.errorResult))")
        }

        let didReachAutomation = actionResult.createResult != 0 ||
            actionResult.rootResult != 0 ||
            actionResult.walkerResult != 0 ||
            actionResult.elementCount > 0
        if actionResult.initializeResult < 0, !didReachAutomation {
            throw Win11DesktopError.nativeCallFailed(
                "CoInitialize failed: \(Self.hresultDescription(actionResult.initializeResult))")
        }
        if !Self.succeeded(actionResult.createResult) {
            throw Win11DesktopError.nativeCallFailed(
                "CoCreateInstance(CUIAutomation) failed: \(Self.hresultDescription(actionResult.createResult))")
        }
        if !Self.succeeded(actionResult.rootResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation root lookup failed: \(Self.hresultDescription(actionResult.rootResult))")
        }
        if !Self.succeeded(actionResult.walkerResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation ControlViewWalker failed: \(Self.hresultDescription(actionResult.walkerResult))")
        }
        if actionResult.foundElement == 0 {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(actionResult.elementIndex) was not found in the bounded snapshot")
        }
        if !Self.succeeded(actionResult.patternResult) {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(actionResult.elementIndex) does not support selection item")
        }
        if !Self.succeeded(actionResult.queryResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationSelectionItemPattern query failed: " +
                    "\(Self.hresultDescription(actionResult.queryResult))")
        }
        if !Self.succeeded(actionResult.actionResult) {
            let description = Self.hresultDescription(actionResult.actionResult)
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationSelectionItemPattern.\(methodName) failed: \(description)")
        }
    }

    private static func validateUIAutomationScrollIntoView(
        _ action: PeekabooWin11UIAutomationActionResult) throws
    {
        if action.errorResult < 0 {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation scroll-into-view failed: \(Self.hresultDescription(action.errorResult))")
        }

        let didReachAutomation = action.createResult != 0 ||
            action.rootResult != 0 ||
            action.walkerResult != 0 ||
            action.elementCount > 0
        if action.initializeResult < 0, !didReachAutomation {
            throw Win11DesktopError.nativeCallFailed(
                "CoInitialize failed: \(Self.hresultDescription(action.initializeResult))")
        }
        if !Self.succeeded(action.createResult) {
            throw Win11DesktopError.nativeCallFailed(
                "CoCreateInstance(CUIAutomation) failed: \(Self.hresultDescription(action.createResult))")
        }
        if !Self.succeeded(action.rootResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation root lookup failed: \(Self.hresultDescription(action.rootResult))")
        }
        if !Self.succeeded(action.walkerResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation ControlViewWalker failed: \(Self.hresultDescription(action.walkerResult))")
        }
        if action.foundElement == 0 {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) was not found in the bounded snapshot")
        }
        if !Self.succeeded(action.patternResult) {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) does not support scroll item")
        }
        if !Self.succeeded(action.queryResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationScrollItemPattern query failed: \(Self.hresultDescription(action.queryResult))")
        }
        if !Self.succeeded(action.actionResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationScrollItemPattern.ScrollIntoView failed: " +
                    "\(Self.hresultDescription(action.actionResult))")
        }
    }

    private static func validateUIAutomationRealizeVirtualizedItem(
        _ action: PeekabooWin11UIAutomationActionResult) throws
    {
        if action.errorResult < 0 {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation realize failed: \(Self.hresultDescription(action.errorResult))")
        }

        let didReachAutomation = action.createResult != 0 ||
            action.rootResult != 0 ||
            action.walkerResult != 0 ||
            action.elementCount > 0
        if action.initializeResult < 0, !didReachAutomation {
            throw Win11DesktopError.nativeCallFailed(
                "CoInitialize failed: \(Self.hresultDescription(action.initializeResult))")
        }
        if !Self.succeeded(action.createResult) {
            throw Win11DesktopError.nativeCallFailed(
                "CoCreateInstance(CUIAutomation) failed: \(Self.hresultDescription(action.createResult))")
        }
        if !Self.succeeded(action.rootResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation root lookup failed: \(Self.hresultDescription(action.rootResult))")
        }
        if !Self.succeeded(action.walkerResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation ControlViewWalker failed: \(Self.hresultDescription(action.walkerResult))")
        }
        if action.foundElement == 0 {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) was not found in the bounded snapshot")
        }
        if !Self.succeeded(action.patternResult) {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(action.elementIndex) does not support virtualized item")
        }
        if !Self.succeeded(action.queryResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationVirtualizedItemPattern query failed: " +
                    "\(Self.hresultDescription(action.queryResult))")
        }
        if !Self.succeeded(action.actionResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationVirtualizedItemPattern.Realize failed: " +
                    "\(Self.hresultDescription(action.actionResult))")
        }
    }

    private static func validateUIAutomationTransform(
        _ actionResult: PeekabooWin11UIAutomationActionResult,
        action: DesktopUIAutomationAction) throws
    {
        let actionName: String
        let methodName: String
        switch action {
        case .move:
            actionName = "move"
            methodName = "Move"
        case .resize:
            actionName = "resize"
            methodName = "Resize"
        case .rotate:
            actionName = "rotate"
            methodName = "Rotate"
        default:
            actionName = "transform"
            methodName = "Transform"
        }
        if actionResult.errorResult < 0 {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation \(actionName) failed: \(Self.hresultDescription(actionResult.errorResult))")
        }

        let didReachAutomation = actionResult.createResult != 0 ||
            actionResult.rootResult != 0 ||
            actionResult.walkerResult != 0 ||
            actionResult.elementCount > 0
        if actionResult.initializeResult < 0, !didReachAutomation {
            throw Win11DesktopError.nativeCallFailed(
                "CoInitialize failed: \(Self.hresultDescription(actionResult.initializeResult))")
        }
        if !Self.succeeded(actionResult.createResult) {
            throw Win11DesktopError.nativeCallFailed(
                "CoCreateInstance(CUIAutomation) failed: \(Self.hresultDescription(actionResult.createResult))")
        }
        if !Self.succeeded(actionResult.rootResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation root lookup failed: \(Self.hresultDescription(actionResult.rootResult))")
        }
        if !Self.succeeded(actionResult.walkerResult) {
            throw Win11DesktopError.nativeCallFailed(
                "UI Automation ControlViewWalker failed: \(Self.hresultDescription(actionResult.walkerResult))")
        }
        if actionResult.foundElement == 0 {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(actionResult.elementIndex) was not found in the bounded snapshot")
        }
        if !Self.succeeded(actionResult.patternResult) {
            throw Win11DesktopError.invalidArgument(
                "UI Automation element index \(actionResult.elementIndex) does not support transform")
        }
        if !Self.succeeded(actionResult.queryResult) {
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationTransformPattern query failed: \(Self.hresultDescription(actionResult.queryResult))")
        }
        if !Self.succeeded(actionResult.actionResult) {
            let description = Self.hresultDescription(actionResult.actionResult)
            throw Win11DesktopError.nativeCallFailed(
                "IUIAutomationTransformPattern.\(methodName) failed: \(description)")
        }
    }

    private static func nativeUIAutomationScope(_ scope: DesktopUIAutomationSnapshotScope) -> Int32 {
        switch scope {
        case .root:
            return 0
        case .foreground:
            return 1
        case .focused:
            return 2
        case .cursor:
            return 3
        }
    }

    private static func uiAutomationElements(
        from snapshot: PeekabooWin11UIAutomationSnapshotResult) -> [DesktopUIAutomationElementSnapshot]
    {
        guard let elementsPointer = snapshot.elements, snapshot.elementCount > 0 else {
            return []
        }

        return (0..<Int(snapshot.elementCount)).map { offset in
            var nativeElement = elementsPointer.advanced(by: offset).pointee
            return Self.uiAutomationElement(from: &nativeElement)
        }
    }

    private static func uiAutomationResultElement(
        from action: PeekabooWin11UIAutomationActionResult) -> DesktopUIAutomationElementSnapshot?
    {
        guard action.hasResultElement != 0 else {
            return nil
        }
        var nativeElement = action.resultElement
        return Self.uiAutomationElement(from: &nativeElement)
    }

    private static func uiAutomationElement(
        from nativeElement: inout PeekabooWin11UIAutomationElementSnapshot)
        -> DesktopUIAutomationElementSnapshot
    {
        let bounds: DesktopRect? = nativeElement.hasBoundingRectangle != 0
            ? DesktopRect(
                x: Int(nativeElement.boundsX),
                y: Int(nativeElement.boundsY),
                width: Int(nativeElement.boundsWidth),
                height: Int(nativeElement.boundsHeight))
            : nil
        let supportedPatterns = Self.uiAutomationPatterns(from: nativeElement.supportedPatternMask)
        let isValueReadOnly = Self.optionalBool(
            hasValue: nativeElement.hasIsValueReadOnly,
            value: nativeElement.isValueReadOnly)
        let isRangeValueReadOnly = Self.optionalBool(
            hasValue: nativeElement.hasIsRangeValueReadOnly,
            value: nativeElement.isRangeValueReadOnly)
        let isHorizontallyScrollable = Self.optionalBool(
            hasValue: nativeElement.hasIsHorizontallyScrollable,
            value: nativeElement.isHorizontallyScrollable)
        let isVerticallyScrollable = Self.optionalBool(
            hasValue: nativeElement.hasIsVerticallyScrollable,
            value: nativeElement.isVerticallyScrollable)
        let expandCollapseState = Self.uiAutomationExpandCollapseState(
            hasValue: nativeElement.hasExpandCollapseState,
            value: nativeElement.expandCollapseState)
        let isKeyboardFocusable = Self.optionalBool(
            hasValue: nativeElement.hasIsKeyboardFocusable,
            value: nativeElement.isKeyboardFocusable)
        let windowVisualState = Self.uiAutomationWindowVisualState(
            hasValue: nativeElement.hasWindowVisualState,
            value: nativeElement.windowVisualState)
        let windowInteractionState = Self.uiAutomationWindowInteractionState(
            hasValue: nativeElement.hasWindowInteractionState,
            value: nativeElement.windowInteractionState)
        let dockPosition = Self.uiAutomationDockPosition(
            hasValue: nativeElement.hasDockPosition,
            value: nativeElement.dockPosition)
        let isSelected = Self.optionalBool(
            hasValue: nativeElement.hasIsSelected,
            value: nativeElement.isSelected)
        let selectionCanSelectMultiple = Self.optionalBool(
            hasValue: nativeElement.hasSelectionCanSelectMultiple,
            value: nativeElement.selectionCanSelectMultiple)
        let selectionIsRequired = Self.optionalBool(
            hasValue: nativeElement.hasSelectionIsRequired,
            value: nativeElement.selectionIsRequired)
        let selectionSelectedItemCount = Self.optionalInt(
            hasValue: nativeElement.hasSelectionSelectedItemCount,
            value: nativeElement.selectionSelectedItemCount)
        let legacyDefaultAction = nativeElement.hasLegacyDefaultAction != 0
            ? Self.rawString(from: PeekabooWin11UIAutomationElementLegacyDefaultAction(&nativeElement))
            : nil
        let legacyValue = nativeElement.hasLegacyValue != 0
            ? Self.rawString(from: PeekabooWin11UIAutomationElementLegacyValue(&nativeElement))
            : nil
        let isEnabled = Self.optionalBool(
            hasValue: nativeElement.hasIsEnabled,
            value: nativeElement.isEnabled)
        let hasClickablePoint = Self.optionalBool(
            hasValue: nativeElement.hasClickablePointResult,
            value: nativeElement.hasClickablePoint)
        let clickablePoint = nativeElement.hasClickablePoint != 0
            ? DesktopPoint(
                x: Int(nativeElement.clickablePointX),
                y: Int(nativeElement.clickablePointY))
            : nil
        return DesktopUIAutomationElementSnapshot(
                index: Int(nativeElement.index),
                parentIndex: nativeElement.parentIndex >= 0 ? Int(nativeElement.parentIndex) : nil,
                depth: Int(nativeElement.depth),
                name: Self.string(from: PeekabooWin11UIAutomationElementName(&nativeElement)),
                automationIdentifier: Self.string(
                    from: PeekabooWin11UIAutomationElementAutomationIdentifier(&nativeElement)),
                className: Self.string(from: PeekabooWin11UIAutomationElementClassName(&nativeElement)),
                localizedControlType: Self.string(
                    from: PeekabooWin11UIAutomationElementLocalizedControlType(&nativeElement)),
                accessKey: Self.string(from: PeekabooWin11UIAutomationElementAccessKey(&nativeElement)),
                acceleratorKey: Self.string(
                    from: PeekabooWin11UIAutomationElementAcceleratorKey(&nativeElement)),
                frameworkId: Self.string(from: PeekabooWin11UIAutomationElementFrameworkId(&nativeElement)),
                helpText: Self.string(from: PeekabooWin11UIAutomationElementHelpText(&nativeElement)),
                itemStatus: Self.string(from: PeekabooWin11UIAutomationElementItemStatus(&nativeElement)),
                itemType: Self.string(from: PeekabooWin11UIAutomationElementItemType(&nativeElement)),
                controlType: Int(nativeElement.controlType),
                controlTypeName: Self.uiAutomationControlTypeName(nativeElement.controlType),
                processIdentifier: nativeElement.processIdentifier > 0
                    ? UInt32(nativeElement.processIdentifier)
                    : nil,
                nativeWindowHandle: nativeElement.nativeWindowHandle > 0
                    ? nativeElement.nativeWindowHandle
                    : nil,
                bounds: bounds,
                isEnabled: isEnabled,
                isKeyboardFocusable: isKeyboardFocusable,
                hasKeyboardFocus: Self.optionalBool(
                    hasValue: nativeElement.hasHasKeyboardFocus,
                    value: nativeElement.hasKeyboardFocus),
                isOffscreen: Self.optionalBool(
                    hasValue: nativeElement.hasIsOffscreen,
                    value: nativeElement.isOffscreen),
                hasClickablePoint: hasClickablePoint,
                clickablePoint: clickablePoint,
                supportedPatterns: supportedPatterns,
                availableActions: Self.uiAutomationActions(
                    supportedPatterns: supportedPatterns,
                    isEnabled: isEnabled,
                    isKeyboardFocusable: isKeyboardFocusable,
                    isValueReadOnly: isValueReadOnly,
                    isRangeValueReadOnly: isRangeValueReadOnly,
                    legacyValue: legacyValue,
                    legacyDefaultAction: legacyDefaultAction,
                    isHorizontallyScrollable: isHorizontallyScrollable,
                    isVerticallyScrollable: isVerticallyScrollable,
                    expandCollapseState: expandCollapseState,
                    dockPosition: dockPosition,
                    isSelected: isSelected,
                    selectionCanSelectMultiple: selectionCanSelectMultiple,
                    selectionIsRequired: selectionIsRequired,
                    selectionSelectedItemCount: selectionSelectedItemCount,
                    canMove: Self.optionalBool(
                        hasValue: nativeElement.hasCanMove,
                        value: nativeElement.canMove),
                    canResize: Self.optionalBool(
                        hasValue: nativeElement.hasCanResize,
                        value: nativeElement.canResize),
                    canRotate: Self.optionalBool(
                        hasValue: nativeElement.hasCanRotate,
                        value: nativeElement.canRotate),
                    canZoom: Self.optionalBool(
                        hasValue: nativeElement.hasCanZoom,
                        value: nativeElement.canZoom)),
                value: nativeElement.hasValue != 0
                    ? Self.rawString(from: PeekabooWin11UIAutomationElementValue(&nativeElement))
                    : nil,
                isValueReadOnly: isValueReadOnly,
                rangeValue: Self.optionalDouble(
                    hasValue: nativeElement.hasRangeValue,
                    value: nativeElement.rangeValue),
                rangeMinimum: Self.optionalDouble(
                    hasValue: nativeElement.hasRangeMinimum,
                    value: nativeElement.rangeMinimum),
                rangeMaximum: Self.optionalDouble(
                    hasValue: nativeElement.hasRangeMaximum,
                    value: nativeElement.rangeMaximum),
                rangeSmallChange: Self.optionalDouble(
                    hasValue: nativeElement.hasRangeSmallChange,
                    value: nativeElement.rangeSmallChange),
                rangeLargeChange: Self.optionalDouble(
                    hasValue: nativeElement.hasRangeLargeChange,
                    value: nativeElement.rangeLargeChange),
                isRangeValueReadOnly: isRangeValueReadOnly,
                horizontalScrollPercent: Self.optionalDouble(
                    hasValue: nativeElement.hasHorizontalScrollPercent,
                    value: nativeElement.horizontalScrollPercent),
                verticalScrollPercent: Self.optionalDouble(
                    hasValue: nativeElement.hasVerticalScrollPercent,
                    value: nativeElement.verticalScrollPercent),
                horizontalScrollViewSize: Self.optionalDouble(
                    hasValue: nativeElement.hasHorizontalScrollViewSize,
                    value: nativeElement.horizontalScrollViewSize),
                verticalScrollViewSize: Self.optionalDouble(
                    hasValue: nativeElement.hasVerticalScrollViewSize,
                    value: nativeElement.verticalScrollViewSize),
                isHorizontallyScrollable: isHorizontallyScrollable,
                isVerticallyScrollable: isVerticallyScrollable,
                toggleState: Self.uiAutomationToggleState(
                    hasValue: nativeElement.hasToggleState,
                    value: nativeElement.toggleState),
                expandCollapseState: expandCollapseState,
                windowVisualState: windowVisualState,
                windowInteractionState: windowInteractionState,
                canMaximizeWindow: Self.optionalBool(
                    hasValue: nativeElement.hasCanMaximizeWindow,
                    value: nativeElement.canMaximizeWindow),
                canMinimizeWindow: Self.optionalBool(
                    hasValue: nativeElement.hasCanMinimizeWindow,
                    value: nativeElement.canMinimizeWindow),
                isModalWindow: Self.optionalBool(
                    hasValue: nativeElement.hasIsModalWindow,
                    value: nativeElement.isModalWindow),
                isTopmostWindow: Self.optionalBool(
                    hasValue: nativeElement.hasIsTopmostWindow,
                    value: nativeElement.isTopmostWindow),
                dockPosition: dockPosition,
                text: nativeElement.hasText != 0
                    ? Self.rawString(from: PeekabooWin11UIAutomationElementText(&nativeElement))
                    : nil,
                selectedText: nativeElement.hasSelectedText != 0
                    ? Self.rawString(from: PeekabooWin11UIAutomationElementSelectedText(&nativeElement))
                    : nil,
                selectedTextRangeCount: Self.optionalInt(
                    hasValue: nativeElement.hasSelectedTextRangeCount,
                    value: nativeElement.selectedTextRangeCount),
                visibleText: nativeElement.hasVisibleText != 0
                    ? Self.rawString(from: PeekabooWin11UIAutomationElementVisibleText(&nativeElement))
                    : nil,
                visibleTextRangeCount: Self.optionalInt(
                    hasValue: nativeElement.hasVisibleTextRangeCount,
                    value: nativeElement.visibleTextRangeCount),
                supportedTextSelection: Self.uiAutomationSupportedTextSelection(
                    hasValue: nativeElement.hasSupportedTextSelection,
                    value: nativeElement.supportedTextSelection),
                textCaretIsActive: Self.optionalBool(
                    hasValue: nativeElement.hasTextCaretIsActive,
                    value: nativeElement.textCaretIsActive),
                textCaretBoundingRectangleCount: Self.optionalInt(
                    hasValue: nativeElement.hasTextCaretBoundingRectangleCount,
                    value: nativeElement.textCaretBoundingRectangleCount),
                textEditHasActiveComposition: Self.optionalBool(
                    hasValue: nativeElement.hasTextEditActiveComposition,
                    value: nativeElement.textEditHasActiveComposition),
                textEditActiveCompositionBoundingRectangleCount: Self.optionalInt(
                    hasValue: nativeElement.hasTextEditActiveCompositionBoundingRectangleCount,
                    value: nativeElement.textEditActiveCompositionBoundingRectangleCount),
                textEditHasConversionTarget: Self.optionalBool(
                    hasValue: nativeElement.hasTextEditConversionTarget,
                    value: nativeElement.textEditHasConversionTarget),
                textEditConversionTargetBoundingRectangleCount: Self.optionalInt(
                    hasValue: nativeElement.hasTextEditConversionTargetBoundingRectangleCount,
                    value: nativeElement.textEditConversionTargetBoundingRectangleCount),
                textChildContainerName: nativeElement.hasTextChildContainerName != 0
                    ? Self.rawString(
                        from: PeekabooWin11UIAutomationElementTextChildContainerName(
                            &nativeElement))
                    : nil,
                textChildHasTextRange: Self.optionalBool(
                    hasValue: nativeElement.hasTextChildTextRange,
                    value: nativeElement.textChildHasTextRange),
                textChildRangeBoundingRectangleCount: Self.optionalInt(
                    hasValue: nativeElement.hasTextChildRangeBoundingRectangleCount,
                    value: nativeElement.textChildRangeBoundingRectangleCount),
                gridRowCount: Self.optionalInt(
                    hasValue: nativeElement.hasGridRowCount,
                    value: nativeElement.gridRowCount),
                gridColumnCount: Self.optionalInt(
                    hasValue: nativeElement.hasGridColumnCount,
                    value: nativeElement.gridColumnCount),
                gridItemRow: Self.optionalInt(
                    hasValue: nativeElement.hasGridItemRow,
                    value: nativeElement.gridItemRow),
                gridItemColumn: Self.optionalInt(
                    hasValue: nativeElement.hasGridItemColumn,
                    value: nativeElement.gridItemColumn),
                gridItemRowSpan: Self.optionalInt(
                    hasValue: nativeElement.hasGridItemRowSpan,
                    value: nativeElement.gridItemRowSpan),
                gridItemColumnSpan: Self.optionalInt(
                    hasValue: nativeElement.hasGridItemColumnSpan,
                    value: nativeElement.gridItemColumnSpan),
                spreadsheetItemFormula: nativeElement.hasSpreadsheetItemFormula != 0
                    ? Self.rawString(
                        from: PeekabooWin11UIAutomationElementSpreadsheetItemFormula(
                            &nativeElement))
                    : nil,
                spreadsheetItemAnnotationObjectCount: Self.optionalInt(
                    hasValue: nativeElement.hasSpreadsheetItemAnnotationObjectCount,
                    value: nativeElement.spreadsheetItemAnnotationObjectCount),
                spreadsheetItemAnnotationTypeCount: Self.optionalInt(
                    hasValue: nativeElement.hasSpreadsheetItemAnnotationTypeCount,
                    value: nativeElement.spreadsheetItemAnnotationTypeCount),
                tableRowOrColumnMajor: Self.uiAutomationRowOrColumnMajor(
                    hasValue: nativeElement.hasTableRowOrColumnMajor,
                    value: nativeElement.tableRowOrColumnMajor),
                tableRowHeaderCount: Self.optionalInt(
                    hasValue: nativeElement.hasTableRowHeaderCount,
                    value: nativeElement.tableRowHeaderCount),
                tableColumnHeaderCount: Self.optionalInt(
                    hasValue: nativeElement.hasTableColumnHeaderCount,
                    value: nativeElement.tableColumnHeaderCount),
                tableItemRowHeaderCount: Self.optionalInt(
                    hasValue: nativeElement.hasTableItemRowHeaderCount,
                    value: nativeElement.tableItemRowHeaderCount),
                tableItemColumnHeaderCount: Self.optionalInt(
                    hasValue: nativeElement.hasTableItemColumnHeaderCount,
                    value: nativeElement.tableItemColumnHeaderCount),
                selectionCanSelectMultiple: selectionCanSelectMultiple,
                selectionIsRequired: selectionIsRequired,
                selectionSelectedItemCount: selectionSelectedItemCount,
                canMove: Self.optionalBool(
                    hasValue: nativeElement.hasCanMove,
                    value: nativeElement.canMove),
                canResize: Self.optionalBool(
                    hasValue: nativeElement.hasCanResize,
                    value: nativeElement.canResize),
                canRotate: Self.optionalBool(
                    hasValue: nativeElement.hasCanRotate,
                    value: nativeElement.canRotate),
                canZoom: Self.optionalBool(
                    hasValue: nativeElement.hasCanZoom,
                    value: nativeElement.canZoom),
                zoomLevel: Self.optionalDouble(
                    hasValue: nativeElement.hasZoomLevel,
                    value: nativeElement.zoomLevel),
                zoomMinimum: Self.optionalDouble(
                    hasValue: nativeElement.hasZoomMinimum,
                    value: nativeElement.zoomMinimum),
                zoomMaximum: Self.optionalDouble(
                    hasValue: nativeElement.hasZoomMaximum,
                    value: nativeElement.zoomMaximum),
                multipleViewCurrentView: Self.optionalInt(
                    hasValue: nativeElement.hasMultipleViewCurrentView,
                    value: nativeElement.multipleViewCurrentView),
                multipleViewCurrentViewName: nativeElement.hasMultipleViewCurrentViewName != 0
                    ? Self.rawString(
                        from: PeekabooWin11UIAutomationElementMultipleViewCurrentViewName(
                            &nativeElement))
                    : nil,
                multipleViewSupportedViewCount: Self.optionalInt(
                    hasValue: nativeElement.hasMultipleViewSupportedViewCount,
                    value: nativeElement.multipleViewSupportedViewCount),
                annotationTypeId: Self.optionalInt(
                    hasValue: nativeElement.hasAnnotationTypeId,
                    value: nativeElement.annotationTypeId),
                annotationTypeName: nativeElement.hasAnnotationTypeName != 0
                    ? Self.rawString(
                        from: PeekabooWin11UIAutomationElementAnnotationTypeName(&nativeElement))
                    : nil,
                annotationAuthor: nativeElement.hasAnnotationAuthor != 0
                    ? Self.rawString(
                        from: PeekabooWin11UIAutomationElementAnnotationAuthor(&nativeElement))
                    : nil,
                annotationDateTime: nativeElement.hasAnnotationDateTime != 0
                    ? Self.rawString(
                        from: PeekabooWin11UIAutomationElementAnnotationDateTime(&nativeElement))
                    : nil,
                annotationTargetName: nativeElement.hasAnnotationTargetName != 0
                    ? Self.rawString(
                        from: PeekabooWin11UIAutomationElementAnnotationTargetName(&nativeElement))
                    : nil,
                styleId: Self.optionalInt(
                    hasValue: nativeElement.hasStyleId,
                    value: nativeElement.styleId),
                styleName: nativeElement.hasStyleName != 0
                    ? Self.rawString(from: PeekabooWin11UIAutomationElementStyleName(&nativeElement))
                    : nil,
                styleFillColor: Self.optionalInt(
                    hasValue: nativeElement.hasStyleFillColor,
                    value: nativeElement.styleFillColor),
                styleFillPatternColor: Self.optionalInt(
                    hasValue: nativeElement.hasStyleFillPatternColor,
                    value: nativeElement.styleFillPatternColor),
                styleShape: nativeElement.hasStyleShape != 0
                    ? Self.rawString(from: PeekabooWin11UIAutomationElementStyleShape(&nativeElement))
                    : nil,
                styleExtendedProperties: nativeElement.hasStyleExtendedProperties != 0
                    ? Self.rawString(
                        from: PeekabooWin11UIAutomationElementStyleExtendedProperties(
                            &nativeElement))
                    : nil,
                dragDropEffect: nativeElement.hasDragDropEffect != 0
                    ? Self.rawString(from: PeekabooWin11UIAutomationElementDragDropEffect(&nativeElement))
                    : nil,
                dragDropEffectCount: Self.optionalInt(
                    hasValue: nativeElement.hasDragDropEffectCount,
                    value: nativeElement.dragDropEffectCount),
                dragIsGrabbed: Self.optionalBool(
                    hasValue: nativeElement.hasDragIsGrabbed,
                    value: nativeElement.dragIsGrabbed),
                dragGrabbedItemCount: Self.optionalInt(
                    hasValue: nativeElement.hasDragGrabbedItemCount,
                    value: nativeElement.dragGrabbedItemCount),
                dropTargetEffect: nativeElement.hasDropTargetEffect != 0
                    ? Self.rawString(
                        from: PeekabooWin11UIAutomationElementDropTargetEffect(&nativeElement))
                    : nil,
                dropTargetEffectCount: Self.optionalInt(
                    hasValue: nativeElement.hasDropTargetEffectCount,
                    value: nativeElement.dropTargetEffectCount),
                legacyChildId: Self.optionalInt(
                    hasValue: nativeElement.hasLegacyChildId,
                    value: nativeElement.legacyChildId),
                legacyName: nativeElement.hasLegacyName != 0
                    ? Self.rawString(from: PeekabooWin11UIAutomationElementLegacyName(&nativeElement))
                    : nil,
                legacyValue: legacyValue,
                legacyDescription: nativeElement.hasLegacyDescription != 0
                    ? Self.rawString(
                        from: PeekabooWin11UIAutomationElementLegacyDescription(&nativeElement))
                    : nil,
                legacyHelp: nativeElement.hasLegacyHelp != 0
                    ? Self.rawString(from: PeekabooWin11UIAutomationElementLegacyHelp(&nativeElement))
                    : nil,
                legacyKeyboardShortcut: nativeElement.hasLegacyKeyboardShortcut != 0
                    ? Self.rawString(
                        from: PeekabooWin11UIAutomationElementLegacyKeyboardShortcut(&nativeElement))
                    : nil,
                legacyDefaultAction: legacyDefaultAction,
                legacyRole: Self.optionalInt(
                    hasValue: nativeElement.hasLegacyRole,
                    value: nativeElement.legacyRole),
                legacyState: Self.optionalInt(
                    hasValue: nativeElement.hasLegacyState,
                    value: nativeElement.legacyState),
                isSelected: isSelected,
                childCount: Int(nativeElement.childCount))
    }

    private static func uiAutomationActions(
        supportedPatterns: [DesktopUIAutomationPattern],
        isEnabled: Bool?,
        isKeyboardFocusable: Bool?,
        isValueReadOnly: Bool?,
        isRangeValueReadOnly: Bool?,
        legacyValue: String?,
        legacyDefaultAction: String?,
        isHorizontallyScrollable: Bool?,
        isVerticallyScrollable: Bool?,
        expandCollapseState: DesktopUIAutomationExpandCollapseState?,
        dockPosition _: DesktopUIAutomationDockPosition?,
        isSelected: Bool?,
        selectionCanSelectMultiple: Bool?,
        selectionIsRequired: Bool?,
        selectionSelectedItemCount: Int?,
        canMove: Bool?,
        canResize: Bool?,
        canRotate: Bool?,
        canZoom: Bool?) -> [DesktopUIAutomationAction]
    {
        var actions: [DesktopUIAutomationAction] = []
        if isKeyboardFocusable == true, isEnabled != false {
            actions.append(.focus)
        }
        if supportedPatterns.contains(.invoke) {
            actions.append(.invoke)
        }
        if supportedPatterns.contains(.legacyIAccessible),
            let legacyDefaultAction,
            !legacyDefaultAction.isEmpty
        {
            actions.append(.performLegacyDefaultAction)
        }
        if supportedPatterns.contains(.legacyIAccessible), legacyValue != nil, isEnabled != false {
            actions.append(.setLegacyValue)
        }
        if supportedPatterns.contains(.value), isValueReadOnly == false, isEnabled != false {
            actions.append(.setValue)
        }
        if supportedPatterns.contains(.text) {
            actions.append(.getText)
        }
        if supportedPatterns.contains(.rangeValue), isRangeValueReadOnly == false {
            actions.append(.setRangeValue)
        }
        if supportedPatterns.contains(.scroll),
            isHorizontallyScrollable == true || isVerticallyScrollable == true
        {
            actions.append(.setScrollPercent)
        }
        if supportedPatterns.contains(.window) {
            actions.append(.setWindowVisualState)
            actions.append(.closeWindow)
            actions.append(.waitForWindowInputIdle)
        }
        if supportedPatterns.contains(.dock) {
            actions.append(.setDockPosition)
        }
        if supportedPatterns.contains(.multipleView) {
            actions.append(.setCurrentView)
        }
        if supportedPatterns.contains(.transform2), canZoom == true {
            actions.append(.setZoomLevel)
            actions.append(.zoomByUnit)
        }
        if supportedPatterns.contains(.synchronizedInput) {
            actions.append(.startSynchronizedInput)
            actions.append(.cancelSynchronizedInput)
        }
        if supportedPatterns.contains(.customNavigation) {
            actions.append(.navigateCustom)
        }
        if supportedPatterns.contains(.itemContainer) {
            actions.append(.findItemByProperty)
        }
        if supportedPatterns.contains(.spreadsheet) {
            actions.append(.getSpreadsheetItem)
        }
        if supportedPatterns.contains(.grid) {
            actions.append(.getGridItem)
        }
        if supportedPatterns.contains(.transform), canMove == true {
            actions.append(.move)
        }
        if supportedPatterns.contains(.transform), canResize == true {
            actions.append(.resize)
        }
        if supportedPatterns.contains(.transform), canRotate == true {
            actions.append(.rotate)
        }
        if supportedPatterns.contains(.virtualizedItem) {
            actions.append(.realize)
        }
        if supportedPatterns.contains(.toggle) {
            actions.append(.toggle)
        }
        if supportedPatterns.contains(.expandCollapse) {
            switch expandCollapseState {
            case .collapsed:
                actions.append(.expand)
            case .expanded:
                actions.append(.collapse)
            case .partiallyExpanded:
                actions.append(.expand)
                actions.append(.collapse)
            case .leafNode, nil:
                break
            }
        }
        if supportedPatterns.contains(.selectionItem) {
            actions.append(.select)
            if selectionCanSelectMultiple == true {
                actions.append(.addToSelection)
            }
            if isSelected == true,
                selectionIsRequired != true || (selectionSelectedItemCount ?? 0) > 1
            {
                actions.append(.removeFromSelection)
            }
        }
        if supportedPatterns.contains(.scrollItem) {
            actions.append(.scrollIntoView)
        }
        return actions
    }

    private static func uiAutomationToggleState(
        hasValue: Int32,
        value: Int32) -> DesktopUIAutomationToggleState?
    {
        guard hasValue != 0 else {
            return nil
        }
        switch value {
        case 0:
            return .off
        case 1:
            return .on
        case 2:
            return .indeterminate
        default:
            return nil
        }
    }

    private static func uiAutomationExpandCollapseState(
        hasValue: Int32,
        value: Int32) -> DesktopUIAutomationExpandCollapseState?
    {
        guard hasValue != 0 else {
            return nil
        }
        switch value {
        case 0:
            return .collapsed
        case 1:
            return .expanded
        case 2:
            return .partiallyExpanded
        case 3:
            return .leafNode
        default:
            return nil
        }
    }

    private static func uiAutomationWindowVisualState(
        hasValue: Int32,
        value: Int32) -> DesktopUIAutomationWindowVisualState?
    {
        guard hasValue != 0 else {
            return nil
        }
        switch value {
        case 0:
            return .normal
        case 1:
            return .maximized
        case 2:
            return .minimized
        default:
            return nil
        }
    }

    private static func nativeWindowVisualState(_ state: DesktopUIAutomationWindowVisualState) -> Int32 {
        switch state {
        case .normal:
            return 0
        case .maximized:
            return 1
        case .minimized:
            return 2
        }
    }

    private static func uiAutomationDockPosition(
        hasValue: Int32,
        value: Int32) -> DesktopUIAutomationDockPosition?
    {
        guard hasValue != 0 else {
            return nil
        }
        switch value {
        case 0:
            return .top
        case 1:
            return .left
        case 2:
            return .bottom
        case 3:
            return .right
        case 4:
            return .fill
        case 5:
            return .none
        default:
            return nil
        }
    }

    private static func nativeDockPosition(_ position: DesktopUIAutomationDockPosition) -> Int32 {
        switch position {
        case .top:
            return 0
        case .left:
            return 1
        case .bottom:
            return 2
        case .right:
            return 3
        case .fill:
            return 4
        case .none:
            return 5
        }
    }

    private static func nativeZoomUnit(_ unit: DesktopUIAutomationZoomUnit) -> Int32 {
        switch unit {
        case .none:
            return 0
        case .largeDecrement:
            return 1
        case .smallDecrement:
            return 2
        case .largeIncrement:
            return 3
        case .smallIncrement:
            return 4
        }
    }

    private static func nativeSynchronizedInputType(
        _ inputType: DesktopUIAutomationSynchronizedInputType) -> Int32
    {
        switch inputType {
        case .keyUp:
            return 1
        case .keyDown:
            return 2
        case .mouseLeftButtonUp:
            return 4
        case .mouseLeftButtonDown:
            return 8
        case .mouseRightButtonUp:
            return 16
        case .mouseRightButtonDown:
            return 32
        }
    }

    private static func nativeNavigationDirection(
        _ direction: DesktopUIAutomationNavigationDirection) -> Int32
    {
        switch direction {
        case .parent:
            return 0
        case .nextSibling:
            return 1
        case .previousSibling:
            return 2
        case .firstChild:
            return 3
        case .lastChild:
            return 4
        }
    }

    private static func nativeItemContainerProperty(
        _ property: DesktopUIAutomationItemContainerProperty) -> Int32
    {
        switch property {
        case .name:
            return 1
        case .automationId:
            return 2
        }
    }

    private static func nativeTextSource(_ source: DesktopUIAutomationTextSource) -> Int32 {
        switch source {
        case .document:
            return 1
        case .selected:
            return 2
        case .visible:
            return 3
        }
    }

    private static func spreadsheetItemWasVerified(
        resultElement: DesktopUIAutomationElementSnapshot?,
        name: String) -> Bool?
    {
        resultElement?.name.map { $0 == name }
    }

    private static func itemContainerResultWasVerified(
        resultElement: DesktopUIAutomationElementSnapshot?,
        property: DesktopUIAutomationItemContainerProperty,
        value: String) -> Bool?
    {
        switch property {
        case .name:
            return resultElement?.name.map { $0 == value }
        case .automationId:
            return resultElement?.automationIdentifier.map { $0 == value }
        }
    }

    private static func gridItemWasVerified(
        resultElement: DesktopUIAutomationElementSnapshot?,
        row: Int,
        column: Int) -> Bool?
    {
        guard let resultRow = resultElement?.gridItemRow,
              let resultColumn = resultElement?.gridItemColumn
        else {
            return nil
        }
        return resultRow == row && resultColumn == column
    }

    private static func textResultWasVerified(
        result: String,
        maxLength: Int,
        source: DesktopUIAutomationTextSource,
        element: DesktopUIAutomationElementSnapshot) -> Bool?
    {
        let observed: String?
        switch source {
        case .document:
            observed = element.text
        case .selected:
            observed = element.selectedText
        case .visible:
            observed = element.visibleText
        }

        guard let observed else {
            return nil
        }
        if String(observed.prefix(maxLength)) == result {
            return true
        }
        if observed.utf8.count < 255 {
            return false
        }
        return nil
    }

    private static func zoomByUnitWasVerified(
        previousZoomLevel: Double?,
        postActionElement: DesktopUIAutomationElementSnapshot?,
        unit: DesktopUIAutomationZoomUnit) -> Bool?
    {
        guard let previousZoomLevel, let postZoomLevel = postActionElement?.zoomLevel else {
            return nil
        }
        switch unit {
        case .none:
            return abs(postZoomLevel - previousZoomLevel) < 0.0001
        case .largeIncrement, .smallIncrement:
            return postZoomLevel > previousZoomLevel
        case .largeDecrement, .smallDecrement:
            return postZoomLevel < previousZoomLevel
        }
    }

    private static func uiAutomationWindowInteractionState(
        hasValue: Int32,
        value: Int32) -> DesktopUIAutomationWindowInteractionState?
    {
        guard hasValue != 0 else {
            return nil
        }
        switch value {
        case 0:
            return .running
        case 1:
            return .closing
        case 2:
            return .readyForUserInteraction
        case 3:
            return .blockedByModalWindow
        case 4:
            return .notResponding
        default:
            return nil
        }
    }

    private static func uiAutomationSupportedTextSelection(
        hasValue: Int32,
        value: Int32) -> DesktopUIAutomationSupportedTextSelection?
    {
        guard hasValue != 0 else {
            return nil
        }
        switch value {
        case 0:
            return .none
        case 1:
            return .single
        case 2:
            return .multiple
        default:
            return nil
        }
    }

    private static func uiAutomationRowOrColumnMajor(
        hasValue: Int32,
        value: Int32) -> DesktopUIAutomationRowOrColumnMajor?
    {
        guard hasValue != 0 else {
            return nil
        }
        switch value {
        case 0:
            return .rowMajor
        case 1:
            return .columnMajor
        case 2:
            return .indeterminate
        default:
            return nil
        }
    }

    private static func uiAutomationPatterns(from mask: UInt64) -> [DesktopUIAutomationPattern] {
        var patterns: [DesktopUIAutomationPattern] = []
        if Self.hasPatternBit(mask, 0) {
            patterns.append(.invoke)
        }
        if Self.hasPatternBit(mask, 1) {
            patterns.append(.value)
        }
        if Self.hasPatternBit(mask, 2) {
            patterns.append(.rangeValue)
        }
        if Self.hasPatternBit(mask, 3) {
            patterns.append(.scroll)
        }
        if Self.hasPatternBit(mask, 4) {
            patterns.append(.expandCollapse)
        }
        if Self.hasPatternBit(mask, 5) {
            patterns.append(.window)
        }
        if Self.hasPatternBit(mask, 15) {
            patterns.append(.dock)
        }
        if Self.hasPatternBit(mask, 14) {
            patterns.append(.selection)
        }
        if Self.hasPatternBit(mask, 6) {
            patterns.append(.selectionItem)
        }
        if Self.hasPatternBit(mask, 7) {
            patterns.append(.text)
        }
        if Self.hasPatternBit(mask, 25) {
            patterns.append(.text2)
        }
        if Self.hasPatternBit(mask, 26) {
            patterns.append(.textEdit)
        }
        if Self.hasPatternBit(mask, 27) {
            patterns.append(.textChild)
        }
        if Self.hasPatternBit(mask, 8) {
            patterns.append(.toggle)
        }
        if Self.hasPatternBit(mask, 9) {
            patterns.append(.legacyIAccessible)
        }
        if Self.hasPatternBit(mask, 30) {
            patterns.append(.itemContainer)
        }
        if Self.hasPatternBit(mask, 31) {
            patterns.append(.synchronizedInput)
        }
        if Self.hasPatternBit(mask, 32) {
            patterns.append(.objectModel)
        }
        if Self.hasPatternBit(mask, 10) {
            patterns.append(.grid)
        }
        if Self.hasPatternBit(mask, 11) {
            patterns.append(.gridItem)
        }
        if Self.hasPatternBit(mask, 28) {
            patterns.append(.spreadsheet)
        }
        if Self.hasPatternBit(mask, 29) {
            patterns.append(.spreadsheetItem)
        }
        if Self.hasPatternBit(mask, 16) {
            patterns.append(.table)
        }
        if Self.hasPatternBit(mask, 17) {
            patterns.append(.tableItem)
        }
        if Self.hasPatternBit(mask, 12) {
            patterns.append(.transform)
        }
        if Self.hasPatternBit(mask, 18) {
            patterns.append(.transform2)
        }
        if Self.hasPatternBit(mask, 19) {
            patterns.append(.multipleView)
        }
        if Self.hasPatternBit(mask, 20) {
            patterns.append(.virtualizedItem)
        }
        if Self.hasPatternBit(mask, 21) {
            patterns.append(.annotation)
        }
        if Self.hasPatternBit(mask, 22) {
            patterns.append(.styles)
        }
        if Self.hasPatternBit(mask, 23) {
            patterns.append(.drag)
        }
        if Self.hasPatternBit(mask, 24) {
            patterns.append(.dropTarget)
        }
        if Self.hasPatternBit(mask, 33) {
            patterns.append(.customNavigation)
        }
        if Self.hasPatternBit(mask, 13) {
            patterns.append(.scrollItem)
        }
        return patterns
    }

    private static func hasPatternBit(_ mask: UInt64, _ bit: Int) -> Bool {
        (mask & (UInt64(1) << UInt64(bit))) != 0
    }

    private static func uiAutomationControlTypeName(_ controlType: Int32) -> String? {
        switch controlType {
        case 50_000:
            return "Button"
        case 50_001:
            return "Calendar"
        case 50_002:
            return "CheckBox"
        case 50_003:
            return "ComboBox"
        case 50_004:
            return "Edit"
        case 50_005:
            return "Hyperlink"
        case 50_006:
            return "Image"
        case 50_007:
            return "ListItem"
        case 50_008:
            return "List"
        case 50_009:
            return "Menu"
        case 50_010:
            return "MenuBar"
        case 50_011:
            return "MenuItem"
        case 50_012:
            return "ProgressBar"
        case 50_013:
            return "RadioButton"
        case 50_014:
            return "ScrollBar"
        case 50_015:
            return "Slider"
        case 50_016:
            return "Spinner"
        case 50_017:
            return "StatusBar"
        case 50_018:
            return "Tab"
        case 50_019:
            return "TabItem"
        case 50_020:
            return "Text"
        case 50_021:
            return "ToolBar"
        case 50_022:
            return "ToolTip"
        case 50_023:
            return "Tree"
        case 50_024:
            return "TreeItem"
        case 50_025:
            return "Custom"
        case 50_026:
            return "Group"
        case 50_027:
            return "Thumb"
        case 50_028:
            return "DataGrid"
        case 50_029:
            return "DataItem"
        case 50_030:
            return "Document"
        case 50_031:
            return "SplitButton"
        case 50_032:
            return "Window"
        case 50_033:
            return "Pane"
        case 50_034:
            return "Header"
        case 50_035:
            return "HeaderItem"
        case 50_036:
            return "Table"
        case 50_037:
            return "TitleBar"
        case 50_038:
            return "Separator"
        case 50_039:
            return "SemanticZoom"
        case 50_040:
            return "AppBar"
        default:
            return nil
        }
    }

    private static func string(from pointer: UnsafePointer<CChar>?) -> String? {
        guard let pointer else {
            return nil
        }
        let value = String(cString: pointer)
        return value.isEmpty ? nil : value
    }

    private static func rawString(from pointer: UnsafePointer<CChar>?) -> String {
        guard let pointer else {
            return ""
        }
        return String(cString: pointer)
    }

    private static func optionalBool(hasValue: Int32, value: Int32) -> Bool? {
        guard hasValue != 0 else {
            return nil
        }
        return value != 0
    }

    private static func optionalDouble(hasValue: Int32, value: Double) -> Double? {
        guard hasValue != 0 else {
            return nil
        }
        return value
    }

    private static func optionalInt(hasValue: Int32, value: Int32) -> Int? {
        guard hasValue != 0 else {
            return nil
        }
        return Int(value)
    }

    private static let noScrollPercent = -1.0

    private static func rangeValueString(_ value: Double) -> String {
        String(value)
    }

    private static func validateScrollPercent(_ value: Double?, axisName: String) throws {
        guard let value else {
            return
        }
        guard value.isFinite, (0.0...100.0).contains(value) else {
            throw Win11DesktopError.invalidArgument(
                "UI Automation \(axisName) scroll percent must be between 0 and 100")
        }
    }

    private static func scrollPercentString(
        horizontalPercent: Double?,
        verticalPercent: Double?) -> String
    {
        let horizontal = horizontalPercent.map { String($0) } ?? "noScroll"
        let vertical = verticalPercent.map { String($0) } ?? "noScroll"
        return "horizontal=\(horizontal),vertical=\(vertical)"
    }

    private static func scrollPercentWasVerified(
        postActionElement: DesktopUIAutomationElementSnapshot?,
        horizontalPercent: Double?,
        verticalPercent: Double?) -> Bool?
    {
        guard let postActionElement else {
            return nil
        }
        if let horizontalPercent {
            guard let actual = postActionElement.horizontalScrollPercent else {
                return nil
            }
            guard abs(actual - horizontalPercent) <= 0.000_001 else {
                return false
            }
        }
        if let verticalPercent {
            guard let actual = postActionElement.verticalScrollPercent else {
                return nil
            }
            guard abs(actual - verticalPercent) <= 0.000_001 else {
                return false
            }
        }
        return true
    }

    private static func transformValueString(
        action: DesktopUIAutomationAction,
        firstValue: Double,
        secondValue: Double) -> String
    {
        if action == .move {
            return "x=\(firstValue),y=\(secondValue)"
        }
        if action == .rotate {
            return "degrees=\(firstValue)"
        }
        return "width=\(firstValue),height=\(secondValue)"
    }

    private static func transformWasVerified(
        action: DesktopUIAutomationAction,
        postActionElement: DesktopUIAutomationElementSnapshot?,
        firstValue: Double,
        secondValue: Double) -> Bool?
    {
        if action == .rotate {
            return nil
        }
        guard let bounds = postActionElement?.bounds else {
            return nil
        }
        if action == .move {
            return abs(Double(bounds.x) - firstValue) <= 0.000_001 &&
                abs(Double(bounds.y) - secondValue) <= 0.000_001
        }
        return abs(Double(bounds.width) - firstValue) <= 0.000_001 &&
            abs(Double(bounds.height) - secondValue) <= 0.000_001
    }

    private static func toggleWasVerified(
        previousState: DesktopUIAutomationToggleState?,
        postActionElement: DesktopUIAutomationElementSnapshot?) -> Bool?
    {
        guard let previousState, let currentState = postActionElement?.toggleState else {
            return nil
        }
        return currentState != previousState
    }

    private static func succeeded(_ result: Int32) -> Bool {
        result >= 0
    }

    private static func hresultDescription(_ result: Int32) -> String {
        let bits = UInt32(bitPattern: result)
        return "0x" + String(bits, radix: 16, uppercase: true)
    }

    private static func captureRegion(bounds: Win11Rect, outputPath: String) throws -> Win11CaptureResult {
        guard !bounds.isEmpty else {
            throw Win11DesktopError.emptyCaptureRegion(bounds)
        }

        guard let desktopDC = GetDC(nil) else {
            throw Win11DesktopError.nativeCallFailed("GetDC")
        }
        defer { ReleaseDC(nil, desktopDC) }

        guard let memoryDC = CreateCompatibleDC(desktopDC) else {
            throw Win11DesktopError.nativeCallFailed("CreateCompatibleDC")
        }
        defer { DeleteDC(memoryDC) }

        guard let bitmap = CreateCompatibleBitmap(desktopDC, Int32(bounds.width), Int32(bounds.height)) else {
            throw Win11DesktopError.nativeCallFailed("CreateCompatibleBitmap")
        }
        defer { DeleteObject(bitmap) }

        let oldObject = SelectObject(memoryDC, bitmap)
        defer { SelectObject(memoryDC, oldObject) }

        guard BitBlt(
            memoryDC,
            0,
            0,
            Int32(bounds.width),
            Int32(bounds.height),
            desktopDC,
            Int32(bounds.x),
            Int32(bounds.y),
            DWORD(SRCCOPY))
        else {
            throw Win11DesktopError.nativeCallFailed("BitBlt")
        }

        let data = try Self.bitmapData(bitmap: bitmap, dc: memoryDC, width: bounds.width, height: bounds.height)
        let outputURL = URL(fileURLWithPath: outputPath)
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        try data.write(to: outputURL, options: [.atomic])

        return Win11CaptureResult(path: outputPath, bounds: bounds, format: .bmp, byteCount: data.count)
    }

    private static func virtualScreenBounds() -> Win11Rect {
        let x = Int(GetSystemMetrics(SM_XVIRTUALSCREEN))
        let y = Int(GetSystemMetrics(SM_YVIRTUALSCREEN))
        let width = Int(GetSystemMetrics(SM_CXVIRTUALSCREEN))
        let height = Int(GetSystemMetrics(SM_CYVIRTUALSCREEN))
        return Win11Rect(x: x, y: y, width: width, height: height)
    }

    fileprivate static func rect(from value: RECT) -> Win11Rect {
        Win11Rect(
            x: Int(value.left),
            y: Int(value.top),
            width: Int(value.right - value.left),
            height: Int(value.bottom - value.top))
    }

    fileprivate static func windowTitle(_ hwnd: HWND?) -> String {
        let length = Int(GetWindowTextLengthW(hwnd))
        guard length > 0 else {
            return ""
        }

        var buffer = [WCHAR](repeating: 0, count: length + 1)
        let written = GetWindowTextW(hwnd, &buffer, Int32(buffer.count))
        guard written > 0 else {
            return ""
        }

        return String(decoding: buffer.prefix(Int(written)), as: UTF16.self)
    }

    fileprivate static func processIdentifier(for hwnd: HWND?) -> UInt32? {
        guard let hwnd else {
            return nil
        }

        var processId: DWORD = 0
        GetWindowThreadProcessId(hwnd, &processId)
        return UInt32(processId)
    }

    fileprivate static func executablePath(processIdentifier: UInt32) -> String? {
        let handle = OpenProcess(DWORD(PROCESS_QUERY_LIMITED_INFORMATION), false, DWORD(processIdentifier))
        guard let handle else {
            return nil
        }
        defer { CloseHandle(handle) }

        var buffer = [WCHAR](repeating: 0, count: Int(MAX_PATH))
        var size = DWORD(buffer.count)
        guard QueryFullProcessImageNameW(handle, 0, &buffer, &size) else {
            return nil
        }

        return String(decoding: buffer.prefix(Int(size)), as: UTF16.self)
    }

    fileprivate static func lastPathComponent(_ path: String) -> String {
        path.replacingOccurrences(of: "\\", with: "/")
            .split(separator: "/")
            .last
            .map(String.init) ?? path
    }

    private static func bitmapData(bitmap: HBITMAP, dc: HDC, width: Int, height: Int) throws -> Data {
        let bytesPerPixel = 4
        let imageByteCount = width * height * bytesPerPixel

        var bitmapInfo = BITMAPINFO()
        bitmapInfo.bmiHeader.biSize = DWORD(MemoryLayout<BITMAPINFOHEADER>.size)
        bitmapInfo.bmiHeader.biWidth = LONG(width)
        bitmapInfo.bmiHeader.biHeight = -LONG(height)
        bitmapInfo.bmiHeader.biPlanes = 1
        bitmapInfo.bmiHeader.biBitCount = 32
        bitmapInfo.bmiHeader.biCompression = DWORD(BI_RGB)

        var pixels = [UInt8](repeating: 0, count: imageByteCount)
        let lines = pixels.withUnsafeMutableBytes { buffer in
            GetDIBits(
                dc,
                bitmap,
                0,
                UINT(height),
                buffer.baseAddress,
                &bitmapInfo,
                UINT(DIB_RGB_COLORS))
        }

        guard Int(lines) == height else {
            throw Win11DesktopError.nativeCallFailed("GetDIBits")
        }

        var data = Data()
        let fileHeaderSize = 14
        let infoHeaderSize = MemoryLayout<BITMAPINFOHEADER>.size
        let pixelDataOffset = fileHeaderSize + infoHeaderSize
        let fileSize = pixelDataOffset + pixels.count

        data.append(contentsOf: [0x42, 0x4d])
        data.appendLittleEndian(UInt32(fileSize))
        data.appendLittleEndian(UInt16(0))
        data.appendLittleEndian(UInt16(0))
        data.appendLittleEndian(UInt32(pixelDataOffset))
        data.appendLittleEndian(UInt32(infoHeaderSize))
        data.appendLittleEndian(Int32(width))
        data.appendLittleEndian(Int32(-height))
        data.appendLittleEndian(UInt16(1))
        data.appendLittleEndian(UInt16(32))
        data.appendLittleEndian(UInt32(BI_RGB))
        data.appendLittleEndian(UInt32(pixels.count))
        data.appendLittleEndian(Int32(0))
        data.appendLittleEndian(Int32(0))
        data.appendLittleEndian(UInt32(0))
        data.appendLittleEndian(UInt32(0))
        data.append(contentsOf: pixels)

        return data
    }
}

private final class DisplayCollector {
    var displays: [Win11Display] = []
}

private final class WindowCollector {
    let includeInvisible: Bool
    var windows: [Win11Window] = []

    init(includeInvisible: Bool) {
        self.includeInvisible = includeInvisible
    }
}

private struct Win32VirtualKey {
    let name: String
    let virtualKey: BYTE
}

private let displayEnumerationCallback: MONITORENUMPROC = { monitor, _, _, context in
    guard let rawContext = UnsafeRawPointer(bitPattern: Int(context)) else {
        return true
    }
    guard let monitor else {
        return true
    }

    let collector = Unmanaged<DisplayCollector>.fromOpaque(rawContext).takeUnretainedValue()

    var info = MONITORINFO()
    info.cbSize = DWORD(MemoryLayout<MONITORINFO>.size)
    guard GetMonitorInfoW(monitor, &info) else {
        return true
    }

    let display = Win11Display(
        id: UInt64(UInt(bitPattern: monitor)),
        index: collector.displays.count,
        bounds: Win32DesktopAdapter.rect(from: info.rcMonitor),
        workArea: Win32DesktopAdapter.rect(from: info.rcWork),
        isPrimary: (info.dwFlags & DWORD(MONITORINFOF_PRIMARY)) != 0)
    collector.displays.append(display)
    return true
}

private let windowEnumerationCallback: WNDENUMPROC = { hwnd, context in
    guard let rawContext = UnsafeRawPointer(bitPattern: Int(context)) else {
        return true
    }
    guard let hwnd else {
        return true
    }

    let collector = Unmanaged<WindowCollector>.fromOpaque(rawContext).takeUnretainedValue()
    let isVisible = IsWindowVisible(hwnd)
    if !collector.includeInvisible && !isVisible {
        return true
    }

    var rect = RECT()
    guard GetWindowRect(hwnd, &rect) else {
        return true
    }

    let bounds = Win32DesktopAdapter.rect(from: rect)
    if bounds.isEmpty {
        return true
    }

    let title = Win32DesktopAdapter.windowTitle(hwnd)
    if title.isEmpty && !collector.includeInvisible {
        return true
    }

    let pid = Win32DesktopAdapter.processIdentifier(for: hwnd) ?? 0
    let executablePath = Win32DesktopAdapter.executablePath(processIdentifier: pid)
    let foregroundWindow = GetForegroundWindow()

    let window = Win11Window(
        windowIdentifier: UInt64(UInt(bitPattern: hwnd)),
        processIdentifier: pid,
        title: title,
        bounds: bounds,
        isVisible: isVisible,
        isMinimized: IsIconic(hwnd),
        isForeground: hwnd == foregroundWindow,
        executableName: executablePath.map(Win32DesktopAdapter.lastPathComponent),
        index: collector.windows.count,
        isOnScreen: isVisible)
    collector.windows.append(window)
    return true
}

private extension Data {
    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { bytes in
            self.append(contentsOf: bytes)
        }
    }
}
#endif
