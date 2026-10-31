-- Small visual and sound effects that every player sees.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local Effects = {}

local folder

-- Sounds go in groups so each player can turn them off in their settings
-- (client/Settings.luau). Lobby music has a group of its own.
local function soundGroup(name)
	local group = SoundService:FindFirstChild(name)
	if not group then
		group = Instance.new("SoundGroup")
		group.Name = name
		group.Parent = SoundService
	end
	return group
end
for _, name in { "Music", "Ambience", "Effects" } do
	soundGroup(name)
end

local function getFolder()
	if not folder or not folder.Parent then
		folder = Instance.new("Folder")
		folder.Name = "Effects"
		folder.Parent = workspace
	end
	return folder
end

-- Plays a Config.Sounds sound at a spot, for everyone near enough to hear.
function Effects.sound(name, position, volume)
	local id = Config.Sounds[name]
	if not id or id == "" then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Parent = workspace.Terrain
	attachment.WorldPosition = position

	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or 0.6
	sound.RollOffMaxDistance = 140
	sound.SoundGroup = soundGroup("Effects")
	sound.Parent = attachment
	sound:Play()
	Debris:AddItem(attachment, 8)
end

-- A white disc on the water that spreads out and fades, with a splash
-- (Config.Sounds.Splash, or the sound named).
function Effects.splash(position, radius, soundName)
	local ring = Instance.new("Part")
	ring.Name = "Splash"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Color = Color3.fromRGB(235, 248, 252)
	ring.Material = Enum.Material.SmoothPlastic
	ring.Transparency = 0.2
	ring.Size = Vector3.new(0.15, 1, 1)
	ring.CFrame = CFrame.new(position + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Parent = getFolder()

	local tween = TweenService:Create(ring, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.15, radius * 2, radius * 2),
		Transparency = 1,
	})
	tween:Play()
	Debris:AddItem(ring, 1)
	Effects.sound(soundName or "Splash", position, 0.8)
end

function Effects.startAmbience()
	local id = Config.Sounds.Ambience
	if id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = "Ambience"
	sound.SoundId = id
	sound.Looped = true
	sound.Volume = 0.4
	sound.SoundGroup = soundGroup("Ambience")
	sound.Parent = workspace
	sound:Play()
end

return Effects
