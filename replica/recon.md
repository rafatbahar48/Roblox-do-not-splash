# Recon map: DONT SPLASH (Roblox: PC, mobile, console)

Scope: the core loop (a party crosses flooded rooms without splashing while a blind creature hunts by sound), plus the lobby, party/difficulty select, coins, upgrades and items that wrap it. Our version is **Still Water**. It rebuilds the mechanics and flow, not the original's name, art, sounds, monster design, stage names, text or prices.
For: Rafat's own Roblox game, published under its own name and branding.
Date: 2026-10-27

Mechanics and genre conventions are fair game. Everything the original made itself is not: its title, thumbnail and icon, models, textures, sounds, music, text, and stage and item names. Our stages, items and creature get their own names and designs (see "Make it ours").

## Sources

Roblox API data is first-hand. Everything about gameplay comes from fan-run guide sites. They often disagree, so treat it as medium confidence until we've played it ourselves. We had no access to the game itself: no account login, and the CDN serving its screenshots is blocked from this environment. The guide sites were also blocked, so the gameplay notes come from search-result summaries of them.

| # | source | URL | notes |
| --- | --- | --- | --- |
| 1 | Roblox games API | https://games.roblox.com/v1/games?universeIds=10771421858 | name, creator slo7th, genre Obby & Platformer / Runner, max 10 players per server, ~50k playing and 52M visits on 2026-10-27, created 2026-10-17, copying off |
| 2 | Roblox votes API | https://games.roblox.com/v1/games/votes?universeIds=10771421858 | 32,768 up / 4,152 down (~89% liked) |
| 3 | Roblox badges / passes APIs | https://badges.roblox.com/v1/universes/10771421858/badges | no badges and no passes listed on this universe. Passes the guides mention may live on another universe or be developer products |
| 4 | Roblox media API | https://games.roblox.com/v2/games/10771421858/media | 3 store images, no video. Couldn't download them (CDN blocked); not needed |
| 5 | Store description | (from source 1) | inspired by the Poolrooms and House of the Locust; "it knows" hook |
| 6 | RoWatcher | https://rowatcher.com/games/10771421858/upd-dont-splash | player-count history, peak ~20k |
| 7 | Sportskeeda beginner's guide | https://www.sportskeeda.com/roblox-news/don-t-splash-a-beginner-s-guide | lobby, shop, party |
| 8 | Fan guide: how to play | https://dontsplash.wiki/guide/dont-splash-how-to-play | pebble piles, throwing to lure |
| 9 | Fan guide: how to escape | https://dontsplash.wiki/survival/dont-splash-how-to-escape | safe-bordered sinking tiles, final room |
| 10 | Fan guide: upgrades | https://dontsplash.wiki/upgrades/dont-splash-guide | six upgrades, 3 levels each |
| 11 | Fan guide: game passes | https://dontsplash.wiki/guide/dont-splash-gamepasses | Robux catalogue (unverified) |
| 12 | Fan wiki: walkthrough | https://www.dontsplashwiki.wiki/walkthrough/DONT-SPLASH-full-walkthrough | nine-room order |
| 13 | Newtoplay | https://newtoplay.com/games/dont-splash | blind monster, valves and rising water ending |
| 14 | "Play as the MONSTER" place | https://www.roblox.com/games/92747855551719/DONT-SPLASH-Play-as-the-MONSTER | separate place advertising monster mode and 4-player Classic. Ownership unconfirmed |
| 15 | Fortnite island of the same name | https://www.fortnite.com/creative/island-codes/0931-1267-5135 | same concept on another platform: pebbles, rafts, collectibles, 3 difficulties |

## Core loop

A party of players crosses a chain of flooded rooms by jumping between tiles. The creature in the water can't see and goes after any splash, so every fall or careless step draws it in, and thrown pebbles pull it somewhere else. Clearing rooms and escaping pays coins, which buy permanent upgrades and items for the next run.

## Screens

In a Roblox game, a "screen" is either a 3D space or a UI panel.

| ID | screen | route / how to reach | purpose | key components | states seen |
| --- | --- | --- | --- | --- | --- |
| S01 | Lobby (3D hub) | join the game | meet up, shop, start a run | spawn, party portals, upgrade circle, shop area | solo, with friends |
| S02 | Party / queue panel | step into a portal ("touch to create a party") | form a party, pick map and difficulty, start | member list, map pick, difficulty picker, start button | creating, waiting, full, difficulty locked |
| S03 | Upgrades panel | step into the UPGRADES circle in the lobby | spend coins on permanent upgrades | upgrade cards with level pips (0-3), cost, next-level preview, "max with Robux" button | affordable, can't afford, maxed, maxed by pass |
| S04 | Item shop / loadout | lobby shop | buy pebbles and bottles with coins, fill slots | item cards, 3 slots (4th and 5th sold for Robux) | empty, full, slot locked |
| S05 | Robux purchase | buttons on S03/S04 | buy passes and coin packs | native Roblox purchase prompt | prompt, owned |
| S06 | Run HUD | during a run | items, prompts, warnings | hotbar slots, "hold E" prompts, rising-water warning, teammate status | normal, downed, spectating (guess) |
| S07 | Stage rooms (3D) | doors between rooms during a run | the obstacle course | tiles, water, monster(s), pebble piles | per hazard: see stage list |
| S08 | Final room (3D) | last room | finish the run | two valves (hold E), timer, rising water, yellow climb blocks, glowing doorway, exit corridor | before valves, timer running, water rising |
| S09 | Downed / rescue / spectate | fall in or get caught (guess) | stay in the run as a team | rescue rope, self-revive (event pack), spectate view | downed, being rescued, dead |
| S10 | Escaped / results | reach the end of the exit corridor | reward and return | "you escaped" banner, coins earned | win, (loss: guess) |

### Stage types in the original (paraphrased)

The guides report nine rooms, five of them added around 2026-10-23:

1. A hall of pillars to hop between
2. A broken walkway with gaps
3. Sinking platforms that drop if you stand too long. Tiles with a dark border don't sink and are safe to rest on.
4. A bridge that rotates
5. Platforms that move on a track
6. Platforms that drift on the water
7. A memory bridge, where you remember which tiles are safe
8. Walls that close in
9. A locked exit: turn two valves, survive rising water, climb out (one guide says it's a number puzzle instead)

## Flows

```
F01 Play a run (happy path)
    S01 -> S02 (create party, pick difficulty, start) -> S07 x8 -> S08 -> S10 -> S01
    happy path clicks: ~3 UI clicks before the run, then all movement
    edge: difficulty still locked; party member leaves mid-run; everyone downed;
          valve timer runs out before the climb; disconnect mid-run

F02 Distract the creature
    S07 grab pebbles from a pile -> equip from hotbar -> aim -> throw -> splash pulls creature
    edge: no pebbles left; slots full; pebble lands on a tile instead of water;
          Pebble Skipping upgrade adds extra splashes per throw

F03 Buy an upgrade
    S01 -> S03 -> pick upgrade -> buy next level
    happy path clicks: 2
    edge: not enough coins; already 3/3; owns the max pass

F04 Buy items / extra slots
    S01 -> S04 -> buy item (coins) or slot (Robux, S05)
    edge: slots full; slot already owned

F05 Save a teammate (guess)
    S07 teammate downed -> rescue rope / walk over -> hold to pull out
    edge: rescuer gets caught; Rope Reach / Rescue Speed upgrades change range and time

F06 Unlock a harder difficulty
    clear Normal twice -> Hard unlocks in S02
    edge: progress shared or per-party (unknown)

F07 Buy Robux items
    S03/S04 -> S05 -> pass / coin pack applied
    edge: purchase fails or is cancelled; already owned
```

## Components

| component | variants | states | used on |
| --- | --- | --- | --- |
| Proximity prompt | press E, hold E | idle, holding, done | S01 portals/circles, S07 pebble piles, S08 valves |
| Hotbar slot | item, empty, locked | selected, unselected | S04, S06 |
| Shop card | upgrade (level pips), item, pass | affordable, unaffordable, maxed, owned | S03, S04 |
| Price button | coins, Robux | enabled, disabled | S03, S04 |
| Difficulty picker | Easy, Normal, Hard | selected, locked | S02 |
| Party list | member row | host, member, empty slot | S02 |
| Warning banner | rising water, creature near | shown, hidden | S06, S08 |
| Countdown timer | valve timer | running, expired | S08 |
| Results panel | escaped | — | S10 |
| Toast | coins earned, unlock | — | all |

## Inferred data model

```
PlayerData  coins, upgrades {throwRange, pebbleSkip, toyBattery, flareRadius,
            ropeReach, rescueSpeed: 0..3}, slotsUnlocked (3..5),
            loadout [itemId], ownedPasses [passId], clears {easy, normal, hard}
            evidence: S03 upgrade levels, S04 slots, F06 unlock rule, sources 10-11
            confidence: medium

Party       id, hostUserId, members [userId] (max 4 or 10, sources disagree),
            map, difficulty, state (forming | in_run)
            evidence: S02, sources 7 and 14
            confidence: medium

Run         partyId, difficulty, monsterCount (Easy 1, Normal 3, Hard 5),
            stages [stageType], currentStage, coinsEarned, state (running | escaped | failed)
            evidence: source 12 monster counts, S10 rewards
            confidence: medium

Stage       type (pillars | broken_walkway | sinking | rotating_bridge | moving |
            drifting | memory | crushing_walls | locked_exit), pebblePiles
            evidence: stage list above
            confidence: medium

Item        id (pebble | bottle | toy | flare | rescue_rope), source (pickup | shop | pass),
            stack size
            evidence: upgrade names (Toy Battery, Flare Radius, Rope Reach), source 10
            confidence: guess for toy and flare behaviour

Upgrade     id, maxLevel 3, costs [level], effect per level, maxPassId
            evidence: S03, source 10 (first Pebble Skipping level 150 coins)
            confidence: medium
```

Relationships: Party 1-n Player, Party 1-1 Run, Run 1-n Stage, Player 1-1 PlayerData, PlayerData n-n Upgrade (levels), PlayerData n-n Item (loadout).

## Feature matrix

See `features.csv`. Must: 15 (6 done, 5 partial, 4 to build), should: 18 (3 done, 1 partial, 14 to build), could: 9 (4 done, all ours), skip: 6.

## Make it ours (decisions to carry into design and build)

- **Name and look:** "Still Water" (working title) with its own logo, thumbnail and colours. No poolrooms-yellow lighting copied from their screenshots, and no reuse of their title wording.
- **Our own creature:** our own model, sounds and behaviour. Ours already differs: several creatures that each listen in their own room, they can pull loud players off tiles, and there's a visible **noise meter**.
- **Our own stages and names:** we keep the genre staples (pillars, sinking and drifting tiles) under our own names, and add hazards they don't have: creaky tiles, stages built from the map seed, and one hidden collectible per stage (shells).
- **Our own items:** keep pebbles (a genre staple). Design our own second and third items rather than copying bottle, toy and flare one for one.
- **Our own economy:** our own currency name, prices and upgrade list. No copied Robux price points.

## Out of scope (cannot or should not be cloned)

- The name "DONT SPLASH", its thumbnail, icon and store text
- Its models, textures, sounds and music; their monster's design
- Its stage and item names, and any text it shows players
- Its player base and the visits, likes and favourites it has built up
- Seasonal deals tied to its events (we can run our own events)
- The "play as the monster" spin-off: a separate game. Could be our own later.

## Size

Screens 10, flows 7, entities 6. Hard parts:
1. **Party → reserved run servers:** the lobby teleports parties into private run servers with TeleportService, and data has to survive the hop.
2. **Downed/rescue for a group:** network ownership of a downed player being pulled.
3. **Nine distinct hazard rooms**, including rotating bridges, crushing walls and a timed rising-water finale. All server-authoritative and fair on mobile.

Size: **M** (a few weeks) on top of what Still Water already has.
