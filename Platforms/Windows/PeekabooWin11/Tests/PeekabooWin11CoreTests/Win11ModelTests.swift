import PeekabooDesktop
import XCTest
@testable import PeekabooWin11Core

final class Win11ModelTests: XCTestCase {
    func testRectCodableRoundTrip() throws {
        let rect = Win11Rect(x: -10, y: 20, width: 1920, height: 1080)
        let data = try JSONEncoder().encode(rect)
        let decoded = try JSONDecoder().decode(Win11Rect.self, from: data)

        XCTAssertEqual(decoded, rect)
        XCTAssertFalse(decoded.isEmpty)
    }

    func testPlatformInfoAdvertisesWin32Windows11() {
        let info: Win11PlatformInfo
        #if os(Windows)
        info = Win32DesktopAdapter().platformInfo()
        #else
        info = Win11PlatformInfo(
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
            ])
        #endif

        XCTAssertEqual(info.minimumSystemVersion, "Windows 11")
        XCTAssertEqual(info.nativeBackend, "Win32")
        XCTAssertTrue(info.capabilities.contains(.enumerateWindows))
        XCTAssertTrue(info.capabilities.contains(.captureScreenBMP))
        XCTAssertTrue(info.capabilities.contains(.captureAreaBMP))
        XCTAssertTrue(info.capabilities.contains(.captureWindowBMP))
        XCTAssertTrue(info.capabilities.contains(.captureFrontmostBMP))
        XCTAssertTrue(info.capabilities.contains(.readCursorPosition))
        XCTAssertTrue(info.capabilities.contains(.moveCursor))
        XCTAssertTrue(info.capabilities.contains(.clickMouse))
        XCTAssertTrue(info.capabilities.contains(.scrollMouse))
        XCTAssertTrue(info.capabilities.contains(.dragMouse))
        XCTAssertTrue(info.capabilities.contains(.sendHotkey))
        XCTAssertTrue(info.capabilities.contains(.typeText))
        XCTAssertTrue(info.capabilities.contains(.inspectUIAutomation))
        XCTAssertFalse(info.capabilities.contains(.captureScreenPNG))
    }

    func testUnsupportedAdapterFailsOffWindows() throws {
        #if os(Windows)
        throw XCTSkip("The default adapter is native on Windows.")
        #else
        let adapter = Win11DesktopAdapterFactory.makeDefault()
        XCTAssertThrowsError(try adapter.listDisplays())
        XCTAssertThrowsError(try adapter.listWindows(includeInvisible: false))
        XCTAssertThrowsError(try adapter.listApplications())
        XCTAssertThrowsError(try adapter.captureArea(
            Win11Rect(x: 0, y: 0, width: 1, height: 1),
            outputPath: "area.bmp"))
        XCTAssertThrowsError(try adapter.captureWindow(windowIdentifier: 1, outputPath: "window.bmp"))
        XCTAssertThrowsError(try adapter.captureFrontmost(outputPath: "frontmost.bmp"))
        XCTAssertThrowsError(try adapter.cursorPosition())
        XCTAssertThrowsError(try adapter.moveCursor(to: DesktopPoint(x: 0, y: 0)))
        XCTAssertThrowsError(try adapter.click(
            at: DesktopPoint(x: 0, y: 0),
            button: .left,
            clickCount: 1))
        XCTAssertThrowsError(try adapter.scroll(
            at: DesktopPoint(x: 0, y: 0),
            direction: .down,
            amount: 1))
        XCTAssertThrowsError(try adapter.drag(
            from: DesktopPoint(x: 0, y: 0),
            to: DesktopPoint(x: 0, y: 0),
            button: .left,
            steps: 1))
        XCTAssertThrowsError(try adapter.hotkey(keys: ["shift"], holdDurationMilliseconds: 0))
        XCTAssertThrowsError(try adapter.typeText("a", delayMilliseconds: 0))
        XCTAssertThrowsError(try adapter.uiAutomationStatus())
        XCTAssertThrowsError(try adapter.uiAutomationSnapshot(scope: .root, maxDepth: 1, maxElements: 4))
        #endif
    }

    func testCliReturnsFailureForUnsupportedCommand() {
        var errorOutput = ""
        let status = Win11CLI.run(
            arguments: ["peekaboo-win11", "unknown"],
            adapter: UnsupportedWin11DesktopAdapter(),
            stdout: { _ in },
            stderr: { errorOutput = $0 })

        XCTAssertEqual(status, 1)
        XCTAssertTrue(errorOutput.contains("Unknown command"))
    }

    func testCliUsesSharedDesktopCommandRunnerHelp() {
        var output = ""
        let status = Win11CLI.run(
            arguments: ["peekaboo-win11", "--help"],
            adapter: UnsupportedWin11DesktopAdapter(),
            stdout: { output = $0 },
            stderr: { _ in })

        XCTAssertEqual(status, 0)
        XCTAssertTrue(output.contains("peekaboo-win11"))
        XCTAssertTrue(output.contains("list displays"))
        XCTAssertTrue(output.contains("capture screen --path"))
        XCTAssertTrue(output.contains("capture area --rect"))
        XCTAssertTrue(output.contains("capture window --id"))
        XCTAssertTrue(output.contains("capture frontmost --path"))
        XCTAssertTrue(output.contains("input position"))
        XCTAssertTrue(output.contains("input move --point"))
        XCTAssertTrue(output.contains("input click --point"))
        XCTAssertTrue(output.contains("input scroll --point"))
        XCTAssertTrue(output.contains("input drag --from"))
        XCTAssertTrue(output.contains("input hotkey --keys"))
        XCTAssertTrue(output.contains("input type --text"))
        XCTAssertTrue(output.contains("automation status"))
        XCTAssertTrue(output.contains("automation snapshot"))
    }

    func testNativeWindowsAdapterCanReadDesktopState() throws {
        #if os(Windows)
        let adapter = Win32DesktopAdapter()
        let displays = try adapter.listDisplays()
        let windows = try adapter.listWindows(includeInvisible: true)

        XCTAssertFalse(displays.isEmpty)
        XCTAssertNotNil(windows)
        #else
        throw XCTSkip("Native Windows adapter smoke test only runs on Windows.")
        #endif
    }

    func testNativeWindowsAdapterCanCaptureBMP() throws {
        #if os(Windows)
        let adapter = Win32DesktopAdapter()
        let outputPath = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("peekaboo-win11-smoke.bmp")
            .path

        defer {
            try? FileManager.default.removeItem(atPath: outputPath)
        }

        let result = try adapter.captureScreen(displayIndex: nil, outputPath: outputPath)

        XCTAssertEqual(result.format, .bmp)
        XCTAssertGreaterThan(result.byteCount, 54)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputPath))
        #else
        throw XCTSkip("Native Windows capture smoke test only runs on Windows.")
        #endif
    }

    func testNativeWindowsAdapterCanCaptureAreaBMP() throws {
        #if os(Windows)
        let adapter = Win32DesktopAdapter()
        let displays = try adapter.listDisplays()
        let display = try XCTUnwrap(displays.first)
        let area = Win11Rect(
            x: display.bounds.x,
            y: display.bounds.y,
            width: min(10, display.bounds.width),
            height: min(10, display.bounds.height))
        let outputPath = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("peekaboo-win11-area-smoke.bmp")
            .path

        defer {
            try? FileManager.default.removeItem(atPath: outputPath)
        }

        let result = try adapter.captureArea(area, outputPath: outputPath)

        XCTAssertEqual(result.format, .bmp)
        XCTAssertEqual(result.bounds, area)
        XCTAssertGreaterThan(result.byteCount, 54)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputPath))
        #else
        throw XCTSkip("Native Windows area capture smoke test only runs on Windows.")
        #endif
    }

    func testNativeWindowsAdapterCanCaptureWindowBMP() throws {
        #if os(Windows)
        let adapter = Win32DesktopAdapter()
        guard let window = try adapter.listWindows(includeInvisible: false).first else {
            throw XCTSkip("No visible windows available for native window capture smoke test.")
        }
        let outputPath = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("peekaboo-win11-window-smoke.bmp")
            .path

        defer {
            try? FileManager.default.removeItem(atPath: outputPath)
        }

        let result = try adapter.captureWindow(
            windowIdentifier: window.windowIdentifier,
            outputPath: outputPath)

        XCTAssertEqual(result.format, .bmp)
        XCTAssertEqual(result.bounds, window.bounds)
        XCTAssertGreaterThan(result.byteCount, 54)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputPath))
        #else
        throw XCTSkip("Native Windows window capture smoke test only runs on Windows.")
        #endif
    }

    func testNativeWindowsAdapterCanCaptureFrontmostBMP() throws {
        #if os(Windows)
        let adapter = Win32DesktopAdapter()
        let outputPath = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("peekaboo-win11-frontmost-smoke.bmp")
            .path

        defer {
            try? FileManager.default.removeItem(atPath: outputPath)
        }

        do {
            let result = try adapter.captureFrontmost(outputPath: outputPath)

            XCTAssertEqual(result.format, .bmp)
            XCTAssertGreaterThan(result.byteCount, 54)
            XCTAssertTrue(FileManager.default.fileExists(atPath: outputPath))
        } catch let error as Win11DesktopError {
            if case .invalidArgument = error {
                throw XCTSkip("No foreground window available for native frontmost capture smoke test.")
            }
            throw error
        }
        #else
        throw XCTSkip("Native Windows frontmost capture smoke test only runs on Windows.")
        #endif
    }

    func testNativeWindowsAdapterCanReadAndMoveCursor() throws {
        #if os(Windows)
        let adapter = Win32DesktopAdapter()
        let position = try adapter.cursorPosition()
        let moved = try adapter.moveCursor(to: position)

        XCTAssertEqual(moved, position)
        #else
        throw XCTSkip("Native Windows cursor smoke test only runs on Windows.")
        #endif
    }

    func testNativeWindowsAdapterCanClickCurrentCursorPosition() throws {
        #if os(Windows)
        let adapter = Win32DesktopAdapter()
        let position = try adapter.cursorPosition()
        let result = try adapter.click(at: position, button: .left, clickCount: 1)

        XCTAssertEqual(result.point, position)
        XCTAssertEqual(result.button, .left)
        XCTAssertEqual(result.clickCount, 1)
        #else
        throw XCTSkip("Native Windows click smoke test only runs on Windows.")
        #endif
    }

    func testNativeWindowsAdapterCanScrollAtCurrentCursorPosition() throws {
        #if os(Windows)
        let adapter = Win32DesktopAdapter()
        let position = try adapter.cursorPosition()
        let result = try adapter.scroll(at: position, direction: .down, amount: 1)

        XCTAssertEqual(result.point, position)
        XCTAssertEqual(result.direction, .down)
        XCTAssertEqual(result.amount, 1)
        #else
        throw XCTSkip("Native Windows scroll smoke test only runs on Windows.")
        #endif
    }

    func testNativeWindowsAdapterCanDragAtCurrentCursorPosition() throws {
        #if os(Windows)
        let adapter = Win32DesktopAdapter()
        let position = try adapter.cursorPosition()
        let result = try adapter.drag(
            from: position,
            to: position,
            button: .left,
            steps: 1)

        XCTAssertEqual(result.startPoint, position)
        XCTAssertEqual(result.endPoint, position)
        XCTAssertEqual(result.button, .left)
        XCTAssertEqual(result.steps, 1)
        #else
        throw XCTSkip("Native Windows drag smoke test only runs on Windows.")
        #endif
    }

    func testNativeWindowsAdapterCanSendModifierOnlyHotkey() throws {
        #if os(Windows)
        let adapter = Win32DesktopAdapter()
        let result = try adapter.hotkey(keys: ["shift"], holdDurationMilliseconds: 0)

        XCTAssertEqual(result.keys, ["shift"])
        XCTAssertEqual(result.holdDurationMilliseconds, 0)
        #else
        throw XCTSkip("Native Windows hotkey smoke test only runs on Windows.")
        #endif
    }

    func testNativeWindowsAdapterRejectsUnknownHotkey() throws {
        #if os(Windows)
        let adapter = Win32DesktopAdapter()

        XCTAssertThrowsError(try adapter.hotkey(keys: ["not-a-key"], holdDurationMilliseconds: 0))
        #else
        throw XCTSkip("Native Windows hotkey validation test only runs on Windows.")
        #endif
    }

    func testNativeWindowsAdapterCanTypeText() throws {
        #if os(Windows)
        let adapter = Win32DesktopAdapter()
        let result = try adapter.typeText("a", delayMilliseconds: 0)

        XCTAssertEqual(result.text, "a")
        XCTAssertEqual(result.characterCount, 1)
        XCTAssertEqual(result.delayMilliseconds, 0)
        #else
        throw XCTSkip("Native Windows typing smoke test only runs on Windows.")
        #endif
    }

    func testNativeWindowsAdapterRejectsUnsupportedTextCharacter() throws {
        #if os(Windows)
        let adapter = Win32DesktopAdapter()

        XCTAssertThrowsError(try adapter.typeText("\u{1F642}", delayMilliseconds: 0))
        #else
        throw XCTSkip("Native Windows typing validation test only runs on Windows.")
        #endif
    }

    func testNativeWindowsAdapterCanProbeUIAutomation() throws {
        #if os(Windows)
        let adapter = Win32DesktopAdapter()
        let status = try adapter.uiAutomationStatus()

        XCTAssertEqual(status.nativeBackend, "UIAutomation")
        XCTAssertTrue(status.isAvailable, status.error ?? "UI Automation is not available")
        XCTAssertTrue(status.rootElementAvailable, status.error ?? "UI Automation root element is not available")
        #else
        throw XCTSkip("Native Windows UI Automation smoke test only runs on Windows.")
        #endif
    }

    func testNativeWindowsAdapterCanSnapshotUIAutomationRoot() throws {
        #if os(Windows)
        let adapter = Win32DesktopAdapter()
        let snapshot = try adapter.uiAutomationSnapshot(scope: .root, maxDepth: 1, maxElements: 16)

        XCTAssertEqual(snapshot.nativeBackend, "UIAutomation")
        XCTAssertEqual(snapshot.scope, .root)
        XCTAssertEqual(snapshot.maxDepth, 1)
        XCTAssertEqual(snapshot.maxElements, 16)
        XCTAssertNil(snapshot.error)
        XCTAssertFalse(snapshot.elements.isEmpty)
        XCTAssertEqual(snapshot.elements.first?.depth, 0)
        XCTAssertEqual(snapshot.elements.first?.parentIndex, nil)
        XCTAssertTrue(snapshot.elements.contains { element in
            element.controlTypeName != nil
        })
        XCTAssertTrue(snapshot.elements.contains { element in
            element.isEnabled != nil || element.isOffscreen != nil
        })
        #else
        throw XCTSkip("Native Windows UI Automation snapshot smoke test only runs on Windows.")
        #endif
    }
}
