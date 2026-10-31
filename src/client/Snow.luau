-- Christmas in the lobby, on this screen (Config.Christmas): snow falling
-- round you while you are in the courtyard, and a faceful of snow when a
-- snowball hits you (server/Snowballs.luau).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Zones = require(ReplicatedStorage.Shared.Zones)

local player = Players.LocalPlayer

local FLAKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds" -- ships with Roblox; small, it is a soft flake
local SNOW = Color3.fromRGB(245, 248, 255)
local AREA = 140 -- studs across the snowfall, centred on you
local HEIGHT = 40 -- how far above you it starts
local SPLAT_TIME = 0.9

local Snow = {}

local function invisiblePart(name, size)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = size
	part.Parent = workspace
	return part
end

local function makeSnowfall()
	local holder = invisiblePart("Snowfall", Vector3.new(AREA, 1, AREA))
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = FLAKE_TEXTURE
	emitter.Color = ColorSequence.new(SNOW)
	emitter.LightEmission = 0.25
	emitter.LightInfluence = 0.5
	emitter.Size = NumberSequence.new(0.35)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.08, 0.15),
		NumberSequenceKeypoint.new(0.9, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(6, 8)
	emitter.Rate = 260
	emitter.Speed = NumberRange.new(5, 8)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.SpreadAngle = Vector2.new(12, 12)
	emitter.Acceleration = Vector3.new(1.2, 0, 0.6) -- a light breeze
	emitter.RotSpeed = NumberRange.new(-40, 40)
	emitter.Enabled = false
	emitter.Parent = holder
	return holder, emitter
end

-- Snow in your face: a burst of white puffs just in front of the camera,
-- following it for a moment, and a quick white flash.
local function splat()
	local camera = workspace.CurrentCamera
	local holder = invisiblePart("SnowSplat", Vector3.new(2.5, 1.6, 0.2))
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = FLAKE_TEXTURE
	emitter.Color = ColorSequence.new(SNOW)
	emitter.LightEmission = 0.3
	emitter.LightInfluence = 0
	emitter.LockedToPart = true
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1.6) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.6, 0.3), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(0.5, SPLAT_TIME)
	emitter.Speed = NumberRange.new(0.5, 2)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -3, 0)
	emitter.Rate = 0
	emitter.Parent = holder
	local follow = RunService.RenderStepped:Connect(function()
		holder.CFrame = camera.CFrame * CFrame.new(0, 0, -1.6)
	end)
	holder.CFrame = camera.CFrame * CFrame.new(0, 0, -1.6)
	emitter:Emit(30)

	local flash = Instance.new("ColorCorrectionEffect")
	flash.Name = "SnowFlash"
	flash.Brightness = 0.3
	flash.TintColor = Color3.fromRGB(235, 245, 255)
	flash.Parent = Lighting
	TweenService:Create(flash, TweenInfo.new(0.6), { Brightness = 0, TintColor = Color3.new(1, 1, 1) }):Play()

	task.delay(SPLAT_TIME + 0.1, function()
		follow:Disconnect()
		holder:Destroy()
		flash:Destroy()
	end)
end

function Snow.start()
	if not Config.Christmas then
		return
	end
	local holder, emitter = makeSnowfall()
	RunService.Heartbeat:Connect(function()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local inLobby = root ~= nil and Zones.at(root.Position) == "lobby"
		if inLobby then
			holder.Position = root.Position + Vector3.new(0, HEIGHT, 0)
		end
		if emitter.Enabled ~= inLobby then
			emitter.Enabled = inLobby
			if inLobby then
				emitter:Emit(600) -- already falling when you arrive
			end
		end
	end)
	Remotes.SnowballHit.OnClientEvent:Connect(splat)
end

return Snow
