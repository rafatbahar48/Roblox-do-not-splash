# Still Water

Roblox horror obby, written as a Rojo project (`default.project.json`). The map is built by script at server start, so the place looks empty in edit mode; press Play to see it.

- `src/shared` → ReplicatedStorage.Shared (Config, Stages, Remotes)
- `src/server` → ServerScriptService.Server (Main.server.luau starts everything)
- `src/client` → StarterPlayerScripts.Client (HUD and throw input)

Edit the `.luau` files here, not the scripts inside Studio: `rojo serve` syncs files into Studio one way, so script edits made in Studio are overwritten.

The `robloxstudio` MCP server (`.mcp.json`) talks to the Roblox Studio plugin. Use it to inspect the running place, start play tests and read Output errors.
