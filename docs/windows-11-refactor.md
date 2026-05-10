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

The `peekaboo-win11` executable now delegates its basic command parsing to
`DesktopCommandRunner` in `PeekabooDesktop`. The Windows target owns native
adapter construction; the shared package owns the platform-neutral
`platform-info`, `list`, `capture screen`, and `capture area` command contract.

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
first capture read paths are also routed through the adapter: compatible
`image --mode screen` PNG captures now use `DesktopAsyncAdapter.captureScreen`,
and compatible `image --mode area --region x,y,width,height` PNG captures now
use `DesktopAsyncAdapter.captureArea`. Retina, forced-engine, JPG, and
frontmost captures stay on the existing macOS observation pipeline. Window
capture is now part of the neutral desktop adapter and the Windows platform CLI
can capture a window by ID through the existing Win32 region capture path. The
main macOS `image --mode window` path stays on the existing observation
pipeline until a behavior-compatible adapter route is proven.

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
```

The first Windows window capture is region-backed: the adapter resolves the
enumerated window bounds for the requested ID, then captures that screen
rectangle to BMP.

## Next Integration Steps

1. Continue routing the remaining main macOS CLI capture read paths through the
   same desktop adapter contract where the existing output behavior can be
   preserved.
2. Add Windows implementations for input and UI Automation after capture and
   enumeration have stable test coverage.
