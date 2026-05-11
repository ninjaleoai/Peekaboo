import CoreGraphics
import Foundation
import PeekabooDesktop

@MainActor
public final class MacAutomationDesktopAdapter: DesktopAsyncAdapter {
    private let applications: any ApplicationServiceProtocol
    private let screens: any ScreenServiceProtocol
    private let screenCapture: (any ScreenCaptureServiceProtocol)?

    public init(
        applications: any ApplicationServiceProtocol = ApplicationService(),
        screens: any ScreenServiceProtocol = ScreenService(),
        screenCapture: (any ScreenCaptureServiceProtocol)? = nil)
    {
        self.applications = applications
        self.screens = screens
        self.screenCapture = screenCapture
    }

    public func platformInfo() async -> DesktopPlatformInfo {
        DesktopPlatformInfo(
            name: "macOS",
            minimumSystemVersion: "14",
            nativeBackend: "AppKit+Accessibility+ScreenCaptureKit",
            capabilities: self.platformCapabilities())
    }

    public func listDisplays() async throws -> [DesktopDisplay] {
        self.screens.listScreens().map(\.desktopDisplay)
    }

    public func listApplications() async throws -> [DesktopApplication] {
        try await self.applications.listApplications()
            .data
            .applications
            .map(\.desktopApplication)
    }

    public func listWindows(includeInvisible: Bool) async throws -> [DesktopWindow] {
        let applications = try await self.applications.listApplications().data.applications
        var windows: [DesktopWindow] = []

        for application in applications {
            let windowList = try await self.applications.listWindows(for: application.name, timeout: nil)
            let desktopWindows = windowList.data.windows.map { window in
                window.desktopWindow(
                    processIdentifier: application.processIdentifier,
                    executableName: application.name)
            }

            if includeInvisible {
                windows.append(contentsOf: desktopWindows)
            } else {
                windows.append(contentsOf: desktopWindows.filter(\.isVisible))
            }
        }

        return windows
    }

    public func captureScreen(displayIndex: Int?, outputPath: String) async throws -> DesktopCaptureResult {
        guard let screenCapture else {
            throw DesktopAdapterError.unsupportedPlatform("Screen capture service was not provided")
        }

        let result = try await screenCapture.captureScreen(
            displayIndex: displayIndex,
            visualizerMode: .screenshotFlash,
            scale: .logical1x)
        try Self.write(result.imageData, to: outputPath)

        return DesktopCaptureResult(
            path: outputPath,
            bounds: self.captureBounds(from: result, displayIndex: displayIndex),
            format: .png,
            byteCount: result.imageData.count)
    }

    private func platformCapabilities() -> [DesktopPlatformCapability] {
        var capabilities: [DesktopPlatformCapability] = [
            .enumerateApplications,
            .enumerateDisplays,
            .enumerateWindows,
        ]

        if self.screenCapture != nil {
            capabilities.append(.captureScreenPNG)
            capabilities.append(.captureAreaPNG)
            capabilities.append(.captureWindowPNG)
            capabilities.append(.captureFrontmostPNG)
        }

        return capabilities
    }

    private func captureBounds(from result: CaptureResult, displayIndex: Int?) -> DesktopRect {
        if let bounds = result.metadata.displayInfo?.bounds {
            return bounds.desktopRect
        }

        if let display = displayIndex.flatMap({ self.screens.screen(at: $0) }) {
            return display.frame.desktopRect
        }

        if let primaryDisplay = self.screens.primaryScreen {
            return primaryDisplay.frame.desktopRect
        }

        return CGRect(origin: .zero, size: result.metadata.size).desktopRect
    }

    public func captureWindow(windowIdentifier: UInt64, outputPath: String) async throws -> DesktopCaptureResult {
        guard let screenCapture else {
            throw DesktopAdapterError.unsupportedPlatform("Screen capture service was not provided")
        }

        let result = try await screenCapture.captureWindow(
            windowID: CGWindowID(clamping: windowIdentifier),
            visualizerMode: .screenshotFlash,
            scale: .logical1x)
        try Self.write(result.imageData, to: outputPath)

        return DesktopCaptureResult(
            path: outputPath,
            bounds: self.windowCaptureBounds(from: result),
            format: .png,
            byteCount: result.imageData.count)
    }

    private func windowCaptureBounds(from result: CaptureResult) -> DesktopRect {
        if let bounds = result.metadata.windowInfo?.bounds {
            return bounds.desktopRect
        }

        return CGRect(origin: .zero, size: result.metadata.size).desktopRect
    }

    public func captureFrontmost(outputPath: String) async throws -> DesktopCaptureResult {
        guard let screenCapture else {
            throw DesktopAdapterError.unsupportedPlatform("Screen capture service was not provided")
        }

        let result = try await screenCapture.captureFrontmost(
            visualizerMode: .screenshotFlash,
            scale: .logical1x)
        try Self.write(result.imageData, to: outputPath)

        return DesktopCaptureResult(
            path: outputPath,
            bounds: self.windowCaptureBounds(from: result),
            format: .png,
            byteCount: result.imageData.count)
    }

    public func captureArea(_ rect: DesktopRect, outputPath: String) async throws -> DesktopCaptureResult {
        guard let screenCapture else {
            throw DesktopAdapterError.unsupportedPlatform("Screen capture service was not provided")
        }
        guard !rect.isEmpty else {
            throw DesktopAdapterError.emptyCaptureRegion(rect)
        }

        let result = try await screenCapture.captureArea(
            rect.cgRect,
            visualizerMode: .screenshotFlash,
            scale: .logical1x)
        try Self.write(result.imageData, to: outputPath)

        return DesktopCaptureResult(
            path: outputPath,
            bounds: rect,
            format: .png,
            byteCount: result.imageData.count)
    }

    public func cursorPosition() async throws -> DesktopPoint {
        throw DesktopAdapterError.unsupportedPlatform("Cursor position is not implemented by this adapter")
    }

    public func moveCursor(to _: DesktopPoint) async throws -> DesktopPoint {
        throw DesktopAdapterError.unsupportedPlatform("Cursor movement is not implemented by this adapter")
    }

    public func click(
        at _: DesktopPoint,
        button _: DesktopMouseButton,
        clickCount _: Int) async throws -> DesktopClickResult
    {
        throw DesktopAdapterError.unsupportedPlatform("Mouse click is not implemented by this adapter")
    }

    public func scroll(
        at _: DesktopPoint,
        direction _: DesktopScrollDirection,
        amount _: Int) async throws -> DesktopScrollResult
    {
        throw DesktopAdapterError.unsupportedPlatform("Mouse scroll is not implemented by this adapter")
    }

    public func drag(
        from _: DesktopPoint,
        to _: DesktopPoint,
        button _: DesktopMouseButton,
        steps _: Int) async throws -> DesktopDragResult
    {
        throw DesktopAdapterError.unsupportedPlatform("Mouse drag is not implemented by this adapter")
    }

    public func hotkey(keys _: [String], holdDurationMilliseconds _: Int) async throws -> DesktopHotkeyResult {
        throw DesktopAdapterError.unsupportedPlatform("Hotkey input is not implemented by this adapter")
    }

    public func typeText(_: String, delayMilliseconds _: Int) async throws -> DesktopTypingResult {
        throw DesktopAdapterError.unsupportedPlatform("Typing input is not implemented by this adapter")
    }

    public func uiAutomationStatus() async throws -> DesktopUIAutomationStatus {
        throw DesktopAdapterError.unsupportedPlatform("UI Automation status is not implemented by this adapter")
    }

    public func uiAutomationSnapshot(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int) async throws -> DesktopUIAutomationSnapshot
    {
        throw DesktopAdapterError.unsupportedPlatform("UI Automation snapshots are not implemented by this adapter")
    }

    public func invokeUIAutomationElement(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int,
        elementIndex _: Int) async throws -> DesktopUIAutomationActionResult
    {
        throw DesktopAdapterError.unsupportedPlatform("UI Automation invoke is not implemented by this adapter")
    }

    public func focusUIAutomationElement(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int,
        elementIndex _: Int) async throws -> DesktopUIAutomationActionResult
    {
        throw DesktopAdapterError.unsupportedPlatform("UI Automation focus is not implemented by this adapter")
    }

    public func performUIAutomationElementLegacyDefaultAction(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int,
        elementIndex _: Int) async throws -> DesktopUIAutomationActionResult
    {
        throw DesktopAdapterError.unsupportedPlatform(
            "UI Automation legacy default action is not implemented by this adapter")
    }

    public func setUIAutomationElementLegacyValue(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int,
        elementIndex _: Int,
        value _: String) async throws -> DesktopUIAutomationActionResult
    {
        throw DesktopAdapterError.unsupportedPlatform(
            "UI Automation set-legacy-value is not implemented by this adapter")
    }

    public func setUIAutomationElementValue(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int,
        elementIndex _: Int,
        value _: String) async throws -> DesktopUIAutomationActionResult
    {
        throw DesktopAdapterError.unsupportedPlatform("UI Automation set-value is not implemented by this adapter")
    }

    public func setUIAutomationElementRangeValue(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int,
        elementIndex _: Int,
        value _: Double) async throws -> DesktopUIAutomationActionResult
    {
        throw DesktopAdapterError.unsupportedPlatform(
            "UI Automation set-range-value is not implemented by this adapter")
    }

    public func setUIAutomationElementScrollPercent(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int,
        elementIndex _: Int,
        horizontalPercent _: Double?,
        verticalPercent _: Double?) async throws -> DesktopUIAutomationActionResult
    {
        throw DesktopAdapterError.unsupportedPlatform(
            "UI Automation set-scroll-percent is not implemented by this adapter")
    }

    public func setUIAutomationElementWindowVisualState(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int,
        elementIndex _: Int,
        state _: DesktopUIAutomationWindowVisualState) async throws -> DesktopUIAutomationActionResult
    {
        throw DesktopAdapterError.unsupportedPlatform(
            "UI Automation set-window-state is not implemented by this adapter")
    }

    public func closeUIAutomationWindow(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int,
        elementIndex _: Int) async throws -> DesktopUIAutomationActionResult
    {
        throw DesktopAdapterError.unsupportedPlatform(
            "UI Automation close-window is not implemented by this adapter")
    }

    public func waitForUIAutomationWindowInputIdle(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int,
        elementIndex _: Int,
        timeoutMilliseconds _: Int) async throws -> DesktopUIAutomationActionResult
    {
        throw DesktopAdapterError.unsupportedPlatform(
            "UI Automation wait-window-idle is not implemented by this adapter")
    }

    public func moveUIAutomationElement(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int,
        elementIndex _: Int,
        x _: Double,
        y _: Double) async throws -> DesktopUIAutomationActionResult
    {
        throw DesktopAdapterError.unsupportedPlatform("UI Automation move is not implemented by this adapter")
    }

    public func resizeUIAutomationElement(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int,
        elementIndex _: Int,
        width _: Double,
        height _: Double) async throws -> DesktopUIAutomationActionResult
    {
        throw DesktopAdapterError.unsupportedPlatform("UI Automation resize is not implemented by this adapter")
    }

    public func rotateUIAutomationElement(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int,
        elementIndex _: Int,
        degrees _: Double) async throws -> DesktopUIAutomationActionResult
    {
        throw DesktopAdapterError.unsupportedPlatform("UI Automation rotate is not implemented by this adapter")
    }

    public func realizeUIAutomationVirtualizedItem(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int,
        elementIndex _: Int) async throws -> DesktopUIAutomationActionResult
    {
        throw DesktopAdapterError.unsupportedPlatform("UI Automation realize is not implemented by this adapter")
    }

    public func toggleUIAutomationElement(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int,
        elementIndex _: Int) async throws -> DesktopUIAutomationActionResult
    {
        throw DesktopAdapterError.unsupportedPlatform("UI Automation toggle is not implemented by this adapter")
    }

    public func expandUIAutomationElement(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int,
        elementIndex _: Int) async throws -> DesktopUIAutomationActionResult
    {
        throw DesktopAdapterError.unsupportedPlatform("UI Automation expand is not implemented by this adapter")
    }

    public func collapseUIAutomationElement(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int,
        elementIndex _: Int) async throws -> DesktopUIAutomationActionResult
    {
        throw DesktopAdapterError.unsupportedPlatform("UI Automation collapse is not implemented by this adapter")
    }

    public func selectUIAutomationElement(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int,
        elementIndex _: Int) async throws -> DesktopUIAutomationActionResult
    {
        throw DesktopAdapterError.unsupportedPlatform("UI Automation select is not implemented by this adapter")
    }

    public func setUIAutomationElementDockPosition(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int,
        elementIndex _: Int,
        position _: DesktopUIAutomationDockPosition) async throws -> DesktopUIAutomationActionResult
    {
        throw DesktopAdapterError.unsupportedPlatform(
            "UI Automation set-dock-position is not implemented by this adapter")
    }

    public func setUIAutomationElementCurrentView(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int,
        elementIndex _: Int,
        viewId _: Int) async throws -> DesktopUIAutomationActionResult
    {
        throw DesktopAdapterError.unsupportedPlatform(
            "UI Automation set-current-view is not implemented by this adapter")
    }

    public func setUIAutomationElementZoomLevel(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int,
        elementIndex _: Int,
        zoomLevel _: Double) async throws -> DesktopUIAutomationActionResult
    {
        throw DesktopAdapterError.unsupportedPlatform(
            "UI Automation set-zoom is not implemented by this adapter")
    }

    public func zoomUIAutomationElementByUnit(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int,
        elementIndex _: Int,
        unit _: DesktopUIAutomationZoomUnit) async throws -> DesktopUIAutomationActionResult
    {
        throw DesktopAdapterError.unsupportedPlatform(
            "UI Automation zoom-by-unit is not implemented by this adapter")
    }

    public func startUIAutomationSynchronizedInput(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int,
        elementIndex _: Int,
        inputType _: DesktopUIAutomationSynchronizedInputType) async throws -> DesktopUIAutomationActionResult
    {
        throw DesktopAdapterError.unsupportedPlatform(
            "UI Automation start-synchronized-input is not implemented by this adapter")
    }

    public func cancelUIAutomationSynchronizedInput(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int,
        elementIndex _: Int) async throws -> DesktopUIAutomationActionResult
    {
        throw DesktopAdapterError.unsupportedPlatform(
            "UI Automation cancel-synchronized-input is not implemented by this adapter")
    }

    public func addUIAutomationElementToSelection(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int,
        elementIndex _: Int) async throws -> DesktopUIAutomationActionResult
    {
        throw DesktopAdapterError.unsupportedPlatform(
            "UI Automation add-to-selection is not implemented by this adapter")
    }

    public func removeUIAutomationElementFromSelection(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int,
        elementIndex _: Int) async throws -> DesktopUIAutomationActionResult
    {
        throw DesktopAdapterError.unsupportedPlatform(
            "UI Automation remove-from-selection is not implemented by this adapter")
    }

    public func scrollUIAutomationElementIntoView(
        scope _: DesktopUIAutomationSnapshotScope,
        maxDepth _: Int,
        maxElements _: Int,
        elementIndex _: Int) async throws -> DesktopUIAutomationActionResult
    {
        throw DesktopAdapterError.unsupportedPlatform(
            "UI Automation scroll-into-view is not implemented by this adapter")
    }

    private static func write(_ data: Data, to outputPath: String) throws {
        let outputURL = URL(fileURLWithPath: outputPath)
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        try data.write(to: outputURL, options: .atomic)
    }
}

private extension DesktopRect {
    var cgRect: CGRect {
        CGRect(x: self.x, y: self.y, width: self.width, height: self.height)
    }
}
