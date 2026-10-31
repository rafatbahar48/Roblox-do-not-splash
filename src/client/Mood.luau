-- Lighting by where you are: a warm, colourful night in the courtyard and on
-- the way out, cold blue fog in the drowned forest, with mist drifting low
-- over the water round you, and in the cave between them, gloom you can
-- still see by. The contrast is the point: the forest feels darker for
-- having just left somewhere safe.
--
-- Changes made here are only seen on this screen. The dark values are the
-- ones the server set (MapBuilder.luau's setupLighting).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Zones = require(ReplicatedStorage.Shared.Zones)
local DeathScene = require(script.Parent.DeathScene)

local player = Players.LocalPlayer

local CHECK_INTERVAL = 0.25
local FADE = TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local MIST_TEXTURE = "rbxasset://textures/particles/smoke_main.dds" -- ships with Roblox
local MIST_AREA = 70 -- studs across, centred on you

local SAFE = {
	-- Midnight under an open sky: moonlight, a purple-blue fill so the neon
	-- and lamps stand out, and a soft haze far off.
	lighting = {
		ClockTime = 0,
		Brightness = 0.9,
		Ambient = Color3.fromRGB(56, 54, 90),
		OutdoorAmbient = Color3.fromRGB(62, 62, 104),
		EnvironmentDiffuseScale = 0.25,
		FogStart = 160,
		FogEnd = 700,
		FogColor = Color3.fromRGB(24, 24, 52),
	},
	grade = {
		Saturation = 0.18,
		Contrast = 0.08,
		TintColor = Color3.fromRGB(255, 250, 255),
	},
	-- A soft halo round the lamps and bulbs, not a glare.
	bloom = {
		Intensity = 0.3,
		Size = 18,
		Threshold = 1.8,
	},
}

-- The cave (server/CaveBuilder.luau): its torches and crystals do most of
-- the lighting, with enough fill that the rock never goes black, and a
-- haze that swallows the forest past its mouth.
local CAVE = {
	lighting = {
		ClockTime = 0,
		Brightness = 1.2,
		Ambient = Color3.fromRGB(66, 62, 78),
		OutdoorAmbient = Color3.fromRGB(70, 76, 98),
		EnvironmentDiffuseScale = 0.3,
		FogStart = 16,
		FogEnd = 110,
		FogColor = Color3.fromRGB(28, 32, 44),
	},
	grade = {
		Saturation = -0.08,
		Contrast = 0.12,
		TintColor = Color3.fromRGB(240, 232, 240),
	},
	bloom = {
		Intensity = 0.5,
		Size = 22,
		Threshold = 1.5,
	},
}

local Mood = {}

-- Big, faint puffs drifting low over the water round you. Only this screen
-- sees them, and they follow you about.
local function makeMist()
	local holder = Instance.new("Part")
	holder.Name = "Mist"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.CastShadow = false
	holder.Transparency = 1
	holder.Size = Vector3.new(MIST_AREA, 1, MIST_AREA)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = MIST_TEXTURE
	emitter.Color = ColorSequence.new(Color3.fromRGB(120, 136, 160))
	emitter.LightEmission = 0.05
	emitter.LightInfluence = 0.6
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.86),
		NumberSequenceKeypoint.new(0.7, 0.88),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Size = NumberSequence.new(14, 22)
	emitter.Lifetime = NumberRange.new(10, 14)
	emitter.Rate = 14
	emitter.Speed = NumberRange.new(0.3, 1)
	emitter.SpreadAngle = Vector2.new(180, 10)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-6, 6)
	emitter.Enabled = false
	emitter.Parent = holder
	holder.Parent = workspace
	return holder, emitter
end

function Mood.start()
	-- What each part of SAFE applies to. A missing effect is left out.
	local targets = {
		lighting = Lighting,
		grade = Lighting:WaitForChild("Grade", 10),
		bloom = Lighting:WaitForChild("Glow", 10),
	}
	local dark = {}
	for name, target in targets do
		dark[name] = {}
		for key in SAFE[name] do
			dark[name][key] = target[key]
		end
	end

	local current -- "safe", "cave" or "dark"
	local wasDying = false
	local mist, mistEmitter = makeMist()

	local function apply(mood)
		local wasDark = current == "dark"
		current = mood
		local values = if mood == "safe" then SAFE elseif mood == "cave" then CAVE else dark
		for name, target in targets do
			TweenService:Create(target, FADE, values[name]):Play()
		end
		mistEmitter.Enabled = mood == "dark"
		if mood == "dark" and not wasDark then
			mistEmitter:Emit(100) -- already lying there when you arrive
		end
	end

	task.spawn(function()
		while true do
			if DeathScene.playing() then
				wasDying = true
			else
				-- The death scene puts its own values back; settle again after it.
				if wasDying then
					wasDying = false
					current = nil
				end
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if root then
					mist.Position = Vector3.new(root.Position.X, Config.Room.SurfaceY + 1.5, root.Position.Z)
					local zone = Zones.at(root.Position)
					local mood = if zone == "forest" then "dark" elseif zone == "cave" then "cave" else "safe"
					if mood ~= current then
						apply(mood)
					end
				end
			end
			task.wait(CHECK_INTERVAL)
		end
	end)
end

return Mood
