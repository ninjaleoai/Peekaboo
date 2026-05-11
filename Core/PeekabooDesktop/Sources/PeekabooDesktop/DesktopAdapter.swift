import Foundation

public protocol DesktopAdapter: Sendable {
    func platformInfo() -> DesktopPlatformInfo
    func listDisplays() throws -> [DesktopDisplay]
    func listWindows(includeInvisible: Bool) throws -> [DesktopWindow]
    func listApplications() throws -> [DesktopApplication]
    func captureScreen(displayIndex: Int?, outputPath: String) throws -> DesktopCaptureResult
    func captureArea(_ rect: DesktopRect, outputPath: String) throws -> DesktopCaptureResult
    func captureWindow(windowIdentifier: UInt64, outputPath: String) throws -> DesktopCaptureResult
    func captureFrontmost(outputPath: String) throws -> DesktopCaptureResult
    func cursorPosition() throws -> DesktopPoint
    func moveCursor(to point: DesktopPoint) throws -> DesktopPoint
    func click(at point: DesktopPoint, button: DesktopMouseButton, clickCount: Int) throws -> DesktopClickResult
    func scroll(at point: DesktopPoint, direction: DesktopScrollDirection, amount: Int) throws -> DesktopScrollResult
    func drag(
        from startPoint: DesktopPoint,
        to endPoint: DesktopPoint,
        button: DesktopMouseButton,
        steps: Int) throws -> DesktopDragResult
    func hotkey(keys: [String], holdDurationMilliseconds: Int) throws -> DesktopHotkeyResult
    func typeText(_ text: String, delayMilliseconds: Int) throws -> DesktopTypingResult
    func uiAutomationStatus() throws -> DesktopUIAutomationStatus
    func uiAutomationSnapshot(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int) throws -> DesktopUIAutomationSnapshot
    func invokeUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    func focusUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    func performUIAutomationElementLegacyDefaultAction(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    func setUIAutomationElementLegacyValue(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        value: String) throws -> DesktopUIAutomationActionResult
    func setUIAutomationElementValue(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        value: String) throws -> DesktopUIAutomationActionResult
    func setUIAutomationElementRangeValue(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        value: Double) throws -> DesktopUIAutomationActionResult
    func setUIAutomationElementScrollPercent(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        horizontalPercent: Double?,
        verticalPercent: Double?) throws -> DesktopUIAutomationActionResult
    func setUIAutomationElementWindowVisualState(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        state: DesktopUIAutomationWindowVisualState) throws -> DesktopUIAutomationActionResult
    func closeUIAutomationWindow(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    func waitForUIAutomationWindowInputIdle(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        timeoutMilliseconds: Int) throws -> DesktopUIAutomationActionResult
    func setUIAutomationElementDockPosition(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        position: DesktopUIAutomationDockPosition) throws -> DesktopUIAutomationActionResult
    func setUIAutomationElementCurrentView(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        viewId: Int) throws -> DesktopUIAutomationActionResult
    func setUIAutomationElementZoomLevel(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        zoomLevel: Double) throws -> DesktopUIAutomationActionResult
    func moveUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        x: Double,
        y: Double) throws -> DesktopUIAutomationActionResult
    func resizeUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        width: Double,
        height: Double) throws -> DesktopUIAutomationActionResult
    func rotateUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        degrees: Double) throws -> DesktopUIAutomationActionResult
    func toggleUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    func expandUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    func collapseUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    func selectUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    func addUIAutomationElementToSelection(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    func removeUIAutomationElementFromSelection(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    func scrollUIAutomationElementIntoView(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
}

public protocol DesktopAsyncAdapter: Sendable {
    func platformInfo() async -> DesktopPlatformInfo
    func listDisplays() async throws -> [DesktopDisplay]
    func listWindows(includeInvisible: Bool) async throws -> [DesktopWindow]
    func listApplications() async throws -> [DesktopApplication]
    func captureScreen(displayIndex: Int?, outputPath: String) async throws -> DesktopCaptureResult
    func captureArea(_ rect: DesktopRect, outputPath: String) async throws -> DesktopCaptureResult
    func captureWindow(windowIdentifier: UInt64, outputPath: String) async throws -> DesktopCaptureResult
    func captureFrontmost(outputPath: String) async throws -> DesktopCaptureResult
    func cursorPosition() async throws -> DesktopPoint
    func moveCursor(to point: DesktopPoint) async throws -> DesktopPoint
    func click(at point: DesktopPoint, button: DesktopMouseButton, clickCount: Int) async throws -> DesktopClickResult
    func scroll(
        at point: DesktopPoint,
        direction: DesktopScrollDirection,
        amount: Int) async throws -> DesktopScrollResult
    func drag(
        from startPoint: DesktopPoint,
        to endPoint: DesktopPoint,
        button: DesktopMouseButton,
        steps: Int) async throws -> DesktopDragResult
    func hotkey(keys: [String], holdDurationMilliseconds: Int) async throws -> DesktopHotkeyResult
    func typeText(_ text: String, delayMilliseconds: Int) async throws -> DesktopTypingResult
    func uiAutomationStatus() async throws -> DesktopUIAutomationStatus
    func uiAutomationSnapshot(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int) async throws -> DesktopUIAutomationSnapshot
    func invokeUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) async throws -> DesktopUIAutomationActionResult
    func focusUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) async throws -> DesktopUIAutomationActionResult
    func performUIAutomationElementLegacyDefaultAction(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) async throws -> DesktopUIAutomationActionResult
    func setUIAutomationElementLegacyValue(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        value: String) async throws -> DesktopUIAutomationActionResult
    func setUIAutomationElementValue(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        value: String) async throws -> DesktopUIAutomationActionResult
    func setUIAutomationElementRangeValue(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        value: Double) async throws -> DesktopUIAutomationActionResult
    func setUIAutomationElementScrollPercent(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        horizontalPercent: Double?,
        verticalPercent: Double?) async throws -> DesktopUIAutomationActionResult
    func setUIAutomationElementWindowVisualState(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        state: DesktopUIAutomationWindowVisualState) async throws -> DesktopUIAutomationActionResult
    func closeUIAutomationWindow(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) async throws -> DesktopUIAutomationActionResult
    func waitForUIAutomationWindowInputIdle(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        timeoutMilliseconds: Int) async throws -> DesktopUIAutomationActionResult
    func setUIAutomationElementDockPosition(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        position: DesktopUIAutomationDockPosition) async throws -> DesktopUIAutomationActionResult
    func setUIAutomationElementCurrentView(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        viewId: Int) async throws -> DesktopUIAutomationActionResult
    func setUIAutomationElementZoomLevel(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        zoomLevel: Double) async throws -> DesktopUIAutomationActionResult
    func moveUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        x: Double,
        y: Double) async throws -> DesktopUIAutomationActionResult
    func resizeUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        width: Double,
        height: Double) async throws -> DesktopUIAutomationActionResult
    func rotateUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        degrees: Double) async throws -> DesktopUIAutomationActionResult
    func toggleUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) async throws -> DesktopUIAutomationActionResult
    func expandUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) async throws -> DesktopUIAutomationActionResult
    func collapseUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) async throws -> DesktopUIAutomationActionResult
    func selectUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) async throws -> DesktopUIAutomationActionResult
    func addUIAutomationElementToSelection(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) async throws -> DesktopUIAutomationActionResult
    func removeUIAutomationElementFromSelection(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) async throws -> DesktopUIAutomationActionResult
    func scrollUIAutomationElementIntoView(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) async throws -> DesktopUIAutomationActionResult
}

public struct DesktopAdapterAsyncBridge<Adapter: DesktopAdapter>: DesktopAsyncAdapter {
    public let adapter: Adapter

    public init(_ adapter: Adapter) {
        self.adapter = adapter
    }

    public func platformInfo() async -> DesktopPlatformInfo {
        self.adapter.platformInfo()
    }

    public func listDisplays() async throws -> [DesktopDisplay] {
        try self.adapter.listDisplays()
    }

    public func listWindows(includeInvisible: Bool) async throws -> [DesktopWindow] {
        try self.adapter.listWindows(includeInvisible: includeInvisible)
    }

    public func listApplications() async throws -> [DesktopApplication] {
        try self.adapter.listApplications()
    }

    public func captureScreen(displayIndex: Int?, outputPath: String) async throws -> DesktopCaptureResult {
        try self.adapter.captureScreen(displayIndex: displayIndex, outputPath: outputPath)
    }

    public func captureArea(_ rect: DesktopRect, outputPath: String) async throws -> DesktopCaptureResult {
        try self.adapter.captureArea(rect, outputPath: outputPath)
    }

    public func captureWindow(windowIdentifier: UInt64, outputPath: String) async throws -> DesktopCaptureResult {
        try self.adapter.captureWindow(windowIdentifier: windowIdentifier, outputPath: outputPath)
    }

    public func captureFrontmost(outputPath: String) async throws -> DesktopCaptureResult {
        try self.adapter.captureFrontmost(outputPath: outputPath)
    }

    public func cursorPosition() async throws -> DesktopPoint {
        try self.adapter.cursorPosition()
    }

    public func moveCursor(to point: DesktopPoint) async throws -> DesktopPoint {
        try self.adapter.moveCursor(to: point)
    }

    public func click(
        at point: DesktopPoint,
        button: DesktopMouseButton,
        clickCount: Int) async throws -> DesktopClickResult
    {
        try self.adapter.click(at: point, button: button, clickCount: clickCount)
    }

    public func scroll(
        at point: DesktopPoint,
        direction: DesktopScrollDirection,
        amount: Int) async throws -> DesktopScrollResult
    {
        try self.adapter.scroll(at: point, direction: direction, amount: amount)
    }

    public func drag(
        from startPoint: DesktopPoint,
        to endPoint: DesktopPoint,
        button: DesktopMouseButton,
        steps: Int) async throws -> DesktopDragResult
    {
        try self.adapter.drag(from: startPoint, to: endPoint, button: button, steps: steps)
    }

    public func hotkey(keys: [String], holdDurationMilliseconds: Int) async throws -> DesktopHotkeyResult {
        try self.adapter.hotkey(keys: keys, holdDurationMilliseconds: holdDurationMilliseconds)
    }

    public func typeText(_ text: String, delayMilliseconds: Int) async throws -> DesktopTypingResult {
        try self.adapter.typeText(text, delayMilliseconds: delayMilliseconds)
    }

    public func uiAutomationStatus() async throws -> DesktopUIAutomationStatus {
        try self.adapter.uiAutomationStatus()
    }

    public func uiAutomationSnapshot(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int) async throws -> DesktopUIAutomationSnapshot
    {
        try self.adapter.uiAutomationSnapshot(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements)
    }

    public func invokeUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) async throws -> DesktopUIAutomationActionResult
    {
        try self.adapter.invokeUIAutomationElement(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex)
    }

    public func focusUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) async throws -> DesktopUIAutomationActionResult
    {
        try self.adapter.focusUIAutomationElement(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex)
    }

    public func performUIAutomationElementLegacyDefaultAction(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) async throws -> DesktopUIAutomationActionResult
    {
        try self.adapter.performUIAutomationElementLegacyDefaultAction(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex)
    }

    public func setUIAutomationElementLegacyValue(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        value: String) async throws -> DesktopUIAutomationActionResult
    {
        try self.adapter.setUIAutomationElementLegacyValue(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex,
            value: value)
    }

    public func setUIAutomationElementValue(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        value: String) async throws -> DesktopUIAutomationActionResult
    {
        try self.adapter.setUIAutomationElementValue(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex,
            value: value)
    }

    public func setUIAutomationElementRangeValue(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        value: Double) async throws -> DesktopUIAutomationActionResult
    {
        try self.adapter.setUIAutomationElementRangeValue(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex,
            value: value)
    }

    public func setUIAutomationElementScrollPercent(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        horizontalPercent: Double?,
        verticalPercent: Double?) async throws -> DesktopUIAutomationActionResult
    {
        try self.adapter.setUIAutomationElementScrollPercent(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex,
            horizontalPercent: horizontalPercent,
            verticalPercent: verticalPercent)
    }

    public func setUIAutomationElementWindowVisualState(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        state: DesktopUIAutomationWindowVisualState) async throws -> DesktopUIAutomationActionResult
    {
        try self.adapter.setUIAutomationElementWindowVisualState(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex,
            state: state)
    }

    public func closeUIAutomationWindow(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) async throws -> DesktopUIAutomationActionResult
    {
        try self.adapter.closeUIAutomationWindow(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex)
    }

    public func waitForUIAutomationWindowInputIdle(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        timeoutMilliseconds: Int) async throws -> DesktopUIAutomationActionResult
    {
        try self.adapter.waitForUIAutomationWindowInputIdle(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex,
            timeoutMilliseconds: timeoutMilliseconds)
    }

    public func setUIAutomationElementDockPosition(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        position: DesktopUIAutomationDockPosition) async throws -> DesktopUIAutomationActionResult
    {
        try self.adapter.setUIAutomationElementDockPosition(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex,
            position: position)
    }

    public func setUIAutomationElementCurrentView(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        viewId: Int) async throws -> DesktopUIAutomationActionResult
    {
        try self.adapter.setUIAutomationElementCurrentView(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex,
            viewId: viewId)
    }

    public func setUIAutomationElementZoomLevel(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        zoomLevel: Double) async throws -> DesktopUIAutomationActionResult
    {
        try self.adapter.setUIAutomationElementZoomLevel(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex,
            zoomLevel: zoomLevel)
    }

    public func moveUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        x: Double,
        y: Double) async throws -> DesktopUIAutomationActionResult
    {
        try self.adapter.moveUIAutomationElement(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex,
            x: x,
            y: y)
    }

    public func resizeUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        width: Double,
        height: Double) async throws -> DesktopUIAutomationActionResult
    {
        try self.adapter.resizeUIAutomationElement(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex,
            width: width,
            height: height)
    }

    public func rotateUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        degrees: Double) async throws -> DesktopUIAutomationActionResult
    {
        try self.adapter.rotateUIAutomationElement(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex,
            degrees: degrees)
    }

    public func toggleUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) async throws -> DesktopUIAutomationActionResult
    {
        try self.adapter.toggleUIAutomationElement(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex)
    }

    public func expandUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) async throws -> DesktopUIAutomationActionResult
    {
        try self.adapter.expandUIAutomationElement(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex)
    }

    public func collapseUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) async throws -> DesktopUIAutomationActionResult
    {
        try self.adapter.collapseUIAutomationElement(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex)
    }

    public func selectUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) async throws -> DesktopUIAutomationActionResult
    {
        try self.adapter.selectUIAutomationElement(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex)
    }

    public func addUIAutomationElementToSelection(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) async throws -> DesktopUIAutomationActionResult
    {
        try self.adapter.addUIAutomationElementToSelection(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex)
    }

    public func removeUIAutomationElementFromSelection(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) async throws -> DesktopUIAutomationActionResult
    {
        try self.adapter.removeUIAutomationElementFromSelection(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex)
    }

    public func scrollUIAutomationElementIntoView(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) async throws -> DesktopUIAutomationActionResult
    {
        try self.adapter.scrollUIAutomationElementIntoView(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex)
    }
}

public enum DesktopAdapterError: Error, Equatable, Sendable {
    case unsupportedPlatform(String)
    case invalidArgument(String)
    case nativeCallFailed(String)
    case displayNotFound(Int)
    case emptyCaptureRegion(DesktopRect)
    case outputPathRequired
}

extension DesktopAdapterError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .unsupportedPlatform(message):
            return message
        case let .invalidArgument(message):
            return message
        case let .nativeCallFailed(call):
            return "Native desktop call failed: \(call)"
        case let .displayNotFound(index):
            return "Display not found at index \(index)"
        case let .emptyCaptureRegion(rect):
            return "Capture region is empty: \(rect)"
        case .outputPathRequired:
            return "An output path is required for capture"
        }
    }
}
