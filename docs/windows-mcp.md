---
title: Windows MCP
summary: 'Windows MCP stdio bridge, supported tool subset, and unsupported macOS-only tools.'
description: Use peekaboo-win11.exe mcp serve to expose Windows desktop automation to MCP clients.
read_when:
  - 'connecting an MCP client to the Windows fork'
  - 'checking supported and unsupported Windows MCP tools'
---

# Windows MCP

`peekaboo-win11.exe mcp serve` starts a line-delimited JSON-RPC MCP server over stdio. It is backed by the Windows desktop adapter instead of the original macOS agent runtime, so it exposes the first practical Windows desktop tool subset while documenting macOS-only gaps clearly.

## Start the server

```powershell
.\peekaboo-win11.exe mcp serve
```

The process reads JSON-RPC messages from stdin and writes JSON-RPC responses to stdout. Logs and client-side process supervision belong to the MCP client.

## Supported tools

| Tool | Purpose |
| --- | --- |
| `list` | Running apps, windows, displays, and server status |
| `image` | Screen, display, area, foreground-window, app-window, and window-ID BMP capture |
| `see` / `observe` | Screenshot plus bounded UI Automation snapshot and snapshot ID |
| `snapshot` | Get, list, or clear in-process snapshots from `see` / `observe` |
| `move` | Move the cursor |
| `click` | Click at a point |
| `scroll` | Wheel-scroll at a point |
| `drag` | Drag between two points |
| `hotkey` | Send modifier/virtual-key hotkeys |
| `type` | Type focused text |
| `uia` | UIA status, snapshot/inspect, focus, invoke, value, toggle, expand/collapse, and select actions |
| `perform_action` | Alias-style UIA action entry point |
| `set_value` | Convenience value-setting action |

## Smoke test

```powershell
@(
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"smoke","version":"1.0"}}}'
  '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}'
  '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'
  '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"list","arguments":{"item_type":"server_status"}}}'
) -join "`n" | .\peekaboo-win11.exe mcp serve
```

## Unsupported macOS-only tools

The Windows MCP bridge intentionally does not advertise the macOS-only tool set until equivalent Windows services exist. Unsupported tools include `agent`, `analyze`, `browser`, `clipboard`, `dialog`, `dock`, `menu`, `paste`, `permissions`, and `space`.

The current bridge preserves original command/tool behavior where practical by keeping names such as `list`, `image`, `see`, `click`, `type`, `hotkey`, `scroll`, `drag`, `perform_action`, and `set_value`, while routing them through the Windows adapter.
