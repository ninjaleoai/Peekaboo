---
title: Windows CLI
summary: 'Current peekaboo-win11.exe command surface and support boundaries.'
description: Windows 11 command reference for the packaged Peekaboo fork.
read_when:
  - 'looking for supported Windows CLI commands'
  - 'checking which original Peekaboo commands exist in the Windows fork'
---

# Windows CLI

`peekaboo-win11.exe` is the standalone Windows 11 command-line entry point. It is backed by `Core/PeekabooDesktop` for the neutral command model and `Win32DesktopAdapter` for native Windows behavior.

## Commands

| Command | Key arguments | What it does |
| --- | --- | --- |
| `platform-info` | none | Report Windows platform metadata and native capabilities |
| `list` | `apps`, `windows`, `displays`, `--include-invisible` | Enumerate apps, windows, and displays |
| `capture screen` | `--path`, `--display-id` | Capture a full display or the desktop to BMP |
| `capture area` | `--rect`, `--path` | Capture a rectangular screen area to BMP |
| `capture window` | `--id`, `--path` | Capture a window by ID to BMP |
| `capture frontmost` | `--path` | Capture the foreground window to BMP |
| `input position` | none | Read the cursor position |
| `input move` | `--point` | Move the cursor |
| `input click` | `--point`, `--button`, `--count` | Click at a point |
| `input scroll` | `--point`, `--direction`, `--amount` | Wheel-scroll at a point |
| `input drag` | `--from`, `--to`, `--button`, `--steps` | Drag between two points |
| `input hotkey` | `--keys`, `--hold-ms` | Send modifier/virtual-key hotkeys |
| `input type` | `--text`, `--delay-ms` | Type focused text |
| `automation status` | none | Probe Windows UI Automation availability |
| `automation snapshot` | `--scope`, `--max-depth`, `--max-elements` | Capture a bounded UIA control-view snapshot |
| `automation element` | `--index`, snapshot flags | Return one UIA element from a bounded snapshot |
| `automation invoke` | `--index`, snapshot flags | Invoke a UIA element when the pattern is available |
| `automation focus` | `--index`, snapshot flags | Set UIA focus on an element |
| `automation set-value` | `--index`, `--value` | Set a UIA Value-pattern element |
| `automation toggle` | `--index`, snapshot flags | Toggle a UIA Toggle-pattern element |
| `automation expand` / `collapse` | `--index`, snapshot flags | Expand or collapse a UIA element |
| `automation select` | `--index`, snapshot flags | Select a UIA SelectionItem-pattern element |
| `mcp serve` | stdio JSON-RPC | Expose the Windows desktop subset to MCP clients |

## Verification

The Windows package verifier checks the packaged CLI, checksum, manifest/build metadata, help text, platform info, desktop enumeration, capture commands, UI Automation status/snapshot/element lookup, and a packaged MCP stdio smoke.

Run the full package verification on Windows:

```powershell
.\scripts\windows\build-win11.ps1
.\scripts\windows\package-win11.ps1
.\scripts\windows\verify-package-win11.ps1
```

## Unsupported original commands

The standalone Windows artifact does not currently package the macOS natural-language `agent` runtime, provider-backed `analyze`, or macOS-only tools for menus, Dock, Spaces, dialogs, clipboard, browser control, and macOS permissions.
