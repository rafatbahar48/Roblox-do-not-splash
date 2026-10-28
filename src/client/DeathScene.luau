-- What you see when the creature catches you (the server fires Caught).
--
--   0.00s  the grab: the camera snaps round to face it, a red flash
--   0.35s  dragged under: water rises up the screen, the view sinks below the
--          surface and goes murky, blurred and muffled, bubbles rush past,
--          and two red eyes close in
--   1.30s  darkness, then what gave you away ("It heard your splash"), how
--          loud you were, and a tip
--   respawn: you come up gasping; the water drains off and the screen clears

local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local WHITE = Color3.fromRGB(240, 246, 248)
local MUTED = Color3.fromRGB(170, 186, 190)
local MURK = Color3.fromRGB(18, 56, 60)
local RED = Color3.fromRGB(255, 60, 60)

-- What gave you away, by the cause the server reports (server/Noise.luau).
local CAUSES = {
	splash = { "It heard your splash.", "Falling in is the loudest sound there is." },
	wading = { "It heard you wading.", "Every second in the water keeps the noise coming." },
	landing = { "It heard you land.", "Big drops are loud. Hop down where it's lower." },
	creak = { "It heard the floor creak.", "Yellowed tiles creak. Cross them when it's far away." },
}
local UNKNOWN = { "It heard you.", "" }

local DeathScene = {}

local playing = false
local token = 0 -- bumps with each scene, so a leftover delay can't touch a newer one
local baseFov
local ui = {}
local blur, tint
local saved -- lighting and sound settings to put back afterwards

local function create(className, props, children)
	local instance = Instance.new(className)
	for key, value in props do
		instance[key] = value
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	return instance
end

local function round()
	return create("UICorner", { CornerRadius = UDim.new(1, 0) })
end

local function tween(instance, seconds, props, style, direction)
	local t = TweenService:Create(instance, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function cover(name, color, zIndex)
	return create("Frame", {
		Name = name,
		BackgroundColor3 = color,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = zIndex,
	})
end

local function makeEye(xScale)
	return create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(xScale, 0.5),
		Size = UDim2.fromScale(0.34, 1.7),
		BackgroundColor3 = RED,
		BackgroundTransparency = 0.75,
	}, {
		round(),
		create("UIAspectRatioConstraint", { AspectRatio = 1 }),
		create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.36, 0.36),
			BackgroundColor3 = Color3.fromRGB(255, 150, 120),
		}, { round() }),
	})
end

local function build()
	local gui = create("ScreenGui", {
		Name = "DeathScene",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 10, -- over the HUD and the shop
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})

	ui.flash = cover("Flash", Color3.fromRGB(140, 0, 0), 1)
	ui.flash.Parent = gui

	-- Rises from the bottom; the gradient softens its top edge.
	ui.water = create("Frame", {
		Name = "Water",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = MURK,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = gui,
	}, {
		create("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.7),
				NumberSequenceKeypoint.new(0.08, 0),
				NumberSequenceKeypoint.new(1, 0),
			}),
		}),
	})

	ui.bubbles = create("Frame", {
		Name = "Bubbles",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Parent = gui,
	})

	ui.blackout = cover("Blackout", Color3.new(0, 0, 0), 4)
	ui.blackout.Parent = gui

	ui.eyes = create("CanvasGroup", {
		Name = "Eyes",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(120, 30),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		ZIndex = 5,
		Parent = gui,
	}, { makeEye(0.3), makeEye(0.7) })

	ui.recap = create("CanvasGroup", {
		Name = "Recap",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0, 120),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		ZIndex = 6,
		Parent = gui,
	}, { create("UISizeConstraint", { MaxSize = Vector2.new(560, 120) }) })
	ui.title = create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 40),
		Font = Enum.Font.GothamBlack,
		Text = "",
		TextColor3 = WHITE,
		TextScaled = true,
		Parent = ui.recap,
	}, { create("UITextSizeConstraint", { MaxTextSize = 34 }) })
	local meter = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 56),
		Size = UDim2.fromOffset(260, 10),
		BackgroundColor3 = Color3.fromRGB(40, 48, 52),
		BorderSizePixel = 0,
		Parent = ui.recap,
	}, { create("UICorner", { CornerRadius = UDim.new(0, 5) }) })
	ui.fill = create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = RED,
		BorderSizePixel = 0,
		Parent = meter,
	}, { create("UICorner", { CornerRadius = UDim.new(0, 5) }) })
	create("Frame", {
		Position = UDim2.fromScale(Config.Lurker.LungeNoise / Config.Noise.Max, 0),
		Size = UDim2.new(0, 2, 1, 0),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Parent = meter,
	})
	ui.detail = create("TextLabel", {
		Position = UDim2.fromOffset(0, 76),
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Text = "",
		TextColor3 = MUTED,
		TextSize = 16,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = ui.recap,
	})

	ui.drops = create("Frame", {
		Name = "Drops",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 7,
		Parent = gui,
	})

	gui.Parent = player:WaitForChild("PlayerGui")

	-- Client-only screen effects; they stay neutral until a scene plays.
	blur = create("BlurEffect", { Name = "DeathBlur", Size = 0, Parent = Lighting })
	tint = create("ColorCorrectionEffect", { Name = "DeathTint", Parent = Lighting })
end

local function bubbles(count, seconds)
	for _ = 1, count do
		local size = math.random(6, 22)
		local x = math.random()
		local bubble = create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(x, 0, 1, size),
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = Color3.fromRGB(210, 240, 245),
			BackgroundTransparency = 0.6,
			Parent = ui.bubbles,
		}, { round(), create("UIStroke", { Color = WHITE, Transparency = 0.3 }) })
		local wait = math.random() * 0.5
		local rise = seconds * (0.5 + math.random() * 0.6)
		task.delay(wait, function()
			tween(bubble, rise, {
				Position = UDim2.new(x + (math.random() - 0.5) * 0.1, 0, -0.1, 0),
				BackgroundTransparency = 1,
			}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end)
		Debris:AddItem(bubble, wait + rise + 0.1)
	end
end

-- Water beading on the screen as you come up; it runs down and fades.
local function droplets(count)
	for _ = 1, count do
		local size = math.random(14, 46)
		local x, y = math.random(), math.random() * 0.8
		local drop = create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromOffset(size, size * 1.15),
			BackgroundColor3 = Color3.fromRGB(220, 240, 245),
			BackgroundTransparency = 0.8,
			Parent = ui.drops,
		}, { round(), create("UIStroke", { Color = WHITE, Transparency = 0.55 }) })
		local seconds = 0.9 + math.random() * 0.9
		tween(drop, seconds, { Position = UDim2.fromScale(x, y + 0.08 + math.random() * 0.1), BackgroundTransparency = 1 }, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
		local stroke = drop:FindFirstChildOfClass("UIStroke")
		tween(stroke, seconds, { Transparency = 1 }, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
		Debris:AddItem(drop, seconds + 0.1)
	end
end

-- Coming back up: everything the scene changed eases back to normal.
local function surface()
	if not playing then
		return
	end
	playing = false
	token += 1

	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = baseFov
	if saved then
		SoundService.AmbientReverb = saved.reverb
		tween(Lighting, 1.4, { FogStart = saved.fogStart, FogEnd = saved.fogEnd, FogColor = saved.fogColor })
		saved = nil
	end

	ui.eyes.GroupTransparency = 1
	tween(ui.recap, 0.3, { GroupTransparency = 1 })
	tween(ui.blackout, 0.5, { BackgroundTransparency = 1 })
	tween(ui.water, 0.9, { Size = UDim2.fromScale(1, 0) }, Enum.EasingStyle.Sine)
	tween(blur, 1.4, { Size = 0 })
	tween(tint, 1.4, { TintColor = Color3.new(1, 1, 1), Brightness = 0, Saturation = 0 })
	droplets(12)
end

local function play(position, cause, loudness)
	if typeof(position) ~= "Vector3" or playing then
		return
	end
	playing = true
	token += 1
	local id = token
	local function later(seconds, fn)
		task.delay(seconds, function()
			if playing and token == id then
				fn()
			end
		end)
	end

	local camera = workspace.CurrentCamera
	saved = {
		fogStart = Lighting.FogStart,
		fogEnd = Lighting.FogEnd,
		fogColor = Lighting.FogColor,
		reverb = SoundService.AmbientReverb,
	}

	-- The grab
	local eye = camera.CFrame.Position
	camera.CameraType = Enum.CameraType.Scriptable
	tween(camera, 0.25, { CFrame = CFrame.lookAt(eye, position), FieldOfView = baseFov - 15 })
	ui.flash.BackgroundTransparency = 0.25
	tween(ui.flash, 0.6, { BackgroundTransparency = 1 })

	-- Dragged under
	later(0.35, function()
		local flat = Vector3.new(position.X - eye.X, 0, position.Z - eye.Z)
		flat = if flat.Magnitude > 0.1 then flat.Unit else Vector3.zAxis
		local under = Vector3.new(position.X, Config.Room.SurfaceY - 2.5, position.Z) - flat * 3
		tween(camera, 1.1, {
			CFrame = CFrame.lookAt(under, under + flat - Vector3.new(0, 0.15, 0)),
			FieldOfView = baseFov - 25,
		}, Enum.EasingStyle.Sine)

		ui.water.Size = UDim2.fromScale(1, 0)
		tween(ui.water, 0.45, { Size = UDim2.fromScale(1, 1.15) })
		bubbles(28, 1.2)
		tween(blur, 0.6, { Size = 12 })
		tween(tint, 0.6, { TintColor = Color3.fromRGB(130, 205, 200), Brightness = -0.15, Saturation = -0.45 })
		tween(Lighting, 0.8, { FogStart = 0, FogEnd = 24, FogColor = MURK })
		SoundService.AmbientReverb = Enum.ReverbType.UnderWater

		ui.eyes.Size = UDim2.fromOffset(120, 30)
		tween(ui.eyes, 0.5, { GroupTransparency = 0 })
		tween(ui.eyes, 1.4, { Size = UDim2.fromOffset(420, 105) }, Enum.EasingStyle.Sine)
	end)

	-- Darkness, then what gave you away
	later(1.3, function()
		tween(ui.blackout, 0.5, { BackgroundTransparency = 0 })
	end)
	later(1.75, function()
		tween(ui.eyes, 0.45, { GroupTransparency = 1 })
	end)
	later(2.1, function()
		local words = CAUSES[cause] or UNKNOWN
		local level = math.clamp(math.floor(tonumber(loudness) or 0), 0, Config.Noise.Max)
		ui.title.Text = words[1]
		ui.fill.Size = UDim2.fromScale(level / Config.Noise.Max, 1)
		ui.detail.Text = if words[2] ~= "" then ("Noise %d   ·   %s"):format(level, words[2]) else ("Noise %d"):format(level)
		tween(ui.recap, 0.4, { GroupTransparency = 0 })
	end)

	-- In case no new character arrives (left the game, respawn failed).
	later(12, surface)
end

-- True while the scene is playing, so other effects can stay out of the way.
function DeathScene.playing()
	return playing
end

function DeathScene.start()
	baseFov = workspace.CurrentCamera.FieldOfView
	build()
	Remotes.Caught.OnClientEvent:Connect(play)
	player.CharacterAdded:Connect(surface)
end

return DeathScene
