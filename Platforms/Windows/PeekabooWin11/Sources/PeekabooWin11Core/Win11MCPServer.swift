import Foundation
import PeekabooDesktop

public protocol Win11MCPDesktopProviding: Sendable {
    func platformInfo() -> Win11PlatformInfo
    func listDisplays() throws -> [Win11Display]
    func listWindows(includeInvisible: Bool) throws -> [Win11Window]
    func listApplications() throws -> [Win11Application]
    func captureScreen(displayIndex: Int?, outputPath: String) throws -> Win11CaptureResult
    func captureArea(_ rect: Win11Rect, outputPath: String) throws -> Win11CaptureResult
    func captureWindow(windowIdentifier: UInt64, outputPath: String) throws -> Win11CaptureResult
    func captureFrontmost(outputPath: String) throws -> Win11CaptureResult
    func cursorPosition() throws -> DesktopPoint
    func moveCursor(to point: DesktopPoint) throws -> DesktopPoint
    func click(at point: DesktopPoint, button: DesktopMouseButton, clickCount: Int) throws -> DesktopClickResult
    func scroll(at point: DesktopPoint, direction: DesktopScrollDirection, amount: Int) throws -> DesktopScrollResult
    func drag(
        from startPoint: DesktopPoint,
        to endPoint: DesktopPoint,
        button: DesktopMouseButton,
        steps: Int) throws -> DesktopDragResult
    func hotkey(keys: [String], holdDurationMilliseconds: Int) throws -> DesktopHotkeyResult
    func typeText(_ text: String, delayMilliseconds: Int) throws -> DesktopTypingResult
    func uiAutomationStatus() throws -> DesktopUIAutomationStatus
    func uiAutomationSnapshot(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int) throws -> DesktopUIAutomationSnapshot
    func invokeUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    func focusUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    func performUIAutomationElementLegacyDefaultAction(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    func setUIAutomationElementValue(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        value: String) throws -> DesktopUIAutomationActionResult
    func toggleUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    func expandUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    func collapseUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    func selectUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
}

public struct Win11MCPDesktopAdapterBridge: Win11MCPDesktopProviding {
    private let adapter: any Win11DesktopAdapter

    public init(adapter: any Win11DesktopAdapter) {
        self.adapter = adapter
    }

    public func platformInfo() -> Win11PlatformInfo {
        self.adapter.platformInfo()
    }

    public func listDisplays() throws -> [Win11Display] {
        try self.adapter.listDisplays()
    }

    public func listWindows(includeInvisible: Bool) throws -> [Win11Window] {
        try self.adapter.listWindows(includeInvisible: includeInvisible)
    }

    public func listApplications() throws -> [Win11Application] {
        try self.adapter.listApplications()
    }

    public func captureScreen(displayIndex: Int?, outputPath: String) throws -> Win11CaptureResult {
        try self.adapter.captureScreen(displayIndex: displayIndex, outputPath: outputPath)
    }

    public func captureArea(_ rect: Win11Rect, outputPath: String) throws -> Win11CaptureResult {
        try self.adapter.captureArea(rect, outputPath: outputPath)
    }

    public func captureWindow(windowIdentifier: UInt64, outputPath: String) throws -> Win11CaptureResult {
        try self.adapter.captureWindow(windowIdentifier: windowIdentifier, outputPath: outputPath)
    }

    public func captureFrontmost(outputPath: String) throws -> Win11CaptureResult {
        try self.adapter.captureFrontmost(outputPath: outputPath)
    }

    public func cursorPosition() throws -> DesktopPoint {
        try self.adapter.cursorPosition()
    }

    public func moveCursor(to point: DesktopPoint) throws -> DesktopPoint {
        try self.adapter.moveCursor(to: point)
    }

    public func click(at point: DesktopPoint, button: DesktopMouseButton, clickCount: Int) throws -> DesktopClickResult {
        try self.adapter.click(at: point, button: button, clickCount: clickCount)
    }

    public func scroll(
        at point: DesktopPoint,
        direction: DesktopScrollDirection,
        amount: Int) throws -> DesktopScrollResult
    {
        try self.adapter.scroll(at: point, direction: direction, amount: amount)
    }

    public func drag(
        from startPoint: DesktopPoint,
        to endPoint: DesktopPoint,
        button: DesktopMouseButton,
        steps: Int) throws -> DesktopDragResult
    {
        try self.adapter.drag(from: startPoint, to: endPoint, button: button, steps: steps)
    }

    public func hotkey(keys: [String], holdDurationMilliseconds: Int) throws -> DesktopHotkeyResult {
        try self.adapter.hotkey(keys: keys, holdDurationMilliseconds: holdDurationMilliseconds)
    }

    public func typeText(_ text: String, delayMilliseconds: Int) throws -> DesktopTypingResult {
        try self.adapter.typeText(text, delayMilliseconds: delayMilliseconds)
    }

    public func uiAutomationStatus() throws -> DesktopUIAutomationStatus {
        try self.adapter.uiAutomationStatus()
    }

    public func uiAutomationSnapshot(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int) throws -> DesktopUIAutomationSnapshot
    {
        try self.adapter.uiAutomationSnapshot(scope: scope, maxDepth: maxDepth, maxElements: maxElements)
    }

    public func invokeUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    {
        try self.adapter.invokeUIAutomationElement(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex)
    }

    public func focusUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    {
        try self.adapter.focusUIAutomationElement(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex)
    }

    public func performUIAutomationElementLegacyDefaultAction(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    {
        try self.adapter.performUIAutomationElementLegacyDefaultAction(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex)
    }

    public func setUIAutomationElementValue(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        value: String) throws -> DesktopUIAutomationActionResult
    {
        try self.adapter.setUIAutomationElementValue(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex,
            value: value)
    }

    public func toggleUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    {
        try self.adapter.toggleUIAutomationElement(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex)
    }

    public func expandUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    {
        try self.adapter.expandUIAutomationElement(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex)
    }

    public func collapseUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    {
        try self.adapter.collapseUIAutomationElement(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex)
    }

    public func selectUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    {
        try self.adapter.selectUIAutomationElement(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex)
    }
}

public final class Win11MCPServer {
    private let desktop: any Win11MCPDesktopProviding
    private var snapshots: [String: Win11MCPSnapshot] = [:]
    private var snapshotOrder: [String] = []

    public init(desktop: any Win11MCPDesktopProviding) {
        self.desktop = desktop
    }

    public func handleLine(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        do {
            let data = Data(trimmed.utf8)
            let request = try JSONDecoder().decode(Win11MCPJSONRPCRequest.self, from: data)
            guard request.jsonrpc == nil || request.jsonrpc == "2.0" else {
                return try self.errorIfNeeded(
                    id: request.id,
                    hasID: request.hasID,
                    code: -32600,
                    message: "Invalid JSON-RPC version")
            }
            return try self.handle(request)
        } catch {
            return try? Win11MCPJSONRPC.error(
                id: .null,
                code: -32700,
                message: "Parse error: \(error.localizedDescription)")
        }
    }

    private func handle(_ request: Win11MCPJSONRPCRequest) throws -> String? {
        do {
            let result = try self.result(for: request)
            guard request.hasID else { return nil }
            return try Win11MCPJSONRPC.result(id: request.id ?? .null, result)
        } catch let error as Win11MCPProtocolError {
            return try self.errorIfNeeded(
                id: request.id,
                hasID: request.hasID,
                code: error.code,
                message: error.message)
        } catch {
            return try self.errorIfNeeded(
                id: request.id,
                hasID: request.hasID,
                code: -32603,
                message: error.localizedDescription)
        }
    }

    private func result(for request: Win11MCPJSONRPCRequest) throws -> Win11MCPJSONValue {
        switch request.method {
        case "initialize":
            return self.initializeResult()
        case "notifications/initialized":
            return .object([:])
        case "ping":
            return .object([:])
        case "tools/list":
            return .object([
                "tools": .array(Self.toolDefinitions.map(\.jsonValue)),
            ])
        case "tools/call":
            return try self.callTool(params: request.params)
        case "resources/list":
            return .object([
                "resources": .array([]),
            ])
        case "prompts/list":
            return .object([
                "prompts": .array([]),
            ])
        default:
            throw Win11MCPProtocolError(code: -32601, message: "Method not found: \(request.method)")
        }
    }

    private func errorIfNeeded(
        id: Win11MCPJSONValue?,
        hasID: Bool,
        code: Int,
        message: String) throws -> String?
    {
        guard hasID else { return nil }
        return try Win11MCPJSONRPC.error(id: id ?? .null, code: code, message: message)
    }

    private func initializeResult() -> Win11MCPJSONValue {
        .object([
            "protocolVersion": .string("2025-06-18"),
            "capabilities": .object([
                "tools": .object([
                    "listChanged": .bool(false),
                ]),
                "resources": .object([:]),
                "prompts": .object([:]),
            ]),
            "serverInfo": .object([
                "name": .string("peekaboo-win11"),
                "title": .string("Peekaboo Windows 11 MCP"),
                "version": .string("0.1.0"),
            ]),
            "instructions": .string(
                "Windows MCP subset backed by PeekabooWin11Core. macOS-only menu, dock, dialog, space, " +
                    "browser, clipboard, and AI-provider tools are not exposed by this Windows bridge."),
        ])
    }

    private func callTool(params: Win11MCPJSONValue?) throws -> Win11MCPJSONValue {
        guard let object = params?.objectValue else {
            throw Win11MCPProtocolError(code: -32602, message: "tools/call params must be an object")
        }
        guard let name = object["name"]?.stringValue, !name.isEmpty else {
            throw Win11MCPProtocolError(code: -32602, message: "tools/call requires a tool name")
        }

        guard Self.toolDefinitions.contains(where: { $0.name == name }) else {
            throw Win11MCPProtocolError(code: -32602, message: "Unknown tool: \(name)")
        }

        let arguments = object["arguments"]?.objectValue ?? [:]
        do {
            switch name {
            case "list":
                return try self.executeList(arguments)
            case "image":
                return try self.executeImage(arguments)
            case "see", "observe":
                return try self.executeSee(arguments, toolName: name)
            case "snapshot":
                return try self.executeSnapshot(arguments)
            case "move":
                return try self.executeMove(arguments)
            case "click":
                return try self.executeClick(arguments)
            case "scroll":
                return try self.executeScroll(arguments)
            case "drag":
                return try self.executeDrag(arguments)
            case "hotkey":
                return try self.executeHotkey(arguments)
            case "type":
                return try self.executeType(arguments)
            case "uia":
                return try self.executeUIAutomation(arguments)
            case "perform_action":
                return try self.executePerformAction(arguments)
            case "set_value":
                return try self.executeSetValue(arguments)
            default:
                throw Win11MCPToolError("Tool is registered but has no executor: \(name)")
            }
        } catch let error as Win11MCPToolError {
            return self.toolResult(message: error.message, structuredContent: .object([:]), isError: true)
        } catch {
            return self.toolResult(
                message: error.localizedDescription,
                structuredContent: .object([:]),
                isError: true)
        }
    }

    private func executeList(_ arguments: [String: Win11MCPJSONValue]) throws -> Win11MCPJSONValue {
        let itemType = arguments["item_type"]?.stringValue ??
            (arguments["app"]?.stringValue == nil ? "running_applications" : "application_windows")

        switch itemType {
        case "running_applications", "apps", "applications":
            let applications = try self.desktop.listApplications()
            return try self.toolResult(
                message: "Found \(applications.count) running application\(applications.count == 1 ? "" : "s").",
                encodableContent: Win11MCPApplicationsResult(
                    platform: self.desktop.platformInfo().name,
                    applications: applications))

        case "application_windows", "windows":
            let includeInvisible = arguments["include_invisible"]?.boolValue ?? false
            let app = arguments["app"]?.stringValue
            let windows = try self.filteredWindows(app: app, includeInvisible: includeInvisible)
            return try self.toolResult(
                message: "Found \(windows.count) window\(windows.count == 1 ? "" : "s").",
                encodableContent: Win11MCPWindowsResult(
                    platform: self.desktop.platformInfo().name,
                    app: app,
                    windows: windows))

        case "displays", "screens":
            let displays = try self.desktop.listDisplays()
            return try self.toolResult(
                message: "Found \(displays.count) display\(displays.count == 1 ? "" : "s").",
                encodableContent: Win11MCPDisplaysResult(
                    platform: self.desktop.platformInfo().name,
                    displays: displays))

        case "server_status":
            let info = self.desktop.platformInfo()
            let status = try? self.desktop.uiAutomationStatus()
            return try self.toolResult(
                message: "Peekaboo Windows MCP server is available.",
                encodableContent: Win11MCPServerStatus(
                    platform: info,
                    uiAutomation: status,
                    unsupportedMacOSTools: Self.unsupportedMacOSTools))

        default:
            throw Win11MCPToolError(
                "Unsupported item_type '\(itemType)'. Use running_applications, application_windows, displays, or server_status.")
        }
    }

    private func executeImage(_ arguments: [String: Win11MCPJSONValue]) throws -> Win11MCPJSONValue {
        let target = arguments["app_target"]?.stringValue ?? arguments["target"]?.stringValue
        let path = try self.outputPath(from: arguments, prefix: "peekaboo-win11-image")
        let capture = try self.capture(target: target, arguments: arguments, outputPath: path)
        return try self.toolResult(
            message: "Captured Windows desktop image to \(capture.path).",
            encodableContent: Win11MCPImageResult(target: target ?? "screen", capture: capture))
    }

    private func executeSee(
        _ arguments: [String: Win11MCPJSONValue],
        toolName: String) throws -> Win11MCPJSONValue
    {
        let target = arguments["app_target"]?.stringValue ?? arguments["target"]?.stringValue
        let path = try self.outputPath(from: arguments, prefix: "peekaboo-win11-see")
        let capture = try self.capture(target: target, arguments: arguments, outputPath: path)
        let maxDepth = try self.boundedInt(arguments["max_depth"], defaultValue: 2, range: 0...8, label: "max_depth")
        let maxElements = try self.boundedInt(
            arguments["max_elements"],
            defaultValue: 64,
            range: 1...512,
            label: "max_elements")
        let scope = try self.scope(from: arguments["scope"]?.stringValue)
        let automation = try self.desktop.uiAutomationSnapshot(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements)
        let snapshotID = arguments["snapshot"]?.stringValue ?? arguments["snapshot_id"]?.stringValue ?? UUID().uuidString
        let snapshot = Win11MCPSnapshot(
            id: snapshotID,
            tool: toolName,
            target: target ?? "screen",
            capture: capture,
            automation: automation)
        self.storeSnapshot(snapshot)
        return try self.toolResult(
            message: "Captured Windows UI snapshot \(snapshotID) with \(automation.elementCount) UIA element(s).",
            encodableContent: snapshot)
    }

    private func executeSnapshot(_ arguments: [String: Win11MCPJSONValue]) throws -> Win11MCPJSONValue {
        let action = arguments["action"]?.stringValue ?? "get"
        switch action {
        case "list":
            let summaries = self.snapshotOrder.compactMap { self.snapshots[$0]?.summary }
            return try self.toolResult(
                message: "Stored \(summaries.count) Windows MCP snapshot\(summaries.count == 1 ? "" : "s").",
                encodableContent: ["snapshots": summaries])
        case "get":
            let id = arguments["snapshot"]?.stringValue ?? arguments["snapshot_id"]?.stringValue ?? self.snapshotOrder.last
            guard let id, let snapshot = self.snapshots[id] else {
                throw Win11MCPToolError("Snapshot not found.")
            }
            return try self.toolResult(
                message: "Loaded Windows MCP snapshot \(id).",
                encodableContent: snapshot)
        case "clear":
            self.snapshots.removeAll()
            self.snapshotOrder.removeAll()
            return self.toolResult(
                message: "Cleared Windows MCP snapshots.",
                structuredContent: .object(["cleared": .bool(true)]))
        default:
            throw Win11MCPToolError("Unsupported snapshot action '\(action)'. Use get, list, or clear.")
        }
    }

    private func executeMove(_ arguments: [String: Win11MCPJSONValue]) throws -> Win11MCPJSONValue {
        let point = try self.point(from: arguments, primaryKey: "to", fallbackKey: "point")
        let result = try self.desktop.moveCursor(to: point)
        return try self.toolResult(message: "Moved cursor to \(result.x),\(result.y).", encodableContent: result)
    }

    private func executeClick(_ arguments: [String: Win11MCPJSONValue]) throws -> Win11MCPJSONValue {
        let point = try self.point(from: arguments, primaryKey: "at", fallbackKey: "point")
        let button = try self.mouseButton(from: arguments["button"]?.stringValue)
        let count = try self.boundedInt(
            arguments["click_count"] ?? arguments["count"],
            defaultValue: 1,
            range: 1...10,
            label: "click_count")
        let result = try self.desktop.click(at: point, button: button, clickCount: count)
        return try self.toolResult(message: "Clicked \(button.rawValue) at \(point.x),\(point.y).", encodableContent: result)
    }

    private func executeScroll(_ arguments: [String: Win11MCPJSONValue]) throws -> Win11MCPJSONValue {
        let point = try self.point(from: arguments, primaryKey: "at", fallbackKey: "point")
        let directionValue = arguments["direction"]?.stringValue ?? "down"
        guard let direction = DesktopScrollDirection(rawValue: directionValue.lowercased()) else {
            throw Win11MCPToolError("direction must be up, down, left, or right.")
        }
        let amount = try self.boundedInt(arguments["amount"], defaultValue: 1, range: 1...100, label: "amount")
        let result = try self.desktop.scroll(at: point, direction: direction, amount: amount)
        return try self.toolResult(message: "Scrolled \(direction.rawValue) at \(point.x),\(point.y).", encodableContent: result)
    }

    private func executeDrag(_ arguments: [String: Win11MCPJSONValue]) throws -> Win11MCPJSONValue {
        let start = try self.point(from: arguments, primaryKey: "from", fallbackKey: "start")
        let end = try self.point(from: arguments, primaryKey: "to", fallbackKey: "end")
        let button = try self.mouseButton(from: arguments["button"]?.stringValue)
        let steps = try self.boundedInt(arguments["steps"], defaultValue: 10, range: 1...100, label: "steps")
        let result = try self.desktop.drag(from: start, to: end, button: button, steps: steps)
        return try self.toolResult(message: "Dragged from \(start.x),\(start.y) to \(end.x),\(end.y).", encodableContent: result)
    }

    private func executeHotkey(_ arguments: [String: Win11MCPJSONValue]) throws -> Win11MCPJSONValue {
        let keys = try self.keys(from: arguments["keys"] ?? arguments["key"])
        let hold = try self.boundedInt(
            arguments["hold_ms"] ?? arguments["hold_duration_ms"],
            defaultValue: 0,
            range: 0...10_000,
            label: "hold_ms")
        let result = try self.desktop.hotkey(keys: keys, holdDurationMilliseconds: hold)
        return try self.toolResult(message: "Sent hotkey \(keys.joined(separator: \"+\")).", encodableContent: result)
    }

    private func executeType(_ arguments: [String: Win11MCPJSONValue]) throws -> Win11MCPJSONValue {
        guard let text = arguments["text"]?.stringValue ?? arguments["value"]?.stringValue else {
            throw Win11MCPToolError("type requires text.")
        }
        let delay = try self.boundedInt(
            arguments["delay_ms"] ?? arguments["delay"],
            defaultValue: 0,
            range: 0...10_000,
            label: "delay_ms")
        let result = try self.desktop.typeText(text, delayMilliseconds: delay)
        return try self.toolResult(message: "Typed \(result.characterCount) character(s).", encodableContent: result)
    }

    private func executePerformAction(_ arguments: [String: Win11MCPJSONValue]) throws -> Win11MCPJSONValue {
        var merged = arguments
        merged["action"] = arguments["action"] ?? .string("invoke")
        return try self.executeUIAutomation(merged)
    }

    private func executeSetValue(_ arguments: [String: Win11MCPJSONValue]) throws -> Win11MCPJSONValue {
        var merged = arguments
        merged["action"] = .string("set_value")
        return try self.executeUIAutomation(merged)
    }

    private func executeUIAutomation(_ arguments: [String: Win11MCPJSONValue]) throws -> Win11MCPJSONValue {
        let action = arguments["action"]?.stringValue ?? "snapshot"
        let maxDepth = try self.boundedInt(arguments["max_depth"], defaultValue: 2, range: 0...8, label: "max_depth")
        let maxElements = try self.boundedInt(
            arguments["max_elements"],
            defaultValue: 64,
            range: 1...512,
            label: "max_elements")
        let scope = try self.scope(from: arguments["scope"]?.stringValue)

        switch action {
        case "status":
            let status = try self.desktop.uiAutomationStatus()
            return try self.toolResult(message: "Windows UI Automation status loaded.", encodableContent: status)
        case "snapshot", "inspect":
            let snapshot = try self.desktop.uiAutomationSnapshot(
                scope: scope,
                maxDepth: maxDepth,
                maxElements: maxElements)
            return try self.toolResult(
                message: "Loaded \(snapshot.elementCount) Windows UIA element(s).",
                encodableContent: snapshot)
        case "invoke":
            return try self.uiActionResult(
                self.desktop.invokeUIAutomationElement(
                    scope: scope,
                    maxDepth: maxDepth,
                    maxElements: maxElements,
                    elementIndex: try self.elementIndex(arguments)))
        case "focus":
            return try self.uiActionResult(
                self.desktop.focusUIAutomationElement(
                    scope: scope,
                    maxDepth: maxDepth,
                    maxElements: maxElements,
                    elementIndex: try self.elementIndex(arguments)))
        case "legacy_default_action", "perform_legacy_default_action", "performLegacyDefaultAction":
            return try self.uiActionResult(
                self.desktop.performUIAutomationElementLegacyDefaultAction(
                    scope: scope,
                    maxDepth: maxDepth,
                    maxElements: maxElements,
                    elementIndex: try self.elementIndex(arguments)))
        case "set_value", "setValue":
            guard let value = arguments["value"]?.stringValue else {
                throw Win11MCPToolError("set_value requires value.")
            }
            return try self.uiActionResult(
                self.desktop.setUIAutomationElementValue(
                    scope: scope,
                    maxDepth: maxDepth,
                    maxElements: maxElements,
                    elementIndex: try self.elementIndex(arguments),
                    value: value))
        case "toggle":
            return try self.uiActionResult(
                self.desktop.toggleUIAutomationElement(
                    scope: scope,
                    maxDepth: maxDepth,
                    maxElements: maxElements,
                    elementIndex: try self.elementIndex(arguments)))
        case "expand":
            return try self.uiActionResult(
                self.desktop.expandUIAutomationElement(
                    scope: scope,
                    maxDepth: maxDepth,
                    maxElements: maxElements,
                    elementIndex: try self.elementIndex(arguments)))
        case "collapse":
            return try self.uiActionResult(
                self.desktop.collapseUIAutomationElement(
                    scope: scope,
                    maxDepth: maxDepth,
                    maxElements: maxElements,
                    elementIndex: try self.elementIndex(arguments)))
        case "select":
            return try self.uiActionResult(
                self.desktop.selectUIAutomationElement(
                    scope: scope,
                    maxDepth: maxDepth,
                    maxElements: maxElements,
                    elementIndex: try self.elementIndex(arguments)))
        default:
            throw Win11MCPToolError(
                "Unsupported UIA action '\(action)'. Use status, snapshot, invoke, focus, set_value, toggle, expand, collapse, or select.")
        }
    }

    private func uiActionResult(_ result: DesktopUIAutomationActionResult) throws -> Win11MCPJSONValue {
        try self.toolResult(
            message: "Performed Windows UIA action \(result.action.rawValue) on element \(result.elementIndex).",
            encodableContent: result)
    }

    private func capture(
        target: String?,
        arguments: [String: Win11MCPJSONValue],
        outputPath: String) throws -> Win11CaptureResult
    {
        if let rect = try self.rect(from: arguments["rect"]) {
            return try self.desktop.captureArea(rect, outputPath: outputPath)
        }

        guard let target, !target.isEmpty else {
            return try self.desktop.captureScreen(displayIndex: nil, outputPath: outputPath)
        }

        let lower = target.lowercased()
        if lower == "screen" || lower == "all" || lower == "desktop" {
            return try self.desktop.captureScreen(displayIndex: nil, outputPath: outputPath)
        }
        if lower == "frontmost" || lower == "foreground" {
            return try self.desktop.captureFrontmost(outputPath: outputPath)
        }
        if lower.hasPrefix("screen:") || lower.hasPrefix("display:") {
            let value = target.split(separator: ":", maxSplits: 1).last.map(String.init) ?? ""
            guard let displayIndex = Int(value) else {
                throw Win11MCPToolError("Screen target must be screen:<index>.")
            }
            return try self.desktop.captureScreen(displayIndex: displayIndex, outputPath: outputPath)
        }
        if lower.hasPrefix("window:") {
            let value = target.split(separator: ":", maxSplits: 1).last.map(String.init) ?? ""
            guard let windowID = UInt64(value) else {
                throw Win11MCPToolError("Window target must be window:<window-id>.")
            }
            return try self.desktop.captureWindow(windowIdentifier: windowID, outputPath: outputPath)
        }
        if lower.hasPrefix("area:") {
            let value = target.split(separator: ":", maxSplits: 1).last.map(String.init) ?? ""
            return try self.desktop.captureArea(try self.rect(from: value), outputPath: outputPath)
        }

        let windows = try self.filteredWindows(app: target, includeInvisible: false)
        guard let window = windows.first(where: { $0.isForeground }) ?? windows.first else {
            throw Win11MCPToolError("No visible window matched target '\(target)'.")
        }
        return try self.desktop.captureWindow(windowIdentifier: window.windowIdentifier, outputPath: outputPath)
    }

    private func filteredWindows(app: String?, includeInvisible: Bool) throws -> [Win11Window] {
        let windows = try self.desktop.listWindows(includeInvisible: includeInvisible)
        guard let app, !app.isEmpty else {
            return windows
        }
        return windows.filter { self.matches($0, app: app) }
    }

    private func matches(_ window: Win11Window, app: String) -> Bool {
        let lower = app.lowercased()
        if lower.hasPrefix("pid:") {
            let value = lower.dropFirst(4)
            return UInt32(String(value)) == window.processIdentifier
        }
        let executable = window.executableName?.lowercased() ?? ""
        return executable.contains(lower) || window.title.lowercased().contains(lower)
    }

    private func outputPath(
        from arguments: [String: Win11MCPJSONValue],
        prefix: String) throws -> String
    {
        if let path = arguments["path"]?.stringValue, !path.isEmpty {
            return path
        }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("peekaboo-win11-mcp", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString).bmp")
            .path
    }

    private func storeSnapshot(_ snapshot: Win11MCPSnapshot) {
        self.snapshots[snapshot.id] = snapshot
        self.snapshotOrder.removeAll { $0 == snapshot.id }
        self.snapshotOrder.append(snapshot.id)
    }

    private func point(
        from arguments: [String: Win11MCPJSONValue],
        primaryKey: String,
        fallbackKey: String) throws -> DesktopPoint
    {
        if let value = arguments[primaryKey] ?? arguments[fallbackKey] {
            return try self.point(from: value)
        }
        if let x = arguments["x"]?.intValue, let y = arguments["y"]?.intValue {
            return DesktopPoint(x: x, y: y)
        }
        throw Win11MCPToolError("Point required. Use \(primaryKey), \(fallbackKey), or x/y.")
    }

    private func point(from value: Win11MCPJSONValue) throws -> DesktopPoint {
        if let string = value.stringValue {
            let parts = string.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2, let x = Int(parts[0]), let y = Int(parts[1]) else {
                throw Win11MCPToolError("Point string must use x,y.")
            }
            return DesktopPoint(x: x, y: y)
        }
        if let array = value.arrayValue, array.count == 2,
           let x = array[0].intValue,
           let y = array[1].intValue {
            return DesktopPoint(x: x, y: y)
        }
        if let object = value.objectValue, let x = object["x"]?.intValue, let y = object["y"]?.intValue {
            return DesktopPoint(x: x, y: y)
        }
        throw Win11MCPToolError("Point must be an x,y string, [x,y], or {x,y}.")
    }

    private func rect(from value: Win11MCPJSONValue?) throws -> Win11Rect? {
        guard let value else { return nil }
        if let string = value.stringValue {
            return try self.rect(from: string)
        }
        if let array = value.arrayValue, array.count == 4,
           let x = array[0].intValue,
           let y = array[1].intValue,
           let width = array[2].intValue,
           let height = array[3].intValue {
            return Win11Rect(x: x, y: y, width: width, height: height)
        }
        if let object = value.objectValue,
           let x = object["x"]?.intValue,
           let y = object["y"]?.intValue,
           let width = object["width"]?.intValue,
           let height = object["height"]?.intValue {
            return Win11Rect(x: x, y: y, width: width, height: height)
        }
        throw Win11MCPToolError("rect must be x,y,width,height, [x,y,width,height], or {x,y,width,height}.")
    }

    private func rect(from value: String) throws -> Win11Rect {
        let parts = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 4,
              let x = Int(parts[0]),
              let y = Int(parts[1]),
              let width = Int(parts[2]),
              let height = Int(parts[3])
        else {
            throw Win11MCPToolError("Rectangle string must use x,y,width,height.")
        }
        return Win11Rect(x: x, y: y, width: width, height: height)
    }

    private func mouseButton(from value: String?) throws -> DesktopMouseButton {
        guard let value else { return .left }
        guard let button = DesktopMouseButton(rawValue: value.lowercased()) else {
            throw Win11MCPToolError("button must be left, right, or middle.")
        }
        return button
    }

    private func keys(from value: Win11MCPJSONValue?) throws -> [String] {
        if let string = value?.stringValue {
            let keys = string.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard !keys.isEmpty else { throw Win11MCPToolError("keys cannot be empty.") }
            return keys
        }
        if let array = value?.arrayValue {
            let keys = array.compactMap(\.stringValue)
            guard keys.count == array.count, !keys.isEmpty else {
                throw Win11MCPToolError("keys array must contain one or more strings.")
            }
            return keys
        }
        throw Win11MCPToolError("hotkey requires keys as a comma-separated string or string array.")
    }

    private func boundedInt(
        _ value: Win11MCPJSONValue?,
        defaultValue: Int,
        range: ClosedRange<Int>,
        label: String) throws -> Int
    {
        let result = value?.intValue ?? defaultValue
        guard range.contains(result) else {
            throw Win11MCPToolError("\(label) must be between \(range.lowerBound) and \(range.upperBound).")
        }
        return result
    }

    private func scope(from value: String?) throws -> DesktopUIAutomationSnapshotScope {
        guard let value else { return .foreground }
        guard let scope = DesktopUIAutomationSnapshotScope(rawValue: value.lowercased()) else {
            throw Win11MCPToolError("scope must be root, foreground, focused, or cursor.")
        }
        return scope
    }

    private func elementIndex(_ arguments: [String: Win11MCPJSONValue]) throws -> Int {
        guard let index = (arguments["element_index"] ?? arguments["index"] ?? arguments["element"])?.intValue,
              index >= 0
        else {
            throw Win11MCPToolError("UIA action requires non-negative element_index.")
        }
        return index
    }

    private func toolResult<T: Encodable>(
        message: String,
        encodableContent: T,
        isError: Bool = false) throws -> Win11MCPJSONValue
    {
        try self.toolResult(
            message: message,
            structuredContent: .fromEncodable(encodableContent),
            isError: isError)
    }

    private func toolResult(
        message: String,
        structuredContent: Win11MCPJSONValue,
        isError: Bool = false) -> Win11MCPJSONValue
    {
        .object([
            "content": .array([
                .object([
                    "type": .string("text"),
                    "text": .string(message),
                ]),
            ]),
            "structuredContent": structuredContent,
            "isError": .bool(isError),
        ])
    }
}

extension Win11MCPServer {
    static let unsupportedMacOSTools = [
        "agent",
        "analyze",
        "browser",
        "clipboard",
        "dialog",
        "dock",
        "menu",
        "paste",
        "permissions",
        "space",
    ]

    static let toolDefinitions: [Win11MCPToolDefinition] = [
        .init(
            name: "list",
            title: "List Windows Desktop State",
            description: """
            Lists Windows running applications, application windows, displays, or server status.
            Mirrors the original Peekaboo list tool where practical.
            """,
            inputSchema: .schemaObject(
                properties: [
                    "item_type": .schemaString(
                        description: "running_applications, application_windows, displays, or server_status.",
                        enumValues: ["running_applications", "application_windows", "displays", "server_status"]),
                    "app": .schemaString(description: "Optional app name, window title fragment, or PID:<pid>."),
                    "include_invisible": .schemaBoolean(description: "Include invisible windows when listing windows."),
                ])),
        .init(
            name: "image",
            title: "Capture Windows Image",
            description: "Captures a Windows screen, display, area, app window, specific window, or foreground window to BMP.",
            inputSchema: .captureSchema),
        .init(
            name: "see",
            title: "Observe Windows UI",
            description: """
            Captures a Windows screenshot plus a bounded UI Automation snapshot and stores it as a snapshot.
            This is the Windows bridge for Peekaboo's original observe/see workflow.
            """,
            inputSchema: .seeSchema),
        .init(
            name: "observe",
            title: "Observe Windows UI",
            description: "Alias for see, provided for agents that ask for an observe-style tool.",
            inputSchema: .seeSchema),
        .init(
            name: "snapshot",
            title: "Read Windows MCP Snapshots",
            description: "Gets, lists, or clears in-process snapshots produced by see/observe.",
            inputSchema: .schemaObject(
                properties: [
                    "action": .schemaString(description: "get, list, or clear.", enumValues: ["get", "list", "clear"]),
                    "snapshot": .schemaString(description: "Snapshot ID. Defaults to the latest snapshot for get."),
                    "snapshot_id": .schemaString(description: "Snapshot ID alias."),
                ])),
        .init(name: "move", title: "Move Cursor", description: "Moves the Windows cursor.", inputSchema: .pointSchema),
        .init(
            name: "click",
            title: "Click",
            description: "Clicks a Windows screen coordinate.",
            inputSchema: .schemaObject(
                properties: [
                    "point": .pointValueSchema,
                    "at": .pointValueSchema,
                    "x": .schemaNumber(description: "X coordinate."),
                    "y": .schemaNumber(description: "Y coordinate."),
                    "button": .schemaString(description: "left, right, or middle.", enumValues: ["left", "right", "middle"]),
                    "click_count": .schemaNumber(description: "Positive click count."),
                    "count": .schemaNumber(description: "click_count alias."),
                ])),
        .init(
            name: "scroll",
            title: "Scroll",
            description: "Scrolls at a Windows screen coordinate.",
            inputSchema: .schemaObject(
                properties: [
                    "point": .pointValueSchema,
                    "at": .pointValueSchema,
                    "x": .schemaNumber(description: "X coordinate."),
                    "y": .schemaNumber(description: "Y coordinate."),
                    "direction": .schemaString(
                        description: "Scroll direction.",
                        enumValues: ["up", "down", "left", "right"]),
                    "amount": .schemaNumber(description: "Positive wheel amount."),
                ])),
        .init(
            name: "drag",
            title: "Drag",
            description: "Drags between two Windows screen coordinates.",
            inputSchema: .schemaObject(
                properties: [
                    "from": .pointValueSchema,
                    "start": .pointValueSchema,
                    "to": .pointValueSchema,
                    "end": .pointValueSchema,
                    "button": .schemaString(description: "left, right, or middle.", enumValues: ["left", "right", "middle"]),
                    "steps": .schemaNumber(description: "Drag interpolation steps."),
                ],
                required: ["from", "to"])),
        .init(
            name: "hotkey",
            title: "Hotkey",
            description: "Sends a Windows hotkey sequence.",
            inputSchema: .schemaObject(
                properties: [
                    "keys": .schema(
                        type: "array",
                        description: "String array, or pass a comma-separated string.",
                        items: .schemaString(description: "Key name.")),
                    "hold_ms": .schemaNumber(description: "Modifier hold duration in milliseconds."),
                ],
                required: ["keys"])),
        .init(
            name: "type",
            title: "Type Text",
            description: "Types text into the focused Windows control.",
            inputSchema: .schemaObject(
                properties: [
                    "text": .schemaString(description: "Text to type."),
                    "value": .schemaString(description: "text alias."),
                    "delay_ms": .schemaNumber(description: "Delay between characters in milliseconds."),
                ])),
        .init(
            name: "uia",
            title: "Windows UI Automation",
            description: "Inspects or acts on Windows UI Automation elements by bounded snapshot element index.",
            inputSchema: .uiaSchema),
        .init(
            name: "perform_action",
            title: "Perform UI Action",
            description: "Original-style alias for UIA element actions. Defaults to invoke.",
            inputSchema: .uiaSchema),
        .init(
            name: "set_value",
            title: "Set UIA Value",
            description: "Original-style alias for setting a Windows UIA Value-pattern element.",
            inputSchema: .uiaSchema),
    ]
}

struct Win11MCPToolDefinition: Sendable {
    let name: String
    let title: String
    let description: String
    let inputSchema: Win11MCPJSONValue

    var jsonValue: Win11MCPJSONValue {
        .object([
            "name": .string(self.name),
            "title": .string(self.title),
            "description": .string(self.description),
            "inputSchema": self.inputSchema,
        ])
    }
}

struct Win11MCPProtocolError: Error {
    let code: Int
    let message: String
}

struct Win11MCPToolError: Error {
    let message: String

    init(_ message: String) {
        self.message = message
    }
}

struct Win11MCPServerStatus: Encodable {
    let platform: Win11PlatformInfo
    let uiAutomation: Win11UIAutomationStatus?
    let unsupportedMacOSTools: [String]
}

struct Win11MCPApplicationsResult: Encodable {
    let platform: String
    let applications: [Win11Application]
}

struct Win11MCPWindowsResult: Encodable {
    let platform: String
    let app: String?
    let windows: [Win11Window]
}

struct Win11MCPDisplaysResult: Encodable {
    let platform: String
    let displays: [Win11Display]
}

struct Win11MCPImageResult: Encodable {
    let target: String
    let capture: Win11CaptureResult
}

struct Win11MCPSnapshot: Encodable {
    let id: String
    let tool: String
    let target: String
    let capture: Win11CaptureResult
    let automation: Win11UIAutomationSnapshot

    var summary: Win11MCPSnapshotSummary {
        Win11MCPSnapshotSummary(
            id: self.id,
            tool: self.tool,
            target: self.target,
            screenshotPath: self.capture.path,
            elementCount: self.automation.elementCount,
            didTruncate: self.automation.didTruncate)
    }
}

struct Win11MCPSnapshotSummary: Encodable {
    let id: String
    let tool: String
    let target: String
    let screenshotPath: String
    let elementCount: Int
    let didTruncate: Bool
}

private extension Win11MCPJSONValue {
    static func schema(
        type: String,
        description: String? = nil,
        enumValues: [String]? = nil,
        items: Win11MCPJSONValue? = nil) -> Win11MCPJSONValue
    {
        var object: [String: Win11MCPJSONValue] = ["type": .string(type)]
        if let description {
            object["description"] = .string(description)
        }
        if let enumValues {
            object["enum"] = .array(enumValues.map { .string($0) })
        }
        if let items {
            object["items"] = items
        }
        return .object(object)
    }

    static func schemaObject(
        properties: [String: Win11MCPJSONValue],
        required: [String] = []) -> Win11MCPJSONValue
    {
        .object([
            "type": .string("object"),
            "properties": .object(properties),
            "required": .array(required.map { .string($0) }),
        ])
    }

    static func schemaString(description: String, enumValues: [String]? = nil) -> Win11MCPJSONValue {
        self.schema(type: "string", description: description, enumValues: enumValues)
    }

    static func schemaNumber(description: String) -> Win11MCPJSONValue {
        self.schema(type: "number", description: description)
    }

    static func schemaBoolean(description: String) -> Win11MCPJSONValue {
        self.schema(type: "boolean", description: description)
    }

    static var pointValueSchema: Win11MCPJSONValue {
        .object([
            "description": .string("Point as x,y string, [x,y], or {x,y}."),
            "oneOf": .array([
                .schema(type: "string"),
                .schema(type: "array", items: .schema(type: "number")),
                .schemaObject(properties: [
                    "x": .schemaNumber(description: "X coordinate."),
                    "y": .schemaNumber(description: "Y coordinate."),
                ]),
            ]),
        ])
    }

    static var pointSchema: Win11MCPJSONValue {
        .schemaObject(properties: [
            "point": .pointValueSchema,
            "to": .pointValueSchema,
            "x": .schemaNumber(description: "X coordinate."),
            "y": .schemaNumber(description: "Y coordinate."),
        ])
    }

    static var captureSchema: Win11MCPJSONValue {
        .schemaObject(properties: [
            "app_target": .schemaString(
                description: "screen, screen:<index>, frontmost, window:<id>, area:x,y,width,height, app name, or PID:<pid>."),
            "target": .schemaString(description: "app_target alias."),
            "rect": .object([
                "description": .string("Rectangle as x,y,width,height, [x,y,width,height], or {x,y,width,height}."),
            ]),
            "path": .schemaString(description: "Output BMP path. Defaults to a temp path."),
        ])
    }

    static var seeSchema: Win11MCPJSONValue {
        var object = self.captureSchema.objectValue ?? [:]
        var properties = object["properties"]?.objectValue ?? [:]
        properties["snapshot"] = .schemaString(description: "Snapshot ID to create or replace.")
        properties["snapshot_id"] = .schemaString(description: "snapshot alias.")
        properties["scope"] = .schemaString(
            description: "UIA snapshot scope.",
            enumValues: ["root", "foreground", "focused", "cursor"])
        properties["max_depth"] = .schemaNumber(description: "UIA max depth, 0 through 8.")
        properties["max_elements"] = .schemaNumber(description: "UIA max element count, 1 through 512.")
        object["properties"] = .object(properties)
        return .object(object)
    }

    static var uiaSchema: Win11MCPJSONValue {
        .schemaObject(properties: [
            "action": .schemaString(
                description: "status, snapshot, invoke, focus, legacy_default_action, set_value, toggle, expand, collapse, or select.",
                enumValues: [
                    "status",
                    "snapshot",
                    "invoke",
                    "focus",
                    "legacy_default_action",
                    "set_value",
                    "toggle",
                    "expand",
                    "collapse",
                    "select",
                ]),
            "element_index": .schemaNumber(description: "UIA element index from a bounded snapshot."),
            "index": .schemaNumber(description: "element_index alias."),
            "value": .schemaString(description: "Value for set_value."),
            "scope": .schemaString(
                description: "UIA snapshot scope.",
                enumValues: ["root", "foreground", "focused", "cursor"]),
            "max_depth": .schemaNumber(description: "UIA max depth, 0 through 8."),
            "max_elements": .schemaNumber(description: "UIA max element count, 1 through 512."),
        ])
    }
}
