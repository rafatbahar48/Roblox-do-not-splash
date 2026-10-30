-- What you see when the creature catches you. The server fires Caught with
-- where it caught you, what gave you away, how loud you were and which
-- creature it was (server/Lurker.luau), and holds you facing it.
--
--   0.00s  it has you: a red flash, and you are face to face with it, being
--          pulled right up to its face; it stares at you
--   0.75s  its mouth splits open, huge, rows of fangs and a red glow inside
--          (or, if it has a mouth of its own, it gapes at you)
--   1.20s  it lunges at the camera
--   1.55s  cut to a dead TV channel: static, rolling bars, NO SIGNAL
--   3.00s  over the static: what gave you away ("It heard your splash"),
--          how loud you were, and a tip
--   respawn: the static cuts out and you're back

local AssetService = game:GetService("AssetService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local LurkerVisuals = require(script.Parent.LurkerVisuals)

local player = Players.LocalPlayer

local WHITE = Color3.fromRGB(240, 246, 248)
local MUTED = Color3.fromRGB(170, 186, 190)
local RED = Color3.fromRGB(255, 60, 60)

local SNOW_SIZE = Vector2.new(320, 180) -- pixels of fine snow, stretched over the screen
local SNOW_FRAMES = 6 -- drawn once, shown in a random order
local STATIC_COLUMNS, STATIC_ROWS = 64, 36 -- the coarser snow, if images can't be drawn
local STATIC_LAYERS = 3
local CAMERA_STEP = "DeathCamera"

-- What gave you away, by the cause the server reports (server/Noise.luau).
local CAUSES = {
	splash = { "It heard your splash.", "Falling in is the loudest sound there is." },
	wading = { "It heard you wading.", "Every second in the water keeps the noise coming." },
	landing = { "It heard you land.", "Big drops are loud. Hop down where it's lower." },
	creak = { "It heard the boards creak.", "Old boards creak. Cross them when it's far away." },
}
local UNKNOWN = { "It heard you.", "" }

local DeathScene = {}

local playing = false
local token = 0 -- bumps with each scene, so a leftover delay can't touch a newer one
local baseFov
local ui = {}
local hud -- the HUD, hidden while the scene plays
local staticConnection

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

local function tween(instance, seconds, props, style, direction)
	local t = TweenService:Create(instance, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

-- Where the camera films the creature's face from: level in front of its
-- mouth, above the water, and pulled in if a tree is in the way.
local function closeUpFrom(mouth, frame, character)
	local look = Vector3.new(mouth.LookVector.X, 0, mouth.LookVector.Z)
	look = if look.Magnitude > 0.05 then look.Unit else mouth.LookVector
	local face = mouth.Position + Vector3.new(0, frame.aim, 0)
	local spot = mouth.Position + look * frame.distance + Vector3.new(0, frame.height, 0)
	spot = Vector3.new(spot.X, math.max(spot.Y, Config.Room.SurfaceY + 1.5), spot.Z)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, workspace:FindFirstChild("LurkerBodies") }
	local hit = workspace:Raycast(face, spot - face, params)
	if hit then
		spot = hit.Position - (spot - face).Unit * 0.6
	end
	return CFrame.lookAt(spot, face), face
end

local function smooth(alpha)
	alpha = math.clamp(alpha, 0, 1)
	return alpha * alpha * (3 - 2 * alpha)
end

-- Fine TV snow drawn into an image, if this game may draw images (Game
-- Settings > Security > Allow Mesh / Image APIs). Returns nil if it can't.
local function buildSnowImage(parent)
	local ok, image = pcall(AssetService.CreateEditableImage, AssetService, { Size = SNOW_SIZE })
	if not ok or not image then
		return nil
	end
	local pixels = SNOW_SIZE.X * SNOW_SIZE.Y
	local frames = {}
	for f = 1, SNOW_FRAMES do
		local frame = buffer.create(pixels * 4)
		for i = 0, pixels - 1 do
			-- Mostly dark, some bright: grey bytes R, G, B and an opaque A.
			local value = math.floor(math.random() ^ 1.3 * 255)
			buffer.writeu32(frame, i * 4, 0xFF000000 + value * 0x010101)
		end
		frames[f] = frame
		task.wait()
	end
	local label = create("ImageLabel", {
		Name = "Snow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1.04, 1.04),
		BackgroundTransparency = 1,
		ImageContent = Content.fromObject(image),
		Parent = parent,
	})
	return { image = image, frames = frames, label = label }
end

-- One frame of coarser snow: a grid of grey cells. Built a little at a time,
-- so making them doesn't stall the game.
local function buildStaticLayer(parent, index)
	local layer = create("CanvasGroup", {
		Name = "Snow" .. index,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1.04, 1.04), -- a little oversized, so it can jitter
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Visible = false,
		Parent = parent,
	}, {
		create("UIGridLayout", {
			CellPadding = UDim2.new(),
			CellSize = UDim2.fromScale(1 / STATIC_COLUMNS, 1 / STATIC_ROWS),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i = 1, STATIC_COLUMNS * STATIC_ROWS do
		local value = math.random() ^ 1.4
		create("Frame", {
			BackgroundColor3 = Color3.new(value, value, value * 1.04),
			BorderSizePixel = 0,
			LayoutOrder = i,
			Parent = layer,
		})
		if i % 400 == 0 then
			task.wait()
		end
	end
	return layer
end

local function build()
	local gui = create("ScreenGui", {
		Name = "DeathScene",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 10, -- over the HUD and the shop
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})

	ui.flash = create("Frame", {
		Name = "Flash",
		BackgroundColor3 = Color3.fromRGB(140, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
		Parent = gui,
	})

	-- The dead channel: snow, two pale bars rolling down it, and the TV's
	-- own NO SIGNAL message.
	ui.static = create("Frame", {
		Name = "Static",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 2,
		Parent = gui,
	})
	ui.snow = {}
	task.spawn(function()
		ui.snowImage = buildSnowImage(ui.static)
		if not ui.snowImage then
			for i = 1, STATIC_LAYERS do
				ui.snow[i] = buildStaticLayer(ui.static, i)
			end
		end
	end)
	ui.bars = {}
	for i = 1, 2 do
		ui.bars[i] = create("Frame", {
			Name = "Bar",
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.82,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 0.05 + i * 0.03),
			ZIndex = 3,
			Parent = ui.static,
		})
	end
	ui.dim = create("Frame", {
		Name = "Dim",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 4,
		Parent = ui.static,
	})
	ui.noSignal = create("TextLabel", {
		Name = "NoSignal",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(380, 70),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Font = Enum.Font.Arcade,
		Text = "NO SIGNAL",
		TextColor3 = WHITE,
		TextSize = 48,
		ZIndex = 5,
		Parent = ui.static,
	})

	ui.recap = create("CanvasGroup", {
		Name = "Recap",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.58),
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
		TextStrokeTransparency = 0.4,
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
		TextStrokeTransparency = 0.5,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = ui.recap,
	})

	gui.Parent = player:WaitForChild("PlayerGui")
end

-- Snow: a different frame of it every frame, jittered, with the bars rolling
-- down.
local function startStatic()
	ui.static.Visible = true
	ui.dim.BackgroundTransparency = 1
	local shown
	local start = os.clock()
	staticConnection = RunService.RenderStepped:Connect(function()
		local layers = ui.snow
		local snow = ui.snowImage
		if snow then
			snow.image:WritePixelsBuffer(Vector2.zero, SNOW_SIZE, snow.frames[math.random(1, #snow.frames)])
			snow.label.Position = UDim2.new(0.5, math.random(-6, 6), 0.5, math.random(-4, 4))
		elseif #layers > 0 then
			if shown then
				shown.Visible = false
			end
			shown = layers[math.random(1, #layers)]
			shown.Visible = true
			shown.Position = UDim2.new(0.5, math.random(-12, 12), 0.5, math.random(-8, 8))
			shown.Rotation = if math.random() < 0.5 then 0 else 180
		end
		local t = os.clock() - start
		for i, bar in ui.bars do
			bar.Position = UDim2.fromScale(0, ((t * (0.35 + i * 0.2) + i * 0.4) % 1.3) - 0.15)
		end
		-- The message flickers now and then, like an old set.
		ui.noSignal.TextTransparency = if math.random() < 0.06 then 0.6 else 0
	end)
end

local function stopStatic()
	if staticConnection then
		staticConnection:Disconnect()
		staticConnection = nil
	end
	ui.static.Visible = false
end

-- Back to the game: everything the scene changed is put back.
local function surface()
	if not playing then
		return
	end
	playing = false
	token += 1

	RunService:UnbindFromRenderStep(CAMERA_STEP)
	stopStatic()
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = baseFov
	ui.flash.BackgroundTransparency = 1
	ui.recap.GroupTransparency = 1
	if hud then
		hud.Enabled = true
		hud = nil
	end
end

local function play(position, cause, loudness, anchor)
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

	hud = player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("Hud")
	if hud then
		hud.Enabled = false
	end
	if typeof(anchor) == "Instance" then
		-- Its mouth stays shut until the camera is right up at its face.
		LurkerVisuals.roar(anchor, 0.75, 1.2)
	end

	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	local from = camera.CFrame
	local character = player.Character
	-- Your own body would only get in the way of its face.
	if character then
		for _, item in character:GetDescendants() do
			if item:IsA("BasePart") or item:IsA("Decal") then
				item.LocalTransparencyModifier = 1
			end
		end
	end
	local start = os.clock()
	ui.flash.BackgroundTransparency = 0.3
	tween(ui.flash, 0.5, { BackgroundTransparency = 1 })

	local shot -- where the camera is, gliding after where it should be
	RunService:BindToRenderStep(CAMERA_STEP, Enum.RenderPriority.Camera.Value + 2, function(dt)
		local t = os.clock() - start
		local mouth, frame
		if typeof(anchor) == "Instance" then
			mouth, frame = LurkerVisuals.face(anchor)
		end
		mouth = mouth or CFrame.lookAt(position + Vector3.new(0, 4, 0) - from.LookVector * 4, position)
		frame = frame or { distance = 3.1, height = 0.35, aim = 0.45 }
		local closeUp, face = closeUpFrom(mouth, frame, character)
		local want, shake = nil, 0.004
		if t < 1 then
			-- Face to face with it at once (from where you were, the way up
			-- to its face goes through its body), pulled in close.
			local away = closeUpFrom(mouth, { distance = frame.distance + 4, height = frame.height + 0.6, aim = frame.aim }, character)
			want = away:Lerp(closeUp, smooth(t / 0.9))
		else
			-- It stares, its mouth opens, and it lunges at you.
			local lunge = math.clamp((t - 1.2) / 0.35, 0, 1) ^ 2
			local into = CFrame.lookAt(face:Lerp(closeUp.Position, 0.3), mouth.Position)
			want = closeUp:Lerp(into, lunge)
			shake += lunge * 0.026
		end
		-- Glide rather than jump when a branch moves in and out of the way.
		shot = if shot then shot:Lerp(want, 1 - math.exp(-dt * 14)) else want
		camera.CFrame = shot * CFrame.Angles((math.random() - 0.5) * shake, (math.random() - 0.5) * shake, 0)
		camera.FieldOfView = baseFov + (50 - baseFov) * smooth(t / 1) - 10 * math.clamp((t - 1.2) / 0.35, 0, 1)
	end)

	-- Cut to a dead channel.
	later(1.55, function()
		RunService:UnbindFromRenderStep(CAMERA_STEP)
		startStatic()
	end)

	-- What gave you away, over the snow.
	later(3, function()
		local words = CAUSES[cause] or UNKNOWN
		local level = math.clamp(math.floor(tonumber(loudness) or 0), 0, Config.Noise.Max)
		ui.title.Text = words[1]
		ui.fill.Size = UDim2.fromScale(level / Config.Noise.Max, 1)
		ui.detail.Text = if words[2] ~= "" then ("Noise %d   ·   %s"):format(level, words[2]) else ("Noise %d"):format(level)
		tween(ui.dim, 0.5, { BackgroundTransparency = 0.45 })
		tween(ui.recap, 0.4, { GroupTransparency = 0 })
	end)

	-- In case no new character arrives (left the game, respawn failed).
	later(Config.RespawnTime + 6, surface)
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
