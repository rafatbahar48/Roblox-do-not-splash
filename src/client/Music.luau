-- The music, fading from one track to the next: a music box in the lobby
-- and at the way out (haunted sleigh bells while it is Christmas), scary suspense out in the forest, and the chase
-- while something hunts you. Silent in the cave, where you hear the drips
-- and the wind (Cave.luau), and while it has you (DeathScene.luau).
-- Ids are in Config.Sounds; the Music setting turns the Music sound group
-- off (Settings.luau).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Zones = require(ReplicatedStorage.Shared.Zones)
local DeathScene = require(script.Parent.DeathScene)
local Sounds = require(script.Parent.Sounds)

local player = Players.LocalPlayer

local TRACKS = {
	lobby = { sound = if Config.Christmas then "ChristmasMusic" else "LobbyMusic", volume = 0.35 },
	forest = { sound = "ForestMusic", volume = 0.5 },
	chase = { sound = "Chase", volume = 0.45, fromStart = true },
}
local FADE = TweenInfo.new(1.5)
local CHECK_INTERVAL = 0.25

local Music = {}

function Music.start()
	local tracks = {}
	for key, track in TRACKS do
		local sound = Sounds.loop(track.sound, 0, "Music")
		if sound then
			tracks[key] = { sound = sound, volume = track.volume, fromStart = track.fromStart }
		end
	end

	local function wanted()
		if DeathScene.playing() then
			return nil
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local zone = if root then Zones.at(root.Position) else "lobby"
		if zone == "cave" then
			return nil
		elseif zone == "forest" then
			return if player:GetAttribute("Hunted") then "chase" else "forest"
		end
		return "lobby"
	end

	local current = false
	local function switch(key)
		if key == current then
			return
		end
		current = key
		for name, track in tracks do
			local on = name == key
			if on and not track.sound.IsPlaying then
				if track.sound.IsPaused and not track.fromStart then
					track.sound:Resume()
				else
					track.sound.TimePosition = 0
					track.sound:Play()
				end
			end
			local tween = TweenService:Create(track.sound, FADE, { Volume = if on then track.volume else 0 })
			tween:Play()
			if not on then
				tween.Completed:Connect(function(state)
					if state == Enum.PlaybackState.Completed and current ~= name then
						track.sound:Pause()
					end
				end)
			end
		end
	end

	task.spawn(function()
		while true do
			switch(wanted())
			task.wait(CHECK_INTERVAL)
		end
	end)
end

return Music
