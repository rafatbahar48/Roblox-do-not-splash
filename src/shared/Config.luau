-- Tuning for the whole game. Change numbers here rather than in the scripts.

local Config = {}

Config.GameName = "Still Water"
Config.Tagline = "Stay out of the water. It is listening."

Config.DataStoreName = "StillWater_v1"
Config.RespawnTime = 3
Config.WalkSpeed = 16

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

Config.Lurker = {
	IdleSpeed = 5,
	HuntSpeed = 15,
	HearingThreshold = 15, -- how loud something must sound, after distance, to be noticed
	DistanceFalloff = 0.6, -- loudness lost per stud of distance
	Stickiness = 10, -- bonus that keeps it on the player it is already chasing
	GrabRange = 4, -- reach for players standing in the water
	LungeRange = 7, -- reach for loud players standing on a tile
	LungeNoise = 55, -- players on tiles must be at least this loud to be grabbed
	SearchTime = 3, -- seconds it circles a spot after reaching a noise
	Depth = 1.4, -- how far under the surface it swims
	Margin = 1.5, -- keeps it off the pool walls
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
	Width = 40,
	Height = 18,
	PoolDepth = 4,
	TileHeight = 1.5, -- how far tiles and landings stand above the water
	StartLanding = 10,
	EndLanding = 12,
	DoorWidth = 8,
	DoorHeight = 10,
	LightSpacing = 16,
	LobbyLength = 30,
	ExitLength = 24,
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
