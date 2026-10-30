-- Draws and animates the creatures on this client. The server moves one
-- invisible anchor per creature at its feet (server/Lurker.luau); here each
-- anchor gets a body: very long legs whose knees bend backwards, a hunched
-- back, arms that hang to its knees, and red eyes that burn brighter while
-- it hunts. Its face is smooth until it grabs someone; then a huge mouth
-- full of fangs splits open (client/DeathScene.luau films it up close).
--
-- The body is the Meshy model in ReplicatedStorage.Creatures (the first model
-- there), posed bone by bone. Without one, a body built from parts stands in.
-- Either way the pose is worked out every frame from where its feet step
-- (two-bone IK for legs and arms), so it strides, stops dead, stands and
-- watches, and runs, with no animation files. Ripples spread where its feet
-- go in.
--
-- Attributes on the model:
--   OwnMouth  true if it has a mouth of its own (its headfront bone marks it);
--             otherwise one opens up out of its face when it grabs
--   Eyes      false to leave off the glowing eyes; its throat glows instead
--   CloseUpDistance, CloseUpHeight, CloseUpAim
--             where the death scene's camera goes in front of its mouth, how
--             far above the mouth, and how far above the mouth it looks
--             (studs; bigger mouths want the camera further back)
--
-- Creatures too far away to see through the fog are left where they are.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(script.Parent.Sounds)

local ANIMATE_RANGE = 300 -- past the fog
local SURFACE_Y = Config.Room.SurfaceY
local STRIDE_WALK, STRIDE_RUN = 4.5, 8
local LIFT_WALK, LIFT_RUN = 1.6, 3

-- The part-built body's proportions, in studs. It stands about 22 tall.
local PARTS = {
	hipHeight = 11.6,
	thigh = 6.6,
	shin = 6.9,
	footSpread = 1.35,
	ankleHeight = 0.4,
	torso = 5.4,
	neck = 2,
	upperArm = 5.2,
	forearm = 5.2,
	shoulderWidth = 1.3,
}

local SKIN = Color3.fromRGB(150, 160, 150)
local DARK = Color3.fromRGB(96, 104, 98)
local THROAT = Color3.fromRGB(34, 4, 6)
local TOOTH = Color3.fromRGB(226, 220, 196)
local TEETH = 7 -- in each row
local EYE_IDLE = Color3.fromRGB(120, 16, 14)
local EYE_ALERT = Color3.fromRGB(255, 40, 28)
local RIPPLE = Color3.fromRGB(150, 170, 180)
-- Its sounds (Config.Sounds): how loud (Roblox's scale, up to 10), loudest
-- within near studs, gone past far, and how fast they fade in between.
local STEPS = { volume = 4, near = 10, far = 230, mode = Enum.RollOffMode.Linear }
local GROWL = { volume = 3.5, near = 4, far = 120, mode = Enum.RollOffMode.LinearSquare }

local LurkerVisuals = {}

local CLOSE_UP = { distance = 3.1, height = 0.35, aim = 0.45 }

local bodies -- client-only folder for the bodies and ripples
local creatures = {} -- [anchor] = creature
local template -- the Meshy model, if the place has it

local function makePart(name, size, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = true
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Reflectance = if material then 0 else 0.08 -- a wet sheen
	part.Size = size
	return part
end

local function ball(name, diameter, color, material)
	local part = makePart(name, Vector3.one * diameter, color, material)
	part.Shape = Enum.PartType.Ball
	return part
end

-- Where the middle joint goes for a limb from root to tip with these two
-- lengths, bending towards hint.
local function solve(root, tip, upper, lower, hint)
	local offset = tip - root
	local distance = math.clamp(offset.Magnitude, 0.01, upper + lower - 0.01)
	local direction = if offset.Magnitude > 1e-3 then offset.Unit else -Vector3.yAxis
	local along = (upper * upper - lower * lower + distance * distance) / (2 * distance)
	local out = math.sqrt(math.max(0, upper * upper - along * along))
	local bend = hint - direction * hint:Dot(direction)
	bend = if bend.Magnitude > 1e-3 then bend.Unit else Vector3.zAxis
	return root + direction * along + bend * out
end

local function between(a, b)
	return CFrame.lookAt((a + b) / 2, b)
end

-- The shortest turn that takes direction a to direction b.
local function arc(a, b)
	local axis = a:Cross(b)
	local dot = math.clamp(a:Dot(b), -1, 1)
	if axis.Magnitude < 1e-5 then
		return if dot > 0 then CFrame.identity else CFrame.fromAxisAngle(Vector3.xAxis, math.pi)
	end
	return CFrame.fromAxisAngle(axis.Unit, math.acos(dot))
end

-- Turns a bone so it points along direction (its own +Y points at its
-- child), given its parent's world CFrame. Returns its new world CFrame.
local function aim(bone, parentWorld, direction)
	local rest = parentWorld * bone.CFrame
	local world = CFrame.new(rest.Position) * arc(rest.UpVector, direction.Unit) * rest.Rotation
	bone.Transform = rest:Inverse() * world
	return world
end

-- Moves a bone to position without turning it. Returns its new world CFrame.
local function place(bone, parentWorld, position)
	local rest = parentWorld * bone.CFrame
	local world = rest.Rotation + position
	bone.Transform = rest:Inverse() * world
	return world
end

-- Bodies -----------------------------------------------------------------------

-- Without eyes, the red glow comes from its throat: a glowing core in its
-- open mouth while it comes for you, so you see it through the fog.
local function addThroatGlow(creature)
	local holder = ball("Glow", 0.5, EYE_ALERT, Enum.Material.Neon)
	holder.Transparency = 1
	holder.CastShadow = false
	holder.Parent = creature.model
	table.insert(creature.parts, holder)
	creature.glowPart = holder
	local glow = Instance.new("PointLight")
	glow.Color = EYE_ALERT
	glow.Range = 9
	glow.Brightness = 0.4
	glow.Parent = holder
	creature.glow = glow
end

local function addEyes(creature, size)
	for _ = 1, 2 do
		local eye = ball("Eye", size, EYE_IDLE, Enum.Material.Neon)
		eye.CastShadow = false
		eye.Parent = creature.model
		table.insert(creature.eyes, eye)
		table.insert(creature.parts, eye)
	end
	local glow = Instance.new("PointLight")
	glow.Color = EYE_ALERT
	glow.Range = 9
	glow.Brightness = 0.4
	glow.Parent = creature.eyes[1]
	creature.glow = glow
end

-- The mouth: a dark throat and two rows of fangs, out of sight until it
-- opens. Posed every frame from creature.mouth, a CFrame on the face with -Z
-- pointing out of it.
local function addMaw(creature)
	local maw = { teeth = {} }
	-- A sphere mesh, so it can stretch into an oval (a Ball part can't).
	maw.throat = makePart("Throat", Vector3.one, THROAT)
	maw.throat.CastShadow = false
	maw.throat.Reflectance = 0
	local oval = Instance.new("SpecialMesh")
	oval.MeshType = Enum.MeshType.Sphere
	oval.Parent = maw.throat
	maw.throat.Parent = creature.model
	table.insert(creature.parts, maw.throat)
	maw.light = Instance.new("PointLight")
	maw.light.Color = EYE_ALERT
	maw.light.Range = 5
	maw.light.Brightness = 0
	maw.light.Parent = maw.throat
	for row = 1, 2 do
		for i = 1, TEETH do
			local tooth = Instance.new("WedgePart")
			tooth.Name = "Fang"
			tooth.Anchored = true
			tooth.CanCollide = false
			tooth.CanQuery = false
			tooth.CanTouch = false
			tooth.CastShadow = false
			tooth.Color = TOOTH
			tooth.Material = Enum.Material.SmoothPlastic
			tooth.Size = Vector3.new(0.08, 0.5, 0.2)
			tooth.Parent = creature.model
			table.insert(maw.teeth, { part = tooth, row = row, i = i })
			table.insert(creature.parts, tooth)
		end
	end
	creature.maw = maw
end

-- Where the mouth's parts go for how far open it is (0 shut .. 1 wide).
local function poseMaw(creature, cframes)
	local maw, open, mouth = creature.maw, creature.mawOpen, creature.mouth
	local hidden = open < 0.03
	local width, height = 0.8 + 0.7 * open, 0.15 + 1.5 * open
	local center = mouth * CFrame.new(0, -0.15 * open, 0)
	maw.throat.Transparency = if hidden then 1 else 0
	maw.throat.Size = Vector3.new(width * 1.06, height * 1.06, 0.7)
	maw.light.Brightness = open * 1.4
	cframes[maw.throat] = center * CFrame.new(0, 0, 0.12)
	for _, tooth in maw.teeth do
		-- Along the top and bottom of an oval, longest in the middle; the top
		-- row hangs down, the bottom row points up.
		local u = (tooth.i - (TEETH + 1) / 2) / ((TEETH + 1) / 2)
		local edge = height / 2 * math.sqrt(math.max(0, 1 - u * u))
		local length = (0.3 + 0.55 * open) * (1 - 0.4 * math.abs(u))
		local part = tooth.part
		part.Transparency = if hidden then 1 else 0
		part.Size = Vector3.new(0.2, length, width / (TEETH + 1) * 1.2)
		local y = if tooth.row == 1 then edge - length / 2 else -edge + length / 2
		local flip = if tooth.row == 1 then CFrame.Angles(0, 0, math.pi) else CFrame.identity
		cframes[part] = center * CFrame.new(u * width / 2, y, -0.05) * flip * CFrame.Angles(0, math.pi / 2, 0)
	end
end

local function buildParts(creature)
	local function add(name, part)
		part.Parent = creature.model
		creature.limbs[name] = part
		table.insert(creature.parts, part)
		return part
	end
	for _, side in { "L", "R" } do
		add("Thigh" .. side, makePart("Thigh", Vector3.new(0.8, 0.8, PARTS.thigh), SKIN))
		add("Knee" .. side, ball("Knee", 0.95, SKIN))
		add("Shin" .. side, makePart("Shin", Vector3.new(0.55, 0.55, PARTS.shin), SKIN))
		add("Ankle" .. side, ball("Ankle", 0.6, DARK))
		for toe = 1, 3 do
			add("Toe" .. side .. toe, makePart("Toe", Vector3.new(0.22, 0.22, 2), DARK))
		end
		add("Spur" .. side, makePart("Spur", Vector3.new(0.2, 0.2, 1), DARK))
		add("UpperArm" .. side, makePart("UpperArm", Vector3.new(0.5, 0.5, PARTS.upperArm), SKIN))
		add("Elbow" .. side, ball("Elbow", 0.6, SKIN))
		add("Forearm" .. side, makePart("Forearm", Vector3.new(0.42, 0.42, PARTS.forearm), SKIN))
		add("Hand" .. side, makePart("Hand", Vector3.new(0.6, 0.25, 0.9), SKIN))
		for finger = 1, 3 do
			add("Finger" .. side .. finger, makePart("Finger", Vector3.new(0.14, 0.14, 1.6), DARK))
		end
	end
	add("Pelvis", ball("Pelvis", 1.8, SKIN))
	add("Waist", makePart("Waist", Vector3.new(1.1, 0.9, PARTS.torso * 0.45), SKIN))
	add("Ribs", makePart("Ribs", Vector3.new(2.3, 1.5, PARTS.torso * 0.6), SKIN))
	add("Neck", makePart("Neck", Vector3.new(0.45, 0.45, PARTS.neck), SKIN))
	add("Head", makePart("Head", Vector3.new(1.4, 1.9, 1.6), SKIN))
	addEyes(creature, 0.38)
	addMaw(creature)
	creature.dims = PARTS
end

-- The Meshy model: one skinned mesh. Measures its own bones, standing at
-- rest, so the legs and arms keep their lengths.
local function buildSkinned(creature)
	local model = template:Clone()
	model.Parent = creature.model
	local mesh = model.PrimaryPart or model:FindFirstChildWhichIsA("MeshPart", true)
	local bones = {}
	for _, item in mesh:GetDescendants() do
		if item:IsA("Bone") then
			bones[item.Name] = item
		end
	end
	-- Where it stands: the bottom of its mesh, facing the way the mesh does
	-- (-Z). Models don't agree on where their own origin is.
	local pivot = mesh.CFrame * CFrame.new(0, -mesh.Size.Y / 2, 0)
	local function rest(name)
		return pivot:PointToObjectSpace(bones[name].WorldPosition)
	end
	creature.mesh = mesh
	creature.meshOffset = pivot:ToObjectSpace(mesh.CFrame)
	creature.closeUp = {
		distance = template:GetAttribute("CloseUpDistance") or CLOSE_UP.distance,
		height = template:GetAttribute("CloseUpHeight") or CLOSE_UP.height,
		aim = template:GetAttribute("CloseUpAim") or CLOSE_UP.aim,
	}
	creature.bones = bones
	creature.dims = {
		hipHeight = rest("Hips").Y * 0.9, -- knees a little bent
		thigh = (rest("LeftLeg") - rest("LeftUpLeg")).Magnitude,
		shin = (rest("LeftFoot") - rest("LeftLeg")).Magnitude,
		footSpread = math.abs(rest("LeftFoot").X) * 0.75,
		ankleHeight = rest("LeftFoot").Y,
		upperArm = (rest("LeftForeArm") - rest("LeftArm")).Magnitude,
		forearm = (rest("LeftHand") - rest("LeftForeArm")).Magnitude,
	}
	local head = bones.Head.WorldCFrame
	creature.eyeOffsets = {}
	if template:GetAttribute("Eyes") ~= false then
		-- The eyes in the texture are small; neon ones on top glow through fog.
		for _, sign in { -1, 1 } do
			table.insert(creature.eyeOffsets, head:ToObjectSpace(pivot * CFrame.new(sign * 0.3, rest("Head").Y + 1.35, rest("Head").Z - 0.62)))
		end
		addEyes(creature, 0.26)
	else
		addThroatGlow(creature)
	end
	if template:GetAttribute("OwnMouth") == true and bones.headfront then
		-- Its own mouth, facing the way it does.
		creature.mouthOffset = head:ToObjectSpace(pivot.Rotation + bones.headfront.WorldPosition)
	else
		-- The mouth sits low on the face, under the eyes.
		creature.mouthOffset = head:ToObjectSpace(pivot * CFrame.new(0, rest("Head").Y + 0.7, rest("Head").Z - 1.4))
		addMaw(creature)
	end
	table.insert(creature.parts, 1, mesh)
end

local function build(anchor)
	local creature = {
		anchor = anchor,
		model = Instance.new("Model"),
		pos = anchor.Position,
		look = anchor.CFrame.LookVector,
		speed = 0,
		moving = 0, -- 0 standing still .. 1 striding
		phase = math.random() * math.pi * 2,
		crouch = 0, -- 0 upright .. 1 reaching down to grab
		mawOpen = 0, -- 0 shut .. 1 wide
		closeUp = CLOSE_UP,
		parts = {}, -- moved together with one BulkMoveTo
		cframes = {},
		limbs = {},
		eyes = {},
		lastLift = { 0, 0 },
	}
	creature.model.Name = "CreatureBody"
	if template then
		buildSkinned(creature)
	else
		buildParts(creature)
	end
	creature.model.Parent = bodies
	return creature
end

local function setAlert(creature)
	local anchor = creature.anchor
	creature.alert = anchor:GetAttribute("Alert") == true
	creature.running = anchor:GetAttribute("Running") == true
	creature.lunging = anchor:GetAttribute("Lunging") == true
	local burning = creature.alert or creature.lunging
	for _, eye in creature.eyes do
		eye.Color = if burning then EYE_ALERT else EYE_IDLE
	end
	creature.glow.Brightness = if creature.lunging then 1.6 elseif burning then 1.1 else 0.4
	-- Its feet in the water while it runs, and a growl while it hunts. While
	-- it only watches from the fog it makes no sound at all.
	local function playIf(sound, on)
		if sound and on ~= sound.IsPlaying then
			if on then
				sound:Play()
			else
				sound:Stop()
			end
		end
	end
	playIf(creature.steps, creature.running and not creature.lunging)
	playIf(creature.growl, creature.alert and not creature.lunging)
end

local function ripple(position, size, transparency)
	local ring = makePart("Ripple", Vector3.new(0.08, size, size), RIPPLE)
	ring.Shape = Enum.PartType.Cylinder
	ring.CastShadow = false
	ring.Reflectance = 0
	ring.Transparency = transparency
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Parent = bodies
	TweenService:Create(ring, TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.08, size * 3.5, size * 3.5),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 1.4)
end

-- Movement ------------------------------------------------------------------------

-- Follows the anchor and works out where the feet, hips and hands go this
-- frame, for either body.
local function gait(creature, dt, now)
	local dims = creature.dims
	local anchorCFrame = creature.anchor.CFrame
	local follow = 1 - math.exp(-dt * (if creature.lunging then 14 else 8))
	local position = creature.pos:Lerp(anchorCFrame.Position, follow)
	local speed = Vector3.new(position.X - creature.pos.X, 0, position.Z - creature.pos.Z).Magnitude / math.max(dt, 1e-3)
	creature.speed += (speed - creature.speed) * math.min(1, dt * 5)
	creature.pos = position
	local look = creature.look:Lerp(anchorCFrame.LookVector, math.min(1, dt * 5))
	look = Vector3.new(look.X, 0, look.Z)
	creature.look = if look.Magnitude > 1e-3 then look.Unit else creature.look

	local g = { position = position, forward = creature.look, up = Vector3.yAxis }
	g.right = g.forward:Cross(Vector3.yAxis).Unit
	g.running = creature.running and not creature.lunging
	creature.moving += ((if creature.speed > 0.6 then 1 else 0) - creature.moving) * math.min(1, dt * 4)
	g.moving = creature.moving
	local stride = if g.running then STRIDE_RUN else STRIDE_WALK
	creature.phase += dt * math.clamp(creature.speed, 0, 30) / stride * math.pi
	creature.crouch += ((if creature.lunging then 1 else 0) - creature.crouch) * math.min(1, dt * (if creature.lunging then 10 else 3))
	g.crouch = creature.crouch

	-- Feet: each swings forward lifted, then plants and slides back.
	g.feet, g.lift = {}, {}
	for i, sign in { -1, 1 } do
		local phase = creature.phase + (i - 1) * math.pi
		local swing = math.sin(phase) * stride / 2 * g.moving
		local lift = math.max(0, math.cos(phase)) * (if g.running then LIFT_RUN else LIFT_WALK) * g.moving
		g.feet[i] = position + g.right * sign * dims.footSpread + g.forward * swing + g.up * (dims.ankleHeight + lift)
		g.lift[i] = lift
		-- A ripple each time a foot comes down.
		if creature.lastLift[i] > 0.15 and lift <= 0.15 then
			ripple(Vector3.new(g.feet[i].X, SURFACE_Y + 0.05, g.feet[i].Z), if g.running then 2.2 else 1.4, if g.running then 0.45 else 0.7)
		end
		creature.lastLift[i] = lift
	end

	-- Hips bob with each step and drop as it reaches down. Its back hunches
	-- more when it runs or grabs; when it stands, it sways slowly.
	local bob = math.cos(creature.phase * 2) * 0.35 * g.moving
	g.pelvis = position + g.up * (dims.hipHeight + bob - g.crouch * 3.5) + g.forward * (if g.running then 0.8 else 0)
	g.hunch = math.rad(22 + (if g.running then 18 else 0) + g.crouch * 30) + math.sin(now * 0.7 + creature.phase * 0.1) * 0.03
	g.armSwing = {}
	for i = 1, 2 do
		g.armSwing[i] = -math.sin(creature.phase + (i - 1) * math.pi) * 1.6 * g.moving
	end
	-- How far its hands reach forward: a little when running, all the way to grab.
	g.reach = math.max(if g.running then 0.6 else 0, g.crouch)

	-- The mouth opens while it grabs (see LurkerVisuals.roar).
	local wide = creature.lunging and now >= (creature.roarAt or 0) or now < (creature.roarUntil or 0)
	creature.mawOpen += ((if wide then 1 else 0) - creature.mawOpen) * math.min(1, dt * (if wide then 5 else 3))
	return g
end

-- Where a hand goes, from its shoulder.
local function handTarget(g, shoulder, sign, i, armLength)
	local hang = shoulder - g.up * armLength * 0.92 + g.forward * (1 + g.armSwing[i]) + g.right * sign * 0.6
	local reach = shoulder + g.forward * armLength * 0.7 - g.up * armLength * 0.5 + g.right * sign * 0.4
	return hang:Lerp(reach, g.reach)
end

local function poseParts(creature, g)
	local dims, limbs, cframes = creature.dims, creature.limbs, {}
	local forward, right, up = g.forward, g.right, g.up
	local spine = (up * math.cos(g.hunch) + forward * math.sin(g.hunch)).Unit
	local waistTop = g.pelvis + spine * dims.torso * 0.45
	local chest = g.pelvis + spine * dims.torso
	local neckDirection = (spine * 0.4 + forward * (0.8 + g.crouch * 0.4) - up * g.crouch * 0.3).Unit
	local neckTop = chest + neckDirection * dims.neck
	local headCFrame = CFrame.lookAt(neckTop + neckDirection * 0.7, neckTop + neckDirection * 0.7 + forward - up * (0.15 + g.crouch * 0.6))

	for i, sign in { -1, 1 } do
		local side = if sign < 0 then "L" else "R"
		local foot = g.feet[i]
		-- Knees bend backwards.
		local hip = g.pelvis + right * sign * dims.footSpread * 0.55
		local knee = solve(hip, foot, dims.thigh, dims.shin, -forward + right * sign * 0.15)
		cframes[limbs["Thigh" .. side]] = between(hip, knee)
		cframes[limbs["Knee" .. side]] = CFrame.new(knee)
		cframes[limbs["Shin" .. side]] = between(knee, foot)
		cframes[limbs["Ankle" .. side]] = CFrame.new(foot)
		for toe = 1, 3 do
			local angle = (toe - 2) * 0.45
			local direction = (forward * math.cos(angle) + right * math.sin(angle) * sign - up * 0.2).Unit
			cframes[limbs["Toe" .. side .. toe]] = between(foot, foot + direction * 2)
		end
		cframes[limbs["Spur" .. side]] = between(foot, foot - forward + up * 0.1)

		local shoulder = chest - spine * 0.4 + right * sign * dims.shoulderWidth
		local hand = handTarget(g, shoulder, sign, i, dims.upperArm + dims.forearm)
		local elbow = solve(shoulder, hand, dims.upperArm, dims.forearm, -forward + right * sign * 0.6)
		cframes[limbs["UpperArm" .. side]] = between(shoulder, elbow)
		cframes[limbs["Elbow" .. side]] = CFrame.new(elbow)
		cframes[limbs["Forearm" .. side]] = between(elbow, hand)
		local handDirection = (hand - elbow).Unit
		cframes[limbs["Hand" .. side]] = CFrame.lookAt(hand + handDirection * 0.35, hand + handDirection)
		for finger = 1, 3 do
			local direction = (handDirection + right * (finger - 2) * 0.25 + forward * 0.2).Unit
			local start = hand + handDirection * 0.7
			cframes[limbs["Finger" .. side .. finger]] = between(start, start + direction * 1.6)
		end
	end

	cframes[limbs.Pelvis] = CFrame.lookAt(g.pelvis, g.pelvis + forward)
	cframes[limbs.Waist] = between(g.pelvis, waistTop)
	cframes[limbs.Ribs] = CFrame.lookAt((waistTop + chest) / 2, chest, forward)
	cframes[limbs.Neck] = between(chest, neckTop)
	cframes[limbs.Head] = headCFrame
	for i, sign in { -1, 1 } do
		cframes[creature.eyes[i]] = headCFrame * CFrame.new(sign * 0.36, 0.15, -0.72)
	end
	creature.mouth = headCFrame * CFrame.new(0, -0.45, -0.78)
	poseMaw(creature, cframes)

	local list = creature.cframes
	for i, part in creature.parts do
		list[i] = cframes[part]
	end
	workspace:BulkMoveTo(creature.parts, list, Enum.BulkMoveMode.FireCFrameChanged)
end

local function poseSkinned(creature, g)
	local dims, bones = creature.dims, creature.bones
	local forward, right, up = g.forward, g.right, g.up
	local meshCFrame = CFrame.lookAt(g.position, g.position + forward) * creature.meshOffset

	local hips = place(bones.Hips, meshCFrame, g.pelvis)

	-- The back curls forward more towards the top, then the neck reaches out.
	local world = hips
	for i, name in { "Spine02", "Spine01", "Spine" } do
		local angle = g.hunch * (0.5 + i * 0.3)
		world = aim(bones[name], world, up * math.cos(angle) + forward * math.sin(angle))
	end
	local chest = world
	local neck = aim(bones.neck, chest, up * 0.35 + forward * (0.9 + g.crouch * 0.3) - up * g.crouch * 0.4)
	local head = aim(bones.Head, neck, up * 0.85 + forward * (0.35 - g.crouch * 0.2))

	for i, sign in { -1, 1 } do
		local side = if sign < 0 then "Left" else "Right"
		-- Knees bend backwards.
		local upLeg = bones[side .. "UpLeg"]
		local hip = (hips * upLeg.CFrame).Position
		local foot = g.feet[i]
		local knee = solve(hip, foot, dims.thigh, dims.shin, -forward + right * sign * 0.15)
		local thigh = aim(upLeg, hips, knee - hip)
		local shin = aim(bones[side .. "Leg"], thigh, foot - knee)
		aim(bones[side .. "Foot"], shin, forward * 0.6 - up * (0.8 + g.lift[i] * 0.2))

		local collar = bones[side .. "Shoulder"]
		collar.Transform = CFrame.identity
		local shoulderWorld = chest * collar.CFrame
		local upperArm = bones[side .. "Arm"]
		local shoulder = (shoulderWorld * upperArm.CFrame).Position
		local hand = handTarget(g, shoulder, sign, i, dims.upperArm + dims.forearm)
		local elbow = solve(shoulder, hand, dims.upperArm, dims.forearm, -forward + right * sign * 0.6)
		local arm = aim(upperArm, shoulderWorld, elbow - shoulder)
		local forearm = aim(bones[side .. "ForeArm"], arm, hand - elbow)
		aim(bones[side .. "Hand"], forearm, (hand - elbow).Unit + forward * 0.3 - up * 0.2)
	end

	local cframes = { [creature.mesh] = meshCFrame }
	for i, offset in creature.eyeOffsets do
		cframes[creature.eyes[i]] = head * offset
	end
	creature.mouth = head * creature.mouthOffset
	if creature.glowPart then
		cframes[creature.glowPart] = creature.mouth * CFrame.new(0, 0, 0.3)
		-- Only on the way in: up close, while it has you (or in your death
		-- scene), it would just be a red ball.
		local shown = creature.alert and not creature.lunging and os.clock() >= (creature.roarUntil or 0)
		creature.glowPart.Transparency = if shown then 0 else 1
	end
	if creature.maw then
		poseMaw(creature, cframes)
	end
	local list = creature.cframes
	for i, part in creature.parts do
		list[i] = cframes[part]
	end
	workspace:BulkMoveTo(creature.parts, list, Enum.BulkMoveMode.FireCFrameChanged)
end

local function update(creature, dt, now)
	local g = gait(creature, dt, now)
	if creature.bones then
		poseSkinned(creature, g)
	else
		poseParts(creature, g)
	end
end

local function track(anchor)
	if creatures[anchor] or not anchor:IsA("BasePart") then
		return
	end
	local creature = build(anchor)
	creatures[anchor] = creature
	-- Its sounds play from the anchor, which goes where it goes. The footsteps
	-- carry a long way, so you hear it coming from out in the fog; the growl
	-- is faint far off and swells as it closes in.
	creature.steps = Sounds.loop("CreatureSteps", STEPS.volume, "Effects", anchor)
	creature.growl = Sounds.loop("CreatureGrowl", GROWL.volume, "Effects", anchor)
	for sound, falloff in { [creature.steps or false] = STEPS, [creature.growl or false] = GROWL } do
		if sound then
			sound.RollOffMode = falloff.mode
			sound.RollOffMinDistance = falloff.near
			sound.RollOffMaxDistance = falloff.far
		end
	end
	setAlert(creature)
	for _, name in { "Alert", "Running", "Lunging" } do
		anchor:GetAttributeChangedSignal(name):Connect(function()
			setAlert(creature)
		end)
	end
	-- Moved somewhere new in one go: put the body straight there.
	anchor:GetAttributeChangedSignal("Warp"):Connect(function()
		creature.pos = anchor.Position
		local look = anchor.CFrame.LookVector
		look = Vector3.new(look.X, 0, look.Z)
		creature.look = if look.Magnitude > 1e-3 then look.Unit else creature.look
		creature.speed = 0
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

-- The creature's mouth this frame (a CFrame on its face, -Z pointing out)
-- and how to frame it ({ distance, height, aim }), for the death scene's
-- camera. nil if there is no such creature.
function LurkerVisuals.face(anchor)
	local creature = creatures[anchor]
	if not creature then
		return nil, CLOSE_UP
	end
	return creature.mouth, creature.closeUp
end

-- Keeps its mouth shut for after seconds, then holds it wide open for
-- seconds more: the victim's camera gets there first, then it opens.
function LurkerVisuals.roar(anchor, after, seconds)
	local creature = creatures[anchor]
	if creature then
		local now = os.clock()
		creature.roarAt = now + after
		-- Held a little past the cut to static, so it stays that way to the end.
		creature.roarUntil = now + after + seconds + 1
	end
end

function LurkerVisuals.start()
	bodies = Instance.new("Folder")
	bodies.Name = "LurkerBodies"
	bodies.Parent = workspace

	task.spawn(function()
		local folder = ReplicatedStorage:WaitForChild("Creatures", 5)
		template = folder and folder:FindFirstChildWhichIsA("Model")
		if not template then
			warn("[LurkerVisuals] No creature model in ReplicatedStorage.Creatures; using the body built from parts")
		end
		local anchors = workspace:WaitForChild("Lurkers")
		anchors.ChildAdded:Connect(track)
		anchors.ChildRemoved:Connect(untrack)
		for _, anchor in anchors:GetChildren() do
			track(anchor)
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		local eye = workspace.CurrentCamera.CFrame.Position
		local now = os.clock()
		for anchor, creature in creatures do
			if (anchor.Position - eye).Magnitude <= ANIMATE_RANGE then
				update(creature, dt, now)
			end
		end
	end)
end

return LurkerVisuals
