-- Small visual and sound effects that every player sees.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local Effects = {}

local folder

local function getFolder()
	if not folder or not folder.Parent then
		folder = Instance.new("Folder")
		folder.Name = "Effects"
		folder.Parent = workspace
	end
	return folder
end

function Effects.sound(name, position)
	local id = Config.Sounds[name]
	if not id or id == "" then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Parent = workspace.Terrain
	attachment.WorldPosition = position

	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.RollOffMaxDistance = 140
	sound.Parent = attachment
	sound:Play()
	Debris:AddItem(attachment, 8)
end

-- A white disc on the water that spreads out and fades.
function Effects.splash(position, radius)
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
	Effects.sound("Splash", position)
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
	sound.Parent = workspace
	sound:Play()
end

return Effects
