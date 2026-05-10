import XCTest
@testable import PeekabooDesktop

final class DesktopModelTests: XCTestCase {
    func testDesktopRectRoundTrip() throws {
        let rect = DesktopRect(x: -320, y: 40, width: 1920, height: 1080)
        let data = try JSONEncoder().encode(rect)
        let decoded = try JSONDecoder().decode(DesktopRect.self, from: data)

        XCTAssertEqual(decoded, rect)
        XCTAssertEqual(decoded.origin, DesktopPoint(x: -320, y: 40))
        XCTAssertEqual(decoded.size, DesktopSize(width: 1920, height: 1080))
        XCTAssertFalse(decoded.isEmpty)
    }

    func testPlatformInfoEnvelopeEncoding() throws {
        let info = DesktopPlatformInfo(
            name: "Windows",
            minimumSystemVersion: "Windows 11",
            nativeBackend: "Win32",
            capabilities: [.enumerateDisplays, .enumerateWindows])

        let output = try DesktopJSON.encode(DesktopCommandEnvelope(ok: true, data: info, error: nil))

        XCTAssertTrue(output.contains("\"ok\" : true"))
        XCTAssertTrue(output.contains("\"minimumSystemVersion\" : \"Windows 11\""))
        XCTAssertTrue(output.contains("\"nativeBackend\" : \"Win32\""))
    }

    func testDesktopWindowDecodesMissingShareableAsTrue() throws {
        let data = Data("""
        {
          "windowIdentifier": 20,
          "processIdentifier": 30,
          "title": "Window",
          "bounds": { "x": 1, "y": 2, "width": 3, "height": 4 },
          "isVisible": true,
          "isMinimized": false,
          "isForeground": true,
          "executableName": "Example",
          "index": 0,
          "isOffScreen": false,
          "layer": 0,
          "isOnScreen": true,
          "alpha": 1.0
        }
        """.utf8)

        let window = try JSONDecoder().decode(DesktopWindow.self, from: data)

        XCTAssertTrue(window.isShareable)
    }

    func testSyncAdapterAsyncBridgeForwardsCalls() async throws {
        let bridge = DesktopAdapterAsyncBridge(StubDesktopAdapter())

        let info = await bridge.platformInfo()
        let displays = try await bridge.listDisplays()
        let windows = try await bridge.listWindows(includeInvisible: true)
        let applications = try await bridge.listApplications()
        let capture = try await bridge.captureScreen(displayIndex: nil, outputPath: "screen.bmp")
        let area = try await bridge.captureArea(
            DesktopRect(x: 1, y: 2, width: 3, height: 4),
            outputPath: "area.bmp")
        let window = try await bridge.captureWindow(windowIdentifier: 20, outputPath: "window.bmp")
        let frontmost = try await bridge.captureFrontmost(outputPath: "frontmost.bmp")
        let cursor = try await bridge.cursorPosition()
        let movedCursor = try await bridge.moveCursor(to: DesktopPoint(x: 9, y: 10))
        let click = try await bridge.click(
            at: DesktopPoint(x: 11, y: 12),
            button: .right,
            clickCount: 2)

        XCTAssertEqual(info.nativeBackend, "Stub")
        XCTAssertEqual(displays.map(\.index), [0])
        XCTAssertEqual(windows.map(\.title), ["Window"])
        XCTAssertEqual(applications.map(\.executableName), ["Example"])
        XCTAssertEqual(capture.format, .bmp)
        XCTAssertEqual(area.bounds, DesktopRect(x: 1, y: 2, width: 3, height: 4))
        XCTAssertEqual(window.bounds, DesktopRect(x: 1, y: 2, width: 3, height: 4))
        XCTAssertEqual(frontmost.bounds, DesktopRect(x: 1, y: 2, width: 3, height: 4))
        XCTAssertEqual(cursor, DesktopPoint(x: 7, y: 8))
        XCTAssertEqual(movedCursor, DesktopPoint(x: 9, y: 10))
        XCTAssertEqual(click, DesktopClickResult(
            point: DesktopPoint(x: 11, y: 12),
            button: .right,
            clickCount: 2))
    }

    func testDesktopCommandRunnerRoutesPlatformInfo() {
        let result = self.runDesktopCommand(["peekaboo-desktop", "platform-info"])

        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.stderr, "")
        XCTAssertTrue(result.stdout.contains("\"nativeBackend\" : \"Stub\""))
        XCTAssertTrue(result.stdout.contains("\"ok\" : true"))
    }

    func testDesktopCommandRunnerRoutesListCommands() {
        let displays = self.runDesktopCommand(["peekaboo-desktop", "list", "displays"])
        let windows = self.runDesktopCommand(["peekaboo-desktop", "list", "windows", "--include-invisible"])
        let applications = self.runDesktopCommand(["peekaboo-desktop", "list", "apps"])

        XCTAssertEqual(displays.status, 0)
        XCTAssertEqual(windows.status, 0)
        XCTAssertEqual(applications.status, 0)
        XCTAssertTrue(displays.stdout.contains("\"index\" : 0"))
        XCTAssertTrue(windows.stdout.contains("\"title\" : \"Window\""))
        XCTAssertTrue(applications.stdout.contains("\"executableName\" : \"Example\""))
    }

    func testDesktopCommandRunnerRoutesScreenCapture() {
        let result = self.runDesktopCommand([
            "peekaboo-desktop",
            "capture",
            "screen",
            "--path",
            "screen.bmp",
            "--display",
            "0",
        ])

        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.stderr, "")
        XCTAssertTrue(result.stdout.contains("\"path\" : \"screen.bmp\""))
        XCTAssertTrue(result.stdout.contains("\"format\" : \"bmp\""))
    }

    func testDesktopCommandRunnerRoutesAreaCapture() {
        let result = self.runDesktopCommand([
            "peekaboo-desktop",
            "capture",
            "area",
            "--rect",
            "1,2,3,4",
            "--path",
            "area.bmp",
        ])

        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.stderr, "")
        XCTAssertTrue(result.stdout.contains("\"path\" : \"area.bmp\""))
        XCTAssertTrue(result.stdout.contains("\"x\" : 1"))
        XCTAssertTrue(result.stdout.contains("\"width\" : 3"))
    }

    func testDesktopCommandRunnerRoutesWindowCapture() {
        let result = self.runDesktopCommand([
            "peekaboo-desktop",
            "capture",
            "window",
            "--id",
            "20",
            "--path",
            "window.bmp",
        ])

        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.stderr, "")
        XCTAssertTrue(result.stdout.contains("\"path\" : \"window.bmp\""))
        XCTAssertTrue(result.stdout.contains("\"format\" : \"bmp\""))
        XCTAssertTrue(result.stdout.contains("\"x\" : 1"))
    }

    func testDesktopCommandRunnerRoutesFrontmostCapture() {
        let result = self.runDesktopCommand([
            "peekaboo-desktop",
            "capture",
            "frontmost",
            "--path",
            "frontmost.bmp",
        ])

        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.stderr, "")
        XCTAssertTrue(result.stdout.contains("\"path\" : \"frontmost.bmp\""))
        XCTAssertTrue(result.stdout.contains("\"format\" : \"bmp\""))
        XCTAssertTrue(result.stdout.contains("\"x\" : 1"))
    }

    func testDesktopCommandRunnerRoutesInputPosition() {
        let result = self.runDesktopCommand(["peekaboo-desktop", "input", "position"])

        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.stderr, "")
        XCTAssertTrue(result.stdout.contains("\"x\" : 7"))
        XCTAssertTrue(result.stdout.contains("\"y\" : 8"))
    }

    func testDesktopCommandRunnerRoutesInputMove() {
        let result = self.runDesktopCommand([
            "peekaboo-desktop",
            "input",
            "move",
            "--point",
            "9,10",
        ])

        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.stderr, "")
        XCTAssertTrue(result.stdout.contains("\"x\" : 9"))
        XCTAssertTrue(result.stdout.contains("\"y\" : 10"))
    }

    func testDesktopCommandRunnerRoutesInputClick() {
        let result = self.runDesktopCommand([
            "peekaboo-desktop",
            "input",
            "click",
            "--point",
            "11,12",
            "--button",
            "right",
            "--count",
            "2",
        ])

        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.stderr, "")
        XCTAssertTrue(result.stdout.contains("\"x\" : 11"))
        XCTAssertTrue(result.stdout.contains("\"y\" : 12"))
        XCTAssertTrue(result.stdout.contains("\"button\" : \"right\""))
        XCTAssertTrue(result.stdout.contains("\"clickCount\" : 2"))
    }

    func testDesktopCommandRunnerRejectsInvalidInputClickCount() {
        let result = self.runDesktopCommand([
            "peekaboo-desktop",
            "input",
            "click",
            "--point",
            "11,12",
            "--count",
            "0",
        ])

        XCTAssertEqual(result.status, 1)
        XCTAssertEqual(result.stdout, "")
        XCTAssertTrue(result.stderr.contains("Click count must be a positive integer"))
    }

    func testDesktopCommandRunnerHelpIncludesWindowCapture() {
        let result = self.runDesktopCommand(["peekaboo-desktop", "--help"])

        XCTAssertEqual(result.status, 0)
        XCTAssertTrue(result.stdout.contains("capture window --id <window-id> --path"))
        XCTAssertTrue(result.stdout.contains("capture frontmost --path"))
        XCTAssertTrue(result.stdout.contains("input position"))
        XCTAssertTrue(result.stdout.contains("input move --point"))
        XCTAssertTrue(result.stdout.contains("input click --point"))
    }

    func testDesktopCommandRunnerReportsInvalidCommands() {
        let result = self.runDesktopCommand(["peekaboo-desktop", "unknown"])

        XCTAssertEqual(result.status, 1)
        XCTAssertEqual(result.stdout, "")
        XCTAssertTrue(result.stderr.contains("Unknown command"))
    }

    private func runDesktopCommand(_ arguments: [String]) -> CommandResult {
        var stdout = ""
        var stderr = ""
        let status = DesktopCommandRunner.run(
            arguments: arguments,
            adapter: StubDesktopAdapter(),
            stdout: { stdout = $0 },
            stderr: { stderr = $0 })

        return CommandResult(status: status, stdout: stdout, stderr: stderr)
    }
}

private struct StubDesktopAdapter: DesktopAdapter {
    func platformInfo() -> DesktopPlatformInfo {
        DesktopPlatformInfo(
            name: "StubOS",
            minimumSystemVersion: "1",
            nativeBackend: "Stub",
            capabilities: DesktopPlatformCapability.allCases)
    }

    func listDisplays() throws -> [DesktopDisplay] {
        [
            DesktopDisplay(
                id: 10,
                index: 0,
                bounds: DesktopRect(x: 0, y: 0, width: 100, height: 100),
                workArea: DesktopRect(x: 0, y: 0, width: 100, height: 90),
                isPrimary: true),
        ]
    }

    func listWindows(includeInvisible _: Bool) throws -> [DesktopWindow] {
        [
            DesktopWindow(
                windowIdentifier: 20,
                processIdentifier: 30,
                title: "Window",
                bounds: DesktopRect(x: 1, y: 2, width: 3, height: 4),
                isVisible: true,
                isMinimized: false,
                isForeground: true,
                executableName: "Example"),
        ]
    }

    func listApplications() throws -> [DesktopApplication] {
        [
            DesktopApplication(
                processIdentifier: 30,
                executableName: "Example",
                executablePath: "/Applications/Example.app",
                isActive: true,
                visibleWindowCount: 1),
        ]
    }

    func captureScreen(displayIndex _: Int?, outputPath: String) throws -> DesktopCaptureResult {
        DesktopCaptureResult(
            path: outputPath,
            bounds: DesktopRect(x: 0, y: 0, width: 100, height: 100),
            format: .bmp,
            byteCount: 42)
    }

    func captureArea(_ rect: DesktopRect, outputPath: String) throws -> DesktopCaptureResult {
        DesktopCaptureResult(
            path: outputPath,
            bounds: rect,
            format: .bmp,
            byteCount: 21)
    }

    func captureWindow(windowIdentifier _: UInt64, outputPath: String) throws -> DesktopCaptureResult {
        DesktopCaptureResult(
            path: outputPath,
            bounds: DesktopRect(x: 1, y: 2, width: 3, height: 4),
            format: .bmp,
            byteCount: 21)
    }

    func captureFrontmost(outputPath: String) throws -> DesktopCaptureResult {
        DesktopCaptureResult(
            path: outputPath,
            bounds: DesktopRect(x: 1, y: 2, width: 3, height: 4),
            format: .bmp,
            byteCount: 21)
    }

    func cursorPosition() throws -> DesktopPoint {
        DesktopPoint(x: 7, y: 8)
    }

    func moveCursor(to point: DesktopPoint) throws -> DesktopPoint {
        point
    }

    func click(
        at point: DesktopPoint,
        button: DesktopMouseButton,
        clickCount: Int) throws -> DesktopClickResult
    {
        DesktopClickResult(point: point, button: button, clickCount: clickCount)
    }
}

private struct CommandResult {
    let status: Int32
    let stdout: String
    let stderr: String
}
