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
        let scroll = try await bridge.scroll(
            at: DesktopPoint(x: 13, y: 14),
            direction: .down,
            amount: 3)
        let drag = try await bridge.drag(
            from: DesktopPoint(x: 15, y: 16),
            to: DesktopPoint(x: 17, y: 18),
            button: .left,
            steps: 5)
        let hotkey = try await bridge.hotkey(
            keys: ["ctrl", "shift", "escape"],
            holdDurationMilliseconds: 25)
        let typing = try await bridge.typeText("Hello", delayMilliseconds: 3)
        let automation = try await bridge.uiAutomationStatus()
        let snapshot = try await bridge.uiAutomationSnapshot(scope: .root, maxDepth: 1, maxElements: 4)
        let invoke = try await bridge.invokeUIAutomationElement(
            scope: .root,
            maxDepth: 1,
            maxElements: 4,
            elementIndex: 0)
        let setValue = try await bridge.setUIAutomationElementValue(
            scope: .root,
            maxDepth: 1,
            maxElements: 4,
            elementIndex: 0,
            value: "Updated value")
        let setRangeValue = try await bridge.setUIAutomationElementRangeValue(
            scope: .root,
            maxDepth: 1,
            maxElements: 4,
            elementIndex: 0,
            value: 42.5)
        let setScrollPercent = try await bridge.setUIAutomationElementScrollPercent(
            scope: .root,
            maxDepth: 1,
            maxElements: 4,
            elementIndex: 0,
            horizontalPercent: nil,
            verticalPercent: 75.0)
        let setWindowState = try await bridge.setUIAutomationElementWindowVisualState(
            scope: .root,
            maxDepth: 1,
            maxElements: 4,
            elementIndex: 0,
            state: .maximized)
        let toggle = try await bridge.toggleUIAutomationElement(
            scope: .root,
            maxDepth: 1,
            maxElements: 4,
            elementIndex: 0)
        let expand = try await bridge.expandUIAutomationElement(
            scope: .root,
            maxDepth: 1,
            maxElements: 4,
            elementIndex: 0)
        let collapse = try await bridge.collapseUIAutomationElement(
            scope: .root,
            maxDepth: 1,
            maxElements: 4,
            elementIndex: 0)
        let select = try await bridge.selectUIAutomationElement(
            scope: .root,
            maxDepth: 1,
            maxElements: 4,
            elementIndex: 0)

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
        XCTAssertEqual(scroll, DesktopScrollResult(
            point: DesktopPoint(x: 13, y: 14),
            direction: .down,
            amount: 3))
        XCTAssertEqual(drag, DesktopDragResult(
            startPoint: DesktopPoint(x: 15, y: 16),
            endPoint: DesktopPoint(x: 17, y: 18),
            button: .left,
            steps: 5))
        XCTAssertEqual(hotkey, DesktopHotkeyResult(
            keys: ["ctrl", "shift", "escape"],
            holdDurationMilliseconds: 25))
        XCTAssertEqual(typing, DesktopTypingResult(
            text: "Hello",
            characterCount: 5,
            delayMilliseconds: 3))
        XCTAssertEqual(automation, DesktopUIAutomationStatus(
            nativeBackend: "StubUIA",
            isAvailable: true,
            rootElementAvailable: true))
        XCTAssertEqual(snapshot.scope, .root)
        XCTAssertEqual(snapshot.elementCount, 1)
        XCTAssertEqual(snapshot.elements.first?.name, "Desktop")
        XCTAssertEqual(snapshot.elements.first?.controlTypeName, "Pane")
        XCTAssertEqual(snapshot.elements.first?.isEnabled, true)
        XCTAssertEqual(snapshot.elements.first?.isOffscreen, false)
        XCTAssertEqual(
            snapshot.elements.first?.supportedPatterns,
            [
                .invoke,
                .value,
                .rangeValue,
                .scroll,
                .expandCollapse,
                .window,
                .selectionItem,
                .text,
                .toggle,
            ])
        XCTAssertEqual(
            snapshot.elements.first?.availableActions,
            [
                .invoke,
                .setValue,
                .setRangeValue,
                .setScrollPercent,
                .setWindowVisualState,
                .toggle,
                .expand,
                .select,
            ])
        XCTAssertEqual(snapshot.elements.first?.value, "Example value")
        XCTAssertEqual(snapshot.elements.first?.isValueReadOnly, false)
        XCTAssertEqual(snapshot.elements.first?.rangeValue, 12.5)
        XCTAssertEqual(snapshot.elements.first?.rangeMinimum, 0.0)
        XCTAssertEqual(snapshot.elements.first?.rangeMaximum, 100.0)
        XCTAssertEqual(snapshot.elements.first?.rangeSmallChange, 0.5)
        XCTAssertEqual(snapshot.elements.first?.rangeLargeChange, 10.0)
        XCTAssertEqual(snapshot.elements.first?.isRangeValueReadOnly, false)
        XCTAssertEqual(snapshot.elements.first?.horizontalScrollPercent, 0.0)
        XCTAssertEqual(snapshot.elements.first?.verticalScrollPercent, 25.0)
        XCTAssertEqual(snapshot.elements.first?.horizontalScrollViewSize, 100.0)
        XCTAssertEqual(snapshot.elements.first?.verticalScrollViewSize, 50.0)
        XCTAssertEqual(snapshot.elements.first?.isHorizontallyScrollable, false)
        XCTAssertEqual(snapshot.elements.first?.isVerticallyScrollable, true)
        XCTAssertEqual(snapshot.elements.first?.toggleState, .off)
        XCTAssertEqual(snapshot.elements.first?.expandCollapseState, .collapsed)
        XCTAssertEqual(snapshot.elements.first?.windowVisualState, .normal)
        XCTAssertEqual(snapshot.elements.first?.windowInteractionState, .readyForUserInteraction)
        XCTAssertEqual(snapshot.elements.first?.canMaximizeWindow, true)
        XCTAssertEqual(snapshot.elements.first?.canMinimizeWindow, true)
        XCTAssertEqual(snapshot.elements.first?.isModalWindow, false)
        XCTAssertEqual(snapshot.elements.first?.isTopmostWindow, false)
        XCTAssertEqual(snapshot.elements.first?.text, "Example text")
        XCTAssertEqual(snapshot.elements.first?.supportedTextSelection, .single)
        XCTAssertEqual(snapshot.elements.first?.isSelected, false)
        XCTAssertEqual(invoke.action, .invoke)
        XCTAssertEqual(invoke.elementIndex, 0)
        XCTAssertEqual(invoke.element.name, "Desktop")
        XCTAssertEqual(setValue.action, .setValue)
        XCTAssertEqual(setValue.elementIndex, 0)
        XCTAssertEqual(setValue.value, "Updated value")
        XCTAssertEqual(setValue.postActionElement?.value, "Updated value")
        XCTAssertEqual(setValue.valueWasVerified, true)
        XCTAssertEqual(setRangeValue.action, .setRangeValue)
        XCTAssertEqual(setRangeValue.elementIndex, 0)
        XCTAssertEqual(setRangeValue.value, "42.5")
        XCTAssertEqual(setRangeValue.postActionElement?.rangeValue, 42.5)
        XCTAssertEqual(setRangeValue.valueWasVerified, true)
        XCTAssertEqual(setScrollPercent.action, .setScrollPercent)
        XCTAssertEqual(setScrollPercent.elementIndex, 0)
        XCTAssertEqual(setScrollPercent.value, "horizontal=noScroll,vertical=75.0")
        XCTAssertEqual(setScrollPercent.postActionElement?.verticalScrollPercent, 75.0)
        XCTAssertEqual(setScrollPercent.valueWasVerified, true)
        XCTAssertEqual(setWindowState.action, .setWindowVisualState)
        XCTAssertEqual(setWindowState.elementIndex, 0)
        XCTAssertEqual(setWindowState.value, "maximized")
        XCTAssertEqual(setWindowState.postActionElement?.windowVisualState, .maximized)
        XCTAssertEqual(setWindowState.valueWasVerified, true)
        XCTAssertEqual(toggle.action, .toggle)
        XCTAssertEqual(toggle.elementIndex, 0)
        XCTAssertEqual(toggle.element.name, "Desktop")
        XCTAssertEqual(toggle.postActionElement?.toggleState, .on)
        XCTAssertEqual(expand.action, .expand)
        XCTAssertEqual(expand.elementIndex, 0)
        XCTAssertEqual(expand.postActionElement?.expandCollapseState, .expanded)
        XCTAssertEqual(collapse.action, .collapse)
        XCTAssertEqual(collapse.elementIndex, 0)
        XCTAssertEqual(collapse.postActionElement?.expandCollapseState, .collapsed)
        XCTAssertEqual(select.action, .select)
        XCTAssertEqual(select.elementIndex, 0)
        XCTAssertEqual(select.postActionElement?.isSelected, true)
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

    func testDesktopCommandRunnerRoutesInputScroll() {
        let result = self.runDesktopCommand([
            "peekaboo-desktop",
            "input",
            "scroll",
            "--point",
            "13,14",
            "--direction",
            "down",
            "--amount",
            "3",
        ])

        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.stderr, "")
        XCTAssertTrue(result.stdout.contains("\"x\" : 13"))
        XCTAssertTrue(result.stdout.contains("\"y\" : 14"))
        XCTAssertTrue(result.stdout.contains("\"direction\" : \"down\""))
        XCTAssertTrue(result.stdout.contains("\"amount\" : 3"))
    }

    func testDesktopCommandRunnerRejectsInvalidInputScrollDirection() {
        let result = self.runDesktopCommand([
            "peekaboo-desktop",
            "input",
            "scroll",
            "--point",
            "13,14",
            "--direction",
            "diagonal",
        ])

        XCTAssertEqual(result.status, 1)
        XCTAssertEqual(result.stdout, "")
        XCTAssertTrue(result.stderr.contains("Scroll direction must be up, down, left, or right"))
    }

    func testDesktopCommandRunnerRoutesInputDrag() {
        let result = self.runDesktopCommand([
            "peekaboo-desktop",
            "input",
            "drag",
            "--from",
            "15,16",
            "--to",
            "17,18",
            "--button",
            "left",
            "--steps",
            "5",
        ])

        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.stderr, "")
        XCTAssertTrue(result.stdout.contains("\"startPoint\""))
        XCTAssertTrue(result.stdout.contains("\"endPoint\""))
        XCTAssertTrue(result.stdout.contains("\"x\" : 15"))
        XCTAssertTrue(result.stdout.contains("\"y\" : 18"))
        XCTAssertTrue(result.stdout.contains("\"button\" : \"left\""))
        XCTAssertTrue(result.stdout.contains("\"steps\" : 5"))
    }

    func testDesktopCommandRunnerRejectsInvalidInputDragSteps() {
        let result = self.runDesktopCommand([
            "peekaboo-desktop",
            "input",
            "drag",
            "--from",
            "15,16",
            "--to",
            "17,18",
            "--steps",
            "0",
        ])

        XCTAssertEqual(result.status, 1)
        XCTAssertEqual(result.stdout, "")
        XCTAssertTrue(result.stderr.contains("Steps must be a positive integer"))
    }

    func testDesktopCommandRunnerRoutesInputHotkey() {
        let result = self.runDesktopCommand([
            "peekaboo-desktop",
            "input",
            "hotkey",
            "--keys",
            "ctrl, shift, escape",
            "--hold-ms",
            "25",
        ])

        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.stderr, "")
        XCTAssertTrue(result.stdout.contains("\"keys\""))
        XCTAssertTrue(result.stdout.contains("\"ctrl\""))
        XCTAssertTrue(result.stdout.contains("\"shift\""))
        XCTAssertTrue(result.stdout.contains("\"escape\""))
        XCTAssertTrue(result.stdout.contains("\"holdDurationMilliseconds\" : 25"))
    }

    func testDesktopCommandRunnerRejectsInvalidInputHotkeyList() {
        let result = self.runDesktopCommand([
            "peekaboo-desktop",
            "input",
            "hotkey",
            "--keys",
            "ctrl,,escape",
        ])

        XCTAssertEqual(result.status, 1)
        XCTAssertEqual(result.stdout, "")
        XCTAssertTrue(result.stderr.contains("Keys must be a comma-separated list"))
    }

    func testDesktopCommandRunnerRoutesInputType() {
        let result = self.runDesktopCommand([
            "peekaboo-desktop",
            "input",
            "type",
            "--text",
            "Hello",
            "--delay-ms",
            "3",
        ])

        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.stderr, "")
        XCTAssertTrue(result.stdout.contains("\"text\" : \"Hello\""))
        XCTAssertTrue(result.stdout.contains("\"characterCount\" : 5"))
        XCTAssertTrue(result.stdout.contains("\"delayMilliseconds\" : 3"))
    }

    func testDesktopCommandRunnerRejectsEmptyInputTypeText() {
        let result = self.runDesktopCommand([
            "peekaboo-desktop",
            "input",
            "type",
            "--text",
            "",
        ])

        XCTAssertEqual(result.status, 1)
        XCTAssertEqual(result.stdout, "")
        XCTAssertTrue(result.stderr.contains("Missing --text <text> for input type"))
    }

    func testDesktopCommandRunnerRoutesAutomationStatus() {
        let result = self.runDesktopCommand(["peekaboo-desktop", "automation", "status"])

        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.stderr, "")
        XCTAssertTrue(result.stdout.contains("\"nativeBackend\" : \"StubUIA\""))
        XCTAssertTrue(result.stdout.contains("\"isAvailable\" : true"))
        XCTAssertTrue(result.stdout.contains("\"rootElementAvailable\" : true"))
    }

    func testDesktopCommandRunnerRoutesAutomationSnapshot() {
        let result = self.runDesktopCommand([
            "peekaboo-desktop",
            "automation",
            "snapshot",
            "--scope",
            "root",
            "--max-depth",
            "1",
            "--max-elements",
            "4",
        ])

        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.stderr, "")
        XCTAssertTrue(result.stdout.contains("\"scope\" : \"root\""))
        XCTAssertTrue(result.stdout.contains("\"elementCount\" : 1"))
        XCTAssertTrue(result.stdout.contains("\"name\" : \"Desktop\""))
        XCTAssertTrue(result.stdout.contains("\"controlTypeName\" : \"Pane\""))
        XCTAssertTrue(result.stdout.contains("\"isEnabled\" : true"))
        XCTAssertTrue(result.stdout.contains("\"isOffscreen\" : false"))
        XCTAssertTrue(result.stdout.contains("\"supportedPatterns\" : ["))
        XCTAssertTrue(result.stdout.contains("\"availableActions\" : ["))
        XCTAssertTrue(result.stdout.contains("\"invoke\""))
        XCTAssertTrue(result.stdout.contains("\"setValue\""))
        XCTAssertTrue(result.stdout.contains("\"setRangeValue\""))
        XCTAssertTrue(result.stdout.contains("\"setScrollPercent\""))
        XCTAssertTrue(result.stdout.contains("\"setWindowVisualState\""))
        XCTAssertTrue(result.stdout.contains("\"toggle\""))
        XCTAssertTrue(result.stdout.contains("\"expand\""))
        XCTAssertTrue(result.stdout.contains("\"select\""))
        XCTAssertTrue(result.stdout.contains("\"value\""))
        XCTAssertTrue(result.stdout.contains("\"value\" : \"Example value\""))
        XCTAssertTrue(result.stdout.contains("\"isValueReadOnly\" : false"))
        XCTAssertTrue(result.stdout.contains("\"rangeValue\" : 12.5"))
        XCTAssertTrue(result.stdout.contains("\"rangeMinimum\" : 0"))
        XCTAssertTrue(result.stdout.contains("\"rangeMaximum\" : 100"))
        XCTAssertTrue(result.stdout.contains("\"isRangeValueReadOnly\" : false"))
        XCTAssertTrue(result.stdout.contains("\"horizontalScrollPercent\" : 0"))
        XCTAssertTrue(result.stdout.contains("\"verticalScrollPercent\" : 25"))
        XCTAssertTrue(result.stdout.contains("\"isVerticallyScrollable\" : true"))
        XCTAssertTrue(result.stdout.contains("\"toggleState\" : \"off\""))
        XCTAssertTrue(result.stdout.contains("\"expandCollapseState\" : \"collapsed\""))
        XCTAssertTrue(result.stdout.contains("\"windowVisualState\" : \"normal\""))
        XCTAssertTrue(result.stdout.contains("\"windowInteractionState\" : \"readyForUserInteraction\""))
        XCTAssertTrue(result.stdout.contains("\"canMaximizeWindow\" : true"))
        XCTAssertTrue(result.stdout.contains("\"canMinimizeWindow\" : true"))
        XCTAssertTrue(result.stdout.contains("\"isModalWindow\" : false"))
        XCTAssertTrue(result.stdout.contains("\"isTopmostWindow\" : false"))
        XCTAssertTrue(result.stdout.contains("\"text\" : \"Example text\""))
        XCTAssertTrue(result.stdout.contains("\"supportedTextSelection\" : \"single\""))
        XCTAssertTrue(result.stdout.contains("\"isSelected\" : false"))
    }

    func testDesktopCommandRunnerRoutesFocusedAutomationSnapshot() {
        let result = self.runDesktopCommand([
            "peekaboo-desktop",
            "automation",
            "snapshot",
            "--scope",
            "focused",
            "--max-depth",
            "0",
            "--max-elements",
            "1",
        ])

        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.stderr, "")
        XCTAssertTrue(result.stdout.contains("\"scope\" : \"focused\""))
        XCTAssertTrue(result.stdout.contains("\"maxDepth\" : 0"))
        XCTAssertTrue(result.stdout.contains("\"maxElements\" : 1"))
    }

    func testDesktopCommandRunnerRoutesCursorAutomationSnapshot() {
        let result = self.runDesktopCommand([
            "peekaboo-desktop",
            "automation",
            "snapshot",
            "--scope",
            "cursor",
            "--max-depth",
            "1",
            "--max-elements",
            "8",
        ])

        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.stderr, "")
        XCTAssertTrue(result.stdout.contains("\"scope\" : \"cursor\""))
        XCTAssertTrue(result.stdout.contains("\"maxDepth\" : 1"))
        XCTAssertTrue(result.stdout.contains("\"maxElements\" : 8"))
    }

    func testDesktopCommandRunnerRoutesAutomationElementLookup() {
        let result = self.runDesktopCommand([
            "peekaboo-desktop",
            "automation",
            "element",
            "--scope",
            "root",
            "--index",
            "0",
            "--max-depth",
            "1",
            "--max-elements",
            "4",
        ])

        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.stderr, "")
        XCTAssertTrue(result.stdout.contains("\"scope\" : \"root\""))
        XCTAssertTrue(result.stdout.contains("\"elementIndex\" : 0"))
        XCTAssertTrue(result.stdout.contains("\"elementCount\" : 1"))
        XCTAssertTrue(result.stdout.contains("\"name\" : \"Desktop\""))
        XCTAssertTrue(result.stdout.contains("\"controlTypeName\" : \"Pane\""))
        XCTAssertTrue(result.stdout.contains("\"availableActions\" : ["))
        XCTAssertTrue(result.stdout.contains("\"value\" : \"Example value\""))
        XCTAssertTrue(result.stdout.contains("\"isValueReadOnly\" : false"))
        XCTAssertTrue(result.stdout.contains("\"rangeValue\" : 12.5"))
        XCTAssertTrue(result.stdout.contains("\"isRangeValueReadOnly\" : false"))
        XCTAssertTrue(result.stdout.contains("\"verticalScrollPercent\" : 25"))
        XCTAssertTrue(result.stdout.contains("\"isVerticallyScrollable\" : true"))
        XCTAssertTrue(result.stdout.contains("\"expandCollapseState\" : \"collapsed\""))
        XCTAssertTrue(result.stdout.contains("\"windowVisualState\" : \"normal\""))
        XCTAssertTrue(result.stdout.contains("\"windowInteractionState\" : \"readyForUserInteraction\""))
        XCTAssertTrue(result.stdout.contains("\"text\" : \"Example text\""))
        XCTAssertTrue(result.stdout.contains("\"supportedTextSelection\" : \"single\""))
        XCTAssertTrue(result.stdout.contains("\"isSelected\" : false"))
    }

    func testDesktopCommandRunnerRejectsMissingAutomationElementIndex() {
        let result = self.runDesktopCommand([
            "peekaboo-desktop",
            "automation",
            "element",
        ])

        XCTAssertEqual(result.status, 1)
        XCTAssertEqual(result.stdout, "")
        XCTAssertTrue(result.stderr.contains("Missing --index <element-index> for automation element"))
    }

    func testDesktopCommandRunnerRejectsInvalidAutomationElementIndex() {
        let result = self.runDesktopCommand([
            "peekaboo-desktop",
            "automation",
            "element",
            "--index",
            "-1",
        ])

        XCTAssertEqual(result.status, 1)
        XCTAssertEqual(result.stdout, "")
        XCTAssertTrue(result.stderr.contains("UI Automation element index must be a non-negative integer"))
    }

    func testDesktopCommandRunnerRejectsMissingAutomationElement() {
        let result = self.runDesktopCommand([
            "peekaboo-desktop",
            "automation",
            "element",
            "--index",
            "3",
        ])

        XCTAssertEqual(result.status, 1)
        XCTAssertEqual(result.stdout, "")
        XCTAssertTrue(result.stderr.contains("UI Automation element index 3 was not found"))
    }

    func testDesktopCommandRunnerRoutesAutomationInvoke() {
        let result = self.runDesktopCommand([
            "peekaboo-desktop",
            "automation",
            "invoke",
            "--scope",
            "root",
            "--index",
            "0",
            "--max-depth",
            "1",
            "--max-elements",
            "4",
        ])

        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.stderr, "")
        XCTAssertTrue(result.stdout.contains("\"action\" : \"invoke\""))
        XCTAssertTrue(result.stdout.contains("\"elementIndex\" : 0"))
        XCTAssertTrue(result.stdout.contains("\"name\" : \"Desktop\""))
    }

    func testDesktopCommandRunnerRejectsMissingAutomationInvokeIndex() {
        let result = self.runDesktopCommand([
            "peekaboo-desktop",
            "automation",
            "invoke",
        ])

        XCTAssertEqual(result.status, 1)
        XCTAssertEqual(result.stdout, "")
        XCTAssertTrue(result.stderr.contains("Missing --index <element-index> for automation invoke"))
    }

    func testDesktopCommandRunnerRoutesAutomationSetValue() {
        let result = self.runDesktopCommand([
            "peekaboo-desktop",
            "automation",
            "set-value",
            "--scope",
            "root",
            "--index",
            "0",
            "--value",
            "Updated value",
            "--max-depth",
            "1",
            "--max-elements",
            "4",
        ])

        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.stderr, "")
        XCTAssertTrue(result.stdout.contains("\"action\" : \"setValue\""))
        XCTAssertTrue(result.stdout.contains("\"elementIndex\" : 0"))
        XCTAssertTrue(result.stdout.contains("\"value\" : \"Updated value\""))
        XCTAssertTrue(result.stdout.contains("\"postActionElement\""))
        XCTAssertTrue(result.stdout.contains("\"valueWasVerified\" : true"))
    }

    func testDesktopCommandRunnerRejectsMissingAutomationSetValueText() {
        let result = self.runDesktopCommand([
            "peekaboo-desktop",
            "automation",
            "set-value",
            "--index",
            "0",
        ])

        XCTAssertEqual(result.status, 1)
        XCTAssertEqual(result.stdout, "")
        XCTAssertTrue(result.stderr.contains("Missing --value <text> for automation set-value"))
    }

    func testDesktopCommandRunnerRoutesAutomationSetRangeValue() {
        let result = self.runDesktopCommand([
            "peekaboo-desktop",
            "automation",
            "set-range-value",
            "--scope",
            "root",
            "--index",
            "0",
            "--value",
            "42.5",
            "--max-depth",
            "1",
            "--max-elements",
            "4",
        ])

        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.stderr, "")
        XCTAssertTrue(result.stdout.contains("\"action\" : \"setRangeValue\""))
        XCTAssertTrue(result.stdout.contains("\"elementIndex\" : 0"))
        XCTAssertTrue(result.stdout.contains("\"value\" : \"42.5\""))
        XCTAssertTrue(result.stdout.contains("\"rangeValue\" : 42.5"))
        XCTAssertTrue(result.stdout.contains("\"valueWasVerified\" : true"))
    }

    func testDesktopCommandRunnerRejectsMissingAutomationSetRangeValueNumber() {
        let result = self.runDesktopCommand([
            "peekaboo-desktop",
            "automation",
            "set-range-value",
            "--index",
            "0",
        ])

        XCTAssertEqual(result.status, 1)
        XCTAssertEqual(result.stdout, "")
        XCTAssertTrue(result.stderr.contains("Missing --value <number> for automation set-range-value"))
    }

    func testDesktopCommandRunnerRoutesAutomationSetScrollPercent() {
        let result = self.runDesktopCommand([
            "peekaboo-desktop",
            "automation",
            "set-scroll-percent",
            "--scope",
            "root",
            "--index",
            "0",
            "--vertical",
            "75",
            "--max-depth",
            "1",
            "--max-elements",
            "4",
        ])

        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.stderr, "")
        XCTAssertTrue(result.stdout.contains("\"action\" : \"setScrollPercent\""))
        XCTAssertTrue(result.stdout.contains("\"elementIndex\" : 0"))
        XCTAssertTrue(result.stdout.contains("\"value\" : \"horizontal=noScroll,vertical=75.0\""))
        XCTAssertTrue(result.stdout.contains("\"verticalScrollPercent\" : 75"))
        XCTAssertTrue(result.stdout.contains("\"valueWasVerified\" : true"))
    }

    func testDesktopCommandRunnerRejectsMissingAutomationSetScrollPercentAxis() {
        let result = self.runDesktopCommand([
            "peekaboo-desktop",
            "automation",
            "set-scroll-percent",
            "--index",
            "0",
        ])

        XCTAssertEqual(result.status, 1)
        XCTAssertEqual(result.stdout, "")
        XCTAssertTrue(result.stderr.contains("Missing --horizontal <percent> or --vertical <percent>"))
    }

    func testDesktopCommandRunnerRejectsInvalidAutomationSetScrollPercent() {
        let result = self.runDesktopCommand([
            "peekaboo-desktop",
            "automation",
            "set-scroll-percent",
            "--index",
            "0",
            "--vertical",
            "101",
        ])

        XCTAssertEqual(result.status, 1)
        XCTAssertEqual(result.stdout, "")
        XCTAssertTrue(result.stderr.contains("UI Automation scroll percent must be a finite number"))
    }

    func testDesktopCommandRunnerRoutesAutomationSetWindowState() {
        let result = self.runDesktopCommand([
            "peekaboo-desktop",
            "automation",
            "set-window-state",
            "--scope",
            "root",
            "--index",
            "0",
            "--state",
            "maximized",
            "--max-depth",
            "1",
            "--max-elements",
            "4",
        ])

        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.stderr, "")
        XCTAssertTrue(result.stdout.contains("\"action\" : \"setWindowVisualState\""))
        XCTAssertTrue(result.stdout.contains("\"elementIndex\" : 0"))
        XCTAssertTrue(result.stdout.contains("\"value\" : \"maximized\""))
        XCTAssertTrue(result.stdout.contains("\"windowVisualState\" : \"maximized\""))
        XCTAssertTrue(result.stdout.contains("\"valueWasVerified\" : true"))
    }

    func testDesktopCommandRunnerRejectsMissingAutomationSetWindowStateValue() {
        let result = self.runDesktopCommand([
            "peekaboo-desktop",
            "automation",
            "set-window-state",
            "--index",
            "0",
        ])

        XCTAssertEqual(result.status, 1)
        XCTAssertEqual(result.stdout, "")
        XCTAssertTrue(result.stderr.contains("Missing --state <normal|maximized|minimized>"))
    }

    func testDesktopCommandRunnerRejectsInvalidAutomationSetWindowState() {
        let result = self.runDesktopCommand([
            "peekaboo-desktop",
            "automation",
            "set-window-state",
            "--index",
            "0",
            "--state",
            "hidden",
        ])

        XCTAssertEqual(result.status, 1)
        XCTAssertEqual(result.stdout, "")
        XCTAssertTrue(result.stderr.contains("UI Automation window state must be normal"))
    }

    func testDesktopCommandRunnerRoutesAutomationToggle() {
        let result = self.runDesktopCommand([
            "peekaboo-desktop",
            "automation",
            "toggle",
            "--scope",
            "root",
            "--index",
            "0",
            "--max-depth",
            "1",
            "--max-elements",
            "4",
        ])

        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.stderr, "")
        XCTAssertTrue(result.stdout.contains("\"action\" : \"toggle\""))
        XCTAssertTrue(result.stdout.contains("\"elementIndex\" : 0"))
        XCTAssertTrue(result.stdout.contains("\"postActionElement\""))
    }

    func testDesktopCommandRunnerRoutesAutomationExpand() {
        let result = self.runDesktopCommand([
            "peekaboo-desktop",
            "automation",
            "expand",
            "--scope",
            "root",
            "--index",
            "0",
            "--max-depth",
            "1",
            "--max-elements",
            "4",
        ])

        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.stderr, "")
        XCTAssertTrue(result.stdout.contains("\"action\" : \"expand\""))
        XCTAssertTrue(result.stdout.contains("\"elementIndex\" : 0"))
        XCTAssertTrue(result.stdout.contains("\"expandCollapseState\" : \"expanded\""))
    }

    func testDesktopCommandRunnerRoutesAutomationCollapse() {
        let result = self.runDesktopCommand([
            "peekaboo-desktop",
            "automation",
            "collapse",
            "--scope",
            "root",
            "--index",
            "0",
            "--max-depth",
            "1",
            "--max-elements",
            "4",
        ])

        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.stderr, "")
        XCTAssertTrue(result.stdout.contains("\"action\" : \"collapse\""))
        XCTAssertTrue(result.stdout.contains("\"elementIndex\" : 0"))
        XCTAssertTrue(result.stdout.contains("\"expandCollapseState\" : \"collapsed\""))
    }

    func testDesktopCommandRunnerRoutesAutomationSelect() {
        let result = self.runDesktopCommand([
            "peekaboo-desktop",
            "automation",
            "select",
            "--scope",
            "root",
            "--index",
            "0",
            "--max-depth",
            "1",
            "--max-elements",
            "4",
        ])

        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.stderr, "")
        XCTAssertTrue(result.stdout.contains("\"action\" : \"select\""))
        XCTAssertTrue(result.stdout.contains("\"elementIndex\" : 0"))
        XCTAssertTrue(result.stdout.contains("\"isSelected\" : true"))
    }

    func testDesktopCommandRunnerRejectsMissingAutomationToggleIndex() {
        let result = self.runDesktopCommand([
            "peekaboo-desktop",
            "automation",
            "toggle",
        ])

        XCTAssertEqual(result.status, 1)
        XCTAssertEqual(result.stdout, "")
        XCTAssertTrue(result.stderr.contains("Missing --index <element-index> for automation toggle"))
    }

    func testDesktopCommandRunnerRejectsMissingAutomationExpandIndex() {
        let result = self.runDesktopCommand([
            "peekaboo-desktop",
            "automation",
            "expand",
        ])

        XCTAssertEqual(result.status, 1)
        XCTAssertEqual(result.stdout, "")
        XCTAssertTrue(result.stderr.contains("Missing --index <element-index> for automation expand"))
    }

    func testDesktopCommandRunnerRejectsMissingAutomationCollapseIndex() {
        let result = self.runDesktopCommand([
            "peekaboo-desktop",
            "automation",
            "collapse",
        ])

        XCTAssertEqual(result.status, 1)
        XCTAssertEqual(result.stdout, "")
        XCTAssertTrue(result.stderr.contains("Missing --index <element-index> for automation collapse"))
    }

    func testDesktopCommandRunnerRejectsMissingAutomationSelectIndex() {
        let result = self.runDesktopCommand([
            "peekaboo-desktop",
            "automation",
            "select",
        ])

        XCTAssertEqual(result.status, 1)
        XCTAssertEqual(result.stdout, "")
        XCTAssertTrue(result.stderr.contains("Missing --index <element-index> for automation select"))
    }

    func testDesktopCommandRunnerRejectsInvalidAutomationSnapshotScope() {
        let result = self.runDesktopCommand([
            "peekaboo-desktop",
            "automation",
            "snapshot",
            "--scope",
            "everything",
        ])

        XCTAssertEqual(result.status, 1)
        XCTAssertEqual(result.stdout, "")
        XCTAssertTrue(result.stderr.contains("UI Automation scope must be root, foreground, focused, or cursor"))
    }

    func testDesktopCommandRunnerHelpIncludesWindowCapture() {
        let result = self.runDesktopCommand(["peekaboo-desktop", "--help"])

        XCTAssertEqual(result.status, 0)
        XCTAssertTrue(result.stdout.contains("capture window --id <window-id> --path"))
        XCTAssertTrue(result.stdout.contains("capture frontmost --path"))
        XCTAssertTrue(result.stdout.contains("input position"))
        XCTAssertTrue(result.stdout.contains("input move --point"))
        XCTAssertTrue(result.stdout.contains("input click --point"))
        XCTAssertTrue(result.stdout.contains("input scroll --point"))
        XCTAssertTrue(result.stdout.contains("input drag --from"))
        XCTAssertTrue(result.stdout.contains("input hotkey --keys"))
        XCTAssertTrue(result.stdout.contains("input type --text"))
        XCTAssertTrue(result.stdout.contains("automation status"))
        XCTAssertTrue(result.stdout.contains("automation snapshot"))
        XCTAssertTrue(result.stdout.contains("automation element --index"))
        XCTAssertTrue(result.stdout.contains("automation invoke --index"))
        XCTAssertTrue(result.stdout.contains("automation set-value --index"))
        XCTAssertTrue(result.stdout.contains("automation set-range-value --index"))
        XCTAssertTrue(result.stdout.contains("automation set-scroll-percent --index"))
        XCTAssertTrue(result.stdout.contains("automation set-window-state --index"))
        XCTAssertTrue(result.stdout.contains("automation toggle --index"))
        XCTAssertTrue(result.stdout.contains("automation expand --index"))
        XCTAssertTrue(result.stdout.contains("automation collapse --index"))
        XCTAssertTrue(result.stdout.contains("automation select --index"))
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
        DesktopTypingResult(
            text: text,
            characterCount: text.count,
            delayMilliseconds: delayMilliseconds)
    }

    func uiAutomationStatus() throws -> DesktopUIAutomationStatus {
        DesktopUIAutomationStatus(
            nativeBackend: "StubUIA",
            isAvailable: true,
            rootElementAvailable: true)
    }

    func uiAutomationSnapshot(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int) throws -> DesktopUIAutomationSnapshot
    {
        self.stubUIAutomationSnapshot(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementValue: "Example value")
    }

    func invokeUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    {
        let snapshot = try self.uiAutomationSnapshot(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements)
        guard let element = snapshot.elements.first(where: { $0.index == elementIndex }) else {
            throw DesktopAdapterError.invalidArgument("UI Automation element index not found")
        }
        return DesktopUIAutomationActionResult(
            nativeBackend: snapshot.nativeBackend,
            action: .invoke,
            scope: snapshot.scope,
            maxDepth: snapshot.maxDepth,
            maxElements: snapshot.maxElements,
            elementIndex: elementIndex,
            element: element)
    }

    func setUIAutomationElementValue(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        value: String) throws -> DesktopUIAutomationActionResult
    {
        let snapshot = try self.uiAutomationSnapshot(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements)
        guard let element = snapshot.elements.first(where: { $0.index == elementIndex }) else {
            throw DesktopAdapterError.invalidArgument("UI Automation element index not found")
        }
        let postActionElement = self.stubUIAutomationSnapshot(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementValue: value)
            .elements
            .first(where: { $0.index == elementIndex })
        return DesktopUIAutomationActionResult(
            nativeBackend: snapshot.nativeBackend,
            action: .setValue,
            scope: snapshot.scope,
            maxDepth: snapshot.maxDepth,
            maxElements: snapshot.maxElements,
            elementIndex: elementIndex,
            element: element,
            value: value,
            postActionElement: postActionElement,
            valueWasVerified: postActionElement?.value == value)
    }

    func setUIAutomationElementRangeValue(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        value: Double) throws -> DesktopUIAutomationActionResult
    {
        let snapshot = try self.uiAutomationSnapshot(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements)
        guard let element = snapshot.elements.first(where: { $0.index == elementIndex }) else {
            throw DesktopAdapterError.invalidArgument("UI Automation element index not found")
        }
        let postActionElement = self.stubUIAutomationSnapshot(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementValue: element.value ?? "",
            rangeValue: value)
            .elements
            .first(where: { $0.index == elementIndex })
        return DesktopUIAutomationActionResult(
            nativeBackend: snapshot.nativeBackend,
            action: .setRangeValue,
            scope: snapshot.scope,
            maxDepth: snapshot.maxDepth,
            maxElements: snapshot.maxElements,
            elementIndex: elementIndex,
            element: element,
            value: String(value),
            postActionElement: postActionElement,
            valueWasVerified: postActionElement?.rangeValue == value)
    }

    func setUIAutomationElementScrollPercent(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        horizontalPercent: Double?,
        verticalPercent: Double?) throws -> DesktopUIAutomationActionResult
    {
        let snapshot = try self.uiAutomationSnapshot(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements)
        guard let element = snapshot.elements.first(where: { $0.index == elementIndex }) else {
            throw DesktopAdapterError.invalidArgument("UI Automation element index not found")
        }
        let postActionElement = self.stubUIAutomationSnapshot(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementValue: element.value ?? "",
            horizontalScrollPercent: horizontalPercent ?? element.horizontalScrollPercent ?? 0.0,
            verticalScrollPercent: verticalPercent ?? element.verticalScrollPercent ?? 0.0)
            .elements
            .first(where: { $0.index == elementIndex })
        return DesktopUIAutomationActionResult(
            nativeBackend: snapshot.nativeBackend,
            action: .setScrollPercent,
            scope: snapshot.scope,
            maxDepth: snapshot.maxDepth,
            maxElements: snapshot.maxElements,
            elementIndex: elementIndex,
            element: element,
            value: self.scrollPercentValue(
                horizontalPercent: horizontalPercent,
                verticalPercent: verticalPercent),
            postActionElement: postActionElement,
            valueWasVerified: self.scrollPercentWasVerified(
                postActionElement: postActionElement,
                horizontalPercent: horizontalPercent,
                verticalPercent: verticalPercent))
    }

    func setUIAutomationElementWindowVisualState(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        state: DesktopUIAutomationWindowVisualState) throws -> DesktopUIAutomationActionResult
    {
        let snapshot = try self.uiAutomationSnapshot(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements)
        guard let element = snapshot.elements.first(where: { $0.index == elementIndex }) else {
            throw DesktopAdapterError.invalidArgument("UI Automation element index not found")
        }
        let postActionElement = self.stubUIAutomationSnapshot(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementValue: element.value ?? "",
            windowVisualState: state)
            .elements
            .first(where: { $0.index == elementIndex })
        return DesktopUIAutomationActionResult(
            nativeBackend: snapshot.nativeBackend,
            action: .setWindowVisualState,
            scope: snapshot.scope,
            maxDepth: snapshot.maxDepth,
            maxElements: snapshot.maxElements,
            elementIndex: elementIndex,
            element: element,
            value: state.rawValue,
            postActionElement: postActionElement,
            valueWasVerified: postActionElement?.windowVisualState == state)
    }

    func toggleUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    {
        let snapshot = try self.uiAutomationSnapshot(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements)
        guard let element = snapshot.elements.first(where: { $0.index == elementIndex }) else {
            throw DesktopAdapterError.invalidArgument("UI Automation element index not found")
        }
        return DesktopUIAutomationActionResult(
            nativeBackend: snapshot.nativeBackend,
            action: .toggle,
            scope: snapshot.scope,
            maxDepth: snapshot.maxDepth,
            maxElements: snapshot.maxElements,
            elementIndex: elementIndex,
            element: element,
            postActionElement: self.stubUIAutomationSnapshot(
                scope: scope,
                maxDepth: maxDepth,
                maxElements: maxElements,
                elementValue: element.value ?? "",
                toggleState: .on)
                .elements
                .first(where: { $0.index == elementIndex }))
    }

    func expandUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    {
        try self.expandCollapseUIAutomationElement(
            action: .expand,
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex,
            postActionState: .expanded)
    }

    func collapseUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    {
        try self.expandCollapseUIAutomationElement(
            action: .collapse,
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementIndex: elementIndex,
            postActionState: .collapsed)
    }

    func selectUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    {
        let snapshot = try self.uiAutomationSnapshot(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements)
        guard let element = snapshot.elements.first(where: { $0.index == elementIndex }) else {
            throw DesktopAdapterError.invalidArgument("UI Automation element index not found")
        }
        return DesktopUIAutomationActionResult(
            nativeBackend: snapshot.nativeBackend,
            action: .select,
            scope: snapshot.scope,
            maxDepth: snapshot.maxDepth,
            maxElements: snapshot.maxElements,
            elementIndex: elementIndex,
            element: element,
            postActionElement: self.stubUIAutomationSnapshot(
                scope: scope,
                maxDepth: maxDepth,
                maxElements: maxElements,
                elementValue: element.value ?? "",
                isSelected: true)
                .elements
                .first(where: { $0.index == elementIndex }))
    }

    private func expandCollapseUIAutomationElement(
        action: DesktopUIAutomationAction,
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        postActionState: DesktopUIAutomationExpandCollapseState) throws -> DesktopUIAutomationActionResult
    {
        let snapshot = try self.uiAutomationSnapshot(
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements)
        guard let element = snapshot.elements.first(where: { $0.index == elementIndex }) else {
            throw DesktopAdapterError.invalidArgument("UI Automation element index not found")
        }
        return DesktopUIAutomationActionResult(
            nativeBackend: snapshot.nativeBackend,
            action: action,
            scope: snapshot.scope,
            maxDepth: snapshot.maxDepth,
            maxElements: snapshot.maxElements,
            elementIndex: elementIndex,
            element: element,
            postActionElement: self.stubUIAutomationSnapshot(
                scope: scope,
                maxDepth: maxDepth,
                maxElements: maxElements,
                elementValue: element.value ?? "",
                expandCollapseState: postActionState)
                .elements
                .first(where: { $0.index == elementIndex }))
    }

    private func stubUIAutomationSnapshot(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementValue: String,
        rangeValue: Double = 12.5,
        horizontalScrollPercent: Double = 0.0,
        verticalScrollPercent: Double = 25.0,
        windowVisualState: DesktopUIAutomationWindowVisualState = .normal,
        toggleState: DesktopUIAutomationToggleState = .off,
        expandCollapseState: DesktopUIAutomationExpandCollapseState = .collapsed,
        isSelected: Bool = false) -> DesktopUIAutomationSnapshot
    {
        DesktopUIAutomationSnapshot(
            nativeBackend: "StubUIA",
            scope: scope,
            maxDepth: maxDepth,
            maxElements: maxElements,
            elementCount: 1,
            didTruncate: false,
            elements: [
                DesktopUIAutomationElementSnapshot(
                    index: 0,
                    parentIndex: nil,
                    depth: 0,
                    name: "Desktop",
                    localizedControlType: "pane",
                    controlType: 50033,
                    controlTypeName: "Pane",
                    bounds: DesktopRect(x: 0, y: 0, width: 100, height: 100),
                    isEnabled: true,
                    isKeyboardFocusable: false,
                    hasKeyboardFocus: false,
                    isOffscreen: false,
                    supportedPatterns: [
                        .invoke,
                        .value,
                        .rangeValue,
                        .scroll,
                        .expandCollapse,
                        .window,
                        .selectionItem,
                        .text,
                        .toggle,
                    ],
                    availableActions: self.stubAvailableActions(for: expandCollapseState),
                    value: elementValue,
                    isValueReadOnly: false,
                    rangeValue: rangeValue,
                    rangeMinimum: 0.0,
                    rangeMaximum: 100.0,
                    rangeSmallChange: 0.5,
                    rangeLargeChange: 10.0,
                    isRangeValueReadOnly: false,
                    horizontalScrollPercent: horizontalScrollPercent,
                    verticalScrollPercent: verticalScrollPercent,
                    horizontalScrollViewSize: 100.0,
                    verticalScrollViewSize: 50.0,
                    isHorizontallyScrollable: false,
                    isVerticallyScrollable: true,
                    toggleState: toggleState,
                    expandCollapseState: expandCollapseState,
                    windowVisualState: windowVisualState,
                    windowInteractionState: .readyForUserInteraction,
                    canMaximizeWindow: true,
                    canMinimizeWindow: true,
                    isModalWindow: false,
                    isTopmostWindow: false,
                    text: "Example text",
                    supportedTextSelection: .single,
                    isSelected: isSelected),
            ])
    }

    private func stubAvailableActions(
        for expandCollapseState: DesktopUIAutomationExpandCollapseState) -> [DesktopUIAutomationAction]
    {
        switch expandCollapseState {
        case .collapsed:
            return [
                .invoke,
                .setValue,
                .setRangeValue,
                .setScrollPercent,
                .setWindowVisualState,
                .toggle,
                .expand,
                .select,
            ]
        case .expanded:
            return [
                .invoke,
                .setValue,
                .setRangeValue,
                .setScrollPercent,
                .setWindowVisualState,
                .toggle,
                .collapse,
                .select,
            ]
        case .partiallyExpanded:
            return [
                .invoke,
                .setValue,
                .setRangeValue,
                .setScrollPercent,
                .setWindowVisualState,
                .toggle,
                .expand,
                .collapse,
                .select,
            ]
        case .leafNode:
            return [
                .invoke,
                .setValue,
                .setRangeValue,
                .setScrollPercent,
                .setWindowVisualState,
                .toggle,
                .select,
            ]
        }
    }

    private func scrollPercentValue(horizontalPercent: Double?, verticalPercent: Double?) -> String {
        let horizontal = horizontalPercent.map { String($0) } ?? "noScroll"
        let vertical = verticalPercent.map { String($0) } ?? "noScroll"
        return "horizontal=\(horizontal),vertical=\(vertical)"
    }

    private func scrollPercentWasVerified(
        postActionElement: DesktopUIAutomationElementSnapshot?,
        horizontalPercent: Double?,
        verticalPercent: Double?) -> Bool?
    {
        guard let postActionElement else {
            return nil
        }
        if let horizontalPercent {
            guard let actual = postActionElement.horizontalScrollPercent, actual == horizontalPercent else {
                return false
            }
        }
        if let verticalPercent {
            guard let actual = postActionElement.verticalScrollPercent, actual == verticalPercent else {
                return false
            }
        }
        return true
    }
}

private struct CommandResult {
    let status: Int32
    let stdout: String
    let stderr: String
}
