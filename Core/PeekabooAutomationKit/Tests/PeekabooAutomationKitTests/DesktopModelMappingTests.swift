import CoreGraphics
import PeekabooDesktop
@testable import PeekabooAutomationKit
import XCTest

final class DesktopModelMappingTests: XCTestCase {
    func testScreenInfoMapsToDesktopDisplay() {
        let screen = ScreenInfo(
            index: 2,
            name: "External Display",
            frame: CGRect(x: -1920, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: -1920, y: 24, width: 1920, height: 1056),
            isPrimary: false,
            scaleFactor: 2,
            displayID: 42)

        let display = screen.desktopDisplay

        XCTAssertEqual(display.id, 42)
        XCTAssertEqual(display.index, 2)
        XCTAssertEqual(display.bounds, DesktopRect(x: -1920, y: 0, width: 1920, height: 1080))
        XCTAssertEqual(display.workArea, DesktopRect(x: -1920, y: 24, width: 1920, height: 1056))
        XCTAssertFalse(display.isPrimary)
        XCTAssertEqual(display.name, "External Display")
        XCTAssertEqual(display.scaleFactor, 2)
    }

    func testApplicationInfoMapsToDesktopApplication() {
        let application = ServiceApplicationInfo(
            processIdentifier: 1234,
            bundleIdentifier: "com.example.App",
            name: "Example",
            bundlePath: "/Applications/Example.app",
            isActive: true,
            isHidden: false,
            windowCount: 3,
            activationPolicy: .regular)

        let desktopApplication = application.desktopApplication

        XCTAssertEqual(desktopApplication.processIdentifier, 1234)
        XCTAssertEqual(desktopApplication.executableName, "Example")
        XCTAssertEqual(desktopApplication.executablePath, "/Applications/Example.app")
        XCTAssertEqual(desktopApplication.bundleIdentifier, "com.example.App")
        XCTAssertTrue(desktopApplication.isActive)
        XCTAssertFalse(desktopApplication.isHidden)
        XCTAssertEqual(desktopApplication.visibleWindowCount, 3)
    }

    func testWindowInfoMapsToDesktopWindow() {
        let window = ServiceWindowInfo(
            windowID: 99,
            title: "Document",
            bounds: CGRect(x: 10.4, y: 20.6, width: 800.2, height: 599.7),
            isMinimized: false,
            isMainWindow: true,
            alpha: 1,
            isOffScreen: false,
            isOnScreen: true)

        let desktopWindow = window.desktopWindow(processIdentifier: 1234, executableName: "Example")

        XCTAssertEqual(desktopWindow.windowIdentifier, 99)
        XCTAssertEqual(desktopWindow.processIdentifier, 1234)
        XCTAssertEqual(desktopWindow.title, "Document")
        XCTAssertEqual(desktopWindow.bounds, DesktopRect(x: 10, y: 21, width: 800, height: 600))
        XCTAssertTrue(desktopWindow.isVisible)
        XCTAssertFalse(desktopWindow.isMinimized)
        XCTAssertTrue(desktopWindow.isForeground)
        XCTAssertEqual(desktopWindow.executableName, "Example")
    }
}
