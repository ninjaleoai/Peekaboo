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
            ])
        #endif

        XCTAssertEqual(info.minimumSystemVersion, "Windows 11")
        XCTAssertEqual(info.nativeBackend, "Win32")
        XCTAssertTrue(info.capabilities.contains(.enumerateWindows))
        XCTAssertTrue(info.capabilities.contains(.captureScreenBMP))
        XCTAssertTrue(info.capabilities.contains(.captureAreaBMP))
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
}
