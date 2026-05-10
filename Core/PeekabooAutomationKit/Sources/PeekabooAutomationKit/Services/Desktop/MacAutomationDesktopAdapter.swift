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
