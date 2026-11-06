-- Tuning for the whole game. Change numbers here rather than in the scripts.

local Config = {}

Config.GameName = "The Silent Swamp"
Config.Tagline = "Stay out of the water. It is listening."

Config.DataStoreName = "StillWater_v1"
-- Raise this to start the fastest-escape boards and everyone's best times
-- afresh, when the stages change so much that old times can't be beaten
-- (2: ten stages instead of seven). Escapes are kept.
Config.BestTimesVersion = 2
Config.RespawnTime = 6 -- long enough for the death scene and to read what gave you away
Config.WalkSpeed = 16
-- How far the camera can pull back from your character: close enough that
-- nobody can rise above the mist and look out over the forest.
Config.CameraMaxZoom = 14

-- Longest gap (in studs, edge to edge) the level generator will ever ask a
-- player to jump. A default Roblox character clears about 8.
Config.MaxJump = 7

-- needs: escapes on another difficulty before this one opens (Perks.canPlay).
Config.Difficulties = {
	Easy = { order = 1, noiseMultiplier = 0.6, lurkerSpeedMultiplier = 0.8, blurb = "Quieter steps. More room for mistakes." },
	Normal = { order = 2, noiseMultiplier = 1, lurkerSpeedMultiplier = 1, blurb = "As it is meant to be played." },
	Hard = {
		order = 3,
		noiseMultiplier = 1.35,
		lurkerSpeedMultiplier = 1.2,
		blurb = "Louder steps. Less room for mistakes.",
		needs = { on = "Normal", escapes = 2 },
	},
}
Config.DefaultDifficulty = "Easy"

Config.Noise = {
	Max = 100,
	DecayPerSecond = 25,
	Splash = 100, -- falling into the water
	WadingPerSecond = 35, -- every second spent in the water
	HardLandingSpeed = 56, -- landing faster than this (studs/s) makes noise
	HardLandingPerStud = 2,
	HardLandingMax = 60,
	CreakyTile = 30,
	PebbleSplash = 80,
	PebbleClatter = 40,
	PointDecayPerSecond = 30, -- how fast a pebble's noise fades
}

-- The creature: one big thing that wades through the whole forest's water.
-- While nobody is in the water it watches from out in the fog, barely
-- visible. Touch the water and it comes out of the fog ahead of you, where
-- your camera points, runs straight at you, round you, and grabs you.
-- How many creatures a party can choose to have out there (server/Lurkers.luau),
-- and what coins from stages, shells and escapes count for with each number.
Config.Monsters = {
	Max = 3,
	Coins = { 1, 1.5, 2 },
}

Config.Lurker = {
	StalkSpeed = 8, -- moving round in the fog to keep watching you
	HuntSpeed = 26, -- running at you (you wade at 9)
	WatchDistance = { 58, 74 }, -- how far from the nearest player it keeps while nobody is in the water
	HearingThreshold = 15, -- how loud you must sound, after distance, for it to come
	DistanceFalloff = 0.6, -- loudness lost per stud of distance
	Stickiness = 10, -- bonus that keeps it on the player it is already chasing
	GrabRange = 6, -- reach for players standing in the water
	LungeRange = 10, -- reach for players still loud on a stone, fresh out of the water
	LungeNoise = 55, -- how loud they must still be to be grabbed off a stone
	AppearDistance = 66, -- how far ahead of you it comes out of the fog when you touch the water
	CircleRadius = 30, -- this close, it starts circling instead of coming straight in
	CircleMinRadius = 9, -- the tightest it circles
	CloseIn = 6, -- studs per second the circle tightens
	MinCircleTime = 2, -- seconds it runs round you, at least, before it grabs
	MaxCircleTime = 5, -- seconds of circling before it grabs, however far round it got
	Margin = 3, -- keeps it off the edges of the forest's water
	ReactTime = 1.5, -- seconds it stands frozen, staring at you, when it first hears you, before it comes
	StageSpeed = 0.025, -- how much faster it runs for each stage past the first (a share of HuntSpeed)
	StageHearing = 1, -- how much louder it hears you for each stage past the first (noise)
}

-- When it catches you, the static stays up until you choose (client/
-- DeathScene.luau, server/Progress.luau): Revive puts you back on the last
-- dry ground you stood on, using a Self-Revive if you have one, else
-- coins (or Robux for a Self-Revive, if you are short);
-- Bleed out sends you to your last checkpoint; Back to lobby ends the run.
-- Not choosing bleeds out after ChoiceTime.
Config.Revive = {
	Cost = 50, -- coins
	Free = 1, -- Self-Revives a player has until their first run starts
	ChoiceTime = 30, -- seconds to choose
	BuyTime = 60, -- extra seconds while a Robux purchase goes through
	SafeSeconds = 3, -- after a revive, how long you make no noise at all
}

-- Robux: ids from the Creator Dashboard (the published game > Monetization).
-- Products are Developer Products, bought again and again; passes are Game
-- Passes, owned forever. 0 means not set up, and the game doesn't offer it.
-- What each one is and gives: shared/RobuxCatalog.luau. Prices are set on
-- the dashboard.
Config.Products = {
	CoinsSmall = 3725019585,
	CoinsJar = 3725020628,
	CoinsChest = 3725020759,
	CoinsHoard = 3725021036,
	NightKit = 3725025405,
	SelfRevive1 = 3725025739, -- also what the death screen sells when you are short of coins
	SelfRevive3 = 3725026035,
	Updraft5 = 3725026100,
	Hush5 = 3725026348,
	ChristmasBundle = 3725026453, -- the limited bundle (RobuxCatalog.bundles), until New Year
}
Config.Passes = {
	DoubleCoins = 2061271796,
	DeepPockets = 2058219044,
	-- The premium skins (Catalog.luau, premium), one pass each.
	SwampSurvivor = 2070006719,
	BogHunter = 2070462444,
	WillowWraith = 2066436965,
	RotwoodSentinel = 2069958763,
	CursedDiver = 2070252647,
}
-- The game's Roblox community (made on roblox.com). Being in it pays Reward
-- coins, once per player: through the HUD's Join button, or on their next
-- visit if they joined on the website (server/Community.luau). 0 turns it off.
Config.Community = {
	GroupId = 642612714,
	Reward = 100, -- coins
}

-- The reward for coming back on a new day, by UTC (client/WelcomeBack.luau):
-- the first on your first day back, the next on each day in a row after it,
-- round again after the last. Missing a day starts again at the first. A
-- reward is what Progress.grant takes.
Config.Daily = {
	Rewards = {
		{ coins = 50 },
		{ coins = 75 },
		{ boosts = { updraft = 1, hush = 1 } },
		{ coins = 100 },
		{ selfRevives = 1 },
		{ coins = 150 },
		{ coins = 300, selfRevives = 1 },
	},
}

-- The Rare Pack (client/FriendPack.luau): set off in a party with this many
-- friends of its host, and everyone in it who clears every stage on that run
-- gets it, once. Skin is its skin (Catalog.luau, pack).
Config.FriendPack = {
	Friends = 2,
	Skin = "marsh_moth",
	Gives = { items = { "marsh_moth" }, coins = 500, selfRevives = 1 },
}

-- What the passes do (shared/Perks.luau).
Config.PassPerks = {
	DoubleCoins = { multiplier = 2 }, -- coins from stages, shells and escapes
	DeepPockets = { pebbles = 5, maxBoosts = 15 },
}

Config.Pebbles = {
	PerLife = 3,
	Cooldown = 1,
	MaxRange = 80,
	MinFlightTime = 0.45,
	MaxFlightTime = 1.2,
	Lifetime = 6,
}

Config.Wading = {
	WalkSpeed = 9,
}

-- Coins are the shop currency. A stage pays out each time a run clears it,
-- a shell pays once ever, and an escape pays every time.
Config.Coins = {
	PerStage = 10,
	PerShell = 25,
	PerEscape = 60,
}

-- Consumable boosts sold in the shop (prices live in Catalog.luau).
Config.Boosts = {
	MaxCarried = 9,
	updraft = {
		duration = 2, -- seconds of flight
		height = 6, -- studs it lifts you above where you started
		glideSpeed = 18,
		cooldown = 1, -- seconds after it ends before another can start
	},
	hush = {
		duration = 5, -- seconds of making no noise at all
		cooldown = 1,
	},
	grapple = {
		duration = 0.9, -- seconds the swing over to the hook's platform takes
		cooldown = 0.5,
	},
}

-- The grapple's hooks, over gaps too far to jump in the swamp stages
-- (server/Swamp.luau, server/Grapple.luau, client/Grapple.luau).
Config.Grapple = {
	Range = 26, -- how far from a hook's ring you can throw the line
	HookHeight = 10, -- how high over its platform the ring hangs
	FarGap = { 10, 12 }, -- the gap a hook is for, edge to edge
	-- The shell's side path starts with a drop off a stump this much taller
	-- than the rest, this far (edge to edge) from the next platform: a jump
	-- you can make down, but not back up.
	Drop = 4,
	DropGap = 9,
}

Config.Raft = {
	Range = 5, -- how far a raft drifts either side of its centre
	MinPeriod = 5,
	MaxPeriod = 7,
}

Config.SinkingTile = {
	DefaultDelay = 1, -- seconds between stepping on it and it going under
	Drop = 3.5,
	ResetTime = 3,
}

Config.Room = {
	SurfaceY = 100, -- height of the water surface; keeps the map clear of any baseplate
	Width = 40, -- the band the stepping stones are laid in
	Height = 18, -- how tall stage 1's doorway wall is behind the lobby
	PoolDepth = 4, -- where the creature walks
	WadeDepth = 2.6, -- where you stand if you fall in: about waist-deep
	TileHeight = 1.5, -- how far tiles and landings stand above the water
	StartLanding = 10,
	EndLanding = 12,
	DoorWidth = 8,
	DoorHeight = 10,
	LightSpacing = 16,
	ExitLength = 24,
	-- The cave's back wall (behind the lobby's ridge) has shut doorways at
	-- these x positions, where parties seem to have come in (Config.Doors).
	EntranceDoors = { 13, 0, -13 },
}

-- The party pads in the lobby (server/LobbyBuilder.luau). You stand on one
-- and start a party there (the host) or join the one waiting, and when its
-- countdown ends the party goes into the cave at the start of stage 1,
-- together (server/Parties.luau, client/PartyUi.luau). Each station's pads
-- are laid left to right as you face them, in this order.
--   station  "gate"      in the mouth of the Launch Adventure tunnel
--            "party"     at the Party station, under its awning
--   mode     "party"     the host picks the difficulty and how many monsters
--            "practice"  no creature, and no coins or records
Config.Doors = {
	{ station = "gate", mode = "party" },
	{ station = "party", mode = "party" },
	{ station = "gate", mode = "party" },
	{ station = "party", mode = "party" },
	{ station = "gate", mode = "practice" },
}

-- The cave behind the doors, where a party arrives: the start of stage 1,
-- with room to walk about and a supply stall, opening wide onto the forest
-- (server/CaveBuilder.luau). The run timer starts at its mouth.
Config.Cave = {
	Length = 40, -- from the building's back wall to the mouth
	HalfWidth = 24,
	Height = 18,
	ArrivalDelay = 3, -- seconds after arriving before something snaps a stick out there
	GrowlDelay = 2, -- and then it growls
}

-- Christmas in the lobby: snow, decorated trees, presents, wreaths, falling
-- snow, a spookier Christmas tune and snowball fights (server/Christmas.luau,
-- server/Snowballs.luau, client/Snow.luau). Set to false after the holidays.
Config.Christmas = true

-- Snowballs, in the Christmas lobby: grab some from a pile (G), throw them
-- (E, R2 or the HUD's snowball button). A hit only splats snow in their
-- face; it never pushes anyone off a party pad.
Config.Snowballs = {
	PerGrab = 5, -- how many a pile gives, up to Max
	Max = 10,
	Cooldown = 0.4, -- seconds between throws
	MaxRange = 70,
	MinFlightTime = 0.3,
	MaxFlightTime = 0.8,
	Lifetime = 4,
}

-- The stages are stretches of a drowned forest at night, behind the lobby's
-- building (MapBuilder.luau, Forest.luau).
Config.Forest = {
	HalfWidth = 48, -- how far players can wade out either side of the path
	CreatureHalfWidth = 72, -- the creature roams further out, among the trees
	SceneryHalfWidth = 150, -- water and trees carry on this far, into the fog
	IslandHalfWidth = 18, -- the islands at each end of a stage
	TreeSpacing = 13, -- near the path; further out they thin out (the Meshy trees are detailed)
	TreeHeight = { 15, 30 }, -- short enough to stay hidden behind the lobby's building
	LanternSpacing = 22,
}

-- Party doors in the lobby (server/Parties.luau, client/PartyUi.luau).
Config.Party = {
	MaxSize = 4,
	Countdown = 20, -- seconds a new party waits for others to join
	FullCountdown = 5, -- seconds left once it is full
	AutoCreate = 15, -- seconds after the last change in the setup pop-up that it creates the party itself
	SetupTimeout = 45, -- seconds the server keeps a pad held for the pop-up
}

-- The settings window (client/SettingsUi.luau), saved with each player's
-- progress. A setting with min and max is a number stepped by step; the rest
-- are on/off.
Config.Settings = {
	{ id = "music", name = "Music", default = true },
	{ id = "ambience", name = "Night sounds", default = true },
	{ id = "effects", name = "Sound effects", default = true },
	{ id = "shake", name = "Camera shake", default = true },
	{ id = "fov", name = "Field of view", default = 70, min = 60, max = 100, step = 5 },
}

-- Sound ids, for example "rbxassetid://123456". Empty ids are skipped. These
-- are from Roblox's licensed libraries on the Creator Store (APM Music and
-- ProSoundEffects), which any experience may use.
Config.Sounds = {
	-- Music, fading from one to the next (client/Music.luau)
	LobbyMusic = "rbxassetid://9044512469", -- Cypress Bayou: haunting swamp blues on a slide guitar, the lobby and the way out
	ForestMusic = "rbxassetid://71555461626609", -- The Lurking Dread: scary suspense out in the forest
	Chase = "rbxassetid://135888560895946", -- Rising Fear: while it hunts you
	Escape = "rbxassetid://1844016113", -- White Sands (sting): you got out

	-- Heard by everyone, from where they happen (server/Effects.luau)
	Ambience = "rbxassetid://9112764573", -- crickets at night, everywhere
	Splash = "rbxassetid://9120585252", -- someone falls in
	PebbleSplash = "rbxassetid://9125703162", -- a pebble lands in the water
	Creak = "rbxassetid://9120829478", -- creaky boards
	Clatter = "rbxassetid://9118624831", -- a pebble hits something hard
	Lunge = "rbxassetid://9113980319", -- the roar as it grabs someone

	-- The creature, from where it is (client/LurkerVisuals.luau)
	CreatureSteps = "rbxassetid://9114082550", -- big feet in the water, while it runs
	CreatureGrowl = "rbxassetid://9113985466", -- a low growl, while it hunts
	CreaturePanting = "rbxassetid://9113635748", -- heavy snorting breaths, while it runs at you
	CreatureBreathing = "rbxassetid://9113984054", -- a slow wet breath, now and then while it watches
	CreatureCreak = "rbxassetid://9126263691", -- its body creaking like old wood
	CreatureDrip = "rbxassetid://9126181980", -- water dripping off it
	CreatureStep = "rbxassetid://9125702803", -- each foot squelching down in the mud as it stalks
	CreatureBranch = "rbxassetid://9119232904", -- a branch snapping under it as it stalks
	CreatureBubbles = "rbxassetid://9112872437", -- bubbles round it as it glides through the water
	CreatureSniff = "rbxassetid://9119308485", -- the sharp breath in as it hears you
	CreatureNeck = "rbxassetid://9113546532", -- the crack as its neck and back twist round to you
	CreatureSnap = "rbxassetid://9120258724", -- wood snapping as it crashes after you
	CreatureSnarl = "rbxassetid://9113991846", -- a hissing snarl, now and then in the chase
	CreatureImpact = "rbxassetid://9113493156", -- the thud as it grabs someone (with the Lunge roar)

	-- Far off, now and then in the lobby (client/LobbyLife.luau)
	DistantRoar = "rbxassetid://9113987603", -- something roaring beyond the ridge
	DistantSplash = "rbxassetid://9119479417", -- something big dropping into the water out on the swamp
	DistantSplashDeep = "rbxassetid://9119476512", -- the same, deeper

	-- The cave where a party arrives (client/Cave.luau)
	CaveDrips = "rbxassetid://9126190860", -- water dripping, while you are in it
	CaveWind = "rbxassetid://9113732233", -- wind through its mouth, louder nearer it
	StickSnap = "rbxassetid://9113582284", -- something steps on a stick out there, just after you arrive
	CaveGrowl = "rbxassetid://9116292585", -- and growls, two seconds later

	-- Snowball fights in the Christmas lobby (server/Snowballs.luau)
	SnowGrab = "rbxassetid://9119316414", -- scooping up snowballs from a pile
	SnowballThrow = "rbxassetid://9120742716", -- a quick whoosh
	SnowballHit = "rbxassetid://9119312087", -- it hits someone
	SnowballLand = "rbxassetid://9119310905", -- it lands in the snow

	-- Just for you (client/Sounds.luau)
	Wading = "rbxassetid://9120609785", -- your feet in the water
	Heartbeat = "rbxassetid://9043365727", -- while it hunts you (Fear.luau)
	Static = "rbxassetid://9126097283", -- the death scene's TV static
	Checkpoint = "rbxassetid://9116395089", -- a stage cleared
	Shell = "rbxassetid://9116394545", -- a shell found
	Click = "rbxassetid://9119717529", -- menu buttons
	Buy = "rbxassetid://9113728756", -- something bought
}

return Config
