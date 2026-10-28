-- Draws and animates the creatures on this client. The server moves one
-- invisible anchor per creature (server/Lurker.luau); here each anchor gets a
-- body. The head eases after the anchor, the body follows the path the head
-- took and sways as it swims, the jaw opens to strike, and the eyes burn red
-- while it hunts. Ripples and the odd bubble give away where it is.
--
-- Creatures far from the camera are left where they are until you get close.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local SEGMENTS = 12
local SPACING = 0.95 -- studs between body segments
local NECK = 1.3 -- from the head to the first segment
local ANIMATE_RANGE = 170
local SURFACE_Y = Config.Room.SurfaceY

local SKIN = Color3.fromRGB(28, 34, 32)
local FIN = Color3.fromRGB(46, 54, 52)
local MOUTH = Color3.fromRGB(74, 24, 28)
local TOOTH = Color3.fromRGB(214, 206, 180)
local EYE_IDLE = Color3.fromRGB(120, 86, 34)
local EYE_ALERT = Color3.fromRGB(255, 48, 28)
local RIPPLE = Color3.fromRGB(150, 180, 186)

-- Where the lower jaw swings from, relative to the head.
local HINGE = CFrame.new(0, -0.35, -0.45)
local FLIP = CFrame.Angles(0, 0, math.pi) -- turns a wedge upside down

local LurkerVisuals = {}

local bodies -- client-only folder for the bodies, ripples and bubbles
local creatures = {} -- [anchor] = creature

local function makePart(className, name, size, color, material)
	local part = Instance.new(className)
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	if not material then
		part.Reflectance = 0.06 -- a wet sheen
	end
	part.Size = size
	return part
end

local function ball(name, diameter, color, material)
	local part = makePart("Part", name, Vector3.one * diameter, color, material)
	part.Shape = Enum.PartType.Ball
	return part
end

local function build(anchor)
	local model = Instance.new("Model")
	model.Name = "LurkerBody"

	local creature = {
		anchor = anchor,
		model = model,
		rigid = {}, -- { part, offset } carried by the head
		jaw = {}, -- { part, offset } carried by the lower jaw, from the hinge
		segments = {},
		spikes = {}, -- { part, segment, offset }
		tail = {}, -- { part, offset } carried by the last segment
		eyes = {},
		pos = anchor.Position,
		look = anchor.CFrame.LookVector,
		speed = 0,
		phase = math.random() * math.pi * 2,
		jawOpen = 0,
		trail = {},
		points = {},
		swayed = {},
		segmentCFrames = {},
		parts = {},
		cframes = {},
		nextRipple = 0,
		nextBubble = os.clock() + math.random() * 2,
	}

	local function add(list, part, offset)
		part.Parent = model
		table.insert(list, { part = part, offset = offset })
		return part
	end

	-- Head (facing -Z)
	add(creature.rigid, ball("Skull", 2.3, SKIN), CFrame.new(0, 0.15, 0.25))
	add(creature.rigid, makePart("WedgePart", "Snout", Vector3.new(1.5, 0.75, 2.5), SKIN), CFrame.new(0, 0.2, -1.55))
	add(creature.rigid, makePart("Part", "Palate", Vector3.new(1.3, 0.12, 2.1), MOUTH, Enum.Material.SmoothPlastic), CFrame.new(0, -0.2, -1.4))
	for _, side in { -1, 1 } do
		for k = 0, 2 do
			add(creature.rigid, makePart("Part", "Tooth", Vector3.new(0.12, 0.38, 0.12), TOOTH, Enum.Material.SmoothPlastic), CFrame.new(side * 0.52, -0.42, -0.8 - k * 0.6))
		end
		local eye = add(creature.rigid, ball("Eye", 0.42, EYE_IDLE, Enum.Material.Neon), CFrame.new(side * 0.68, 0.66, -0.5))
		table.insert(creature.eyes, eye)
		table.insert(creature.eyes, add(creature.rigid, ball("SmallEye", 0.22, EYE_IDLE, Enum.Material.Neon), CFrame.new(side * 0.5, 0.42, -1.05)))
		add(creature.rigid, makePart("WedgePart", "Fin", Vector3.new(0.08, 0.5, 1.5), FIN), CFrame.new(side * 1.15, -0.45, 0.9) * CFrame.Angles(0, 0, side * 0.9))
		add(creature.rigid, makePart("Part", "Barbel", Vector3.new(0.06, 0.06, 1.3), SKIN), CFrame.new(side * 0.62, -0.35, -2.15) * CFrame.Angles(0.55, side * 0.45, 0))
	end
	add(creature.rigid, makePart("Part", "Tooth", Vector3.new(0.12, 0.42, 0.12), TOOTH, Enum.Material.SmoothPlastic), CFrame.new(0, -0.44, -2.55))

	-- Lower jaw (from the hinge)
	add(creature.jaw, makePart("WedgePart", "Jaw", Vector3.new(1.3, 0.55, 2.1), SKIN), CFrame.new(0, -0.25, -1.05) * FLIP)
	add(creature.jaw, makePart("Part", "Tongue", Vector3.new(1.05, 0.1, 1.8), MOUTH, Enum.Material.SmoothPlastic), CFrame.new(0, 0.04, -0.95))
	for _, side in { -1, 1 } do
		for k = 0, 2 do
			add(creature.jaw, makePart("Part", "Tooth", Vector3.new(0.11, 0.34, 0.11), TOOTH, Enum.Material.SmoothPlastic), CFrame.new(side * 0.46, 0.2, -0.45 - k * 0.55))
		end
	end

	local glow = Instance.new("PointLight")
	glow.Color = EYE_ALERT
	glow.Range = 10
	glow.Brightness = 0
	glow.Parent = creature.eyes[1]
	creature.glow = glow

	-- Body: a tapering chain, with a ridge of spines and a tail fin.
	for i = 1, SEGMENTS do
		local t = (i - 1) / (SEGMENTS - 1)
		local size = 2.0 + (0.45 - 2.0) * t
		local segment = ball("Segment", size, SKIN)
		segment.Parent = model
		creature.segments[i] = segment
		if i <= 9 then
			local spike = makePart("WedgePart", "Spine", Vector3.new(0.1, 0.75 * size, 0.9 * size), FIN)
			spike.Parent = model
			table.insert(creature.spikes, { part = spike, segment = i, offset = CFrame.new(0, size * 0.42, 0) })
		end
	end
	add(creature.tail, makePart("WedgePart", "TailFin", Vector3.new(0.08, 1.3, 1.8), FIN), CFrame.new(0, 0.55, 0.85))
	add(creature.tail, makePart("WedgePart", "TailFin", Vector3.new(0.08, 1.3, 1.8), FIN), CFrame.new(0, -0.55, 0.85) * FLIP)

	-- One flat list in a fixed order, so every frame is a single BulkMoveTo.
	for _, entry in creature.rigid do
		table.insert(creature.parts, entry.part)
	end
	for _, entry in creature.jaw do
		table.insert(creature.parts, entry.part)
	end
	for _, segment in creature.segments do
		table.insert(creature.parts, segment)
	end
	for _, entry in creature.spikes do
		table.insert(creature.parts, entry.part)
	end
	for _, entry in creature.tail do
		table.insert(creature.parts, entry.part)
	end

	model.Parent = bodies
	return creature
end

local function setAlert(creature)
	local alert = creature.anchor:GetAttribute("Alert") == true
	local lunging = creature.anchor:GetAttribute("Lunging") == true
	creature.alert = alert
	creature.lunging = lunging
	for _, eye in creature.eyes do
		eye.Color = if alert or lunging then EYE_ALERT else EYE_IDLE
	end
	creature.glow.Brightness = if lunging then 6 elseif alert then 2.5 else 0
end

local function ripple(position, size, transparency)
	local ring = makePart("Part", "Ripple", Vector3.new(0.08, size, size), RIPPLE, Enum.Material.SmoothPlastic)
	ring.Shape = Enum.PartType.Cylinder
	ring.Transparency = transparency
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Parent = bodies
	TweenService:Create(ring, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.08, size * 3.2, size * 3.2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 1.2)
end

local function bubble(position)
	local part = ball("Bubble", 0.2 + math.random() * 0.15, Color3.fromRGB(200, 230, 235), Enum.Material.Glass)
	part.Transparency = 0.35
	part.CFrame = CFrame.new(position)
	part.Parent = bodies
	TweenService:Create(part, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
		CFrame = CFrame.new(position.X, SURFACE_Y, position.Z),
	}):Play()
	Debris:AddItem(part, 0.85)
end

-- Fills creature.points with positions along the path behind the head, at
-- NECK, NECK + SPACING, ... Past the end of the trail it carries on straight
-- back. Drops trail points nothing uses any more.
local function sampleTrail(creature)
	local trail, points = creature.trail, creature.points
	local back = -creature.look
	local previous = creature.pos
	local travelled = 0
	local index = 1
	for i = 1, SEGMENTS do
		local want = NECK + (i - 1) * SPACING
		while true do
			local nextPoint = trail[index]
			if not nextPoint then
				points[i] = previous + back * (want - travelled)
				break
			end
			local length = (nextPoint - previous).Magnitude
			if travelled + length >= want and length > 0 then
				points[i] = previous:Lerp(nextPoint, (want - travelled) / length)
				break
			end
			travelled += length
			previous = nextPoint
			index += 1
		end
	end
	for i = #trail, index + 2, -1 do
		trail[i] = nil
	end
end

local function lookFrom(from, to, fallback)
	if (to - from).Magnitude < 1e-3 then
		return CFrame.lookAt(from, from + fallback)
	end
	return CFrame.lookAt(from, to)
end

local function update(creature, dt, now)
	local anchorCFrame = creature.anchor.CFrame

	-- The head eases after the anchor, faster when striking.
	local follow = 1 - math.exp(-dt * (if creature.lunging then 18 else 9))
	local position = creature.pos:Lerp(anchorCFrame.Position, follow)
	local speed = (position - creature.pos).Magnitude / math.max(dt, 1e-3)
	creature.speed += (speed - creature.speed) * math.min(1, dt * 4)
	creature.pos = position

	local look = creature.look:Lerp(anchorCFrame.LookVector, math.min(1, dt * 7))
	creature.look = if look.Magnitude > 1e-3 then look.Unit else anchorCFrame.LookVector

	local trail = creature.trail
	if not trail[1] or (position - trail[1]).Magnitude > 0.25 then
		table.insert(trail, 1, position)
	end

	creature.phase += dt * (1.6 + creature.speed * 0.35)
	local sway = 0.12 + math.min(creature.speed, 16) / 16 * 0.5

	local jawTarget = if creature.lunging then 0.95 elseif creature.alert then 0.22 + 0.12 * math.sin(now * 9) else 0.05
	creature.jawOpen += (jawTarget - creature.jawOpen) * math.min(1, dt * (if creature.lunging then 14 else 6))

	local head = CFrame.lookAt(position, position + creature.look) * CFrame.Angles(creature.jawOpen * 0.5, math.sin(creature.phase) * sway * 0.25, 0)
	local hinge = head * HINGE * CFrame.Angles(-creature.jawOpen, 0, 0)

	local cframes = creature.cframes
	local n = 0
	for _, entry in creature.rigid do
		n += 1
		cframes[n] = head * entry.offset
	end
	for _, entry in creature.jaw do
		n += 1
		cframes[n] = hinge * entry.offset
	end

	-- Body along the trail, swaying more towards the tail.
	sampleTrail(creature)
	local points, swayed = creature.points, creature.swayed
	for i = 1, SEGMENTS do
		local ahead = if i == 1 then position else points[i - 1]
		local direction = ahead - points[i]
		local side = direction:Cross(Vector3.yAxis)
		side = if side.Magnitude > 1e-3 then side.Unit else Vector3.xAxis
		local t = i / SEGMENTS
		swayed[i] = points[i] + side * math.sin(creature.phase - i * 0.6) * sway * (0.3 + 0.9 * t)
	end
	local segmentCFrames = creature.segmentCFrames
	for i = 1, SEGMENTS do
		local ahead = if i == 1 then position else swayed[i - 1]
		segmentCFrames[i] = lookFrom(swayed[i], ahead, creature.look)
		n += 1
		cframes[n] = segmentCFrames[i]
	end
	for _, entry in creature.spikes do
		n += 1
		cframes[n] = segmentCFrames[entry.segment] * entry.offset
	end
	local last = segmentCFrames[SEGMENTS]
	for _, entry in creature.tail do
		n += 1
		cframes[n] = last * entry.offset
	end

	workspace:BulkMoveTo(creature.parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)

	-- Signs on the surface.
	local nearSurface = position.Y > SURFACE_Y - 3 and position.Y < SURFACE_Y + 0.5
	if nearSurface and now >= creature.nextRipple and (creature.alert or creature.speed > 4) then
		creature.nextRipple = now + (if creature.alert then 0.35 else 0.9)
		ripple(Vector3.new(position.X, SURFACE_Y + 0.05, position.Z), if creature.alert then 1.6 else 1.1, if creature.alert then 0.55 else 0.82)
	end
	if position.Y < SURFACE_Y and now >= creature.nextBubble then
		creature.nextBubble = now + 1.2 + math.random() * 2
		bubble(position + Vector3.new(0, 1.2, 0))
	end
end

local function track(anchor)
	if creatures[anchor] or not anchor:IsA("BasePart") then
		return
	end
	local creature = build(anchor)
	creatures[anchor] = creature
	setAlert(creature)
	anchor:GetAttributeChangedSignal("Alert"):Connect(function()
		setAlert(creature)
	end)
	anchor:GetAttributeChangedSignal("Lunging"):Connect(function()
		setAlert(creature)
	end)
	update(creature, 1 / 60, os.clock())
end

local function untrack(anchor)
	local creature = creatures[anchor]
	if creature then
		creatures[anchor] = nil
		creature.model:Destroy()
	end
end

function LurkerVisuals.start()
	bodies = Instance.new("Folder")
	bodies.Name = "LurkerBodies"
	bodies.Parent = workspace

	task.spawn(function()
		local anchors = workspace:WaitForChild("Lurkers")
		anchors.ChildAdded:Connect(track)
		anchors.ChildRemoved:Connect(untrack)
		for _, anchor in anchors:GetChildren() do
			track(anchor)
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		local camera = workspace.CurrentCamera
		local eye = camera.CFrame.Position
		local now = os.clock()
		for anchor, creature in creatures do
			if (anchor.Position - eye).Magnitude <= ANIMATE_RANGE then
				update(creature, dt, now)
			end
		end
	end)
end

return LurkerVisuals
