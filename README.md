# Still Water

A Roblox horror obby. Cross a drowned forest at night by jumping from stump to stump over black water. Something very tall walks in that water, out among the trees, and it hunts by sound.

- **Falling in** makes a big splash, and wading keeps making noise. If it reaches you in the water, you're gone.
- **The creature**, one for the whole forest, watches from out in the thick fog, barely visible, while you stay out of the water. Touch the water and it comes out of the fog ahead of you, where your camera points, runs straight at you (much faster than you can wade), round you, closing in, and grabs you. If it gets you, it turns you round to face it: its gaping, toothed mouth up close, then a dead TV channel. Get out of the water and go quiet in time and it loses you. A pebble's splash draws it off to look.
- **Landing hard** (dropping off a tall broken trunk) and **creaky boards** make noise too.
- **Pebbles** (3 per life): throw one into the water to draw it away before you cross.
- **Stepping stones to watch for:** creaky boards (pale old planks on posts), floating moss (pale green mats that go under a second after you step on them), drifting rafts and narrow broken trunks.
- **7 stages**, each a stretch of the forest from one island to the next, with a checkpoint on the far island. Each one has a hidden shell to collect. After the last stage, walk through the exit to escape.
- **Easy, Normal and Hard:** harder modes make you louder and the creature faster.
- **The lobby** is a big open courtyard at night, under the stars, in front of the old brick building the stages are in: lit windows, the game's sign in neon, lamp posts, string lights, grass beds with palms and benches. It is colourful on purpose, so the forest feels darker after it. Nothing in the lobby shows what waits inside: the building hides the forest, and its doorways are pitch black until you step through. The east wall has the record boards (most escapes and the fastest escape on each difficulty) and the shop hut (G).
- **Three doors into stage 1**, one per difficulty (Easy, Normal, Hard). Stepping on a door's pad picks that difficulty; its screen shows how many people are in the water on it.
- **Party doors:** step on a party door's pad and a pop-up sets up a party: size (1 to 4), difficulty, friends only. Others join by stepping on the pad. When the countdown ends the party leaves together for a private server of its own (in Studio, which can't teleport, it goes straight into stage 1 instead).
- **Run timer:** starts when you walk through any of stage 1's doors and stops at the exit. A run counts for the easiest difficulty you played during it. Your best time on each difficulty is saved.
- **Pearls:** earned for each stage cleared, each shell found and each escape. Spend them in the **Shop** (the button at the bottom of the screen, or B).
- **The HUD** is in the same candy style as the menus: pearls and your stage top left, the run timer top middle, difficulty top right, the shop button at the bottom. In the stages it adds the noise meter on the left and round pebble, Updraft and Hush buttons bottom right, which work on touch screens too.
- **Shop:** 6 skins, 6 accessories, and 2 boosts you carry and use: **Updraft** (Q / L1 / Fly button) lifts you and lets you glide for 2 seconds, and **Hush** (F / Y / Hush button) makes you completely silent for 5 seconds.
- Your progress, shells, escapes, difficulty, pearls and items are saved.

The whole map is built by script when the server starts, so almost everything lives in the Luau files under `src/`. The exceptions are the 3D models made in Meshy (`art/models/`), which are imported into the place:

- **The lobby's props** live in `ServerStorage.LobbyProps`. The lobby uses `FloatHut` (the shop), `PottedPalm` and `Planter`, places each one it finds and skips any that are missing.
- **The forest's trees** near the trail are the models in `ServerStorage.ForestProps` (`GnarledTree` and `BrokenTrunk`, from `art/models/dead-tree3.glb` and `dead-tree2.glb`, each standing on its own pivot at the bottom of its roots). Each is planted at a random size and turn, with an invisible post round its trunk. Far off in the fog, or without the models, trees are built from parts.
- **The creature** is the model in `ReplicatedStorage.Creatures` (now `Creature`, from `art/models/flesh-creature-rigged.glb`: remeshed to about 10,000 triangles and rigged in Meshy, scaled to 18 studs, facing -Z). Each client poses its bones as it walks, so any model with Meshy's humanoid skeleton works. Attributes on the model say whether it has its own mouth (`OwnMouth`), whether to add glowing eyes (`Eyes`), and how the death scene frames its mouth (`CloseUpDistance`, `CloseUpHeight`, `CloseUpAim`). Without a model, a body built from parts stands in. The earlier stilt wader is still in `art/models/stilt-wader-rigged.glb`.

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
| Stages: length, gaps, stepping stone mix, flickering lanterns | `src/shared/Stages.luau`. Add an entry to add a stage. |
| How wide the forest is, trees, islands, lanterns | `Config.Forest` |
| Noise amounts, creature speed and hearing, pebbles, difficulty modes | `src/shared/Config.luau` |
| Name and tagline on the lobby sign | `Config.GameName`, `Config.Tagline` |
| How each stretch is laid out, lighting, fog and colour grading | `src/server/MapBuilder.luau` |
| What trees, stumps, islands, lanterns and signposts look like | `src/server/Forest.luau` |
| Lobby: size (`Config.Room.LobbyWidth`, `LobbyLength`), the building, doors and party doors, signs, record wall, lamps and string lights, where each prop stands, spawn | `src/server/LobbyBuilder.luau` |
| Where the difficulty doors are; party size and countdowns | `Config.Room.EntranceDoors`, `Config.Party` |
| Difficulty door pads and screens | `src/server/LobbyDoors.luau` |
| Parties: joining, leaving, countdown, sending a party to its own server | `src/server/Parties.luau` |
| The party pop-up and banner | `src/client/PartyUi.luau` |
| Record boards (titles, colours, refresh rate) | `src/server/Leaderboards.luau` |
| Moonlit lobby and exit lighting | `src/client/Mood.luau` |
| Creature behaviour | `src/server/Lurker.luau` |
| Creature look: posing the Meshy model, how it walks, runs and grabs, the part-built stand-in | `src/client/LurkerVisuals.luau` |
| Fear effects: vignette, heartbeat, faltering lights, camera shake | `src/client/Fear.luau` |
| Being caught: turned to face it, the close-up as its mouth opens, the TV static, "what it heard" recap | `src/client/DeathScene.luau` (the cause comes from `src/server/Noise.luau`) |
| Shop items, names, prices and skin colours | `src/shared/Catalog.luau` |
| Accessory shapes | `src/server/Cosmetics.luau` |
| Pearls per stage, shell and escape; boost timing | `Config.Pearls`, `Config.Boosts` |
| HUD | `src/client/Hud.luau` |
| The candy look shared by the HUD, menus and record boards: colours, raised panels, chunky buttons, lettering | `src/shared/Candy.luau` |
| Shop item pictures | `src/client/ItemIcons.luau` |

Each stage's layout comes from a fixed random seed, so a stage looks the same every time. Change a stage's numbers to get a new layout.

## Layout

```
src/
  shared/              ReplicatedStorage.Shared
    Config.luau          tuning
    Stages.luau          stage list
    Catalog.luau         shop items
    Format.luau          time formatting
    Candy.luau           the shared candy UI look (colours, panels, buttons)
    Remotes.luau         RemoteEvents
  server/              ServerScriptService.Server
    Main.server.luau     starts everything
    MapBuilder.luau      builds the forest stages and the way out; lighting
    Forest.luau          trees, stumps, islands, lanterns, signposts
    LobbyBuilder.luau    builds the night courtyard lobby
    Parts.luau           part-building helpers both builders use
    LobbyDoors.luau      the difficulty doors' pads and screens
    Parties.luau         party doors: parties, countdowns, private servers
    Leaderboards.luau    record boards (OrderedDataStores)
    Noise.luau           per-player noise, splashes, hard landings, Hush
    Lurker.luau          one creature: watching, stalking, chasing (moves an invisible anchor)
    Lurkers.luau         spawns and updates all creatures
    Hazards.luau         creaky boards, sinking moss, rafts, flickering lanterns
    Pebbles.luau         thrown pebbles
    Progress.luau        checkpoints, shells, escapes, run timer, pearls, items, saving, spawning
    Shop.luau            buying, wearing and using items (all checks on the server)
    Cosmetics.luau       puts skins and accessories on characters
    Effects.luau         splash rings and sounds
  client/              StarterPlayerScripts.Client
    Main.client.luau
    Hud.luau             pearls, stage, timer, difficulty, noise meter, shop and action buttons
    ShopUi.luau          the shop window
    ItemIcons.luau       pictures of the shop's items
    PartyUi.luau         the party pop-up and banner
    Boosts.luau          boost input (Q / F / the HUD's buttons) and Updraft flight
    LurkerVisuals.luau   poses the creature model (or a body of parts) as it walks
    Fear.luau            vignette, heartbeat, faltering lights, shake
    DeathScene.luau      the death scene: its face up close, TV static, "what it heard"
    Mood.luau            warm lobby and exit lighting, cold forest fog, drifting mist
    Throw.luau           throw input (E / R2 / the HUD's pebble button)
    CameraReport.luau    tells the server which way your camera points (for where the creature appears)
```
