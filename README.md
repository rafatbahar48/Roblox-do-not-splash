# Still Water

A Roblox horror obby. Cross flooded pool rooms by jumping from tile to tile. Something lives in the water, and it hunts by sound.

- **Falling in** makes a big splash, and wading keeps making noise. If it reaches you in the water, you're gone.
- **Landing hard** (dropping off a tall pillar) and **creaky tiles** make noise too. If you're loud and it's close, it can pull you off a tile.
- **Pebbles** (3 per life): throw one into the water to draw it away before you cross.
- **Tiles to watch for:** creaky tiles (slightly yellow), sinking tiles (thin, bluish slabs that go under a second after you step on them), drifting rafts (orange) and pillars.
- **7 stages** with checkpoints. Each one has a hidden shell to collect. After the last stage, walk through the exit to escape.
- **Easy, Normal and Hard:** harder modes make you louder and the creature faster.
- Your progress, shells, escapes and difficulty are saved.

The whole map is built by script when the server starts, so everything lives in the Luau files under `src/`.

## Open it in Roblox Studio

You need [Roblox Studio](https://create.roblox.com/) and [Rojo](https://rojo.space/), which syncs these files into Studio.

1. Install Rojo:
   - **Studio plugin:** in Studio, open the Toolbox, search for "Rojo" and install the plugin by Rojo (rojo-rbx). Or follow the steps at https://rojo.space/docs/v7/getting-started/installation/.
   - **Command-line tool:** install [Aftman](https://github.com/LPGhatguy/aftman), then run `aftman install` in this folder. That installs the Rojo version listed in `aftman.toml`.
2. In this folder, run:
   ```
   rojo serve
   ```
3. In Studio, create a new **Baseplate** place. Open the Rojo plugin and click **Connect**. The scripts appear under ServerScriptService, ReplicatedStorage and StarterPlayerScripts.
4. Press **Play**. You spawn in the lobby, and the doorway leads to stage 1.

Or skip the live sync: run `rojo build -o StillWater.rbxl` and open the file in Studio.

### Before publishing

1. **File → Publish to Roblox.** Give it your own name, description and thumbnail.
2. **Game Settings → Security → Enable Studio Access to API Services.** Turn this on to test saving in Studio. Published games can always save.
3. **Sounds (optional):** paste sound ids from the Creator Store into `Config.Sounds` in `src/shared/Config.luau`. Slots without an id are skipped.

## Changing the game

| What | Where |
| --- | --- |
| Stages: length, gaps, tile mix, number of creatures, flickering lights | `src/shared/Stages.luau`. Add an entry to add a stage. |
| Noise amounts, creature speed and hearing, pebbles, difficulty modes | `src/shared/Config.luau` |
| Name and tagline on the lobby sign | `Config.GameName`, `Config.Tagline` |
| How rooms and tiles are built | `src/server/MapBuilder.luau` |
| Creature behaviour | `src/server/Lurker.luau` |
| HUD | `src/client/Hud.luau` |

Each stage's tile layout comes from a fixed random seed, so a stage looks the same every time. Change a stage's numbers to get a new layout.

## Layout

```
src/
  shared/              ReplicatedStorage.Shared
    Config.luau          tuning
    Stages.luau          stage list
    Remotes.luau         RemoteEvents
  server/              ServerScriptService.Server
    Main.server.luau     starts everything
    MapBuilder.luau      builds lobby, stages and exit
    Noise.luau           per-player noise, splashes, hard landings
    Lurker.luau          one creature
    Lurkers.luau         spawns and updates all creatures
    Hazards.luau         creaky/sinking tiles, rafts, flickering lights
    Pebbles.luau         thrown pebbles
    Progress.luau        checkpoints, shells, escapes, saving, spawning
    Effects.luau         splash rings and sounds
  client/              StarterPlayerScripts.Client
    Main.client.luau
    Hud.luau             stage, noise meter, warnings, difficulty buttons
    Throw.luau           throw input (E / R2 / touch button)
```
