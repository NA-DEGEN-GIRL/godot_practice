# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **Godot 4.6** project that hosts the **Godot MCP (Model Context Protocol) addon** (`addons/godot_mcp/`). The addon is an EditorPlugin that runs a WebSocket server inside the Godot editor, allowing AI assistants to control and inspect Godot projects through JSON-based commands. It is not a game — it is a development tool/plugin.

The external MCP server bridge is `@satelliteoflove/godot-mcp` (Node.js, configured in `.mcp.json`). The addon itself is pure **GDScript** with all scripts marked `@tool` to run in the editor.

## Architecture

### Communication Flow

```
Claude AI ↔ Node.js MCP Server ↔ WebSocket (port 6550) ↔ Godot EditorPlugin
                                                              ↕
                                                     EngineDebugger
                                                              ↕
                                                     Running Game (MCPGameBridge autoload)
```

### Key Components

- **`plugin.gd`** — Main EditorPlugin entry point. Manages lifecycle, settings persistence, WebSocket server, status panel UI, and debugger plugin registration.
- **`websocket_server.gd`** — TCPServer-based WebSocket listener (single client, 16MB buffer). Handles JSON request/response framing.
- **`command_router.gd`** — Registers 13 command handler classes and dispatches incoming commands via `await callable.call(params)`.
- **`core/base_command.gd`** (`MCPBaseCommand`) — Base class for all command handlers. Provides `_success()`, `_error()`, `_get_node()`, `_require_scene_open()`, and other shared helpers.
- **`game_bridge/mcp_game_bridge.gd`** — AutoLoad singleton in running games. Handles screenshot capture, debug output, performance metrics, input injection, and node queries at runtime.
- **`core/mcp_debugger_plugin.gd`** — EditorDebuggerPlugin bridging editor ↔ running game via `EngineDebugger` message passing (prefix: `"godot_mcp"`).

### Command Handler Pattern

Each file in `commands/` extends `MCPBaseCommand` and overrides `get_commands()` to return a `Dictionary` mapping command name strings to `Callable` methods. The router collects these at startup. Command methods are async (return via `await`) and must return either `_success({...})` or `_error("CODE", "message")`.

Handler categories: system, scene, node, script, selection, project, debug, screenshot, animation, tilemap, resource, scene3d, input.

### Adding a New Command

1. Create or edit a handler in `addons/godot_mcp/commands/`.
2. Extend `MCPBaseCommand`, override `get_commands()` returning `{"command_name": my_method}`.
3. Register the handler in `command_router.gd` → `setup()`.
4. Use `MCPUtils.success()` / `MCPUtils.error()` for responses; use `MCPUtils.serialize_value()` for Godot→JSON type conversion.

### Request/Response Protocol

```json
// Request
{"id": "req_1", "command": "get_scene_tree", "params": {}}

// Success response
{"id": "req_1", "status": "success", "result": {...}}

// Error response
{"id": "req_1", "status": "error", "error": {"code": "NO_SCENE", "message": "..."}}
```

## Configuration

- **Bind mode** — Localhost (default), WSL, or Custom IP. Stored in `project.godot` under `[godot_mcp]`.
- **Port** — Default 6550, configurable via port override setting.
- **Plugin version** — Declared in `addons/godot_mcp/plugin.cfg` (currently v2.15.0, minimum Godot 4.5).

## Development Notes

- All addon scripts use `@tool` annotation — they execute in the editor, not just at runtime.
- Async operations (screenshots, debug output, runtime node queries, input sequences) use GDScript `await` with signal-based timeouts (5–30 seconds).
- The logging system (`mcp_logger.gd`) is thread-safe via Mutex, with bounded history (1000 lines, 100 errors).
- `MCPGameBridge` communicates with the editor via `EngineDebugger.send_message()` — not WebSocket.
