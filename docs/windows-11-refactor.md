---
summary: 'Plan and verify the native Windows 11 adapter seam'
read_when:
  - 'working on Windows 11 support'
  - 'changing the Windows platform adapter'
  - 'planning cross-platform desktop automation'
---

# Windows 11 Refactor

Peekaboo is still macOS-first. The Windows fork now has a first native seam at
`Platforms/Windows/PeekabooWin11`.

## Current Slice

`PeekabooWin11` is a standalone Swift package that avoids AppKit, CoreGraphics,
ScreenCaptureKit, AXorcist, and macOS permission types. It consumes the neutral
desktop models and `DesktopAdapter` interface from `Core/PeekabooDesktop`, then
publishes Windows-named type aliases for Windows 11 automation primitives:

- display enumeration
- visible window enumeration
- application enumeration from window-owning processes
- full-screen or display BMP capture through Win32 GDI
- rectangular-area BMP capture through the same GDI capture path
- region-backed foreground-window BMP capture through the same GDI capture path
- cursor position reads and cursor movement through Win32 cursor APIs
- point-based mouse clicks through Win32 mouse input APIs
- point-based wheel scrolling through Win32 mouse input APIs
- point-to-point mouse dragging through Win32 mouse input APIs
- modifier and virtual-key hotkeys through Win32 keyboard input APIs
- focused text typing through Win32 keyboard input APIs
- native UI Automation availability probing through the Windows UI Automation
  COM API
- bounded native UI Automation root, foreground-window, focused-element, or
  cursor-hit element snapshots through the UIA control view walker
- common UI Automation element metadata for access keys, accelerator keys,
  framework IDs, help text, item status, and item type
- UI Automation clickable-point availability and physical screen coordinate
  metadata in bounded snapshots
- stable UI Automation action availability mapping for snapshot elements
- Window-pattern UI Automation state metadata for windows in bounded snapshots
- Window-pattern UI Automation set-window-state actions against a bounded
  snapshot element index
- Window-pattern UI Automation close-window actions against a bounded snapshot
  element index
- Window-pattern UI Automation wait-window-idle actions against a bounded
  snapshot element index
- Dock-pattern UI Automation dock position metadata in bounded snapshots
- Dock-pattern UI Automation set-dock-position actions against a bounded
  snapshot element index
- Text-pattern UI Automation selection capability and bounded text preview
  metadata in bounded snapshots
- Text-pattern UI Automation selected text and selected range count metadata in
  bounded snapshots
- Text-pattern UI Automation visible text and visible range count metadata in
  bounded snapshots
- Text-pattern UI Automation get-text actions against a bounded snapshot
  element index
- TextPattern2-pattern UI Automation caret active-state and caret rectangle
  count metadata in bounded snapshots
- TextEdit-pattern UI Automation active-composition and conversion-target range
  metadata in bounded snapshots
- TextChild-pattern UI Automation text-container and enclosing-range metadata in
  bounded snapshots
- Legacy IAccessible-pattern UI Automation fallback metadata in bounded
  snapshots
- Grid-pattern and GridItem-pattern UI Automation row, column, and span
  metadata in bounded snapshots
- Spreadsheet-pattern and SpreadsheetItem-pattern UI Automation formula and
  annotation count metadata in bounded snapshots
- Table-pattern and TableItem-pattern UI Automation traversal direction and
  header count metadata in bounded snapshots
- Selection-pattern UI Automation multi-select, required-selection, and
  selected item count metadata in bounded snapshots
- Transform-pattern UI Automation movement, resize, and rotation capability
  metadata in bounded snapshots
- Transform2-pattern UI Automation zoom capability and level metadata in
  bounded snapshots
- Transform2-pattern UI Automation set-zoom actions against a bounded snapshot
  element index
- Transform2-pattern UI Automation zoom-by-unit actions against a bounded
  snapshot element index
- MultipleView-pattern UI Automation current-view metadata in bounded snapshots
- MultipleView-pattern UI Automation set-current-view actions against a bounded
  snapshot element index
- Annotation-pattern UI Automation type, author, timestamp, and target metadata
  in bounded snapshots
- Styles-pattern UI Automation visual style, fill color, shape, and extended
  property metadata in bounded snapshots
- Drag-pattern and DropTarget-pattern UI Automation effect and grabbed-state
  metadata in bounded snapshots
- ItemContainer, SynchronizedInput, ObjectModel, and CustomNavigation UI
  Automation pattern availability in bounded snapshots
- SynchronizedInput-pattern UI Automation start-listening and cancel actions
  against a bounded snapshot element index
- CustomNavigation-pattern UI Automation navigate actions against a bounded
  snapshot element index, returning the navigated UIA element in
  `resultElement` and marking the result verified when UIA returns a target
  element for the requested direction
- ItemContainer-pattern UI Automation find-item actions against a bounded
  snapshot element index, returning the matching item UIA element in
  `resultElement`
- Spreadsheet-pattern UI Automation get-item-by-name actions against a bounded
  snapshot element index, returning the matching cell UIA element in
  `resultElement`
- Grid-pattern UI Automation get-item actions against a bounded snapshot
  element index and zero-based row/column, returning the matching grid UIA
  element in `resultElement`
- VirtualizedItem-pattern UI Automation realize actions against a bounded
  snapshot element index
- Transform-pattern UI Automation move, resize, and rotate actions against a
  bounded snapshot element index
- refreshed post-action verification metadata for observable UI Automation
  Toggle, ExpandCollapse, and SelectionItem actions
- UI Automation focus actions against a bounded snapshot element index, verified
  through refreshed keyboard-focus metadata when UIA reports it
- Invoke-pattern UI Automation actions against a bounded snapshot element index
- Invoke-pattern UI Automation refreshed post-action metadata when the bounded
  lookup can observe the same element after invocation
- Legacy IAccessible-pattern UI Automation default actions against a bounded
  snapshot element index
- Legacy IAccessible-pattern UI Automation set-legacy-value actions against a
  bounded snapshot element index
- Value-pattern UI Automation set-value actions against a bounded snapshot
  element index
- RangeValue-pattern UI Automation set-range-value actions against a bounded
  snapshot element index
- RangeValue-pattern UI Automation disabled-state action suppression and
  preflight rejection
- Scroll-pattern UI Automation scroll-by-amount actions against a bounded
  snapshot element index
- Scroll-pattern UI Automation set-scroll-percent actions against a bounded
  snapshot element index
- ScrollItem-pattern UI Automation scroll-into-view actions against a bounded
  snapshot element index
- Toggle-pattern UI Automation actions against a bounded snapshot element index
- Toggle-pattern UI Automation disabled-state action suppression and preflight
  rejection
- ExpandCollapse-pattern UI Automation expand/collapse actions against a
  bounded snapshot element index
- SelectionItem-pattern UI Automation selection actions against a bounded
  snapshot element index
- SelectionItem-pattern UI Automation add-to-selection and
  remove-from-selection actions against a bounded snapshot element index
- SelectionItem-pattern UI Automation disabled-state action suppression and
  preflight rejection
- SelectionItem-pattern UI Automation add/remove preflight rejection for known
  unsupported selection-container states
- Legacy IAccessible-pattern UI Automation default-action disabled-state
  suppression and preflight rejection
- Transform/Transform2-pattern UI Automation disabled-state action suppression
  and preflight rejection
- Dock/MultipleView-pattern UI Automation disabled-state action suppression and
  preflight rejection

The `peekaboo-win11` executable now delegates its basic command parsing to
`DesktopCommandRunner` in `PeekabooDesktop`. The Windows target owns native
adapter construction; the shared package owns the platform-neutral
`platform-info`, `list`, `capture screen`, `capture area`, `capture window`,
`capture frontmost`, `input position`, `input move`, `input click`,
`input scroll`, `input drag`, `input hotkey`, and `input type` command
contract, plus `automation status` and bounded `automation snapshot` UI
Automation commands. It also exposes `automation element --index <n>` as a
bounded element lookup over the same snapshot traversal, and
`automation focus --index <n>`, `automation invoke --index <n>`,
`automation legacy-default-action --index <n>`,
`automation set-legacy-value --index <n>`,
`automation set-value --index <n>`,
`automation get-text --index <n>`,
`automation set-range-value --index <n>`,
`automation scroll --index <n>`,
`automation set-scroll-percent --index <n>`,
`automation set-window-state --index <n>`,
`automation close-window --index <n>`,
`automation wait-window-idle --index <n>`,
`automation set-dock-position --index <n>`,
`automation set-current-view --index <n>`,
`automation set-zoom --index <n>`,
`automation zoom-by-unit --index <n>`,
`automation start-synchronized-input --index <n>`,
`automation cancel-synchronized-input --index <n>`,
`automation navigate-custom --index <n>`,
`automation find-item --index <n>`,
`automation get-spreadsheet-item --index <n>`,
`automation get-grid-item --index <n>`,
`automation realize --index <n>`,
`automation scroll-into-view --index <n>`,
`automation toggle --index <n>`,
`automation expand --index <n>`,
`automation collapse --index <n>`,
`automation select --index <n>`,
`automation add-to-selection --index <n>`,
`automation remove-from-selection --index <n>`,
`automation move --index <n>`,
`automation resize --index <n>`,
and `automation rotate --index <n>` for Invoke-pattern,
LegacyIAccessible-pattern, Value-pattern, Text-pattern, RangeValue-pattern,
Scroll-pattern, Window-pattern, Dock-pattern, MultipleView-pattern,
Transform2-pattern, SynchronizedInput-pattern, CustomNavigation-pattern,
ItemContainer-pattern, Spreadsheet-pattern, Grid-pattern,
VirtualizedItem-pattern, ScrollItem-pattern, Toggle-pattern,
ExpandCollapse-pattern, SelectionItem-pattern, and Transform-pattern UIA
actions.
`automation focus --index <n>` calls UIA `SetFocus` for a bounded element and
advertises availability only when UIA reports that the element is enabled and
keyboard focusable.
`automation legacy-default-action --index <n>` calls the LegacyIAccessible
pattern default action for older MSAA-backed controls when UIA exposes a default
action string on an enabled element.
`automation set-legacy-value --index <n>` calls the LegacyIAccessible pattern
`SetValue` method for older MSAA-backed controls when UIA exposes legacy value
metadata.
`automation set-value --index <n>` calls the Value pattern `SetValue` method
for enabled, writable controls.
`automation get-text --index <n> --source <document|selected|visible>` covers
Text-pattern controls that expose document, selected, or visible text ranges,
and returns bounded text in the action `value`.
`automation scroll --index <n> --vertical <amount>` covers Scroll-pattern
controls that expose semantic horizontal or vertical scroll increments.
`automation close-window --index <n>` calls the Window pattern `Close` method
for Window-pattern controls.
`automation wait-window-idle --index <n> --timeout-ms <n>` calls the Window
pattern `WaitForInputIdle` method and reports whether the window became idle
before the timeout.
`automation set-dock-position --index <n> --position <top|left|bottom|right|fill|none>`
covers enabled Dock-pattern controls that can be rearranged within a docking
container.
`automation set-current-view --index <n> --view-id <view-id>` covers
enabled MultipleView-pattern controls that expose alternate UI presentations.
`automation set-zoom --index <n> --level <percent>` covers Transform2-pattern
controls that expose zoomable viewports on enabled elements, rejecting known
out-of-range zoom levels when UIA exposes minimum or maximum zoom metadata.
`automation zoom-by-unit --index <n> --unit
<large-increment|small-increment|large-decrement|small-decrement|none>` covers
enabled Transform2-pattern controls that expose unit-based viewport zoom.
`automation start-synchronized-input --index <n> --input-type <input-type>`
starts SynchronizedInput-pattern listening for one keyboard or mouse input
type. `automation cancel-synchronized-input --index <n>` asks the same pattern
to stop listening.
`automation navigate-custom --index <n> --direction
<parent|next-sibling|previous-sibling|first-child|last-child>` covers
CustomNavigation-pattern controls that expose a custom logical navigation
order, returns the target element snapshot in the action `resultElement`, and
marks the result verified when UIA returns a target element for the requested
direction.
`automation find-item --index <n> --property <name|automation-id> --value
<value>` covers ItemContainer-pattern controls that can search by Name or
AutomationId, and returns the matching item element snapshot in the action
`resultElement`.
`automation get-spreadsheet-item --index <n> --name <cell-name>` covers
Spreadsheet-pattern controls that expose friendly cell names, and returns the
matching cell element snapshot in the action `resultElement`.
`automation get-grid-item --index <n> --row <row> --column <column>` covers
Grid-pattern controls that expose zero-based row and column lookup, and returns
the matching grid item element snapshot in the action `resultElement`.
`automation realize --index <n>` covers VirtualizedItem-pattern controls whose
placeholder element can be materialized into a full UIA element.
`automation scroll-into-view --index <n>` covers ScrollItem-pattern controls
that can ask their scrollable container to bring the item into view.
`automation toggle --index <n>` covers Toggle-pattern controls.
`automation expand --index <n>` and
`automation collapse --index <n>` cover ExpandCollapse-pattern controls such
as tree items and combo boxes. `automation select --index <n>` covers
SelectionItem-pattern controls such as list items, menu items, and tabs.
`automation add-to-selection --index <n>` and
`automation remove-from-selection --index <n>` cover the SelectionItem pattern
methods that preserve or reduce a multi-item selection instead of replacing
the selection like `select`. Snapshot action availability uses the selection
container metadata when UIA exposes it, so add-to-selection is only advertised
when the container reports multi-selection support and remove-from-selection is
only advertised for selected items, with required single-selection containers
suppressed. The command path applies the same known-unsupported preflight checks
before calling the UIA SelectionItem method.
When an element supports the UIA Transform pattern, snapshots include whether
UIA reports that it can be moved, resized, or rotated.
`automation move --index <n> --point <x,y>` and
`automation resize --index <n> --size <width,height>` cover Transform-pattern
movement and resizing for enabled controls that advertise those capabilities.
`automation rotate --index <n> --degrees <number>` covers Transform-pattern
rotation for enabled controls where UIA reports `canRotate`.

The production adapter is compiled only behind `#if os(Windows)` and imports
`WinSDK`. Non-Windows builds get `UnsupportedWin11DesktopAdapter`, which keeps
tests and documentation tooling from accidentally pretending the native backend
is available.

`PeekabooAutomationKit` also depends on `Core/PeekabooDesktop`, maps the
existing macOS service models into the neutral desktop models, and exposes
`MacAutomationDesktopAdapter` for async/main-actor macOS automation services.
That gives the main automation package a shared contract to target without
changing existing macOS runtime behavior. The main macOS CLI now uses that
adapter for the `list apps`, `list screens`, and `list windows` read paths
while preserving the existing JSON payload shapes. The neutral window model
now carries the cross-platform fields needed by CLI output, including z-order
index, screen, Space, off-screen, layer, alpha, and on-screen metadata. The
model also preserves whether a window is shareable so adapter-routed captures
keep the same hidden/helper-window filter as the macOS observation path. The
first capture read paths are also routed through the adapter: compatible
`image --mode screen` PNG captures now use `DesktopAsyncAdapter.captureScreen`,
and compatible `image --mode area --region x,y,width,height` PNG captures now
use `DesktopAsyncAdapter.captureArea`. Compatible `image --window-id <id>` PNG
captures now use `DesktopAsyncAdapter.captureWindow`, and compatible
`image --app ...` / `image --pid ...` single-window PNG captures, including
title and index selection, now use `DesktopAsyncAdapter.captureWindow`.
Compatible `image --mode multi --app ...` / `--pid ...` PNG captures now
capture each renderable application window through the same window adapter path.
Compatible `image --mode frontmost` PNG captures now use
`DesktopAsyncAdapter.captureFrontmost`. Retina, forced-engine, and JPG captures
stay on the existing macOS observation pipeline. Window capture is now part of
the neutral desktop adapter and the Windows platform CLI can capture a window
by ID through the existing Win32 region capture path. The Windows platform CLI
can also capture the foreground window through the same region-backed path.

## Why This Seam

The existing macOS implementation leaks platform types through service
interfaces: `CGRect`, `CGWindowID`, `NSScreen`, ScreenCaptureKit, Accessibility,
and AXorcist are spread across capture, observation, window, input, and CLI
modules. A direct rename from macOS services to Windows services would make the
interface nearly as complex as the implementation.

The shared desktop package starts with a smaller interface:

```swift
public protocol DesktopAdapter: Sendable {
    func platformInfo() -> DesktopPlatformInfo
    func listDisplays() throws -> [DesktopDisplay]
    func listWindows(includeInvisible: Bool) throws -> [DesktopWindow]
    func listApplications() throws -> [DesktopApplication]
    func captureScreen(displayIndex: Int?, outputPath: String) throws -> DesktopCaptureResult
    func captureArea(_ rect: DesktopRect, outputPath: String) throws -> DesktopCaptureResult
    func captureWindow(windowIdentifier: UInt64, outputPath: String) throws -> DesktopCaptureResult
    func captureFrontmost(outputPath: String) throws -> DesktopCaptureResult
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
    func setUIAutomationElementLegacyValue(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        value: String) throws -> DesktopUIAutomationActionResult
    func setUIAutomationElementValue(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        value: String) throws -> DesktopUIAutomationActionResult
    func setUIAutomationElementRangeValue(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        value: Double) throws -> DesktopUIAutomationActionResult
    func scrollUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        horizontalAmount: DesktopUIAutomationScrollAmount,
        verticalAmount: DesktopUIAutomationScrollAmount) throws -> DesktopUIAutomationActionResult
    func setUIAutomationElementScrollPercent(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        horizontalPercent: Double?,
        verticalPercent: Double?) throws -> DesktopUIAutomationActionResult
    func setUIAutomationElementWindowVisualState(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        state: DesktopUIAutomationWindowVisualState) throws -> DesktopUIAutomationActionResult
    func closeUIAutomationWindow(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    func waitForUIAutomationWindowInputIdle(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        timeoutMilliseconds: Int) throws -> DesktopUIAutomationActionResult
    func setUIAutomationElementDockPosition(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        position: DesktopUIAutomationDockPosition) throws -> DesktopUIAutomationActionResult
    func setUIAutomationElementCurrentView(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        viewId: Int) throws -> DesktopUIAutomationActionResult
    func setUIAutomationElementZoomLevel(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        zoomLevel: Double) throws -> DesktopUIAutomationActionResult
    func zoomUIAutomationElementByUnit(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        unit: DesktopUIAutomationZoomUnit) throws -> DesktopUIAutomationActionResult
    func moveUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        x: Double,
        y: Double) throws -> DesktopUIAutomationActionResult
    func resizeUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        width: Double,
        height: Double) throws -> DesktopUIAutomationActionResult
    func rotateUIAutomationElement(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int,
        degrees: Double) throws -> DesktopUIAutomationActionResult
    func realizeUIAutomationVirtualizedItem(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
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
    func addUIAutomationElementToSelection(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    func removeUIAutomationElementFromSelection(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
    func scrollUIAutomationElementIntoView(
        scope: DesktopUIAutomationSnapshotScope,
        maxDepth: Int,
        maxElements: Int,
        elementIndex: Int) throws -> DesktopUIAutomationActionResult
}
```

It also exposes `DesktopAsyncAdapter` for platform services that are naturally
async or actor-isolated. A sync-to-async bridge keeps the Win32 adapter usable
from async call sites without forcing the Windows CLI path to change.

`DesktopCommandRunner` sits above that interface so early platform CLIs do not
need to duplicate argument parsing, JSON envelopes, help text, or validation
rules while each platform backend is still being filled in.

That module is deliberately deep: callers get app/window/display/capture
behavior without learning HWND lifetimes, GDI device contexts, UTF-16 buffers,
BMP/PNG file details, or platform-specific actor isolation.

## Build

On Windows 11 with Swift installed:

```powershell
.\scripts\windows\build-win11.ps1
```

Or directly:

```powershell
swift build --package-path Platforms/Windows/PeekabooWin11
swift test --package-path Platforms/Windows/PeekabooWin11
```

## Run

```powershell
swift run --package-path Platforms/Windows/PeekabooWin11 peekaboo-win11 platform-info
swift run --package-path Platforms/Windows/PeekabooWin11 peekaboo-win11 list displays
swift run --package-path Platforms/Windows/PeekabooWin11 peekaboo-win11 list windows
swift run --package-path Platforms/Windows/PeekabooWin11 peekaboo-win11 list apps
swift run --package-path Platforms/Windows/PeekabooWin11 peekaboo-win11 capture screen --path .\screen.bmp
swift run --package-path Platforms/Windows/PeekabooWin11 peekaboo-win11 `
  capture area --rect 0,0,640,480 --path .\area.bmp
swift run --package-path Platforms/Windows/PeekabooWin11 peekaboo-win11 `
  capture window --id <window-id> --path .\window.bmp
swift run --package-path Platforms/Windows/PeekabooWin11 peekaboo-win11 `
  capture frontmost --path .\frontmost.bmp
swift run --package-path Platforms/Windows/PeekabooWin11 peekaboo-win11 input position
swift run --package-path Platforms/Windows/PeekabooWin11 peekaboo-win11 input move --point 100,100
swift run --package-path Platforms/Windows/PeekabooWin11 peekaboo-win11 `
  input click --point 100,100 --button left --count 1
swift run --package-path Platforms/Windows/PeekabooWin11 peekaboo-win11 `
  input scroll --point 100,100 --direction down --amount 3
swift run --package-path Platforms/Windows/PeekabooWin11 peekaboo-win11 `
  input drag --from 100,100 --to 200,200 --button left --steps 10
swift run --package-path Platforms/Windows/PeekabooWin11 peekaboo-win11 `
  input hotkey --keys ctrl,shift,escape --hold-ms 25
swift run --package-path Platforms/Windows/PeekabooWin11 peekaboo-win11 `
  input type --text "hello from Windows" --delay-ms 5
swift run --package-path Platforms/Windows/PeekabooWin11 peekaboo-win11 automation status
swift run --package-path Platforms/Windows/PeekabooWin11 peekaboo-win11 `
  automation snapshot --scope foreground --max-depth 2 --max-elements 64
swift run --package-path Platforms/Windows/PeekabooWin11 peekaboo-win11 `
  automation snapshot --scope focused --max-depth 0 --max-elements 1
swift run --package-path Platforms/Windows/PeekabooWin11 peekaboo-win11 `
  automation snapshot --scope cursor --max-depth 0 --max-elements 1
swift run --package-path Platforms/Windows/PeekabooWin11 peekaboo-win11 `
  automation element --scope foreground --index 0 --max-depth 2 --max-elements 64
swift run --package-path Platforms/Windows/PeekabooWin11 peekaboo-win11 `
  automation invoke --scope foreground --index 0 --max-depth 2 --max-elements 64
swift run --package-path Platforms/Windows/PeekabooWin11 peekaboo-win11 `
  automation focus --scope foreground --index 0 --max-depth 2 --max-elements 64
swift run --package-path Platforms/Windows/PeekabooWin11 peekaboo-win11 `
  automation legacy-default-action --scope foreground --index 0 --max-depth 2 --max-elements 64
swift run --package-path Platforms/Windows/PeekabooWin11 peekaboo-win11 `
  automation set-legacy-value --scope focused --index 0 --value "hello" --max-depth 0 --max-elements 1
swift run --package-path Platforms/Windows/PeekabooWin11 peekaboo-win11 `
  automation set-value --scope focused --index 0 --value "hello" --max-depth 0 --max-elements 1
swift run --package-path Platforms/Windows/PeekabooWin11 peekaboo-win11 `
  automation get-text --scope focused --index 0 --source document --max-length 1024 --max-depth 0 --max-elements 1
swift run --package-path Platforms/Windows/PeekabooWin11 peekaboo-win11 `
  automation set-range-value --scope foreground --index 0 --value 42.5 --max-depth 2 --max-elements 64
swift run --package-path Platforms/Windows/PeekabooWin11 peekaboo-win11 `
  automation scroll --scope foreground --index 0 --vertical large-increment --max-depth 2 --max-elements 64
swift run --package-path Platforms/Windows/PeekabooWin11 peekaboo-win11 `
  automation set-scroll-percent --scope foreground --index 0 --vertical 75 --max-depth 2 --max-elements 64
swift run --package-path Platforms/Windows/PeekabooWin11 peekaboo-win11 `
  automation set-window-state --scope foreground --index 0 --state maximized --max-depth 2 --max-elements 64
swift run --package-path Platforms/Windows/PeekabooWin11 peekaboo-win11 `
  automation close-window --scope foreground --index 0 --max-depth 2 --max-elements 64
swift run --package-path Platforms/Windows/PeekabooWin11 peekaboo-win11 `
  automation wait-window-idle --scope foreground --index 0 --timeout-ms 5000 --max-depth 2 --max-elements 64
swift run --package-path Platforms/Windows/PeekabooWin11 peekaboo-win11 `
  automation set-dock-position --scope foreground --index 0 --position right --max-depth 2 --max-elements 64
swift run --package-path Platforms/Windows/PeekabooWin11 peekaboo-win11 `
  automation set-current-view --scope foreground --index 0 --view-id 2 --max-depth 2 --max-elements 64
swift run --package-path Platforms/Windows/PeekabooWin11 peekaboo-win11 `
  automation set-zoom --scope foreground --index 0 --level 150 --max-depth 2 --max-elements 64
swift run --package-path Platforms/Windows/PeekabooWin11 peekaboo-win11 `
  automation zoom-by-unit --scope foreground --index 0 --unit small-increment --max-depth 2 --max-elements 64
swift run --package-path Platforms/Windows/PeekabooWin11 peekaboo-win11 `
  automation start-synchronized-input --scope foreground --index 0 --input-type key-down --max-depth 2 --max-elements 64
swift run --package-path Platforms/Windows/PeekabooWin11 peekaboo-win11 `
  automation cancel-synchronized-input --scope foreground --index 0 --max-depth 2 --max-elements 64
swift run --package-path Platforms/Windows/PeekabooWin11 peekaboo-win11 `
  automation scroll-into-view --scope foreground --index 0 --max-depth 2 --max-elements 64
swift run --package-path Platforms/Windows/PeekabooWin11 peekaboo-win11 `
  automation move --scope foreground --index 0 --point 100,100 --max-depth 2 --max-elements 64
swift run --package-path Platforms/Windows/PeekabooWin11 peekaboo-win11 `
  automation resize --scope foreground --index 0 --size 640,480 --max-depth 2 --max-elements 64
swift run --package-path Platforms/Windows/PeekabooWin11 peekaboo-win11 `
  automation rotate --scope foreground --index 0 --degrees 45 --max-depth 2 --max-elements 64
swift run --package-path Platforms/Windows/PeekabooWin11 peekaboo-win11 `
  automation realize --scope foreground --index 0 --max-depth 2 --max-elements 64
swift run --package-path Platforms/Windows/PeekabooWin11 peekaboo-win11 `
  automation toggle --scope foreground --index 0 --max-depth 2 --max-elements 64
swift run --package-path Platforms/Windows/PeekabooWin11 peekaboo-win11 `
  automation expand --scope foreground --index 0 --max-depth 2 --max-elements 64
swift run --package-path Platforms/Windows/PeekabooWin11 peekaboo-win11 `
  automation collapse --scope foreground --index 0 --max-depth 2 --max-elements 64
swift run --package-path Platforms/Windows/PeekabooWin11 peekaboo-win11 `
  automation select --scope foreground --index 0 --max-depth 2 --max-elements 64
swift run --package-path Platforms/Windows/PeekabooWin11 peekaboo-win11 `
  automation add-to-selection --scope foreground --index 0 --max-depth 2 --max-elements 64
swift run --package-path Platforms/Windows/PeekabooWin11 peekaboo-win11 `
  automation remove-from-selection --scope foreground --index 0 --max-depth 2 --max-elements 64
```

The first Windows window captures are region-backed: the adapter resolves the
requested or foreground window bounds, then captures that screen rectangle to
BMP. This does not yet provide off-screen semantic window rendering.

The first Windows typing path sends keyboard-layout translated keystrokes to
the current focus. It supports characters that `VkKeyScanW` can translate for
the active keyboard layout, plus return and tab, and rejects unsupported text
instead of silently dropping characters.

The first Windows UI Automation path initializes COM, creates a `CUIAutomation`
object, and requests the root element for status probing. The follow-up
snapshot path can start at the desktop root, foreground window, focused
element, or element under the current cursor, then walks the UIA control view
with explicit `--max-depth` and
`--max-elements` limits. Snapshot elements include the raw control type, stable
non-localized control type name, localized control type, name, automation
identifier, class name, access key, accelerator key, framework ID, help text,
item status, item type, process ID, native window handle, bounds, depth, parent
index, child count, and optional state flags for enabled, focusable, focused,
off-screen, and clickable-point status. When UIA exposes a clickable point,
snapshots include its physical screen coordinates. Elements also report common
supported UIA patterns, including invoke, value, range value, scroll,
expand/collapse, window, selection item, text, text2, textEdit, textChild,
toggle, grid, grid item, spreadsheet, spreadsheet item, table, table item,
transform, transform2, multiple view, annotation, styles, drag, drop target,
item container, synchronized input, object model, custom navigation,
virtualized item, scroll item, and legacy IAccessible. When an element supports
the UIA Value pattern, snapshots also
include its current string value and whether that value is read-only. When an
element supports the
UIA RangeValue pattern, snapshots include the current numeric value, minimum,
maximum, small change, large change, and read-only status when UIA reports
them. When an element supports the UIA Scroll pattern, snapshots include
horizontal and vertical scroll percentages, horizontal and vertical view sizes,
and whether each axis is scrollable when UIA reports them. When an element
supports the UIA Window pattern, snapshots include visual state, interaction
state, whether the window can be minimized or maximized, and whether it is
modal or topmost when UIA reports them. When an element supports the UIA Text
pattern, snapshots include a bounded text preview from the document range,
selected text, selected range count, visible text, visible range count, and
whether text selection is unsupported, single-range, or multi-range when UIA
reports them. When an element supports the UIA TextPattern2 pattern, snapshots
include whether the caret range is active plus the caret range bounding
rectangle count when UIA reports them.
When an element supports the UIA TextEdit pattern, snapshots include whether
active-composition and conversion-target ranges are present plus each range's
bounding rectangle count when UIA reports them.
When an element supports the UIA TextChild pattern, snapshots include the
nearest text container name plus whether UIA returned an enclosing text range
and that range's bounding rectangle count when UIA reports them.
When an element supports the UIA Legacy IAccessible pattern,
snapshots include fallback MSAA child ID, name, value, description, help,
keyboard shortcut, default action, role ID, and state ID when UIA reports them.
When an element supports the UIA Grid pattern, snapshots include row and
column counts; GridItem elements include row, column, row span, and column
span when UIA reports them.
When an element supports the UIA SpreadsheetItem pattern, snapshots include the
cell formula plus annotation object and annotation type counts when UIA reports
them.
When an element supports the UIA Table pattern, snapshots include the primary
row-or-column traversal direction plus row and column header counts when UIA
reports them; TableItem elements include row and column header counts for the
cell when UIA reports them.
When an element supports the UIA Dock pattern, snapshots include the current
dock position: top, left, bottom, right, fill, or none.
When an element supports the UIA Toggle pattern, snapshots also include the
current toggle state: off, on, or indeterminate. When an element supports the
UIA ExpandCollapse pattern,
snapshots also include the current expand/collapse state: collapsed, expanded,
partially expanded, or leaf node. When an element supports the UIA
SelectionItem pattern, snapshots also include whether the item is currently
selected and, when UIA exposes it through the item's selection container,
whether the container supports multiple selection, requires a selection, and how
many items are currently selected. When an element supports the UIA Transform2
pattern, snapshots include whether zooming is supported plus current, minimum,
and maximum zoom levels when UIA reports them. When an element supports the UIA
MultipleView pattern,
snapshots include the current view identifier, localized current view name, and
supported view count when UIA reports them. When an element supports the UIA
Annotation pattern, snapshots include annotation type ID, localized type name,
author, creation date/time, and target element name when UIA reports them.
When an element supports the UIA Styles pattern, snapshots include visual style
ID and name, fill color, fill pattern color, shape, and extended properties
when UIA reports them.
When an element supports the UIA Drag pattern, snapshots include the current
drop effect, supported drop-effect count, grabbed state, and grabbed item count
when UIA reports them. When an element supports the UIA DropTarget pattern,
snapshots include the current drop target effect and supported effect count
when UIA reports them.
Elements also expose stable
available actions derived from those
patterns and element properties: focus is available when UIA reports that the
element is enabled and keyboard focusable, invoke is available when the Invoke
pattern is present on an enabled element, performLegacyDefaultAction is
available when the Legacy IAccessible pattern exposes a non-empty default action
string on an enabled element, setLegacyValue is available when the Legacy
IAccessible pattern exposes legacy value metadata on an enabled element,
setValue is available only when the Value pattern is present and the element is
enabled and known writable, getText is available when the Text pattern is
present, setRangeValue is available only when the RangeValue pattern is present
on an enabled element and known writable, scrollByAmount and setScrollPercent
are available when the Scroll pattern is
present and at least one axis is known scrollable, setWindowVisualState is
available when the Window pattern is present, closeWindow is available when
the Window pattern is present, waitForWindowInputIdle is available when the
Window pattern is present, setDockPosition is available when the Dock pattern
is present on an enabled element, setCurrentView is available when the
MultipleView pattern is present on an enabled element, setZoomLevel is
available when the Transform2 pattern is present on an enabled element and UIA
reports that zoom is supported, zoomByUnit is available under the same
Transform2 zoom condition, startSynchronizedInput and cancelSynchronizedInput
are available when the SynchronizedInput pattern is
present, move, resize, and rotate are available when the Transform pattern is
present on an enabled element and UIA reports the matching capability,
findItemByProperty is available when the ItemContainer
pattern is present, getSpreadsheetItem is available when the Spreadsheet pattern
is present, getGridItem is available when the Grid pattern is present, realize
is available when the VirtualizedItem pattern is
present, toggle is available when the Toggle pattern is present on an enabled
element, expand is available for enabled collapsed or partially expanded
ExpandCollapse elements, collapse is available for enabled expanded or
partially expanded ExpandCollapse elements, select is available when the
SelectionItem pattern is present on an enabled element, addToSelection and
removeFromSelection are available for enabled elements when Selection-pattern
metadata indicates the selection container can support the action, and
scrollIntoView is available when the ScrollItem pattern
is present.
Root snapshots should stay shallow because desktop-wide UIA traversal is
expensive. `automation element --index <n>`
returns a single element from the same bounded traversal, which gives later
invoke and value actions a concrete element lookup surface without introducing
persistent UIA element handles yet. `automation focus --index <n>` calls
`IUIAutomationElement::SetFocus` for the bounded element, rejects elements known
not to be enabled or keyboard focusable, then verifies `hasKeyboardFocus` from a
refreshed lookup when UIA reports it. `automation legacy-default-action --index <n>`
performs the UIA LegacyIAccessible pattern's Microsoft Active Accessibility
default action, rejects elements known not to be enabled before calling UIA, and
returns refreshed post-action metadata without claiming value verification
because the default action's visible effect is provider-specific.
`automation set-legacy-value --index <n>` performs the UIA LegacyIAccessible
pattern's `SetValue` method for MSAA-backed controls, then verifies the
refreshed `legacyValue` metadata when UIA reports one.
`automation invoke --index <n>` performs
the UIA Invoke pattern for an element from that bounded traversal, rejecting
known disabled elements before calling UIA `Invoke`, and returns the pre-action
element metadata used for the invocation plus refreshed post-action metadata
when the bounded lookup can observe the same element afterward. It does not
claim value verification because the visible effect of Invoke is
provider-specific. `automation set-value` does the same for Value-pattern
elements, rejecting known disabled or read-only values before
calling UIA `SetValue`, then attempts a refreshed bounded lookup so the result
can include post-action element metadata and whether the requested value was
observed. `automation get-text` reads Text-pattern document, selected, or
visible ranges with a caller-provided max length capped at 4096 characters and
returns the text in the action `value`; the action is marked verified when the
bounded result matches Text-pattern metadata already visible in the pre-action
snapshot. `automation set-range-value` targets RangeValue-pattern elements,
rejecting known disabled elements, read-only values, and out-of-range values
before calling UIA `SetValue`, then verifies the refreshed numeric value when
UIA reports one.
`automation scroll` targets Scroll-pattern elements, rejects known unscrollable
requested axes before calling UIA `Scroll`, then verifies refreshed scroll
percentages moved in the requested direction when UIA reports them.
`automation set-scroll-percent` does the same for Scroll-pattern elements,
rejecting known unscrollable requested axes before calling UIA
`SetScrollPercent`, then verifies refreshed scroll percentages for requested
axes when UIA reports them. `automation set-window-state` performs the UIA
Window pattern visual-state action, rejects known unsupported maximize or
minimize requests before calling UIA `SetWindowVisualState`, then verifies the
refreshed visual state when UIA reports it. `automation close-window` performs
the UIA Window pattern close action, then verifies the original native window
handle disappeared when a handle and refreshed bounded snapshot are available.
`automation wait-window-idle` performs the UIA Window pattern input-idle wait
with a bounded timeout and reports whether UIA observed the window becoming
idle before the timeout. `automation set-dock-position`
performs the UIA Dock pattern action after rejecting known disabled elements,
then verifies the refreshed dock position when UIA reports it.
`automation set-current-view` performs the UIA MultipleView pattern action after
rejecting known disabled elements, then verifies the refreshed current view
identifier when UIA reports it. `automation set-zoom` performs the
UIA Transform2 pattern zoom action after rejecting known disabled elements and
known out-of-range requested levels when UIA exposes zoom limits, then verifies
the refreshed zoom level when UIA reports it. `automation zoom-by-unit` performs
the UIA Transform2 unit zoom action after rejecting known disabled elements, then
verifies that the refreshed zoom level moved in the requested direction when
pre/post zoom levels are observable. `automation scroll-into-view` performs the UIA ScrollItem pattern
action and verifies that the refreshed element is no longer off-screen when UIA
reports that state. `automation start-synchronized-input` performs the UIA
SynchronizedInput pattern's `StartListening` method for one requested keyboard
or mouse input type. `automation cancel-synchronized-input` performs the same
pattern's `Cancel` method. These actions return the pre-action element metadata
without claiming post-action verification because UIA does not expose a stable
listening-state property in the bounded snapshot.
`automation find-item --index <n> --property <name|automation-id> --value
<value>` performs the UIA ItemContainer pattern's `FindItemByProperty` method
from the start of the container and returns the matching item in
`resultElement`; the action is marked verified when that element reports a
matching Name or AutomationId property.
`automation navigate-custom --index <n>` performs the UIA CustomNavigation
pattern's `Navigate` method and marks the action verified when UIA returns a
target element for the requested direction.
`automation get-spreadsheet-item --index <n> --name <cell-name>` performs the
UIA Spreadsheet pattern's named cell lookup and marks the action verified when
the returned cell reports the requested name.
`automation get-grid-item --index <n> --row <row> --column <column>` performs
the UIA Grid pattern's `GetItem` method for zero-based coordinates and returns
the resulting grid item in `resultElement`; the action is marked verified when
that item reports the requested GridItem row and column metadata.
`automation move --index <n>` and
`automation resize --index <n>` perform the UIA Transform pattern move and
resize actions after rejecting known disabled or unsupported elements, then
verify the refreshed bounds when the bounded lookup can observe them.
`automation rotate --index <n>` performs the UIA Transform pattern rotate
action after rejecting known disabled or unsupported elements, then returns refreshed
post-action metadata without claiming value verification because the current
snapshot model has no rotation angle field. `automation realize --index <n>`
performs the UIA VirtualizedItem pattern realize action, then reports a
verified result when the refreshed bounded lookup no longer reports the item
as virtualized.
`automation toggle --index <n>`
performs the UIA Toggle pattern after rejecting known disabled elements, then
returns pre-action metadata plus any refreshed post-action element, including
the refreshed toggle state when UIA reports one.
`automation expand`
and `automation collapse` perform the UIA ExpandCollapse pattern, reject known
disabled elements and leaf nodes before calling UIA, and return refreshed post-action element
metadata with the latest expand/collapse state and verification of the target
expanded or collapsed state when UIA reports one.
`automation select` performs the UIA SelectionItem pattern after rejecting known
disabled elements, then returns refreshed post-action element metadata with
verification that the selected state is true when UIA reports it. `automation
toggle` verifies that the refreshed toggle state changed when both the
pre-action and post-action states are observable. `automation add-to-selection`
and `automation remove-from-selection` perform the matching UIA SelectionItem
methods after rejecting known disabled elements, then verify the refreshed
selected state when UIA reports it.

## Next Integration Steps

1. Continue routing the remaining main macOS CLI capture read paths through the
   same desktop adapter contract where the existing output behavior can be
   preserved.
2. Continue expanding the Windows UI Automation path from basic
   control-specific actions into richer action result verification where UIA
   exposes observable post-action state.
