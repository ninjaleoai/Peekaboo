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
        let unsupportedWindowsCapabilities: Set<DesktopPlatformCapability> = [
            .captureScreenPNG,
            .captureAreaPNG,
            .captureWindowPNG,
            .captureFrontmostPNG,
        ]
        let expectedCapabilities = DesktopPlatformCapability.allCases.filter {
            !unsupportedWindowsCapabilities.contains($0)
        }
        let info: Win11PlatformInfo
        #if os(Windows)
        info = Win32DesktopAdapter().platformInfo()
        #else
        info = Win11PlatformInfo(
            name: "Windows",
            minimumSystemVersion: "Windows 11",
            nativeBackend: "Win32",
            capabilities: expectedCapabilities)
        #endif

        XCTAssertEqual(info.minimumSystemVersion, "Windows 11")
        XCTAssertEqual(info.nativeBackend, "Win32")
        XCTAssertEqual(info.capabilities.count, expectedCapabilities.count)
        XCTAssertEqual(Set(info.capabilities), Set(expectedCapabilities))
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
        XCTAssertThrowsError(try adapter.invokeUIAutomationElement(
            scope: .root,
            maxDepth: 1,
            maxElements: 4,
            elementIndex: 0))
        XCTAssertThrowsError(try adapter.focusUIAutomationElement(
            scope: .root,
            maxDepth: 1,
            maxElements: 4,
            elementIndex: 0))
        XCTAssertThrowsError(try adapter.performUIAutomationElementLegacyDefaultAction(
            scope: .root,
            maxDepth: 1,
            maxElements: 4,
            elementIndex: 0))
        XCTAssertThrowsError(try adapter.setUIAutomationElementLegacyValue(
            scope: .root,
            maxDepth: 1,
            maxElements: 4,
            elementIndex: 0,
            value: "updated"))
        XCTAssertThrowsError(try adapter.setUIAutomationElementValue(
            scope: .root,
            maxDepth: 1,
            maxElements: 4,
            elementIndex: 0,
            value: "updated"))
        XCTAssertThrowsError(try adapter.getUIAutomationText(
            scope: .root,
            maxDepth: 1,
            maxElements: 4,
            elementIndex: 0,
            source: .document,
            maxLength: 64))
        XCTAssertThrowsError(try adapter.setUIAutomationElementRangeValue(
            scope: .root,
            maxDepth: 1,
            maxElements: 4,
            elementIndex: 0,
            value: 42.5))
        XCTAssertThrowsError(try adapter.setUIAutomationElementScrollPercent(
            scope: .root,
            maxDepth: 1,
            maxElements: 4,
            elementIndex: 0,
            horizontalPercent: nil,
            verticalPercent: 75.0))
        XCTAssertThrowsError(try adapter.scrollUIAutomationElement(
            scope: .root,
            maxDepth: 1,
            maxElements: 4,
            elementIndex: 0,
            horizontalAmount: .none,
            verticalAmount: .largeIncrement))
        XCTAssertThrowsError(try adapter.setUIAutomationElementWindowVisualState(
            scope: .root,
            maxDepth: 1,
            maxElements: 4,
            elementIndex: 0,
            state: .maximized))
        XCTAssertThrowsError(try adapter.closeUIAutomationWindow(
            scope: .root,
            maxDepth: 1,
            maxElements: 4,
            elementIndex: 0))
        XCTAssertThrowsError(try adapter.waitForUIAutomationWindowInputIdle(
            scope: .root,
            maxDepth: 1,
            maxElements: 4,
            elementIndex: 0,
            timeoutMilliseconds: 250))
        XCTAssertThrowsError(try adapter.startUIAutomationSynchronizedInput(
            scope: .root,
            maxDepth: 1,
            maxElements: 4,
            elementIndex: 0,
            inputType: .keyDown))
        XCTAssertThrowsError(try adapter.cancelUIAutomationSynchronizedInput(
            scope: .root,
            maxDepth: 1,
            maxElements: 4,
            elementIndex: 0))
        XCTAssertThrowsError(try adapter.navigateUIAutomationCustom(
            scope: .root,
            maxDepth: 1,
            maxElements: 4,
            elementIndex: 0,
            direction: .nextSibling))
        XCTAssertThrowsError(try adapter.getUIAutomationSpreadsheetItemByName(
            scope: .root,
            maxDepth: 1,
            maxElements: 4,
            elementIndex: 0,
            name: "Revenue"))
        XCTAssertThrowsError(try adapter.findUIAutomationItemByProperty(
            scope: .root,
            maxDepth: 1,
            maxElements: 4,
            elementIndex: 0,
            property: .name,
            value: "Revenue"))
        XCTAssertThrowsError(try adapter.getUIAutomationGridItem(
            scope: .root,
            maxDepth: 1,
            maxElements: 4,
            elementIndex: 0,
            row: 1,
            column: 0))
        XCTAssertThrowsError(try adapter.moveUIAutomationElement(
            scope: .root,
            maxDepth: 1,
            maxElements: 4,
            elementIndex: 0,
            x: 20,
            y: 30))
        XCTAssertThrowsError(try adapter.resizeUIAutomationElement(
            scope: .root,
            maxDepth: 1,
            maxElements: 4,
            elementIndex: 0,
            width: 320,
            height: 240))
        XCTAssertThrowsError(try adapter.rotateUIAutomationElement(
            scope: .root,
            maxDepth: 1,
            maxElements: 4,
            elementIndex: 0,
            degrees: 45))
        XCTAssertThrowsError(try adapter.toggleUIAutomationElement(
            scope: .root,
            maxDepth: 1,
            maxElements: 4,
            elementIndex: 0))
        XCTAssertThrowsError(try adapter.expandUIAutomationElement(
            scope: .root,
            maxDepth: 1,
            maxElements: 4,
            elementIndex: 0))
        XCTAssertThrowsError(try adapter.collapseUIAutomationElement(
            scope: .root,
            maxDepth: 1,
            maxElements: 4,
            elementIndex: 0))
        XCTAssertThrowsError(try adapter.selectUIAutomationElement(
            scope: .root,
            maxDepth: 1,
            maxElements: 4,
            elementIndex: 0))
        XCTAssertThrowsError(try adapter.setUIAutomationElementDockPosition(
            scope: .root,
            maxDepth: 1,
            maxElements: 4,
            elementIndex: 0,
            position: .right))
        XCTAssertThrowsError(try adapter.setUIAutomationElementCurrentView(
            scope: .root,
            maxDepth: 1,
            maxElements: 4,
            elementIndex: 0,
            viewId: 4))
        XCTAssertThrowsError(try adapter.setUIAutomationElementZoomLevel(
            scope: .root,
            maxDepth: 1,
            maxElements: 4,
            elementIndex: 0,
            zoomLevel: 150.0))
        XCTAssertThrowsError(try adapter.zoomUIAutomationElementByUnit(
            scope: .root,
            maxDepth: 1,
            maxElements: 4,
            elementIndex: 0,
            unit: .largeIncrement))
        XCTAssertThrowsError(try adapter.addUIAutomationElementToSelection(
            scope: .root,
            maxDepth: 1,
            maxElements: 4,
            elementIndex: 0))
        XCTAssertThrowsError(try adapter.removeUIAutomationElementFromSelection(
            scope: .root,
            maxDepth: 1,
            maxElements: 4,
            elementIndex: 0))
        XCTAssertThrowsError(try adapter.scrollUIAutomationElementIntoView(
            scope: .root,
            maxDepth: 1,
            maxElements: 4,
            elementIndex: 0))
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
        XCTAssertTrue(output.contains("automation element --index"))
        XCTAssertTrue(output.contains("automation invoke --index"))
        XCTAssertTrue(output.contains("automation focus --index"))
        XCTAssertTrue(output.contains("automation legacy-default-action --index"))
        XCTAssertTrue(output.contains("automation set-legacy-value --index"))
        XCTAssertTrue(output.contains("automation set-value --index"))
        XCTAssertTrue(output.contains("automation get-text --index"))
        XCTAssertTrue(output.contains("automation set-range-value --index"))
        XCTAssertTrue(output.contains("automation scroll --index"))
        XCTAssertTrue(output.contains("automation set-scroll-percent --index"))
        XCTAssertTrue(output.contains("automation set-window-state --index"))
        XCTAssertTrue(output.contains("automation close-window --index"))
        XCTAssertTrue(output.contains("automation wait-window-idle --index"))
        XCTAssertTrue(output.contains("automation set-dock-position --index"))
        XCTAssertTrue(output.contains("automation set-current-view --index"))
        XCTAssertTrue(output.contains("automation set-zoom --index"))
        XCTAssertTrue(output.contains("automation zoom-by-unit --index"))
        XCTAssertTrue(output.contains("automation start-synchronized-input --index"))
        XCTAssertTrue(output.contains("automation cancel-synchronized-input --index"))
        XCTAssertTrue(output.contains("automation navigate-custom --index"))
        XCTAssertTrue(output.contains("automation find-item --index"))
        XCTAssertTrue(output.contains("automation get-spreadsheet-item --index"))
        XCTAssertTrue(output.contains("automation get-grid-item --index"))
        XCTAssertTrue(output.contains("automation move --index"))
        XCTAssertTrue(output.contains("automation resize --index"))
        XCTAssertTrue(output.contains("automation rotate --index"))
        XCTAssertTrue(output.contains("automation realize --index"))
        XCTAssertTrue(output.contains("automation toggle --index"))
        XCTAssertTrue(output.contains("automation expand --index"))
        XCTAssertTrue(output.contains("automation collapse --index"))
        XCTAssertTrue(output.contains("automation select --index"))
        XCTAssertTrue(output.contains("automation add-to-selection --index"))
        XCTAssertTrue(output.contains("automation remove-from-selection --index"))
        XCTAssertTrue(output.contains("automation scroll-into-view --index"))
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
        XCTAssertEqual(result.captureMethod, .gdiRegion)
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
        XCTAssertEqual(result.captureMethod, .gdiRegion)
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
        XCTAssertTrue([.gdiRegion, .printWindow].contains(try XCTUnwrap(result.captureMethod)))
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
            XCTAssertTrue([.gdiRegion, .printWindow].contains(try XCTUnwrap(result.captureMethod)))
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
        let disabledSuppressedActions: [DesktopUIAutomationAction] = [
            .focus,
            .invoke,
            .performLegacyDefaultAction,
            .setLegacyValue,
            .setValue,
            .setRangeValue,
            .setDockPosition,
            .setCurrentView,
            .setZoomLevel,
            .zoomByUnit,
            .move,
            .resize,
            .rotate,
            .toggle,
            .expand,
            .collapse,
            .select,
            .addToSelection,
            .removeFromSelection,
        ]
        for element in snapshot.elements where element.isEnabled == false {
            for action in disabledSuppressedActions {
                XCTAssertFalse(
                    element.availableActions.contains(action),
                    "Disabled element \(element.index) unexpectedly advertises \(action.rawValue)")
            }
        }
        #else
        throw XCTSkip("Native Windows UI Automation snapshot smoke test only runs on Windows.")
        #endif
    }

    func testNativeWindowsAdapterCanSnapshotUIAutomationCursorElement() throws {
        #if os(Windows)
        let adapter = Win32DesktopAdapter()
        let snapshot = try adapter.uiAutomationSnapshot(scope: .cursor, maxDepth: 0, maxElements: 1)

        XCTAssertEqual(snapshot.nativeBackend, "UIAutomation")
        XCTAssertEqual(snapshot.scope, .cursor)
        XCTAssertEqual(snapshot.maxDepth, 0)
        XCTAssertEqual(snapshot.maxElements, 1)
        XCTAssertNil(snapshot.error)
        XCTAssertEqual(snapshot.elementCount, 1)
        XCTAssertEqual(snapshot.elements.first?.depth, 0)
        XCTAssertEqual(snapshot.elements.first?.parentIndex, nil)
        #else
        throw XCTSkip("Native Windows cursor UI Automation snapshot smoke test only runs on Windows.")
        #endif
    }
}
