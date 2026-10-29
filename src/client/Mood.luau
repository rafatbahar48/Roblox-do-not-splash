-- Lighting by where you are: a moonlit night in the open courtyard and on
-- the way out, cold and dark in the flooded rooms. The contrast is the point:
-- the rooms feel darker for having just left somewhere colourful and safe.
--
-- Changes made here are only seen on this screen. The dark values are the
-- ones the server set (MapBuilder.luau's setupLighting).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Stages = require(ReplicatedStorage.Shared.Stages)
local DeathScene = require(script.Parent.DeathScene)

local player = Players.LocalPlayer

local CHECK_INTERVAL = 0.25
local FADE = TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

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

local Mood = {}

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

	-- The way out begins where the last stage ends.
	local exitZ = 0
	for _, stage in Stages do
		exitZ += stage.length
	end

	local current -- "safe" or "dark"
	local wasDying = false

	local function apply(mood)
		current = mood
		local values = if mood == "safe" then SAFE else dark
		for name, target in targets do
			TweenService:Create(target, FADE, values[name]):Play()
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
					local z = root.Position.Z
					local mood = if z < 0 or z >= exitZ then "safe" else "dark"
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
