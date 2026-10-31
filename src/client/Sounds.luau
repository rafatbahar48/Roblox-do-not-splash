-- Sounds only this player hears, and loops other modules start and stop
-- (ids in Config.Sounds; empty ones are skipped). Each goes in the Effects
-- or Music sound group (server/Effects.luau), so the settings can turn it
-- off. Also plays your own feet sloshing while you wade.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer

local WADING_VOLUME = 0.7

local Sounds = {}

local oneShots = {} -- [name] = Sound, or false if it has no id

local function make(name, volume, group)
	local id = Config.Sounds[name]
	if not id or id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = id
	sound.Volume = volume
	sound.SoundGroup = SoundService:FindFirstChild(group)
	return sound
end

-- Plays a sound once, for this player only.
function Sounds.play(name, volume)
	local sound = oneShots[name]
	if sound == nil then
		sound = make(name, volume or 0.5, "Effects") or false
		if sound then
			sound.Parent = SoundService
		end
		oneShots[name] = sound
	end
	if sound then
		sound.Volume = volume or sound.Volume
		sound.TimePosition = 0
		sound:Play()
	end
end

-- A looped sound, not playing yet, or nil if it has no id. It plays from
-- parent (a part, for a sound out in the world) or in this player's ears.
function Sounds.loop(name, volume, group, parent)
	local sound = make(name, volume, group or "Effects")
	if sound then
		sound.Looped = true
		sound.Parent = parent or SoundService
	end
	return sound
end

function Sounds.start()
	local wading = Sounds.loop("Wading", 0)
	if not wading then
		return
	end
	RunService.Heartbeat:Connect(function(dt)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local velocity = if root then root.AssemblyLinearVelocity else Vector3.zero
		local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		local want = if player:GetAttribute("InWater") and speed > 1 then math.min(1, speed / Config.Wading.WalkSpeed) * WADING_VOLUME else 0
		wading.Volume += (want - wading.Volume) * math.min(1, dt * 8)
		if wading.Volume > 0.01 and not wading.IsPlaying then
			wading:Play()
		elseif wading.Volume <= 0.01 and wading.IsPlaying then
			wading:Stop()
		end
	end)
end

return Sounds
