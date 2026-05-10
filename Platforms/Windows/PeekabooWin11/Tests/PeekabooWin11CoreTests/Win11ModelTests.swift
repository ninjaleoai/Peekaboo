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
            capabilities: Win11PlatformCapability.allCases)
        #endif

        XCTAssertEqual(info.minimumSystemVersion, "Windows 11")
        XCTAssertEqual(info.nativeBackend, "Win32")
        XCTAssertTrue(info.capabilities.contains(.enumerateWindows))
        XCTAssertTrue(info.capabilities.contains(.captureScreenBMP))
    }

    func testUnsupportedAdapterFailsOffWindows() throws {
        #if os(Windows)
        throw XCTSkip("The default adapter is native on Windows.")
        #else
        let adapter = Win11DesktopAdapterFactory.makeDefault()
        XCTAssertThrowsError(try adapter.listDisplays())
        XCTAssertThrowsError(try adapter.listWindows(includeInvisible: false))
        XCTAssertThrowsError(try adapter.listApplications())
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
}
