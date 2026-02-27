# Roblox Studio MCP Server

**Connect AI assistants like Claude and Gemini to Roblox Studio**

[![NPM Version](https://img.shields.io/npm/v/robloxstudio-mcp)](https://www.npmjs.com/package/robloxstudio-mcp)

---

## What is This?

An MCP server that lets AI explore your game structure, read/edit scripts, and perform bulk changes all locally and safely.

## Setup

1. Install the [Studio plugin](https://github.com/boshyxd/robloxstudio-mcp/releases) to your Plugins folder
2. Enable **Allow HTTP Requests** in Experience Settings > Security
3. Connect your AI:

**Claude Code:**
```bash
claude mcp add robloxstudio -- npx -y robloxstudio-mcp@latest
```

**Codex CLI:**
```bash
codex mcp add robloxstudio -- npx -y robloxstudio-mcp@latest
```

**Gemini CLI:**
```bash
gemini mcp add robloxstudio npx --trust -- -y robloxstudio-mcp@latest
```

Plugin shows "Connected" when ready.

## Multi-Instance Support

- Each MCP process now auto-binds to the next free port starting at `58741` (or `ROBLOX_STUDIO_PORT`).
- Port scan upper bound is configurable with `ROBLOX_STUDIO_MAX_PORT` (default `65535`).
- On startup, the server prints a machine-readable line:

```text
MCP_INSTANCE_STARTED {"instanceId":"...","host":"0.0.0.0","port":58741,"pid":12345}
```

- Running instances are tracked in a shared local registry (temp directory by default).
- New MCP tools:
  - `list_mcp_instances`
  - `get_mcp_instance_context`
- Plugin UI now shows running servers, plugin connection state, and connected place context.

<details>
<summary>Other MCP clients (Claude Desktop, Cursor, etc.)</summary>

```json
{
  "mcpServers": {
    "robloxstudio-mcp": {
      "command": "npx",
      "args": ["-y", "robloxstudio-mcp@latest"]
    }
  }
}
```

**Windows users:** If you encounter issues, use `cmd`:
```json
{
  "mcpServers": {
    "robloxstudio-mcp": {
      "command": "cmd",
      "args": ["/c", "npx", "-y", "robloxstudio-mcp@latest"]
    }
  }
}
```
</details>

## What Can You Do?

Ask things like: *"What's the structure of this game?"*, *"Find scripts with deprecated APIs"*, *"Create 50 test NPCs in a grid"*, *"Optimize this movement code"*

---

**v2.3.0** - 39+ tools, multi-instance support, shared context registry, improved plugin observability

[Report Issues](https://github.com/boshyxd/robloxstudio-mcp/issues) | [DevForum](https://devforum.roblox.com/t/v180-roblox-studio-mcp-speed-up-your-workflow-by-letting-ai-read-paths-and-properties/3707071) | MIT Licensed
