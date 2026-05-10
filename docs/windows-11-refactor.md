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
ScreenCaptureKit, AXorcist, and macOS permission types. It defines neutral
desktop models and a `Win11DesktopAdapter` interface for Windows 11 automation
primitives:

- display enumeration
- visible window enumeration
- application enumeration from window-owning processes
- full-screen or display BMP capture through Win32 GDI

The production adapter is compiled only behind `#if os(Windows)` and imports
`WinSDK`. Non-Windows builds get `UnsupportedWin11DesktopAdapter`, which keeps
tests and documentation tooling from accidentally pretending the native backend
is available.

## Why This Seam

The existing macOS implementation leaks platform types through service
interfaces: `CGRect`, `CGWindowID`, `NSScreen`, ScreenCaptureKit, Accessibility,
and AXorcist are spread across capture, observation, window, input, and CLI
modules. A direct rename from macOS services to Windows services would make the
interface nearly as complex as the implementation.

The Windows 11 package starts with a smaller interface:

```swift
public protocol Win11DesktopAdapter: Sendable {
    func platformInfo() -> Win11PlatformInfo
    func listDisplays() throws -> [Win11Display]
    func listWindows(includeInvisible: Bool) throws -> [Win11Window]
    func listApplications() throws -> [Win11Application]
    func captureScreen(displayIndex: Int?, outputPath: String) throws -> Win11CaptureResult
}
```

That module is deliberately deep: callers get app/window/display/capture
behavior without learning HWND lifetimes, GDI device contexts, UTF-16 buffers,
or BMP header writing.

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
```

## Next Integration Steps

1. Move neutral geometry and desktop models into shared `PeekabooFoundation`
   after the Windows package is green on CI.
2. Add a platform-neutral desktop adapter seam in `PeekabooAutomationKit` and
   wire macOS as the first adapter, preserving current behavior.
3. Make CLI commands depend on the platform-neutral interface instead of
   directly importing Darwin/CoreGraphics/AppKit at the command layer.
4. Add Windows implementations for input and UI Automation after capture and
   enumeration have stable test coverage.
