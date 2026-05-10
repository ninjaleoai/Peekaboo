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
        let info = Win11PlatformInfo()

        XCTAssertEqual(info.minimumWindowsVersion, "Windows 11")
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
}
