import Foundation
import PeekabooDesktop
import XCTest
@testable import PeekabooWin11Core

final class Win11MCPServerTests: XCTestCase {
    func testInitializeAdvertisesWindowsMCPServer() throws {
        let server = Win11MCPServer(desktop: MockMCPDesktop())

        let response = try XCTUnwrap(server.handleLine(#"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","clientInfo":{"name":"Tests","version":"1"}}}"#))
        let result = try self.resultObject(response)
        let serverInfo = try XCTUnwrap(result["serverInfo"] as? [String: Any])
        let capabilities = try XCTUnwrap(result["capabilities"] as? [String: Any])

        XCTAssertEqual(serverInfo["name"] as? String, "peekaboo-win11")
        XCTAssertNotNil(capabilities["tools"])
    }

    func testToolsListIncludesOriginalStyleWindowsSubset() throws {
        let server = Win11MCPServer(desktop: MockMCPDesktop())

        let response = try XCTUnwrap(server.handleLine(#"{"jsonrpc":"2.0","id":2,"method":"tools/list"}"#))
        let result = try self.resultObject(response)
        let tools = try XCTUnwrap(result["tools"] as? [[String: Any]])
        let names = Set(tools.compactMap { $0["name"] as? String })
        let expected: Set<String> = [
            "list",
            "image",
            "see",
            "observe",
            "snapshot",
            "move",
            "click",
            "scroll",
            "drag",
            "hotkey",
            "type",
            "uia",
            "perform_action",
            "set_value",
        ]

        XCTAssertTrue(names.isSuperset(of: expected))
    }

    func testListApplicationsToolUsesDesktopProvider() throws {
        let server = Win11MCPServer(desktop: MockMCPDesktop())

        let response = try XCTUnwrap(server.handleLine(#"{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"list","arguments":{"item_type":"running_applications"}}}"#))
        let result = try self.resultObject(response)
        let structured = try XCTUnwrap(result["structuredContent"] as? [String: Any])
        let applications = try XCTUnwrap(structured["applications"] as? [[String: Any]])

        XCTAssertEqual(result["isError"] as? Bool, false)
        XCTAssertEqual(applications.first?["executableName"] as? String, "notepad.exe")
    }

    func testSeeCapturesAndStoresSnapshot() throws {
        let desktop = MockMCPDesktop()
        let server = Win11MCPServer(desktop: desktop)

        let response = try XCTUnwrap(server.handleLine(#"{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"see","arguments":{"app_target":"frontmost","path":"C:\\Temp\\peekaboo.bmp","snapshot":"snap-1","max_depth":1,"max_elements":4}}}"#))
        let result = try self.resultObject(response)
        let structured = try XCTUnwrap(result["structuredContent"] as? [String: Any])
        let automation = try XCTUnwrap(structured["automation"] as? [String: Any])

        XCTAssertEqual(result["isError"] as? Bool, false)
        XCTAssertEqual(structured["id"] as? String, "snap-1")
        XCTAssertEqual(automation["elementCount"] as? Int, 1)
        XCTAssertEqual(desktop.lastCapturePath, "C:\\Temp\\peekaboo.bmp")

        let snapshotResponse = try XCTUnwrap(server.handleLine(#"{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"snapshot","arguments":{"action":"get","snapshot":"snap-1"}}}"#))
        let snapshotResult = try self.resultObject(snapshotResponse)
        let snapshotStructured = try XCTUnwrap(snapshotResult["structuredContent"] as? [String: Any])
        XCTAssertEqual(snapshotStructured["id"] as? String, "snap-1")
    }

    func testUnknownToolUsesJSONRPCInvalidParamsError() throws {
        let server = Win11MCPServer(desktop: MockMCPDesktop())

        let response = try XCTUnwrap(server.handleLine(#"{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"missing","arguments":{}}}"#))
        let object = try self.responseObject(response)
        let error = try XCTUnwrap(object["error"] as? [String: Any])

        XCTAssertEqual(error["code"] as? Int, -32602)
        XCTAssertTrue((error["message"] as? String)?.contains("Unknown tool") == true)
    }

    private func resultObject(_ response: String) throws -> [String: Any] {
        let object = try self.responseObject(response)
        return try XCTUnwrap(object["result"] as? [String: Any])
    }

    private func responseObject(_ response: String) throws -> [String: Any] {
        let data = Data(response.utf8)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}

final class MockMCPDesktop: Win11MCPDesktopProviding, @unchecked Sendable {
    var lastCapturePath: String?

    private let element = DesktopUIAutomationElementSnapshot(
        index: 0,
        parentIndex: nil,
        depth: 0,
        name: "OK",
        controlTypeName: "Button",
        processIdentifier: 42,
        nativeWindowHandle: 100,
        bounds: DesktopRect(x: 10, y: 20, width: 80, height: 30),
        isEnabled: true,
        supportedPatterns: [.invoke],
        availableActions: [.invoke])

    func platformInfo() -> Win11PlatformInfo {
        Win11PlatformInfo(
            name: "Windows",
            minimumSystemVersion: "Windows 11",
            nativeBackend: "Mock",
            capabilities: [.enumerateApplications, .enumerateWindows, .captureFrontmostBMP, .inspectUIAutomation])
    }

    func listDisplays() throws -> [Win11Display] {
        [
            Win11Display(
                id: 1,
                index: 0,
                bounds: DesktopRect(x: 0, y: 0, width: 1920, height: 1080),
                workArea: DesktopRect(x: 0, y: 0, width: 1920, height: 1040),
                isPrimary: true),
        ]
    }

    func listWindows(includeInvisible _: Bool) throws -> [Win11Window] {
        [
            Win11Window(
                windowIdentifier: 100,
                processIdentifier: 42,
                title: "Untitled - Notepad",
                bounds: DesktopRect(x: 0, y: 0, width: 800, height: 600),
                isVisible: true,
                isMinimized: false,
                isForeground: true,
                executableName: "notepad.exe"),
        ]
    }

    func listApplications() throws -> [Win11Application] {
        [
            Win11Application(
                processIdentifier: 42,
                executableName: "notepad.exe",
                executablePath: "C:\\Windows\\System32\\notepad.exe",
                isActive: true,
                visibleWindowCount: 1),
        ]
    }

    func captureScreen(displayIndex _: Int?, outputPath: String) throws -> Win11CaptureResult {
        self.capture(outputPath: outputPath)
    }

    func captureArea(_: Win11Rect, outputPath: String) throws -> Win11CaptureResult {
        self.capture(outputPath: outputPath)
    }

    func captureWindow(windowIdentifier _: UInt64, outputPath: String) throws -> Win11CaptureResult {
        self.capture(outputPath: outputPath)
    }

    func captureFrontmost(outputPath: String) throws -> Win11CaptureResult {
        self.capture(outputPath: outputPath)
    }

    func cursorPosition() throws -> DesktopPoint {
        DesktopPoint(x: 10, y: 20)
    }

    func moveCursor(to point: DesktopPoint) throws -> DesktopPoint {
        point
    }

    func click(at point: DesktopPoint, button: DesktopMouseButton, clickCount: Int) throws -> DesktopClickResult {
        DesktopClickResult(point: point, button: button, clickCount: clickCount)
    }

    func scroll(
        at point: DesktopPoint,
        direction: DesktopScrollDirection,
        amount: Int) throws -> DesktopScrollResult
    {
        DesktopScrollResult(point: point, direction: direction, amount: amount)
    }

    func drag(
        from startPoint: DesktopPoint,
        to endPoint: DesktopPoint,
        button: DesktopMouseButton,
        steps: Int) throws -> DesktopDragResult
    {
        DesktopDragResult(startPoint: startPoint, endPoint: endPoint, button: button, steps: steps)
    }

    func hotkey(keys: [String], holdDurationMilliseconds: Int) throws -> DesktopHotkeyResult {
        DesktopHotkeyResult(keys: keys, holdDurationMilliseconds: holdDurationMilliseconds)
    }

    func typeText(_ text: String, delayMilliseconds: Int) throws -> DesktopTypingResult {
        DesktopTypingResult(text: text, characterCount: text.count, delayMilliseconds: delayMilliseconds)
    }

    func uiAutomationStatus() throws -> DesktopUIAutomationStatus {
        DesktopUIAutomationStatus(nativeBackend: "Mock UIA", isAvailable: true, rootElementAvailable: true)
    }

    func uiAutomationSnapshot(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int) throws -> DesktopUIAutomationSnapshot
    {
        DesktopUIAutomationSnapshot(
            nativeBackend: "Mock UIA",
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementCount: 1,
            didTruncate: false,
            elements: [self.element])
    }

    func invokeUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    {
        self.action(.invoke, scope: scope, maxDepth: maxDepth, maxElements: maxElements, elementIndex: elementIndex)
    }

    func focusUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    {
        self.action(.focus, scope: scope, maxDepth: maxDepth, maxElements: maxElements, elementIndex: elementIndex)
    }

    func performUIAutomationElementLegacyDefaultAction(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    {
        self.action(
            .performLegacyDefaultAction,
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex)
    }

    func setUIAutomationElementValue(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        value: String) throws -> DesktopUIAutomationActionResult
    {
        DesktopUIAutomationActionResult(
            nativeBackend: "Mock UIA",
            action: .setValue,
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex,
            element: self.element,
            value: value,
            valueWasVerified: true)
    }

    func toggleUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    {
        self.action(.toggle, scope: scope, maxDepth: maxDepth, maxElements: maxElements, elementIndex: elementIndex)
    }

    func expandUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    {
        self.action(.expand, scope: scope, maxDepth: maxDepth, maxElements: maxElements, elementIndex: elementIndex)
    }

    func collapseUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    {
        self.action(.collapse, scope: scope, maxDepth: maxDepth, maxElements: maxElements, elementIndex: elementIndex)
    }

    func selectUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    {
        self.action(.select, scope: scope, maxDepth: maxDepth, maxElements: maxElements, elementIndex: elementIndex)
    }

    private func capture(outputPath: String) -> Win11CaptureResult {
        self.lastCapturePath = outputPath
        return Win11CaptureResult(
            path: outputPath,
            bounds: DesktopRect(x: 0, y: 0, width: 800, height: 600),
            format: .bmp,
            byteCount: 1024,
            captureMethod: .gdiRegion)
    }

    private func action(
        _ action: DesktopUIAutomationAction,
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) -> DesktopUIAutomationActionResult
    {
        DesktopUIAutomationActionResult(
            nativeBackend: "Mock UIA",
            action: action,
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex,
            element: self.element)
    }
}
