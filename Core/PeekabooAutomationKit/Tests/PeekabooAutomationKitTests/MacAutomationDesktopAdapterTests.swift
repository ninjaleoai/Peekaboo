import CoreGraphics
import Foundation
import PeekabooDesktop
@testable import PeekabooAutomationKit
import XCTest

@MainActor
final class MacAutomationDesktopAdapterTests: XCTestCase {
    func testPlatformInfoAdvertisesCaptureOnlyWhenCaptureServiceIsProvided() async {
        let readOnlyAdapter = MacAutomationDesktopAdapter(
            applications: StubDesktopApplicationService(),
            screens: StubDesktopScreenService(),
            screenCapture: nil)
        let captureAdapter = MacAutomationDesktopAdapter(
            applications: StubDesktopApplicationService(),
            screens: StubDesktopScreenService(),
            screenCapture: StubDesktopScreenCaptureService())

        let readOnlyInfo = await readOnlyAdapter.platformInfo()
        let captureInfo = await captureAdapter.platformInfo()

        XCTAssertEqual(readOnlyInfo.name, "macOS")
        XCTAssertTrue(readOnlyInfo.capabilities.contains(.enumerateApplications))
        XCTAssertFalse(readOnlyInfo.capabilities.contains(.captureScreenPNG))
        XCTAssertFalse(readOnlyInfo.capabilities.contains(.captureAreaPNG))
        XCTAssertFalse(readOnlyInfo.capabilities.contains(.captureWindowPNG))
        XCTAssertFalse(readOnlyInfo.capabilities.contains(.captureFrontmostPNG))
        XCTAssertTrue(captureInfo.capabilities.contains(.captureScreenPNG))
        XCTAssertTrue(captureInfo.capabilities.contains(.captureAreaPNG))
        XCTAssertTrue(captureInfo.capabilities.contains(.captureWindowPNG))
        XCTAssertTrue(captureInfo.capabilities.contains(.captureFrontmostPNG))
    }

    func testListsDisplaysApplicationsAndVisibleWindows() async throws {
        let adapter = MacAutomationDesktopAdapter(
            applications: StubDesktopApplicationService(),
            screens: StubDesktopScreenService(),
            screenCapture: nil)

        let displays = try await adapter.listDisplays()
        let applications = try await adapter.listApplications()
        let visibleWindows = try await adapter.listWindows(includeInvisible: false)
        let allWindows = try await adapter.listWindows(includeInvisible: true)

        XCTAssertEqual(displays.map(\.index), [0, 1])
        XCTAssertEqual(displays.compactMap(\.name), ["Primary", "Secondary"])
        XCTAssertEqual(displays.map(\.scaleFactor), [2, 1])
        XCTAssertEqual(applications.map(\.executableName), ["Example"])
        XCTAssertEqual(applications.compactMap(\.bundleIdentifier), ["com.example.App"])
        XCTAssertEqual(visibleWindows.map(\.title), ["Visible"])
        XCTAssertEqual(allWindows.map(\.title), ["Visible", "Hidden"])
        XCTAssertEqual(allWindows.map(\.processIdentifier), [1234, 1234])
        XCTAssertEqual(allWindows.map(\.index), [0, 1])
        XCTAssertEqual(allWindows.compactMap(\.spaceName), ["Work"])
        XCTAssertEqual(allWindows.map(\.isOffScreen), [false, true])
    }

    func testCaptureWritesPNGOutput() async throws {
        let captureService = StubDesktopScreenCaptureService()
        let adapter = MacAutomationDesktopAdapter(
            applications: StubDesktopApplicationService(),
            screens: StubDesktopScreenService(),
            screenCapture: captureService)
        let outputURL = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("peekaboo-desktop-adapter-test.png")

        defer {
            try? FileManager.default.removeItem(at: outputURL)
        }

        let result = try await adapter.captureScreen(displayIndex: 1, outputPath: outputURL.path)

        XCTAssertEqual(captureService.requestedDisplayIndex, 1)
        XCTAssertEqual(result.path, outputURL.path)
        XCTAssertEqual(result.format, .png)
        XCTAssertEqual(result.byteCount, captureService.imageData.count)
        XCTAssertEqual(result.bounds, DesktopRect(x: 100, y: 0, width: 200, height: 150))
        XCTAssertEqual(try Data(contentsOf: outputURL), captureService.imageData)
    }

    func testCaptureFrontmostWritesPNGOutput() async throws {
        let captureService = StubDesktopScreenCaptureService()
        let adapter = MacAutomationDesktopAdapter(
            applications: StubDesktopApplicationService(),
            screens: StubDesktopScreenService(),
            screenCapture: captureService)
        let outputURL = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("peekaboo-desktop-adapter-frontmost-test.png")

        defer {
            try? FileManager.default.removeItem(at: outputURL)
        }

        let result = try await adapter.captureFrontmost(outputPath: outputURL.path)

        XCTAssertTrue(captureService.requestedFrontmost)
        XCTAssertEqual(result.path, outputURL.path)
        XCTAssertEqual(result.format, .png)
        XCTAssertEqual(result.byteCount, captureService.imageData.count)
        XCTAssertEqual(result.bounds, DesktopRect(x: 10, y: 20, width: 300, height: 200))
        XCTAssertEqual(try Data(contentsOf: outputURL), captureService.imageData)
    }

    func testCaptureAreaWritesPNGOutput() async throws {
        let captureService = StubDesktopScreenCaptureService()
        let adapter = MacAutomationDesktopAdapter(
            applications: StubDesktopApplicationService(),
            screens: StubDesktopScreenService(),
            screenCapture: captureService)
        let outputURL = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("peekaboo-desktop-adapter-area-test.png")
        let rect = DesktopRect(x: 10, y: 20, width: 30, height: 40)

        defer {
            try? FileManager.default.removeItem(at: outputURL)
        }

        let result = try await adapter.captureArea(rect, outputPath: outputURL.path)

        XCTAssertEqual(captureService.requestedArea, CGRect(x: 10, y: 20, width: 30, height: 40))
        XCTAssertEqual(result.path, outputURL.path)
        XCTAssertEqual(result.format, .png)
        XCTAssertEqual(result.byteCount, captureService.imageData.count)
        XCTAssertEqual(result.bounds, rect)
        XCTAssertEqual(try Data(contentsOf: outputURL), captureService.imageData)
    }

    func testCaptureWindowWritesPNGOutput() async throws {
        let captureService = StubDesktopScreenCaptureService()
        let adapter = MacAutomationDesktopAdapter(
            applications: StubDesktopApplicationService(),
            screens: StubDesktopScreenService(),
            screenCapture: captureService)
        let outputURL = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("peekaboo-desktop-adapter-window-test.png")

        defer {
            try? FileManager.default.removeItem(at: outputURL)
        }

        let result = try await adapter.captureWindow(windowIdentifier: 10, outputPath: outputURL.path)

        XCTAssertEqual(captureService.requestedWindowID, CGWindowID(10))
        XCTAssertEqual(result.path, outputURL.path)
        XCTAssertEqual(result.format, .png)
        XCTAssertEqual(result.byteCount, captureService.imageData.count)
        XCTAssertEqual(result.bounds, DesktopRect(x: 10, y: 20, width: 300, height: 200))
        XCTAssertEqual(try Data(contentsOf: outputURL), captureService.imageData)
    }

    func testCaptureWithoutCaptureServiceThrows() async {
        let adapter = MacAutomationDesktopAdapter(
            applications: StubDesktopApplicationService(),
            screens: StubDesktopScreenService(),
            screenCapture: nil)

        do {
            _ = try await adapter.captureScreen(displayIndex: nil, outputPath: "/tmp/unused.png")
            XCTFail("Expected capture without a capture service to throw")
        } catch let error as DesktopAdapterError {
            XCTAssertEqual(error, .unsupportedPlatform("Screen capture service was not provided"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

@MainActor
private final class StubDesktopApplicationService: ApplicationServiceProtocol {
    private let application = ServiceApplicationInfo(
        processIdentifier: 1234,
        bundleIdentifier: "com.example.App",
        name: "Example",
        bundlePath: "/Applications/Example.app",
        isActive: true,
        isHidden: false,
        windowCount: 2,
        activationPolicy: .regular)

    private let windows = [
        ServiceWindowInfo(
            windowID: 10,
            title: "Visible",
            bounds: CGRect(x: 10, y: 20, width: 300, height: 200),
            isMinimized: false,
            isMainWindow: true,
            alpha: 1,
            index: 0,
            spaceName: "Work",
            isOffScreen: false,
            isOnScreen: true),
        ServiceWindowInfo(
            windowID: 11,
            title: "Hidden",
            bounds: CGRect(x: 10, y: 20, width: 300, height: 200),
            isMinimized: false,
            isMainWindow: false,
            alpha: 0,
            index: 1,
            isOffScreen: true,
            isOnScreen: true),
    ]

    func listApplications() async throws -> UnifiedToolOutput<ServiceApplicationListData> {
        UnifiedToolOutput(
            data: ServiceApplicationListData(applications: [self.application]),
            summary: .init(brief: "apps", status: .success),
            metadata: .init(duration: 0))
    }

    func findApplication(identifier _: String) async throws -> ServiceApplicationInfo {
        self.application
    }

    func listWindows(
        for _: String,
        timeout _: Float?) async throws -> UnifiedToolOutput<ServiceWindowListData>
    {
        UnifiedToolOutput(
            data: ServiceWindowListData(windows: self.windows, targetApplication: self.application),
            summary: .init(brief: "windows", status: .success),
            metadata: .init(duration: 0))
    }

    func getFrontmostApplication() async throws -> ServiceApplicationInfo {
        self.application
    }

    func isApplicationRunning(identifier _: String) async -> Bool {
        true
    }

    func launchApplication(identifier _: String) async throws -> ServiceApplicationInfo {
        self.application
    }

    func activateApplication(identifier _: String) async throws {}
    func quitApplication(identifier _: String, force _: Bool) async throws -> Bool { true }
    func hideApplication(identifier _: String) async throws {}
    func unhideApplication(identifier _: String) async throws {}
    func hideOtherApplications(identifier _: String) async throws {}
    func showAllApplications() async throws {}
}

@MainActor
private final class StubDesktopScreenService: ScreenServiceProtocol {
    private let screens = [
        ScreenInfo(
            index: 0,
            name: "Primary",
            frame: CGRect(x: 0, y: 0, width: 100, height: 100),
            visibleFrame: CGRect(x: 0, y: 10, width: 100, height: 90),
            isPrimary: true,
            scaleFactor: 2,
            displayID: 100),
        ScreenInfo(
            index: 1,
            name: "Secondary",
            frame: CGRect(x: 100, y: 0, width: 200, height: 150),
            visibleFrame: CGRect(x: 100, y: 0, width: 200, height: 150),
            isPrimary: false,
            scaleFactor: 1,
            displayID: 101),
    ]

    func listScreens() -> [ScreenInfo] {
        self.screens
    }

    func screenContainingWindow(bounds: CGRect) -> ScreenInfo? {
        self.screens.first { $0.frame.intersects(bounds) }
    }

    func screen(at index: Int) -> ScreenInfo? {
        self.screens.first { $0.index == index }
    }

    var primaryScreen: ScreenInfo? {
        self.screens.first(where: \.isPrimary)
    }
}

@MainActor
private final class StubDesktopScreenCaptureService: ScreenCaptureServiceProtocol {
    let imageData = Data([0x89, 0x50, 0x4E, 0x47])
    var requestedDisplayIndex: Int?
    var requestedArea: CGRect?
    var requestedWindowID: CGWindowID?
    var requestedFrontmost = false

    func captureScreen(
        displayIndex: Int?,
        visualizerMode _: CaptureVisualizerMode,
        scale _: CaptureScalePreference) async throws -> CaptureResult
    {
        self.requestedDisplayIndex = displayIndex
        return CaptureResult(
            imageData: self.imageData,
            metadata: CaptureMetadata(
                size: CGSize(width: 200, height: 150),
                mode: .screen,
                displayInfo: DisplayInfo(
                    index: displayIndex ?? 0,
                    name: "Secondary",
                    bounds: CGRect(x: 100, y: 0, width: 200, height: 150),
                    scaleFactor: 1)))
    }

    func captureWindow(
        appIdentifier _: String,
        windowIndex _: Int?,
        visualizerMode _: CaptureVisualizerMode,
        scale _: CaptureScalePreference) async throws -> CaptureResult
    {
        fatalError("unused")
    }

    func captureFrontmost(
        visualizerMode _: CaptureVisualizerMode,
        scale _: CaptureScalePreference) async throws -> CaptureResult
    {
        self.requestedFrontmost = true
        let bounds = CGRect(x: 10, y: 20, width: 300, height: 200)
        return CaptureResult(
            imageData: self.imageData,
            metadata: CaptureMetadata(
                size: bounds.size,
                mode: .window,
                windowInfo: ServiceWindowInfo(
                    windowID: 10,
                    title: "Visible",
                    bounds: bounds)))
    }

    func captureWindow(
        windowID: CGWindowID,
        visualizerMode _: CaptureVisualizerMode,
        scale _: CaptureScalePreference) async throws -> CaptureResult
    {
        self.requestedWindowID = windowID
        let bounds = CGRect(x: 10, y: 20, width: 300, height: 200)
        return CaptureResult(
            imageData: self.imageData,
            metadata: CaptureMetadata(
                size: bounds.size,
                mode: .window,
                windowInfo: ServiceWindowInfo(
                    windowID: Int(windowID),
                    title: "Visible",
                    bounds: bounds)))
    }

    func captureArea(
        _ rect: CGRect,
        visualizerMode _: CaptureVisualizerMode,
        scale _: CaptureScalePreference) async throws -> CaptureResult
    {
        self.requestedArea = rect
        return CaptureResult(
            imageData: self.imageData,
            metadata: CaptureMetadata(
                size: rect.size,
                mode: .area,
                displayInfo: DisplayInfo(
                    index: 0,
                    name: "Primary",
                    bounds: rect,
                    scaleFactor: 1)))
    }

    func hasScreenRecordingPermission() async -> Bool {
        true
    }
}
