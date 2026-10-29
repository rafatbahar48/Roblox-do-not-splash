# Still Water

A Roblox horror obby. Cross flooded pool rooms by jumping from tile to tile. Something lives in the water, and it hunts by sound.

- **Falling in** makes a big splash, and wading keeps making noise. If it reaches you in the water, you're gone.
- **Landing hard** (dropping off a tall pillar) and **creaky tiles** make noise too. If you're loud and it's close, it can pull you off a tile.
- **Pebbles** (3 per life): throw one into the water to draw it away before you cross.
- **Tiles to watch for:** creaky tiles (slightly yellow), sinking tiles (thin, bluish slabs that go under a second after you step on them), drifting rafts (orange) and pillars.
- **7 stages** with checkpoints. Each one has a hidden shell to collect. After the last stage, walk through the exit to escape.
- **Easy, Normal and Hard:** harder modes make you louder and the creature faster.
- **The lobby** is a big open courtyard at night, under the stars, in front of the old brick building the stages are in: lit windows, the game's sign in neon, lamp posts, string lights, grass beds with palms and benches. It is colourful on purpose, so the rooms feel darker after it. The building's west wing has a flooded ground-floor window (stand by the glass and the creature inside comes to stare at you); the east wall has the record boards (most escapes and the fastest escape on each difficulty) and the shop hut (G).
- **Three doors into stage 1**, one per difficulty (Easy, Normal, Hard). Stepping on a door's pad picks that difficulty; its screen shows how many people are in the water on it.
- **Party doors:** step on a party door's pad and a pop-up sets up a party: size (1 to 4), difficulty, friends only. Others join by stepping on the pad. When the countdown ends the party leaves together for a private server of its own (in Studio, which can't teleport, it goes straight into stage 1 instead).
- **Run timer:** starts when you walk through any of stage 1's doors and stops at the exit. A run counts for the easiest difficulty you played during it. Your best time on each difficulty is saved.
- **Pearls:** earned for each stage cleared, each shell found and each escape. Spend them in the **Shop** (button under the difficulty buttons, or B).
- **Shop:** 6 skins, 6 accessories, and 2 boosts you carry and use: **Updraft** (Q / L1 / Fly button) lifts you and lets you glide for 2 seconds, and **Hush** (F / Y / Hush button) makes you completely silent for 5 seconds.
- Your progress, shells, escapes, difficulty, pearls and items are saved.

The whole map is built by script when the server starts, so almost everything lives in the Luau files under `src/`. The exception is the lobby's 3D props, made in Meshy (`art/models/`): they are imported into the place and kept in `ServerStorage.LobbyProps`. The lobby uses `FloatHut` (the shop), `PottedPalm` and `Planter`, places each one it finds and skips any that are missing.

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
| How rooms and tiles are built, lighting, fog and colour grading | `src/server/MapBuilder.luau` |
| Lobby: size (`Config.Room.LobbyWidth`, `LobbyLength`), the building, doors and party doors, signs, flooded window, record wall, lamps and string lights, where each prop stands, spawn | `src/server/LobbyBuilder.luau` |
| Where the difficulty doors are; party size and countdowns | `Config.Room.EntranceDoors`, `Config.Party` |
| Difficulty door pads and screens | `src/server/LobbyDoors.luau` |
| Parties: joining, leaving, countdown, sending a party to its own server | `src/server/Parties.luau` |
| The party pop-up and banner | `src/client/PartyUi.luau` |
| The aquarium creature | `src/server/LobbyTank.luau` |
| Record boards (titles, colours, refresh rate) | `src/server/Leaderboards.luau` |
| Moonlit lobby and exit lighting | `src/client/Mood.luau` |
| Creature behaviour | `src/server/Lurker.luau` |
| Creature look and swimming animation | `src/client/LurkerVisuals.luau` |
| Fear effects: vignette, heartbeat, faltering lights, camera shake | `src/client/Fear.luau` |
| Being caught: dragged under, "what it heard" recap, coming back up | `src/client/DeathScene.luau` (the cause comes from `src/server/Noise.luau`) |
| Shop items, names, prices and skin colours | `src/shared/Catalog.luau` |
| Accessory shapes | `src/server/Cosmetics.luau` |
| Pearls per stage, shell and escape; boost timing | `Config.Pearls`, `Config.Boosts` |
| HUD | `src/client/Hud.luau` |

Each stage's tile layout comes from a fixed random seed, so a stage looks the same every time. Change a stage's numbers to get a new layout.

## Layout

```
src/
  shared/              ReplicatedStorage.Shared
    Config.luau          tuning
    Stages.luau          stage list
    Catalog.luau         shop items
    Format.luau          time formatting
    Remotes.luau         RemoteEvents
  server/              ServerScriptService.Server
    Main.server.luau     starts everything
    MapBuilder.luau      builds stages and exit; lighting
    LobbyBuilder.luau    builds the night courtyard lobby
    Parts.luau           part-building helpers both builders use
    LobbyDoors.luau      the difficulty doors' pads and screens
    Parties.luau         party doors: parties, countdowns, private servers
    LobbyTank.luau       the creature behind the lobby's flooded window
    Leaderboards.luau    record boards (OrderedDataStores)
    Noise.luau           per-player noise, splashes, hard landings, Hush
    Lurker.luau          one creature (moves an invisible anchor)
    Lurkers.luau         spawns and updates all creatures
    Hazards.luau         creaky/sinking tiles, rafts, flickering lights
    Pebbles.luau         thrown pebbles
    Progress.luau        checkpoints, shells, escapes, run timer, pearls, items, saving, spawning
    Shop.luau            buying, wearing and using items (all checks on the server)
    Cosmetics.luau       puts skins and accessories on characters
    Effects.luau         splash rings and sounds
  client/              StarterPlayerScripts.Client
    Main.client.luau
    Hud.luau             stage, noise meter, warnings, difficulty buttons, pearls
    ShopUi.luau          the shop window
    PartyUi.luau         the party pop-up and banner
    Boosts.luau          boost input and Updraft flight
    LurkerVisuals.luau   creature bodies and swimming animation
    Fear.luau            vignette, heartbeat, faltering lights, shake
    DeathScene.luau      the pulled-under death sequence and "what it heard" recap
    Mood.luau            moonlit lobby and exit lighting, dark rooms
    Throw.luau           throw input (E / R2 / touch button)
```
