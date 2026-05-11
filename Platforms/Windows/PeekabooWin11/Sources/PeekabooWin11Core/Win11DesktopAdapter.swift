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

    public func captureFrontmost(outputPath: String) throws -> Win11CaptureResult {
        throw self.unsupported()
    }

    public func cursorPosition() throws -> DesktopPoint {
        throw self.unsupported()
    }

    public func moveCursor(to _: DesktopPoint) throws -> DesktopPoint {
        throw self.unsupported()
    }

    public func click(
        at _: DesktopPoint,
        button _: DesktopMouseButton,
        clickCount _: Int) throws -> DesktopClickResult
    {
        throw self.unsupported()
    }

    public func scroll(
        at _: DesktopPoint,
        direction _: DesktopScrollDirection,
        amount _: Int) throws -> DesktopScrollResult
    {
        throw self.unsupported()
    }

    public func drag(
        from _: DesktopPoint,
        to _: DesktopPoint,
        button _: DesktopMouseButton,
        steps _: Int) throws -> DesktopDragResult
    {
        throw self.unsupported()
    }

    public func hotkey(keys _: [String], holdDurationMilliseconds _: Int) throws -> DesktopHotkeyResult {
        throw self.unsupported()
    }

    public func typeText(_: String, delayMilliseconds _: Int) throws -> DesktopTypingResult {
        throw self.unsupported()
    }

    public func uiAutomationStatus() throws -> DesktopUIAutomationStatus {
        throw self.unsupported()
    }

    public func uiAutomationSnapshot(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int) throws -> DesktopUIAutomationSnapshot
    {
        throw self.unsupported()
    }

    public func invokeUIAutomationElement(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int,
        elementIndex _: Int) throws -> DesktopUIAutomationActionResult
    {
        throw self.unsupported()
    }

    public func focusUIAutomationElement(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int,
        elementIndex _: Int) throws -> DesktopUIAutomationActionResult
    {
        throw self.unsupported()
    }

    public func performUIAutomationElementLegacyDefaultAction(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int,
        elementIndex _: Int) throws -> DesktopUIAutomationActionResult
    {
        throw self.unsupported()
    }

    public func setUIAutomationElementLegacyValue(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int,
        elementIndex _: Int,
        value _: String) throws -> DesktopUIAutomationActionResult
    {
        throw self.unsupported()
    }

    public func setUIAutomationElementValue(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int,
        elementIndex _: Int,
        value _: String) throws -> DesktopUIAutomationActionResult
    {
        throw self.unsupported()
    }

    public func setUIAutomationElementRangeValue(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int,
        elementIndex _: Int,
        value _: Double) throws -> DesktopUIAutomationActionResult
    {
        throw self.unsupported()
    }

    public func setUIAutomationElementScrollPercent(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int,
        elementIndex _: Int,
        horizontalPercent _: Double?,
        verticalPercent _: Double?) throws -> DesktopUIAutomationActionResult
    {
        throw self.unsupported()
    }

    public func setUIAutomationElementWindowVisualState(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int,
        elementIndex _: Int,
        state _: DesktopUIAutomationWindowVisualState) throws -> DesktopUIAutomationActionResult
    {
        throw self.unsupported()
    }

    public func closeUIAutomationWindow(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int,
        elementIndex _: Int) throws -> DesktopUIAutomationActionResult
    {
        throw self.unsupported()
    }

    public func waitForUIAutomationWindowInputIdle(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int,
        elementIndex _: Int,
        timeoutMilliseconds _: Int) throws -> DesktopUIAutomationActionResult
    {
        throw self.unsupported()
    }

    public func moveUIAutomationElement(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int,
        elementIndex _: Int,
        x _: Double,
        y _: Double) throws -> DesktopUIAutomationActionResult
    {
        throw self.unsupported()
    }

    public func resizeUIAutomationElement(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int,
        elementIndex _: Int,
        width _: Double,
        height _: Double) throws -> DesktopUIAutomationActionResult
    {
        throw self.unsupported()
    }

    public func rotateUIAutomationElement(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int,
        elementIndex _: Int,
        degrees _: Double) throws -> DesktopUIAutomationActionResult
    {
        throw self.unsupported()
    }

    public func toggleUIAutomationElement(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int,
        elementIndex _: Int) throws -> DesktopUIAutomationActionResult
    {
        throw self.unsupported()
    }

    public func expandUIAutomationElement(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int,
        elementIndex _: Int) throws -> DesktopUIAutomationActionResult
    {
        throw self.unsupported()
    }

    public func collapseUIAutomationElement(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int,
        elementIndex _: Int) throws -> DesktopUIAutomationActionResult
    {
        throw self.unsupported()
    }

    public func selectUIAutomationElement(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int,
        elementIndex _: Int) throws -> DesktopUIAutomationActionResult
    {
        throw self.unsupported()
    }

    public func setUIAutomationElementDockPosition(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int,
        elementIndex _: Int,
        position _: DesktopUIAutomationDockPosition) throws -> DesktopUIAutomationActionResult
    {
        throw self.unsupported()
    }

    public func setUIAutomationElementCurrentView(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int,
        elementIndex _: Int,
        viewId _: Int) throws -> DesktopUIAutomationActionResult
    {
        throw self.unsupported()
    }

    public func addUIAutomationElementToSelection(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int,
        elementIndex _: Int) throws -> DesktopUIAutomationActionResult
    {
        throw self.unsupported()
    }

    public func removeUIAutomationElementFromSelection(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int,
        elementIndex _: Int) throws -> DesktopUIAutomationActionResult
    {
        throw self.unsupported()
    }

    public func scrollUIAutomationElementIntoView(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int,
        elementIndex _: Int) throws -> DesktopUIAutomationActionResult
    {
        throw self.unsupported()
    }

    private func unsupported() -> Win11DesktopError {
        Win11DesktopError.unsupportedPlatform(
            "PeekabooWin11 requires Swift on Windows and the WinSDK module.")
    }
}
