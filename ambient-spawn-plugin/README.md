# Ambient Spawn Authoring Plugin

Standalone Roblox Studio plugin project for creating and tuning `EnemySpawnNode` parts used by `AmbientEnemyService`.

## What It Does

- Creates new ambient spawn nodes under `Workspace.Map.Islands.EnemyNodes`
- Tags nodes with `EnemySpawnNode`
- Applies ambient node attributes used by runtime systems
- Visualizes node radius for selected nodes
- Visualizes `MaxAlive` as marker previews distributed in radius
- Lets creatives choose enemy types for `EnemyPool` (CSV) from `EnemyCatalog`

## Runtime Compatibility

The plugin writes attributes expected by `ServerScriptService.Services.AmbientEnemyService`:

- `Enabled` (boolean)
- `Radius` (number)
- `EnemyWeight` (number)
- `MaxAlive` (number)
- `RespawnMin` (number)
- `RespawnMax` (number)
- `ActivationDistance` (number)
- `MinSpawnDistanceFromPlayer` (number)
- `IslandName` (string)
- `EnemyPool` (CSV string)

## Install / Sync

1. Open Roblox Studio.
2. Sync `ambient-spawn-plugin/default.project.json` with your preferred Rojo workflow, or manually create a plugin `Script` and paste:
   - `plugin.server.lua` as the root plugin script source
   - `src/` modules as child `ModuleScript`s under a folder named `src`
3. Enable the plugin and open the **Ambient Spawns** toolbar button.

## Build .rbxmx Package

From repo root:

```bash
npm run build:ambient-plugin
```

This writes:

- `ambient-spawn-plugin/AmbientSpawnPlugin.rbxmx`

## Usage Flow

1. Click `Create Node` to add a new node.
2. Select one or more tagged nodes.
3. Tune radius, max alive, respawn, and weighting values.
4. Toggle enemy types in the enemy list.
5. Use preview toggles for radius and max-enemy markers.

## Notes

- Visual previews are shown only for selected nodes.
- Live edits are applied directly to selected nodes.
- Preview instances are ephemeral under `Workspace.__AmbientSpawnPreview` and are cleaned on plugin unload.
