-- Lighting by where you are: a warm, colourful night in the courtyard and on
-- the way out, cold moonlit fog in the drowned forest (thicker and darker in
-- a stage with gloom, Stages.luau), with faint mist drifting low over the
-- water round you and a bank of thick fog all round further out, which
-- moves with you: what's near you stays clear, and what's past it is lost.
-- In the cave between them, gloom you can still see by. The
-- contrast is the point: the forest feels darker for having just left
-- somewhere safe. A stage's STAGE COMPLETE doorway only lights up as you
-- come near, so you find the end rather than steer for its glow.
--
-- Changes made here are only seen on this screen. The dark values are the
-- ones the server set (MapBuilder.luau's setupLighting).

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Stages = require(ReplicatedStorage.Shared.Stages)
local Zones = require(ReplicatedStorage.Shared.Zones)
local DeathScene = require(script.Parent.DeathScene)

local player = Players.LocalPlayer

local CHECK_INTERVAL = 0.25
local FADE = TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local MIST_TEXTURE = "rbxasset://textures/particles/smoke_main.dds" -- ships with Roblox
local MIST_AREA = 70 -- studs across, centred on you
local FOG_BANK = { 40, 60 } -- studs from you: the fog bank's near and far sides (the camera stays nearer, Config.CameraMaxZoom)
local DOOR_LIT, DOOR_DARK = 45, 75 -- studs: a doorway is fully lit nearer than the first, dark past the second

local SAFE = {
	-- Midnight under an open sky: moonlight, a purple-blue fill so the neon
	-- and lamps stand out, and a soft haze far off.
	lighting = {
		Brightness = 0.9,
		ExposureCompensation = 0,
		Ambient = Color3.fromRGB(56, 54, 90),
		OutdoorAmbient = Color3.fromRGB(62, 62, 104),
		EnvironmentDiffuseScale = 0.25,
	},
	fog = {
		Density = 0.2,
		Offset = 0,
		Color = Color3.fromRGB(40, 40, 76),
		Decay = Color3.fromRGB(26, 26, 54),
		Glare = 0,
		Haze = 0.5,
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
		Brightness = 1.2,
		ExposureCompensation = 0,
		Ambient = Color3.fromRGB(66, 62, 78),
		OutdoorAmbient = Color3.fromRGB(70, 76, 98),
		EnvironmentDiffuseScale = 0.3,
	},
	fog = {
		Density = 0.45,
		Offset = 0,
		Color = Color3.fromRGB(62, 66, 72),
		Decay = Color3.fromRGB(40, 42, 50),
		Glare = 0,
		Haze = 1,
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

-- Big, very faint puffs drifting low over the water round you. Only this
-- screen sees them, and they follow you about.
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
		NumberSequenceKeypoint.new(0.3, 0.94),
		NumberSequenceKeypoint.new(0.7, 0.95),
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

-- Thick fog in a ring round you, FOG_BANK studs out: the forest's fog is
-- thin enough that what's near you is clear, and this hides what's further.
-- Its puffs move with you, so the clear ring never fills up as you go.
local function makeFogBank()
	local holder = Instance.new("Part")
	holder.Name = "FogBank"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.CastShadow = false
	holder.Transparency = 1
	holder.Size = Vector3.new(FOG_BANK[2] * 2, 1, FOG_BANK[2] * 2)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = MIST_TEXTURE
	emitter.Shape = Enum.ParticleEmitterShape.Disc
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.ShapePartial = FOG_BANK[1] / FOG_BANK[2] -- a disc's inner radius
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.LockedToPart = true
	emitter.Color = ColorSequence.new(Color3.fromRGB(84, 102, 138)) -- dark: paler goes grey against the moon
	emitter.LightEmission = 0.05
	emitter.LightInfluence = 0.6
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.6),
		NumberSequenceKeypoint.new(0.7, 0.62),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Size = NumberSequence.new(22, 30)
	emitter.Lifetime = NumberRange.new(10, 14)
	emitter.Rate = 26
	emitter.Speed = NumberRange.new(0.2, 0.6)
	emitter.SpreadAngle = Vector2.new(180, 10)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-4, 4)
	emitter.Enabled = false
	emitter.Parent = holder
	holder.Parent = workspace
	return holder, emitter
end

-- Each doorway's glowing parts, lights and letters as the server made them
-- (server/Forest.luau's stageDoor), to fade from. Not a weak table: Roblox
-- can drop an Instance key from one while the Instance is still there, and
-- it would then be read again already faded.
local doors = {}

local function doorGlow(model)
	local glow = { parts = {}, lights = {}, labels = {} }
	for _, thing in model:GetDescendants() do
		if thing:IsA("BasePart") and thing.Material == Enum.Material.Neon then
			glow.parts[thing] = thing.Transparency
			glow.at = glow.at or thing.Position
		elseif thing:IsA("Light") then
			glow.lights[thing] = thing.Brightness
		elseif thing:IsA("TextLabel") then
			glow.labels[thing] = thing.TextStrokeTransparency
		end
	end
	return glow
end

-- Lights each doorway by how near you are to it.
local function lightDoors(position)
	for _, model in CollectionService:GetTagged("StageDoor") do
		local glow = doors[model]
		if not glow then
			glow = doorGlow(model)
			doors[model] = glow
		end
		if glow.at then
			local dark = math.clamp(((position - glow.at).Magnitude - DOOR_LIT) / (DOOR_DARK - DOOR_LIT), 0, 1)
			for part, lit in glow.parts do
				part.Transparency = lit + (1 - lit) * dark
			end
			for light, brightness in glow.lights do
				light.Brightness = brightness * (1 - dark)
			end
			for label, stroke in glow.labels do
				label.TextTransparency = dark
				label.TextStrokeTransparency = stroke + (1 - stroke) * dark
			end
		end
	end
end

function Mood.start()
	-- What each part of SAFE applies to. A missing effect is left out.
	local targets = {
		lighting = Lighting,
		fog = Lighting:WaitForChild("Fog", 10),
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

	-- The forest's values, gloomier in a stage with gloom (Stages.luau):
	-- thicker fog and darker light.
	local function forest(gloom)
		local values = {}
		for name, base in dark do
			values[name] = table.clone(base)
		end
		if values.fog then
			values.fog.Density = math.min(1, dark.fog.Density + gloom * 0.25)
		end
		values.lighting.Ambient = dark.lighting.Ambient:Lerp(Color3.new(), gloom * 0.35)
		values.lighting.OutdoorAmbient = dark.lighting.OutdoorAmbient:Lerp(Color3.new(), gloom * 0.35)
		return values
	end

	local current -- "safe", "cave" or "dark"
	local currentGloom = 0
	local wasDying = false
	local mist, mistEmitter = makeMist()
	local bank, bankEmitter = makeFogBank()

	local function apply(mood, gloom)
		local wasDark = current == "dark"
		current, currentGloom = mood, gloom
		local values = if mood == "safe" then SAFE elseif mood == "cave" then CAVE else forest(gloom)
		for name, target in targets do
			TweenService:Create(target, FADE, values[name]):Play()
		end
		mistEmitter.Enabled = mood == "dark"
		bankEmitter.Enabled = mood == "dark"
		if mood == "dark" and not wasDark then
			-- Already lying there when you arrive.
			mistEmitter:Emit(100)
			bankEmitter:Emit(300)
		elseif mood ~= "dark" then
			bankEmitter:Clear() -- it would follow you in
		end
	end

	-- The fog bank keeps up with you every frame, or it would jerk along.
	RunService.Heartbeat:Connect(function()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			bank.Position = Vector3.new(root.Position.X, Config.Room.SurfaceY + 1.5, root.Position.Z)
		end
	end)

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
					lightDoors(root.Position)
					local zone = Zones.at(root.Position)
					local mood = if zone == "forest" then "dark" elseif zone == "cave" then "cave" else "safe"
					local stage = Zones.stageAt(root.Position)
					local gloom = if mood == "dark" and stage then Stages[stage].gloom or 0 else 0
					if mood ~= current or gloom ~= currentGloom then
						apply(mood, gloom)
					end
				end
			end
			task.wait(CHECK_INTERVAL)
		end
	end)
end

return Mood
