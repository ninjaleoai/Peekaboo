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
- bounded native UI Automation root, foreground-window, or focused-element
  snapshots through the UIA control view walker

The `peekaboo-win11` executable now delegates its basic command parsing to
`DesktopCommandRunner` in `PeekabooDesktop`. The Windows target owns native
adapter construction; the shared package owns the platform-neutral
`platform-info`, `list`, `capture screen`, `capture area`, `capture window`,
`capture frontmost`, `input position`, `input move`, `input click`,
`input scroll`, `input drag`, `input hotkey`, and `input type` command
contract, plus `automation status` and bounded `automation snapshot` UI
Automation commands.

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
snapshot path can start at the desktop root, foreground window, or focused
element, then walks the UIA control view with explicit `--max-depth` and
`--max-elements` limits. Snapshot elements include the raw control type, stable
non-localized control type name, localized control type, name, automation
identifier, class name, process ID, native window handle, bounds, depth, parent
index, and child count. Root snapshots should stay shallow because desktop-wide
UIA traversal is expensive.

## Next Integration Steps

1. Continue routing the remaining main macOS CLI capture read paths through the
   same desktop adapter contract where the existing output behavior can be
   preserved.
2. Expand the Windows UI Automation path from read-only snapshots into element
   lookup, invoke/value patterns, and stable control-type/action mapping.
