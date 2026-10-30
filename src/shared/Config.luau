-- Tuning for the whole game. Change numbers here rather than in the scripts.

local Config = {}

Config.GameName = "Still Water"
Config.Tagline = "Stay out of the water. It is listening."

Config.DataStoreName = "StillWater_v1"
Config.RespawnTime = 6 -- long enough for the death scene and to read what gave you away
Config.WalkSpeed = 16
-- How far the camera can pull back from your character: close enough that
-- nobody can rise above the mist and look out over the forest.
Config.CameraMaxZoom = 14

-- Longest gap (in studs, edge to edge) the level generator will ever ask a
-- player to jump. A default Roblox character clears about 8.
Config.MaxJump = 7

Config.Difficulties = {
	Easy = { order = 1, noiseMultiplier = 0.6, lurkerSpeedMultiplier = 0.8 },
	Normal = { order = 2, noiseMultiplier = 1, lurkerSpeedMultiplier = 1 },
	Hard = { order = 3, noiseMultiplier = 1.35, lurkerSpeedMultiplier = 1.2 },
}
Config.DefaultDifficulty = "Normal"

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

-- Pearls are the shop currency. A stage pays out each time a run clears it,
-- a shell pays once ever, and an escape pays every time.
Config.Pearls = {
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
	PoolDepth = 4,
	TileHeight = 1.5, -- how far tiles and landings stand above the water
	StartLanding = 10,
	EndLanding = 12,
	DoorWidth = 8,
	DoorHeight = 10,
	LightSpacing = 16,
	-- The lobby is an open courtyard in front of the building the stages are in.
	LobbyLength = 110,
	LobbyWidth = 100,
	FacadeHeight = 30, -- how tall the building's front is
	ExitLength = 24,
	-- Stage 1's front wall has a doorway per difficulty, at these x positions.
	-- Walking through one picks that difficulty (server/LobbyDoors.luau).
	EntranceDoors = { Easy = 13, Normal = 0, Hard = -13 },
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
	SetupTimeout = 45, -- seconds the setup pop-up stays open
}

-- Paste sound ids from the Creator Store, for example "rbxassetid://123456".
-- Empty ids are skipped.
Config.Sounds = {
	Ambience = "",
	Splash = "",
	Lunge = "",
	Creak = "",
	Clatter = "",
}

return Config
