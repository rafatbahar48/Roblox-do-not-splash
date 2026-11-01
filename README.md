# The Silent Swamp

A Roblox horror obby. Cross a drowned forest at night by jumping from stump to stump over black water. Something very tall walks in that water, out among the trees, and it hunts by sound.

- **Falling in** makes a big splash, and wading keeps making noise. If it reaches you in the water, you're gone.
- **The creature**, one for the whole forest, watches from out in the thick fog, barely visible, while you stay out of the water. Touch the water and it comes out of the fog ahead of you, where your camera points, runs straight at you (much faster than you can wade), round you, closing in, and grabs you. If it gets you, it turns you round to face it: its gaping, toothed mouth up close, then a dead TV channel. Get out of the water and go quiet in time and it loses you. A pebble's splash draws it off to look.
- **Landing hard** (dropping off a tall broken trunk) and **creaky boards** make noise too.
- **Pebbles** (3 per life): throw one into the water to draw it away before you cross.
- **Stepping stones to watch for:** creaky boards (pale old planks on posts), floating moss (pale green mats that go under a second after you step on them), drifting rafts and narrow broken trunks.
- **7 stages**, each a stretch of the forest from one island to the next, with a checkpoint on the far island. Each one has a hidden shell to collect. After the last stage, walk through the exit to escape.
- **Easy, Normal and Hard:** harder modes make you louder and the creature faster.
- **The lobby** is a big open courtyard at night, under the stars, in front of the old brick building the stages are in: lit windows, the game's sign in neon, lamp posts, string lights, grass beds with palms and benches. It is colourful on purpose, so the forest feels darker after it. Nothing in the lobby shows what waits inside: the building hides the forest, and its doors stay shut. The east wall has the record boards (most escapes and the fastest escape on each difficulty) and the shop (G): a snowy log cottage with Christmas lights, a striped awning over its counter, a wreath and a snowman, made in Meshy, with a SHOP sign from SpriteCook.
- **Christmas in the lobby** (`Config.Christmas`, on for now): snow over the courtyard with a path shovelled to the doors, snow on every roof, wall, bench and lamp, falling snow, decorated Christmas trees in the beds (a big one with presents under it), wreaths on the doors, frozen puddles, and "Haunted Sleigh Bells" instead of the music box. **Snowball fights:** grab snowballs from a pile (G, up to 10) and throw them (E, R2 or the snowball button). A hit splats snow in their face and tells you both; it never moves anyone, so nobody gets knocked off a party pad. Snowballs only work in the lobby. Set `Config.Christmas = false` after the holidays to bring the palms back.
- **Five doors, and nobody walks through them.** You stand on a door's pad and either start a party there (you are the host) or join the one waiting. The three stone archways in the middle are party doors, so three parties can get going at once; their host picks Normal or Hard. The door on the far left makes Easy parties, and the one on the far right is for **practice**: no creature, and no coins, shells, stats or records (none of a practice run is saved). The pop-up sets the size (1 to 4) and friends only; others join by stepping on the pad. When the countdown ends the party leaves together for a private server of its own (in Studio, which can't teleport, it goes straight into the cave here instead).
- **The cave:** every party starts in a cave behind the building, with room to walk about and a supply stall (G) for last-minute shopping. It is gloomy but never too dark, lit by torches, lanterns and glowing crystals, with water dripping and wind blowing in through its wide mouth onto the forest. A few seconds after you arrive, something out there steps on a stick, growls two seconds later, and a note says it is your last chance to grab supplies (with a button to the shop). Practice runs skip that.
- **Run timer:** starts when you walk out of the cave's mouth and stops at the exit. A run counts for the easiest difficulty played during it. Your best time on each difficulty is saved.
- **Coins:** earned for each stage cleared, each shell found and each escape. Spend them in the **Shop** (the dock's shop button, the + on your coins, or B).
- **The HUD:** your stage top left, coins bottom left (top left on touch screens, clear of the thumbstick), the run timer top middle, difficulty top right. In the lobby and the cave, big **Shop** and **Bag** buttons (what you own, to wear or take off) sit on the left, and on the right the **Christmas** button (with a LIMITED ribbon and how long is left), **2x Coins** (the Passes tab) and **Join** (Roblox's prompt to join the game's community, with a one-time coin reward; it goes away once paid), then **Stats** (escapes, fastest escape, stages cleared, times caught, shells found, runs started, time played), **Settings** (music, night sounds, sound effects, camera shake, field of view) and **Invite** (Roblox's invite-friends prompt). Out in the forest they make way for the noise meter on the left and round pebble, Updraft and Hush buttons bottom right, which work on touch screens too. On touch screens Shop and Bag sit side by side, the right-hand buttons make two rows near the top and the round buttons sit left of the jump button; on small screens (phones, small windows) the whole HUD and the party banner shrink to fit.
- **The Christmas Bundle** (until New Year, UTC): a limited Robux bundle with the exclusive **Frostbite** skin (ice) and **Santa Hat**, 1,000 coins and 3 Self-Revives. Its window has a countdown and its own SpriteCook art. The skin and hat aren't sold for coins: in the shop they point to the bundle, and once it's over they only show to those who have them.
- **Robux shop:** two more tabs in the shop. **Robux**: coin packs (Handful, Jar, Chest, Sunken Hoard), the Night Kit bundle (coins, Updrafts, Hushes and 2 Self-Revives), Self-Revives (1 or 3, kept until you need them) and 5-packs of Updraft and Hush. **Passes**: **2× Coins** (double coins from stages, shells and escapes) and **Deep Pockets** (5 pebbles a life and up to 15 of each boost). The + on your coins opens the Robux tab. What each one gives is in `src/shared/RobuxCatalog.luau`.
- **Getting caught:** its face up close, then a dead TV channel with what gave you away. The static stays until you choose: **Revive** (a Self-Revive if you have one, else 50 coins, else a Self-Revive bought with Robux) puts you back on the last dry ground you stood on, silent for a moment, with your run still going; **Bleed out** sends you to your last checkpoint, or the lobby if you have none; **Back to lobby** ends the run. Not choosing bleeds out after 30 seconds (`Config.Revive`).
- **Music and sound:** a music box in the lobby, an ominous bed in the forest and chase music while it hunts you, fading into each other; crickets at night; splashes, creaky boards, pebbles, your own feet in the water, the creature's footsteps and growl from where it is, a heartbeat while you are hunted, its roar and the TV static when it gets you, and chimes for stages, shells, escapes and purchases. All from Roblox's licensed libraries (APM Music and ProSoundEffects), set in `Config.Sounds`.
- **The menus and buttons are SpriteCook art**, from the UI kit "Still Water lobby menus" (see below); the code only places them and writes the words and numbers.
- **Shop:** 6 skins, 6 accessories, and 2 boosts. Every item has a big card with the thing itself in 3D: skins and accessories on **you** (your own avatar, turning; head things close up), and everything else as its 3D model, spinning and bobbing. Each stands in front of a spinning sunburst in its rarity colour (Common mint, Rare sky, Epic pink, Legendary lemon), with twinkling sparkles and a glint now and then. The boosts, which you carry and use: **Updraft** (Q / L1 / Fly button) lifts you and lets you glide for 2 seconds, and **Hush** (F / Y / Hush button) makes you completely silent for 5 seconds.
- Your progress, shells, escapes, difficulty, coins, items, stats and settings are saved.

The whole map is built by script when the server starts, so almost everything lives in the Luau files under `src/`. The exceptions are the 3D models made in Meshy (`art/models/`), which are imported into the place:

- **The lobby's props** live in `ServerStorage.LobbyProps`. The lobby uses `CottageShop` (the shop, from `art/models/lobby/cottage_shop.glb`), `PottedPalm` and `Planter` (`FloatHut` isn't used any more), places each one it finds and skips any that are missing.
- **The forest's trees** near the trail are the models in `ServerStorage.ForestProps` (`GnarledTree` and `BrokenTrunk`, from `art/models/dead-tree3.glb` and `dead-tree2.glb`, each standing on its own pivot at the bottom of its roots). Each is planted at a random size and turn, with an invisible post round its trunk. Far off in the fog, or without the models, trees are built from parts.
- **The shop's 3D models** live in `ReplicatedStorage.ShopModels`, one per thing sold that isn't worn (coin packs, Night Kit, Self-Revive, passes, Updraft and Hush), named like its icon art (`robux_coins_chest`, `action_hush`, ...). They were made in Meshy from three-quarter drawings of the shop's SpriteCook icons (`art/meshy-refs/shop-3q-*.png`; the models in `art/models/shop/`, previews beside them; `art/models/import/shop/` has copies for Import 3D). `robux_coins_jar` is put together in Studio, because Meshy can't make clear glass: the Meshy coin heap (`coins_heap.glb`) inside see-through glass parts with a lilac lid, its coins as the model's primary part. Without a model, its card shows its icon bobbing instead.
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
4. Press **Play**. You spawn in the lobby. Stand on a door's pad and create a party (size 1 leaves in 5 seconds) to go into the cave and stage 1.

Or skip the live sync: run `rojo build -o StillWater.rbxl` and open the file in Studio.

### The menu art

The panels, buttons, toggles, tiles and icons come from a SpriteCook UI kit. Each part is a PNG in `art/ui/kit/parts/` (logged with its SpriteCook asset id in `art/spritecook-assets.json`); `concept-a.png` and `sheet-1.png` are the concept and the sheet they were cut from.

Roblox only shows uploaded images, so the parts are packed into atlases, `art/ui/kit/atlas-panels.png`, `atlas-icons.png` and `atlas-event.png` (seasonal art; each at most 1024x1024), and `src/shared/UiArtParts.luau` says where each part sits and how it stretches. To change a part:

1. Replace its PNG in `art/ui/kit/parts/`.
2. Run `powershell -ExecutionPolicy Bypass -File tools/pack-ui.ps1` to repack both atlases and rewrite `UiArtParts.luau`.
3. Upload the atlases that changed in Studio (pick the file in an ImageLabel's **Image** property, or use the Asset Manager) and paste their new ids into `src/shared/UiArt.luau`.

### Before publishing

1. **File → Publish to Roblox.** Give it your own name, description and thumbnail.
2. **Game Settings → Security → Enable Studio Access to API Services.** Turn this on to test saving in Studio. Published games can always save.
3. **Robux:** in the Creator Dashboard, open the published game > Monetization. Under **Developer Products** create one for each entry in `Config.Products` (CoinsSmall, CoinsJar, CoinsChest, CoinsHoard, NightKit, SelfRevive1, SelfRevive3, Updraft5, Hush5, and ChristmasBundle while it's on) and under **Passes** one for each in `Config.Passes` (DoubleCoins, DeepPockets), with the names and prices you want, then paste each id into `src/shared/Config.luau`. Anything left at 0 isn't offered in the live game (Studio shows it all, so you can see it). SelfRevive1 is also what the death screen sells when you are short of coins.
4. **Sounds:** every sound's id is in `Config.Sounds` in `src/shared/Config.luau`. Swap any of them for another from the Creator Store; an empty id is skipped.

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
| Christmas on or off; how many snowballs a pile gives, how many you carry, how far and fast they fly | `Config.Christmas`, `Config.Snowballs` |
| What the Christmas trees, presents, wreaths and snowball piles look like | `src/server/Christmas.luau` (where they go: `src/server/LobbyBuilder.luau`) |
| The shop's cottage: where it stands, how big, where its sign, counter and light glows go | `SHOP` in `src/server/LobbyBuilder.luau` (the model is `art/models/lobby/cottage_shop.glb`, the sign `shop_sign` in the UI kit) |
| Throwing snowballs, hits | `src/server/Snowballs.luau`, `src/client/Throw.luau` |
| Falling snow, snow in your face when you're hit | `src/client/Snow.luau` |
| Which door does what (Easy, party, practice) and where; party size and countdowns | `Config.Doors`, `Config.Room.EntranceDoors` (the archways), `Config.Party` |
| Parties: the doors' pads and screens, joining, leaving, countdown, sending a party to its own server or into the cave | `src/server/Parties.luau` |
| Practice runs (nothing earned or saved) | `src/server/Progress.luau`; the creature ignores practice players in `src/server/Lurker.luau` and isn't drawn for them in `src/client/LurkerVisuals.luau` |
| The cave: its size (`Config.Cave`), rock, torches, crystals, stalactites, the supply stall, where a party arrives | `src/server/CaveBuilder.luau` |
| The cave's sounds, the stick and growl when you arrive and how long after, the last-chance note | `src/client/Cave.luau`, `Config.Cave`, `Config.Sounds` |
| The party pop-up and banner | `src/client/PartyUi.luau` |
| Record boards (titles, colours, refresh rate) | `src/server/Leaderboards.luau` |
| Moonlit lobby and exit lighting, the cave's gloom | `src/client/Mood.luau` |
| Creature behaviour | `src/server/Lurker.luau` |
| Creature look: posing the Meshy model, how it walks, runs and grabs, the part-built stand-in | `src/client/LurkerVisuals.luau` |
| Fear effects: vignette, heartbeat, faltering lights, camera shake | `src/client/Fear.luau` |
| Being caught: turned to face it, the close-up as its mouth opens, the TV static, "what it heard" recap, the Revive and Bleed out buttons | `src/client/DeathScene.luau` (the cause comes from `src/server/Noise.luau`) |
| Shop items, names, prices and skin colours | `src/shared/Catalog.luau` |
| Accessory shapes | `src/shared/AccessoryLook.luau` |
| How a skin recolours a character (used in the game and in the shop preview) | `src/shared/SkinLook.luau` |
| Shop cards: the 3D (you in it, or its model), rarity colours, sunburst, sparkles, glint | `src/client/ShopUi.luau`, `src/client/ShopPreview.luau`; rarities in `src/shared/Catalog.luau` and `src/shared/RobuxCatalog.luau` |
| How accessories are built onto a character (in the game and in the shop) | `src/shared/AccessoryLook.luau` |
| Coins per stage, shell and escape; boost timing | `Config.Coins`, `Config.Boosts` |
| HUD: where everything sits, the left and right buttons; the touch-screen layout | `src/client/Hud.luau` |
| How the HUD shrinks to fit small screens | `src/client/ScreenFit.luau` |
| The Christmas Bundle: what it gives, when it ends, the lines its window shows; its window | `RobuxCatalog.bundles` in `src/shared/RobuxCatalog.luau`, `src/client/ChristmasBundle.luau`; the exclusive items are in `src/shared/Catalog.luau` (`exclusive`) and the Santa Hat's shape in `src/shared/AccessoryLook.luau` |
| The menus' and HUD's building blocks: the kit's window, panels, buttons, badges and coins, and the lettering on them | `src/shared/Candy.luau` |
| Which picture each part is, and the atlas ids | `src/shared/UiArt.luau`, `src/shared/UiArtParts.luau` (generated), `art/ui/kit/` |
| The shop and the bag | `src/client/ShopUi.luau` |
| Stats window | `src/client/StatsUi.luau` (the numbers are kept in `src/server/Progress.luau`) |
| Settings: the list and defaults, the window, what each one does | `Config.Settings`, `src/client/SettingsUi.luau`, `src/client/Settings.luau` |
| Revive cost, how long you have to choose, how long a revive keeps you silent | `Config.Revive` (the waiting and paying are in `src/server/Progress.luau`) |
| Robux: what is sold, its name, picture and what it gives | `src/shared/RobuxCatalog.luau` |
| Robux ids; what the passes do | `Config.Products`, `Config.Passes`, `Config.PassPerks` (`src/shared/Perks.luau`) |
| Granting purchases | `src/server/Purchases.luau`, `Progress.grant` in `src/server/Progress.luau` |
| The community: its id, the coins for joining; checking and paying | `Config.Community`; `src/server/Community.luau`, `Progress.rewardCommunity` in `src/server/Progress.luau` |
| Which music and sound effects play | `Config.Sounds` |
| When each piece of music plays, and the fades | `src/client/Music.luau` |
| Sounds only you hear (wading, chimes); the creature's footsteps and growl | `src/client/Sounds.luau`, `src/client/LurkerVisuals.luau` |
| Shop item pictures | `src/client/ItemIcons.luau` |

Each stage's layout comes from a fixed random seed, so a stage looks the same every time. Change a stage's numbers to get a new layout.

## Layout

```
src/
  shared/              ReplicatedStorage.Shared
    Config.luau          tuning
    Stages.luau          stage list
    Catalog.luau         shop items (for coins)
    RobuxCatalog.luau    coin packs, Self-Revives, bundles and passes (for Robux)
    Perks.luau           what the passes change
    SkinLook.luau        how a skin recolours a character
    AccessoryLook.luau   how accessories are built onto a character
    Format.luau          time formatting
    Zones.luau           which part of the map a point is in (lobby, cave, forest, exit)
    Candy.luau           the menus' building blocks (kit windows, panels, buttons, lettering)
    UiArt.luau           which part of which uploaded atlas each picture is
    UiArtParts.luau      where each part sits in its atlas (made by tools/pack-ui.ps1)
    Remotes.luau         RemoteEvents
  server/              ServerScriptService.Server
    Main.server.luau     starts everything
    MapBuilder.luau      builds the forest stages and the way out; lighting
    CaveBuilder.luau     the cave a party arrives in, at the start of stage 1
    Christmas.luau       Christmas trees, presents, wreaths, snow and snowball piles for the lobby
    Forest.luau          trees, stumps, islands, lanterns, signposts
    LobbyBuilder.luau    builds the night courtyard lobby
    Parts.luau           part-building helpers both builders use
    Parties.luau         the lobby's doors: parties, countdowns, private servers, practice
    Leaderboards.luau    record boards (OrderedDataStores)
    Noise.luau           per-player noise, splashes, hard landings, Hush
    Lurker.luau          one creature: watching, stalking, chasing (moves an invisible anchor)
    Lurkers.luau         spawns and updates all creatures
    Hazards.luau         creaky boards, sinking moss, rafts, flickering lanterns
    Pebbles.luau         thrown pebbles
    Snowballs.luau       snowball fights in the Christmas lobby
    Progress.luau        checkpoints, shells, escapes, run timer, coins, items, saving, spawning
    Shop.luau            buying, wearing and using items (all checks on the server)
    Purchases.luau       Robux purchases (each granted once) and who owns which pass
    Cosmetics.luau       puts skins and accessories on characters
    Effects.luau         splash rings and sounds (in sound groups the settings turn off)
  client/              StarterPlayerScripts.Client
    Main.client.luau
    Hud.luau             coins, stage, timer, difficulty, noise meter, the dock, action buttons
    ShopUi.luau          the shop window and the bag
    StatsUi.luau         the stats window
    SettingsUi.luau      the settings window
    Settings.luau        applies and saves settings (sound, shake, field of view)
    Windows.luau         keeps one menu window open at a time
    ScreenFit.luau       shrinks the HUD and party banner to fit small screens
    Music.luau           lobby, forest and chase music, faded into each other (none in the cave)
    Sounds.luau          sounds only you hear, and your wading
    ItemIcons.luau       pictures of the shop's items
    ShopPreview.luau     the 3D on shop cards: you wearing it, or its model
    PartyUi.luau         the party pop-up and banner
    ChristmasBundle.luau the Christmas Bundle's window and countdown
    Cave.luau            the cave's drips, wind and torches; the scare and note when you arrive
    Snow.luau            falling snow in the Christmas lobby, and snow in your face when hit
    Boosts.luau          boost input (Q / F / the HUD's buttons) and Updraft flight
    LurkerVisuals.luau   poses the creature model (or a body of parts) as it walks
    Fear.luau            vignette, heartbeat, faltering lights, shake
    DeathScene.luau      the death scene: its face up close, TV static, "what it heard", revive or bleed out
    Mood.luau            warm lobby and exit lighting, the cave's gloom, cold forest fog, drifting mist
    Throw.luau           throw input (E / R2 / the HUD's pebble or snowball button)
    CameraReport.luau    tells the server which way your camera points (for where the creature appears)
tools/
  pack-ui.ps1          packs the UI kit's parts into atlases
```
