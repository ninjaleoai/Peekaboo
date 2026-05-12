---
title: Peekaboo Windows documentation
summary: 'Entry point for the Windows 11 fork, packaged CLI, MCP bridge, and current support boundaries.'
description: Windows 11 automation that sees the screen and does the clicks. Native Swift CLI, Win32 input, UI Automation, and MCP stdio bridge.
read_when:
  - 'starting with the Peekaboo Windows 11 fork'
  - 'linking the public Windows fork documentation hub from README, site, or release notes'
---

# Peekaboo Windows documentation

Peekaboo for Windows is a Windows 11 fork of Peekaboo that brings the core desktop automation loop to a native Swift package. It captures BMP screenshots, enumerates displays/windows/apps, drives Win32 mouse and keyboard input, inspects bounded UI Automation trees, and exposes the first Windows MCP stdio bridge for agent clients.

> **Status** — Untested Windows fork built through Codex `/goal`. The first Windows refactor pass took 1d 7h 55m. A second pass connected the original agent/MCP product layer to the Windows adapter and took 46m 17s.

## Where to start

- **[Windows quickstart](windows-quickstart.md)** — get the packaged artifact, verify it, and run the first commands.
- **[Windows CLI](windows-cli.md)** — current `peekaboo-win11.exe` command surface.
- **[Windows MCP](windows-mcp.md)** — `peekaboo-win11.exe mcp serve`, supported tools, and unsupported macOS-only tools.
- **[Windows refactor notes](windows-11-refactor.md)** — deeper implementation details and verification history.

## What the Windows fork does

- **Capture** — screen, display, area, window, and foreground-window BMP capture through Win32-backed paths.
- **Discovery** — display, visible-window, and running-application enumeration with structured JSON.
- **Input** — cursor position, cursor movement, clicks, wheel scrolling, drags, modifier hotkeys, and focused text typing.
- **UI Automation** — bounded snapshots, element lookup, focus/invoke/value/toggle/expand/collapse/select actions, and richer UIA metadata.
- **MCP** — an agent-usable stdio server exposing list, capture/observe, snapshots, input, and UIA actions through the Windows adapter.

## Current limits

- The standalone Windows artifact does not package the macOS natural-language `agent` runtime yet.
- macOS-only tools such as menus, Dock, Spaces, dialogs, clipboard, browser, permissions, and provider-backed analysis remain unsupported in the Windows bridge.
- Verification is Windows-focused: the Windows 11 Platform workflow builds, tests, packages, verifies, smoke-tests the packaged CLI/MCP server, and uploads the artifact.

## Surfaces

| Surface | Use it for | Entry point |
| --- | --- | --- |
| **Windows CLI** | scripts, captures, desktop inspection, smoke tests | `peekaboo-win11.exe` |
| **Windows MCP server** | Codex or other MCP clients over stdio | `peekaboo-win11.exe mcp serve` |
| **Shared desktop contract** | neutral command/service model for platform adapters | `Core/PeekabooDesktop` |
| **Windows adapter** | Win32, GDI, input, and UI Automation backend | `Platforms/Windows/PeekabooWin11` |

## Get help

- File issues: [github.com/ninjaleoai/Peekaboo/issues](https://github.com/ninjaleoai/Peekaboo/issues)
- Source: [github.com/ninjaleoai/Peekaboo](https://github.com/ninjaleoai/Peekaboo)
- Upstream original: [github.com/openclaw/Peekaboo](https://github.com/openclaw/Peekaboo)
