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
