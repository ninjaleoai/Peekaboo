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
}

