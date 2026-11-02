# The Mire Stalker

The swamp's monster: a drowned, rotten-tree creature with pale burning eyes, a long fanged mouth and arms that hang to its knees. It replaces the flesh creature, which is kept as a backup. Its hunting (server/Lurker.luau) is the old AI with the three changes agreed on 2026-11-02: a 1.5 second frozen reaction before it charges, a little faster and sharper hearing stage by stage, and the spider crawl while it circles you.

## Files

| File | What it is |
|---|---|
| `references/mire_stalker.png` | The concept it was made from |
| `art/meshy-refs/mire/` | The clean front, side and back views Meshy built it from, and their task |
| `art/models/mire/mire_stalker.glb`, `.fbx` | Meshy's model, unrigged |
| `art/models/mire/mire_stalker_rigged.glb`, `.fbx` | Rigged by Meshy (its 24-bone humanoid skeleton) |
| `art/models/mire/mire_stalker_jaw.glb`, `.fbx` | **The one in the game**: the rig plus a Jaw bone and the darker skin |
| `art/models/mire/add_jaw.py` | The Blender script that makes the jaw version from the rigged one |
| `art/models/mire/texture_*.png` | Its textures (`texture_base_color_dark.png` is the darker skin) |
| `art/models/mire/model-task.json`, `rig-task.json` | Meshy's task records, with the download links removed |
| `src/client/LurkerVisuals.luau` | How it moves, every frame, and its sounds |
| `src/server/Lurker.luau` | How it hunts (unchanged apart from the three changes above) |
| `src/shared/Config.luau` | `Config.Lurker` (`ReactTime`, `StageSpeed`, `StageHearing`) and its sound ids (`Config.Sounds.Creature*`) |

Meshy credits spent: 47 of the agreed 60 (reference views 12, model 30, rig 5). No animations were bought: all its movement is code.

## In Studio

- The model is `ReplicatedStorage.Creatures.MireStalker` (20 studs tall, facing -Z, its bones under the mesh; it was 16 until 2026-11-02, and its strides grow with it, see `MODEL_LEGS`). It lives only in the place file, so **save the place** after any change to it.
- The old creature is `ServerStorage.CreatureBackup.Creature`. To bring it back, move it into `ReplicatedStorage.Creatures` and move `MireStalker` out (the folder should hold one model).
- Attributes on the model: `Eyes`, `EyeOffset`, `EyeSize`, `EyeColor` and `EyeAlertColor` (its glowing eyes), `OwnMouth`, and `CloseUpDistance`, `CloseUpHeight` and `CloseUpAim` (how the death scene frames its mouth).
- **To remake it:** run `add_jaw.py` in Blender 5.2 (`blender --background --factory-startup --python add_jaw.py`). Import `mire_stalker_jaw.fbx` with Import 3D, then:
  1. Scale it to 20 studs (scale 5 in its Scale property), and its eye and close-up attributes by the same amount.
  2. Delete the RootPart, Motor6Ds, AnimationController and InitialPoses folder that the importer adds.
  3. Move the bones under the mesh, and copy the attributes over.

## How it moves

`LurkerVisuals.luau` poses its bones every frame on each player's screen. It works from the few flags the server sets on its anchor (`Alert`, `Reacting`, `Running`, `Circling`, `Lunging`, `Focus`), so no bone movement is sent over the network. Its random twitches and pauses come from the server's clock, so every player sees the same ones. Its moves:

| Move | What it does |
|---|---|
| Idle | Dead still, a twitch now and then, its head slowly turning to whoever is nearest |
| Broken walk | One leg drags late and its body jerks; it stops mid-step |
| Water stalk | Crouched low, its hands skimming the water |
| Reaction | Freezes, its head snaps round and holds, its shoulders rise, its body twists, its jaw opens |
| Chase | Bent flat, head thrust out, claws flailing and lashing at you |
| Crawl | On all fours while it circles you |
| Stop | Stops dead, its arms still swinging, its head on the spot where it lost you, its jaw slowly closing |
| Retreat | Creeps back low, glancing behind |
| Grab | One arm, claws curling, head tipped, jaw wide |

Each move's carriage is one row of `MODES` at the top of its Movement section, so it's easy to tune.

## Sounds

These are licensed ProSoundEffects sounds, in `Config.Sounds` under `Creature*`. They play from where it is, a few at a time, at the same moments for everyone, and not on practice runs:

| When | What you hear |
|---|---|
| Watching | Slow wet breaths, its body creaking like wood, drips |
| Stalking | Each squelching step and a snapping branch, or bubbles in the water |
| Hearing you | Silence, a sharp breath in, then a crack as it twists round |
| Chasing | Panting, its feet in the water, the growl, snapping wood, snarls |
| Grabbing | The roar and a thud |

How loud, how far and how deep each one is: `VOICES`. How often: `CALLS` and `CUES`.

## Test report (2026-11-02, Studio)

**Poses:** checked on a puppet in clear air from the side, for all nine moves:

- idle, broken walk, water stalk, reaction, chase, crawl and stop: as intended;
- grab: it sat down in the water at first; now it bends its back instead (`crouchDrop`);
- in the real fog, from where it watches (58 to 74 studs), it shows as a tall dark shape with two faint eyes, like a dead tree.

**Real hunt:** an Easy run with saving off, wading off stage 1's start island, run twice. The log for the second run:

| Time | What happened |
|---|---|
| 0.8 s | Heard you, and appeared 63 studs ahead in the fog |
| 0.8 to 2.3 s | Froze and reacted |
| 2.3 s | Charged |
| 3.9 s | Started circling, on all fours |
| 7.3 s | Grabbed you |
| 9.1 s | You died |

There was exactly one catch and one death each run (no double kill). The death close-up frames its open mouth and eyes well.

**At 20 studs**, after it was made bigger the same day, another hunt behaved the same: it grabbed at 7.3 s and you died at 9.1 s, with one catch and one death. Its grab still reached, and the close-up still framed its face.

**Bugs found and fixed:**

1. Falling into the water in stages 1 and 2 dropped you out of the world. Since the ten-stage swamp, the lake was longer than the largest part Roblox allows, so its floor no longer reached them. The lake is now built in pieces.
2. When it heard you while you were looking back toward a stage's start, it appeared right beside you. Now it comes from where it was.
3. After it appeared somewhere new, its frozen hands reached back to where it had been.
4. `add_jaw.py` exported Blender's bone-shape sphere with the model. It no longer does (checked on a copy).

**Not checked:**

- **The sounds** were chosen by their titles and load correctly, but nobody has listened to them yet. Play a hunt with sound on and say which to change.
- **A second player** watching someone else get grabbed.
- **The reaction from the player's own camera:** the test camera sat behind the island's bank. Its timing is confirmed by the log, and its pose by the puppet shots.
- "EditableImage is not accessible" appears in Output. It's harmless: the death screen's snow falls back to plain static unless EditableImage is turned on in Experience Settings, Security.
