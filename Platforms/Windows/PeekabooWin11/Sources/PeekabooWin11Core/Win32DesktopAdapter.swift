#if os(Windows)
import Foundation
import PeekabooDesktop
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
