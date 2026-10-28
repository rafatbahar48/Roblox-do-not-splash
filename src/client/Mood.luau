-- Lighting by where you are: warm and bright in the lobby and on the way
-- out, cold and dark in the flooded rooms. The contrast is the point: the
-- rooms feel darker for having just left somewhere safe.
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
	lighting = {
		Brightness = 1.6,
		Ambient = Color3.fromRGB(128, 122, 110),
		OutdoorAmbient = Color3.fromRGB(118, 112, 100),
		EnvironmentDiffuseScale = 0.5,
		FogStart = 90,
		FogEnd = 420,
		FogColor = Color3.fromRGB(226, 214, 192),
	},
	grade = {
		Saturation = 0.05,
		Contrast = 0.04,
		TintColor = Color3.fromRGB(255, 246, 232),
	},
}

local Mood = {}

function Mood.start()
	local grade = Lighting:WaitForChild("Grade", 10)
	local dark = { lighting = {}, grade = {} }
	for key in SAFE.lighting do
		dark.lighting[key] = Lighting[key]
	end
	if grade then
		for key in SAFE.grade do
			dark.grade[key] = grade[key]
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
		TweenService:Create(Lighting, FADE, values.lighting):Play()
		if grade then
			TweenService:Create(grade, FADE, values.grade):Play()
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
