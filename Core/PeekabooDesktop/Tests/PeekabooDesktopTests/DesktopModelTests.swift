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

    func testSyncAdapterAsyncBridgeForwardsCalls() async throws {
        let bridge = DesktopAdapterAsyncBridge(StubDesktopAdapter())

        let info = await bridge.platformInfo()
        let displays = try await bridge.listDisplays()
        let windows = try await bridge.listWindows(includeInvisible: true)
        let applications = try await bridge.listApplications()
        let capture = try await bridge.captureScreen(displayIndex: nil, outputPath: "screen.bmp")

        XCTAssertEqual(info.nativeBackend, "Stub")
        XCTAssertEqual(displays.map(\.index), [0])
        XCTAssertEqual(windows.map(\.title), ["Window"])
        XCTAssertEqual(applications.map(\.executableName), ["Example"])
        XCTAssertEqual(capture.format, .bmp)
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
}
