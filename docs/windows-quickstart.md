---
title: Windows quickstart
summary: 'Download, verify, and run the packaged Peekaboo Windows 11 CLI.'
description: Start using peekaboo-win11.exe from the Windows 11 Platform workflow artifact.
read_when:
  - 'trying the Windows 11 fork for the first time'
  - 'verifying the packaged Windows CLI artifact'
---

# Windows quickstart

The Windows fork ships as a packaged GitHub Actions artifact from the **Windows 11 Platform** workflow. The artifact contains `peekaboo-win11.zip`, a SHA-256 checksum, `PACKAGE_MANIFEST.json`, `BUILD_INFO.txt`, and a packaged README.

## Install

1. Open the latest successful **Windows 11 Platform** workflow run on the fork.
2. Download the `peekaboo-win11-<commit-sha>` artifact.
3. Extract the artifact, then verify the zip checksum:

```powershell
Get-FileHash -Algorithm SHA256 .\peekaboo-win11.zip
Get-Content .\peekaboo-win11.zip.sha256
```

4. Extract `peekaboo-win11.zip`, then run:

```powershell
.\peekaboo-win11.exe --help
.\peekaboo-win11.exe platform-info
```

## First commands

```powershell
# List displays, windows, and apps
.\peekaboo-win11.exe list displays
.\peekaboo-win11.exe list windows
.\peekaboo-win11.exe list apps

# Capture the desktop, an area, a window, or the foreground window
.\peekaboo-win11.exe capture screen --path .\screen.bmp
.\peekaboo-win11.exe capture area --rect 0,0,640,480 --path .\area.bmp
.\peekaboo-win11.exe capture window --id <window-id> --path .\window.bmp
.\peekaboo-win11.exe capture frontmost --path .\frontmost.bmp

# Read and drive input
.\peekaboo-win11.exe input position
.\peekaboo-win11.exe input move --point 100,100
.\peekaboo-win11.exe input click --point 100,100 --button left --count 1
.\peekaboo-win11.exe input type --text "hello from Windows" --delay-ms 5

# Inspect Windows UI Automation
.\peekaboo-win11.exe automation status
.\peekaboo-win11.exe automation snapshot --scope foreground --max-depth 2 --max-elements 64
```

## Agent entry point

Start the Windows MCP stdio bridge for MCP clients:

```powershell
.\peekaboo-win11.exe mcp serve
```

Use this for the current agent-usable Windows subset: list, image capture, observe/see, snapshots, input actions, and UI Automation inspection/actions.
