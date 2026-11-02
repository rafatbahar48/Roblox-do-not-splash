-- Draws and animates the creatures on this client. The server moves one
-- invisible anchor per creature at its feet (server/Lurker.luau); here each
-- anchor gets a body: very long legs whose knees bend backwards, a hunched
-- back, arms that hang to its knees, and red eyes that burn brighter while
-- it hunts. Its face is smooth until it grabs someone; then a huge mouth
-- full of fangs splits open (client/DeathScene.luau films it up close).
--
-- The body is the Meshy model in ReplicatedStorage.Creatures (the first model
-- there; now the Mire Stalker, art/models/mire), posed bone by bone. Without
-- one, a body built from parts stands in. Either way the pose is worked out
-- every frame from where its feet step (two-bone IK for legs and arms), with
-- no animation files, so its feet never slide whatever speed the server
-- moves it at. How it moves depends on what it is doing (gait's modes):
-- dead still and twitching while it watches, a broken, dragging walk or a
-- low glide through the water, a frozen stare and a head snap when it hears
-- you, an explosive sprint, a spider crawl while it circles you, a dead stop
-- when it loses you, and a one-armed lunge. Its head, back, arms and legs
-- each keep their own time. Ripples spread where its feet go in, and water
-- drips from its hands.
--
-- Attributes on the model:
--   OwnMouth  true if it has a mouth of its own (its headfront bone marks it);
--             otherwise one opens up out of its face when it grabs. A Jaw
--             bone, if it has one, opens it.
--   Eyes      false to leave off the glowing eyes; its throat glows instead
--   EyeOffset where the eyes are (a Vector3, studs: to each side, up and
--             forward of the head joint); EyeSize how big; EyeColor and
--             EyeAlertColor their glow while it watches and while it hunts
--   CloseUpDistance, CloseUpHeight, CloseUpAim
--             where the death scene's camera goes in front of its mouth, how
--             far above the mouth, and how far above the mouth it looks
--             (studs; bigger mouths want the camera further back)
--
-- Creatures too far away to see through the fog are left where they are. On a
-- practice run (the Practice attribute) there is no creature at all: no body
-- and no sound.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(script.Parent.Sounds)

local ANIMATE_RANGE = 300 -- past the fog
local SURFACE_Y = Config.Room.SurfaceY

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
-- Its other sounds (see voice), fading evenly from near to far, and how
-- deep (the pitch; lower sounds bigger). The panting loops while it runs.
local VOICES = {
	CreaturePanting = { volume = 3, near = 6, far = 120, pitch = 0.8, looped = true },
	CreatureBreathing = { volume = 2.5, near = 12, far = 110, pitch = 0.75 },
	CreatureCreak = { volume = 2, near = 10, far = 100, pitch = 0.8 },
	CreatureDrip = { volume = 1.2, near = 6, far = 60, pitch = 1 },
	CreatureStep = { volume = 2.5, near = 10, far = 120, pitch = 0.6 },
	CreatureBranch = { volume = 2.5, near = 10, far = 140, pitch = 0.85 },
	CreatureBubbles = { volume = 1.5, near = 8, far = 70, pitch = 0.75 },
	CreatureSniff = { volume = 3, near = 12, far = 120, pitch = 0.6 },
	CreatureNeck = { volume = 3, near = 10, far = 110, pitch = 0.85 },
	CreatureSnap = { volume = 3, near = 10, far = 160, pitch = 0.9 },
	CreatureSnarl = { volume = 2.5, near = 8, far = 120, pitch = 0.7 },
	CreatureImpact = { volume = 3, near = 8, far = 100, pitch = 0.8 },
}

local player = Players.LocalPlayer

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

-- Like aim, then turned round its own length by twist (radians).
local function aimTwist(bone, parentWorld, direction, twist)
	local rest = parentWorld * bone.CFrame
	local world = CFrame.new(rest.Position) * arc(rest.UpVector, direction.Unit) * rest.Rotation * CFrame.Angles(0, twist, 0)
	bone.Transform = rest:Inverse() * world
	return world
end

-- A rotation whose +Y is along a and whose +Z is as near b as it can be.
local function basis(a, b)
	local y = a.Unit
	local z = b - y * b:Dot(y)
	z = if z.Magnitude > 1e-4 then z.Unit else y:Cross(Vector3.xAxis).Unit
	return CFrame.fromMatrix(Vector3.zero, y:Cross(z), y, z)
end

-- Points the head along up and turns it so its face (faceLocal, in its own
-- space) looks along face. Returns its new world CFrame.
local function orient(bone, parentWorld, up, face, faceLocal)
	local rest = parentWorld * bone.CFrame
	local world = CFrame.new(rest.Position) * basis(up, face) * basis(Vector3.yAxis, faceLocal):Inverse()
	bone.Transform = rest:Inverse() * world
	return world
end

-- Turns vector v round axis by angle (radians).
local function turned(v, axis, angle)
	return CFrame.fromAxisAngle(axis, angle):VectorToWorldSpace(v)
end

-- The same "random" number, 0 to 1, on every screen for the same slot (a
-- whole number, usually a stretch of server time) and salt: twitches and
-- pauses agree between players with nothing sent over the network.
local function synced(slot, salt)
	local x = math.sin(slot * 12.9898 + salt * 78.233) * 43758.5453
	return x - math.floor(x)
end

-- A twitch's strength tau seconds after it starts: a quick snap, then a
-- slower settle.
local function twitch(tau)
	if tau < 0 then
		return 0
	end
	return if tau < 0.07 then tau / 0.07 else math.exp(-(tau - 0.07) * 9)
end

local function ease(edge0, edge1, value)
	local t = math.clamp((value - edge0) / (edge1 - edge0), 0, 1)
	return t * t * (3 - 2 * t)
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
		crouchDrop = rest("Hips").Y * 0.12, -- how far its hips sink as it grabs (it bends its back instead)
		thigh = (rest("LeftLeg") - rest("LeftUpLeg")).Magnitude,
		shin = (rest("LeftFoot") - rest("LeftLeg")).Magnitude,
		footSpread = math.abs(rest("LeftFoot").X) * 0.75,
		ankleHeight = rest("LeftFoot").Y,
		upperArm = (rest("LeftForeArm") - rest("LeftArm")).Magnitude,
		forearm = (rest("LeftHand") - rest("LeftForeArm")).Magnitude,
	}
	local head = bones.Head.WorldCFrame
	-- Which way its face looks, in the head bone's own space.
	creature.faceLocal = if bones.headfront then bones.headfront.CFrame.Position else Vector3.new(0, 0, -1)
	creature.eyeOffsets = {}
	if template:GetAttribute("Eyes") ~= false then
		-- The eyes in the texture are small; neon ones on top glow through fog.
		local offset = template:GetAttribute("EyeOffset")
		for _, sign in { -1, 1 } do
			local eye = if typeof(offset) == "Vector3"
				then CFrame.new(bones.Head.WorldPosition + pivot.Rotation * Vector3.new(sign * offset.X, offset.Y, -offset.Z))
				else pivot * CFrame.new(sign * 0.3, rest("Head").Y + 1.35, rest("Head").Z - 0.62)
			table.insert(creature.eyeOffsets, head:ToObjectSpace(eye))
		end
		addEyes(creature, template:GetAttribute("EyeSize") or 0.26)
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
	-- Swamp water dripping off its claws whenever its hands are out of it.
	creature.drips = {}
	for _, name in { "LeftHand", "RightHand" } do
		local drip = Instance.new("ParticleEmitter")
		drip.Name = "Drip"
		drip.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		drip.Color = ColorSequence.new(Color3.fromRGB(150, 170, 165))
		drip.LightEmission = 0.2
		drip.Size = NumberSequence.new(0.12, 0.05)
		drip.Transparency = NumberSequence.new(0.3, 0.9)
		drip.Lifetime = NumberRange.new(0.5, 0.8)
		drip.Rate = 7
		drip.Speed = NumberRange.new(0.2, 0.8)
		drip.SpreadAngle = Vector2.new(20, 20)
		drip.Acceleration = Vector3.new(0, -60, 0)
		drip.Enabled = false
		drip.Parent = bones[name] -- a Bone is an Attachment, so it drips from the hand
		table.insert(creature.drips, drip)
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
		-- How it moves (gait): its mode and when that began, and what is
		-- eased from frame to frame.
		mode = "idle",
		modeSince = os.clock(),
		stopUntil = 0,
		retreatUntil = 0,
		ease = { hips = 0.94, hunch = 30, twist = 0, jaw = 0, raiseL = 7, raiseR = -5, roll = 12 },
		headFace = nil, -- where its face looks (world), eased toward its target
		hands = {}, -- last frame's hand places, held while it freezes
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
	creature.reacting = anchor:GetAttribute("Reacting") == true
	creature.running = anchor:GetAttribute("Running") == true
	creature.circling = anchor:GetAttribute("Circling") == true
	creature.lunging = anchor:GetAttribute("Lunging") == true
	local focus = anchor:GetAttribute("Focus")
	if typeof(focus) == "Vector3" then
		creature.focus = focus
	end
	local burning = creature.alert or creature.lunging
	local idleColor = template and template:GetAttribute("EyeColor") or EYE_IDLE
	local alertColor = template and template:GetAttribute("EyeAlertColor") or EYE_ALERT
	for _, eye in creature.eyes do
		eye.Color = if burning then alertColor else idleColor
	end
	creature.glow.Color = alertColor
	creature.glow.Brightness = if creature.lunging then 1.6 elseif burning then 1.1 else 0.4
	-- Its feet in the water and its panting while it runs, and a growl while
	-- it hunts, but dead silence the moment it hears you (see voice for the
	-- rest).
	local function playIf(sound, on)
		if sound and on ~= sound.IsPlaying then
			if on then
				sound:Play()
			else
				sound:Stop()
			end
		end
	end
	local heard = player:GetAttribute("Practice") ~= true
	local running = heard and creature.running and not creature.lunging
	playIf(creature.steps, running)
	playIf(creature.voices and creature.voices.CreaturePanting, running)
	playIf(creature.growl, heard and creature.alert and not creature.lunging and not creature.reacting)
end

-- Plays one of its sounds once (not while you're practising), a little
-- higher or lower each time by vary (0 to 1).
local function say(creature, name, vary)
	local sound = creature.voices and creature.voices[name]
	if sound and player:GetAttribute("Practice") ~= true then
		sound.PlaybackSpeed = VOICES[name].pitch * (0.9 + 0.2 * vary)
		sound.TimePosition = 0
		sound:Play()
	end
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

-- How it carries itself in each mode (see gait): how high its hips are (a
-- share of standing), how far forward its back bends (degrees), how much its
-- body turns after what it's after (a share), how its head tips sideways
-- (degrees), how far its jaw hangs open (degrees), how long a stride is and
-- how high its feet lift, and how fast its body keeps up with where it is
-- really going (the anchor; lower lags further behind).
local MODES = {
	idle = { hips = 0.94, hunch = 30, twist = 0, roll = 12, jaw = 1, stride = 4.5, lift = 1.4, follow = 6 },
	walk = { hips = 0.9, hunch = 40, twist = 0.4, roll = 8, jaw = 3, stride = 4.2, lift = 1.5, follow = 3.5 },
	glide = { hips = 0.66, hunch = 52, twist = 0.25, roll = 4, jaw = 0, stride = 5.5, lift = 0.45, follow = 6 },
	retreat = { hips = 0.82, hunch = 46, twist = 0, roll = 10, jaw = -3, stride = 4.2, lift = 1.2, follow = 4 },
	react = { hips = 0.92, hunch = 34, twist = 1, roll = 0, jaw = 18, stride = 4.5, lift = 0, follow = 6 },
	chase = { hips = 0.84, hunch = 68, twist = 0.3, roll = 0, jaw = 16, stride = 8.5, lift = 3.2, follow = 10 },
	crawl = { hips = 0.48, hunch = 82, twist = 0.2, roll = -10, jaw = 12, stride = 5, lift = 1.1, follow = 9 },
	stop = { hips = 0.9, hunch = 34, twist = 0.6, roll = 6, jaw = -4, stride = 4.5, lift = 0, follow = 12 },
	grab = { hips = 0.86, hunch = 58, twist = 0.6, roll = 26, jaw = 36, stride = 4.5, lift = 0, follow = 14 },
}
local STOP_TIME = 2.6 -- seconds it stands stock still after it gives up, listening
local RETREAT_TIME = 14 -- seconds after that it creeps back low, glancing behind it

-- What it is doing, from the anchor's flags (server/Lurker.luau) and how it
-- moves:
--   idle     standing, watching: almost lifeless, long stillnesses, a twitch
--            now and then, the head slowly turning to look at you
--   walk     the broken walk: one leg steps, the other drags late, the torso
--            leaning and lagging behind its feet, stopping mid-step
--   glide    the water stalk: crouched low, arms out ahead skimming the
--            water, gliding smoothly (it takes turns with walk)
--   react    it has heard you: freezes, the head snaps round, holds, the
--            shoulders rise, the body slowly twists to you, the jaw opens
--   chase    explosive: back nearly flat, head thrust out, arms flailing,
--            long uneven strides
--   crawl    circling you: down on all fours, elbows out, back arched
--   stop     it lost you: stops dead, arms still swinging, head still on
--            the spot, the jaw slowly closing, the shoulders sinking
--   retreat  creeping back to watch: low, arms dragging, glancing behind
--   grab     one arm lunges for you, claws curling, head tipped, jaw wide
local function decideMode(creature, now, serverNow)
	local was = creature.mode
	local mode
	if creature.lunging then
		mode = "grab"
	elseif creature.reacting then
		mode = "react"
	elseif creature.circling then
		mode = "crawl"
	elseif creature.running then
		mode = "chase"
	else
		if was == "react" or was == "chase" or was == "crawl" or was == "grab" then
			creature.stopUntil = now + STOP_TIME
			creature.retreatUntil = now + STOP_TIME + RETREAT_TIME
		end
		if now < creature.stopUntil then
			mode = "stop"
		elseif creature.moving > 0.3 then
			-- Broken walk or water stalk, taking turns every so often.
			local style = if synced(math.floor(serverNow / 12), 3) < 0.5 then "walk" else "glide"
			mode = if now < creature.retreatUntil and not creature.alert then "retreat" else style
		else
			mode = "idle"
		end
	end
	if mode ~= was then
		creature.mode, creature.modeSince = mode, now
		if mode == "react" then
			-- It was looking elsewhere when it heard you: its body starts
			-- turned away and comes round after its head.
			local side = if synced(math.floor(serverNow), 5) < 0.5 then -1 else 1
			creature.look = turned(creature.look, Vector3.yAxis, side * math.rad(70))
		end
	end
	return mode
end

-- Follows the anchor and works out where the feet, hips and hands go this
-- frame, for either body.
local function gait(creature, dt, now)
	local dims = creature.dims
	local serverNow = workspace:GetServerTimeNow()
	local mode = decideMode(creature, now, serverNow)
	local style = MODES[mode]
	local since = now - creature.modeSince
	local anchorCFrame = creature.anchor.CFrame

	-- Its body follows the anchor, lagging in the broken walk; now and then
	-- it stops mid-step while the anchor goes on, then lurches after it.
	local followRate = style.follow
	local paused = false
	if mode == "walk" or mode == "retreat" then
		local slot = math.floor(serverNow / 1.3)
		paused = synced(slot, 11) < 0.22 and serverNow / 1.3 - slot < 0.45
		if paused then
			followRate = 0.3
		end
	end
	local follow = 1 - math.exp(-dt * followRate)
	local position = creature.pos:Lerp(anchorCFrame.Position, follow)
	local speed = Vector3.new(position.X - creature.pos.X, 0, position.Z - creature.pos.Z).Magnitude / math.max(dt, 1e-3)
	creature.speed += (speed - creature.speed) * math.min(1, dt * 5)
	creature.pos = position
	-- Its hips turn to where it is going: barely while it stands (its head
	-- does the looking), late while it reacts, fast while it runs.
	local turnRate = if mode == "idle" then 0.3 elseif mode == "react" then (if since > 0.9 then 3 else 0) else 5
	local look = creature.look:Lerp(anchorCFrame.LookVector, math.min(1, dt * turnRate))
	look = Vector3.new(look.X, 0, look.Z)
	creature.look = if look.Magnitude > 1e-3 then look.Unit else creature.look

	local g = { position = position, forward = creature.look, up = Vector3.yAxis, mode = mode, since = since, serverNow = serverNow }
	g.right = g.forward:Cross(Vector3.yAxis).Unit
	g.running = mode == "chase" or mode == "crawl"
	creature.moving += ((if creature.speed > 0.6 then 1 else 0) - creature.moving) * math.min(1, dt * 4)
	g.moving = creature.moving
	local stride = style.stride
	if mode == "chase" then
		stride *= 1 + 0.25 * math.sin(creature.phase * 0.31) -- strides of uneven length
	end
	if not paused then
		creature.phase += dt * math.clamp(creature.speed, 0, 34) / stride * math.pi
	end
	creature.crouch += ((if creature.lunging then 1 else 0) - creature.crouch) * math.min(1, dt * (if creature.lunging then 10 else 3))
	g.crouch = creature.crouch

	-- Eased toward this mode's carriage: snapping in a reaction or a chase,
	-- settling slowly when it stops.
	local e = creature.ease
	local rate = if mode == "stop" then 0.9 elseif mode == "chase" or mode == "crawl" or mode == "grab" then 8 else 3
	for key, value in { hips = style.hips, hunch = style.hunch, roll = style.roll } do
		e[key] += (value - e[key]) * math.min(1, dt * rate)
	end

	-- Feet: each swings forward lifted, then plants and slides back. In the
	-- broken walk the second leg comes late and drags, barely lifted; on all
	-- fours they splay wide.
	g.feet, g.lift = {}, {}
	local spread = dims.footSpread * (if mode == "crawl" then 1.5 elseif mode == "glide" then 1.2 else 1)
	for i, sign in { -1, 1 } do
		local dragging = i == 2 and (mode == "walk" or mode == "retreat")
		local phase = creature.phase + (i - 1) * math.pi + (if dragging then 0.9 else 0)
		local swing = math.sin(phase) * stride / 2 * g.moving * (if dragging then 0.75 else 1)
		local lift = math.max(0, math.cos(phase)) * style.lift * g.moving * (if dragging then 0.25 else 1)
		g.feet[i] = position + g.right * sign * spread + g.forward * swing + g.up * (dims.ankleHeight + lift)
		g.lift[i] = lift
		-- A ripple each time a foot comes down, and a squelch as it stalks.
		if creature.lastLift[i] > 0.15 and lift <= 0.15 then
			ripple(Vector3.new(g.feet[i].X, SURFACE_Y + 0.05, g.feet[i].Z), if mode == "chase" then 2.2 else 1.4, if mode == "chase" then 0.45 else 0.7)
			if mode == "walk" or mode == "retreat" then
				say(creature, "CreatureStep", synced(math.floor(creature.phase), 37))
			end
		end
		creature.lastLift[i] = lift
	end

	-- Hips: dipping onto the dragged leg in the broken walk, still in the
	-- glide, bobbing hard in the chase, low and forward on all fours.
	local bob = if mode == "glide" then 0 elseif mode == "walk" or mode == "retreat" then math.min(0, math.cos(creature.phase)) * 0.5 else math.cos(creature.phase * 2) * 0.35
	local lean = if mode == "chase" then 1.4 elseif mode == "crawl" then 1 else 0
	g.pelvis = position + g.up * (dims.hipHeight * e.hips + bob * g.moving - g.crouch * (dims.crouchDrop or 3.5)) + g.forward * lean
	-- Breathing, uneven, and in long spells of none at all while it stands.
	local holding = mode == "idle" and synced(math.floor(serverNow / 6), 7) < 0.5
	local breath = if holding then 0 else math.sin(serverNow * 1.3 + 0.8 * math.sin(serverNow * 0.29)) ^ 3
	g.breath, g.holding = breath, holding
	g.hunch = math.rad(e.hunch + breath * 1.5 + g.crouch * 20)

	-- Twitches: a hand flicks, the head jerks, a shoulder hitches; in the
	-- broken walk, the whole upper body jerks as if yanked on a string.
	g.twitch = { handL = 0, handR = 0, head = 0, shoulderL = 0, shoulderR = 0, body = 0 }
	local chances = { idle = 0.1, walk = 0.08, glide = 0.04, retreat = 0.06, stop = 0.12 }
	local chance = chances[mode]
	if chance then
		local slot = math.floor(serverNow / 0.4)
		for back = 0, 2 do
			if synced(slot - back, 13) < chance then
				local kinds = { "handL", "handR", "head", "shoulderL", "shoulderR" }
				local kind = kinds[1 + math.floor(synced(slot - back, 17) * #kinds)]
				g.twitch[kind] = math.max(g.twitch[kind], twitch(serverNow - (slot - back) * 0.4))
			end
		end
		if mode == "walk" or mode == "retreat" then
			local jerk = math.floor(serverNow / 1.1)
			if synced(jerk, 19) < 0.15 then
				g.twitch.body = twitch(serverNow - jerk * 1.1)
			end
		end
	end

	g.armSwing = {}
	for i = 1, 2 do
		g.armSwing[i] = -math.sin(creature.phase + (i - 1) * math.pi) * 1.6 * g.moving
	end
	-- How far its hands reach forward: a little when running, all the way to grab.
	g.reach = math.max(if g.running then 0.6 else 0, g.crouch)

	-- The jaw: this mode's set (slack while it watches, opening as it reacts,
	-- working while it runs, slowly closing when it stops), wide when it
	-- grabs or roars (see LurkerVisuals.roar).
	local wide = creature.lunging and now >= (creature.roarAt or 0) or now < (creature.roarUntil or 0)
	creature.mawOpen += ((if wide then 1 else 0) - creature.mawOpen) * math.min(1, dt * (if wide then 5 else 3))
	local jaw = style.jaw
	if mode == "react" then
		jaw *= ease(0.7, 1.5, since)
	elseif mode == "chase" then
		jaw += 6 * math.sin(serverNow * 7)
	end
	e.jaw += (jaw - e.jaw) * math.min(1, dt * (if mode == "stop" then 0.8 else 4))
	g.jaw = math.max(e.jaw, creature.mawOpen * 38)
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

-- The signed turn (radians) round the vertical from forward to direction.
local function yawTo(forward, direction)
	local flatDirection = Vector3.new(direction.X, 0, direction.Z)
	if flatDirection.Magnitude < 1e-3 then
		return 0
	end
	flatDirection = flatDirection.Unit
	return math.atan2(forward:Cross(flatDirection).Y, forward:Dot(flatDirection))
end

-- The nearest player's head, seen from position (within the fog), or nil.
local function nearestHead(position)
	local best, bestDistance
	for _, other in Players:GetPlayers() do
		local root = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local distance = (root.Position - position).Magnitude
			if distance < 150 and (not best or distance < bestDistance) then
				best, bestDistance = root.Position + Vector3.new(0, 1.5, 0), distance
			end
		end
	end
	return best
end

-- What its head is turned toward this frame (a world point), and how fast
-- it turns there.
local function headTarget(creature, g, chest)
	local mode, since, forward = g.mode, g.since, g.forward
	local ahead = chest.Position + forward * 30 - Vector3.yAxis * 8 -- the dead stare, down at the water
	local focus = creature.focus
	if mode == "react" then
		-- Snaps round in a blink, holds dead still, then keeps on you.
		return focus or ahead, if since < 0.12 then 35 elseif since < 0.45 then 0 else 6
	elseif mode == "chase" or mode == "crawl" or mode == "grab" then
		return focus or ahead, 12
	elseif mode == "stop" then
		return focus or ahead, 6 -- still on the spot where it lost you
	elseif mode == "retreat" then
		local slot = math.floor(g.serverNow / 3)
		local glancing = focus and synced(slot, 23) < 0.4 and g.serverNow - slot * 3 < 1.5
		return if glancing then focus else ahead, 2.5
	elseif mode == "idle" then
		-- Long stares at nothing; now and then the head slowly comes round
		-- to look at whoever is nearest, the body never moving.
		local slot = math.floor(g.serverNow / 5)
		local watching = synced(slot, 21) < 0.45 and nearestHead(chest.Position)
		return watching or ahead, 1.2
	end
	return if creature.alert and focus then focus else ahead, 4
end

local function poseSkinned(creature, g)
	local dims, bones, e = creature.dims, creature.bones, creature.ease
	local forward, right, up = g.forward, g.right, g.up
	local mode, since, dt = g.mode, g.since, creature.dt or 1 / 60
	local meshCFrame = CFrame.lookAt(g.position, g.position + forward) * creature.meshOffset

	local hips = place(bones.Hips, meshCFrame, g.pelvis)

	-- The body turns after what it's after (the reaction's slow twist), a
	-- third at each bone of the back.
	local target, headRate = headTarget(creature, g, hips)
	local style = MODES[mode]
	local twist = math.clamp(yawTo(forward, target - g.pelvis), -math.rad(75), math.rad(75)) * style.twist
	if mode == "react" then
		twist *= ease(0.5, 1.4, since)
	end
	e.twist += (twist - e.twist) * math.min(1, dt * (if mode == "react" then 4 else 2.5))
	local jerk = g.twitch.body
	local bodyTwist = e.twist + math.rad(10) * jerk

	-- The back curls forward more towards the top (and arches on all fours),
	-- then the neck reaches out: thrust ahead in a chase, hanging low on all
	-- fours, held up out of the water in the glide.
	local world = hips
	local fractions = if mode == "crawl" then { 0.62, 1, 1.08 } else { 0.45, 0.75, 1 }
	local hunch = g.hunch + math.rad(8) * jerk
	for k, name in { "Spine02", "Spine01", "Spine" } do
		local angle = hunch * fractions[k]
		local toward = turned(forward, up, bodyTwist * k / 3)
		world = aimTwist(bones[name], world, up * math.cos(angle) + toward * math.sin(angle), bodyTwist / 3)
	end
	local chest = world
	local chestForward = turned(forward, up, bodyTwist)
	local reach = ({ chase = Vector3.new(0.05, 1.3), crawl = Vector3.new(-0.25, 1), glide = Vector3.new(0.25, 0.9), react = Vector3.new(0.4, 0.85) })[mode]
		or Vector3.new(0.35, 0.9)
	local neck = aim(bones.neck, chest, up * reach.X + chestForward * (reach.Y + g.crouch * 0.3) - up * g.crouch * 0.4)

	-- The head: its own speed, never turned more than 100 degrees from the
	-- body, tipped to one side.
	local wanted = target - neck.Position
	local yaw = math.clamp(yawTo(chestForward, wanted), -math.rad(100), math.rad(100))
	local flatWanted = turned(chestForward, up, yaw)
	local pitch = math.atan2(wanted.Y, Vector3.new(wanted.X, 0, wanted.Z).Magnitude)
	local face = (flatWanted * math.cos(pitch) + up * math.sin(pitch)).Unit
	local current = creature.headFace or face
	current = current:Lerp(face, math.min(1, dt * headRate))
	creature.headFace = if current.Magnitude > 1e-3 then current.Unit else face
	face = turned(creature.headFace, up, math.rad(7) * g.twitch.head)
	local tilt = ({ chase = Vector3.new(0.55, 0.45), crawl = Vector3.new(0.45, 0.55), glide = Vector3.new(0.8, 0.3) })[mode] or Vector3.new(0.85, 0.35)
	local headUp = turned(up * tilt.X + chestForward * tilt.Y, face, math.rad(e.roll + 8 * g.twitch.head))
	local head = orient(bones.Head, neck, headUp, face, creature.faceLocal)

	-- The jaw hinges round the head's own side-to-side axis.
	if bones.Jaw then
		local rest = head * bones.Jaw.CFrame
		local side = face:Cross(head.UpVector)
		if side.Magnitude > 1e-3 then
			local opened = CFrame.new(rest.Position) * CFrame.fromAxisAngle(side.Unit, -math.rad(g.jaw)) * rest.Rotation
			bones.Jaw.Transform = rest:Inverse() * opened
		end
	end

	-- Shoulders: uneven when it stands, rising and falling with each step in
	-- the broken walk, hunched up when it hears you, sinking when it gives up.
	local raises = {
		idle = { 7, -5 },
		walk = { 4 + 9 * math.sin(creature.phase), -3 - 9 * math.sin(creature.phase) },
		glide = { 0, 0 },
		retreat = { -6, -8 },
		react = { 20 * ease(0.35, 0.75, since), 20 * ease(0.35, 0.75, since) },
		chase = { 8, 8 },
		crawl = { 16, 16 },
		stop = { -6, -6 },
		grab = { 5, 15 },
	}
	local raise = raises[mode]
	local raiseRate = if mode == "stop" then 0.8 elseif mode == "react" then 8 else 4
	e.raiseL += (raise[1] - e.raiseL) * math.min(1, dt * raiseRate)
	e.raiseR += (raise[2] - e.raiseR) * math.min(1, dt * raiseRate)

	local armLength = dims.upperArm + dims.forearm
	local surface = SURFACE_Y
	for i, sign in { -1, 1 } do
		local side = if sign < 0 then "Left" else "Right"
		-- Knees bend backwards (and splay outwards on all fours).
		local upLeg = bones[side .. "UpLeg"]
		local hip = (hips * upLeg.CFrame).Position
		local foot = g.feet[i]
		local kneeHint = if mode == "crawl" then right * sign * 1.2 - forward * 0.5 else -forward + right * sign * 0.15
		local knee = solve(hip, foot, dims.thigh, dims.shin, kneeHint)
		local thigh = aim(upLeg, hips, knee - hip)
		local shin = aim(bones[side .. "Leg"], thigh, foot - knee)
		aim(bones[side .. "Foot"], shin, forward * 0.6 - up * (0.8 + g.lift[i] * 0.2))

		local collar = bones[side .. "Shoulder"]
		local upperArm = bones[side .. "Arm"]
		local collarRest = chest * collar.CFrame
		local outward = ((collarRest * upperArm.CFrame).Position - collarRest.Position).Unit
		local lift = math.rad((if i == 1 then e.raiseL else e.raiseR) + 12 * (if i == 1 then g.twitch.shoulderL else g.twitch.shoulderR))
		local shoulderWorld = aim(collar, chest, outward * math.cos(lift) + up * math.sin(lift))
		local shoulder = (shoulderWorld * upperArm.CFrame).Position

		-- Where the hand goes in this mode.
		local hang = shoulder - up * armLength * 0.97 + chestForward * 0.4 + right * sign * 0.5
		local hand
		if mode == "walk" or mode == "retreat" then
			-- Dragging low, the left further behind.
			hand = shoulder - up * armLength * 0.95 + chestForward * ((if i == 1 then -0.8 else 0.6) + g.armSwing[i] * 0.5) + right * sign * 0.7
		elseif mode == "glide" then
			-- Out ahead, sweeping just over the water.
			local sweep = math.sin(creature.phase * 0.5 + i * 2) * 0.8
			hand = g.position + chestForward * (armLength * 0.55 + sweep) + right * sign * 1.2
			hand = Vector3.new(hand.X, surface + 0.2, hand.Z)
		elseif mode == "react" then
			hand = creature.hands[i] or hang -- frozen where they were
		elseif mode == "chase" then
			hand = shoulder + chestForward * (g.armSwing[i] * 1.6 + 0.8) - up * armLength * 0.6 + right * sign
			-- Now and then a claw shoots out at you.
			local slot = math.floor(g.serverNow / 0.9)
			if creature.focus and synced(slot, 29) < 0.35 and (synced(slot, 31) < 0.5) == (i == 1) then
				local out = math.sin(math.clamp((g.serverNow - slot * 0.9) / 0.45, 0, 1) * math.pi)
				local toward = (creature.focus - shoulder)
				hand = hand:Lerp(shoulder + (if toward.Magnitude > 1e-3 then toward.Unit else chestForward) * armLength * 0.95, out)
			end
		elseif mode == "crawl" then
			-- Planted on the water with each step, the right reaching further.
			local phase = creature.phase + (if i == 1 then math.pi else 0)
			local stride = MODES.crawl.stride
			hand = g.position + chestForward * (2.2 + (if i == 2 then 0.9 else 0) + math.sin(phase) * stride * 0.45) + right * sign * dims.footSpread * 1.9
			hand = Vector3.new(hand.X, surface - 0.4 + math.max(0, math.cos(phase)) * 1.4, hand.Z)
		elseif mode == "stop" then
			-- Still swinging from the run after the body has stopped dead.
			local sway = 2.4 * math.exp(-1.5 * since) * math.cos(5 * since + i * 0.9)
			hand = hang + chestForward * sway
		elseif mode == "grab" and i == 2 then
			-- One arm lunges for you, then pulls you in toward its mouth.
			local victim = creature.focus or (shoulder + chestForward * armLength)
			local pull = ease(0.7, 1.3, since)
			hand = victim:Lerp(chest.Position + chestForward * 2 + up * 0.5, pull)
		else
			hand = handTarget(g, shoulder, sign, i, armLength):Lerp(hang, if mode == "idle" then 1 else 0)
		end
		creature.hands[i] = hand

		local elbowHints = {
			crawl = right * sign * 1.6 + up * 0.9,
			chase = -forward * 0.6 + right * sign * 0.7 + up * 0.2,
			glide = right * sign * 0.9 - forward * 0.3 + up * 0.3,
		}
		local elbow = solve(shoulder, hand, dims.upperArm, dims.forearm, elbowHints[mode] or (-forward + right * sign * 0.6))
		local arm = aim(upperArm, shoulderWorld, elbow - shoulder)
		local forearm = aim(bones[side .. "ForeArm"], arm, hand - elbow)
		-- The hand: claws curled in as it closes on you, flat on all fours, a
		-- flick of the wrist now and then.
		local along = (hand - elbow).Unit
		local wrist = along + forward * 0.3 - up * 0.2
		if mode == "grab" and i == 2 then
			wrist = along * 0.4 - up * 0.8 - forward * 0.3 * ease(0.4, 0.8, since)
		elseif mode == "crawl" then
			wrist = forward * 0.5 - up * 0.8
		end
		local flick = if i == 1 then g.twitch.handL else g.twitch.handR
		wrist = turned(wrist, right, math.rad(25) * flick)
		aim(bones[side .. "Hand"], forearm, wrist)

		-- Water dripping off a hand out of the water; ripples where one skims it.
		if creature.drips then
			creature.drips[i].Enabled = hand.Y > surface + 0.6 and mode ~= "idle"
		end
		if mode == "glide" and os.clock() - (creature.lastHandRipple or 0) > 0.5 and (math.floor(os.clock() * 2) % 2 == 0) == (i == 1) then
			creature.lastHandRipple = os.clock()
			ripple(Vector3.new(hand.X, surface + 0.05, hand.Z), 1, 0.75)
		end
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

-- Its sounds, used sparingly, at the same moments for everyone (from the
-- server's clock). Now and then, in each mode (which sound, how many seconds
-- between chances, and the chance):
--   idle     a slow wet breath (never while it holds its breath), its body
--            creaking like old wood, water dripping off it
--   walk     a branch snapping (and each foot squelching down, in gait)
--   glide    bubbles round it in the water
--   chase    wood snapping, a snarl (with the steps, panting and growl)
--   crawl    hissing snarls
local CALLS = {
	idle = { { "CreatureBreathing", 4, 0.45 }, { "CreatureCreak", 5, 0.2 }, { "CreatureDrip", 3, 0.2 } },
	walk = { { "CreatureBranch", 4, 0.25 }, { "CreatureCreak", 5, 0.15 } },
	retreat = { { "CreatureBreathing", 5, 0.3 }, { "CreatureBranch", 5, 0.2 } },
	glide = { { "CreatureBubbles", 2.5, 0.6 } },
	chase = { { "CreatureSnap", 2.5, 0.35 }, { "CreatureSnarl", 3.5, 0.3 } },
	crawl = { { "CreatureSnarl", 2.5, 0.45 }, { "CreatureSnap", 3, 0.2 } },
}
-- And once each, this many seconds into a mode: when it hears you, dead
-- silence, a sharp breath in as its shoulders rise, then a crack as its body
-- twists round to you; when it grabs, the thud (the roar is the server's).
local CUES = {
	react = { { "CreatureSniff", 0.35 }, { "CreatureNeck", 0.9 } },
	grab = { { "CreatureImpact", 0.3 } },
}

local function voice(creature, g)
	if not creature.voices then
		return
	end
	if creature.cuedFor ~= creature.modeSince then
		creature.cuedFor, creature.cued, creature.slots = creature.modeSince, {}, {}
	end
	for _, cue in CUES[g.mode] or {} do
		local name, at = cue[1], cue[2]
		if g.since >= at and not creature.cued[name] then
			creature.cued[name] = true
			if g.since < at + 0.5 then -- not long after, coming back into range
				say(creature, name, math.random())
			end
		end
	end
	for k, call in CALLS[g.mode] or {} do
		local name, every, chance = call[1], call[2], call[3]
		local slot = math.floor(g.serverNow / every)
		local last = creature.slots[name]
		creature.slots[name] = slot
		if last and slot ~= last and synced(slot, 40 + k) < chance and not (name == "CreatureBreathing" and g.holding) then
			say(creature, name, synced(slot, 50 + k))
		end
	end
end

local function update(creature, dt, now)
	creature.dt = dt
	local g = gait(creature, dt, now)
	if creature.bones then
		poseSkinned(creature, g)
	else
		poseParts(creature, g)
	end
	voice(creature, g)
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
	creature.voices = {}
	for name, falloff in VOICES do
		local sound = if falloff.looped
			then Sounds.loop(name, falloff.volume, "Effects", anchor)
			else Sounds.at(name, falloff.volume, anchor)
		if sound then
			sound.RollOffMode = Enum.RollOffMode.Linear
			sound.RollOffMinDistance = falloff.near
			sound.RollOffMaxDistance = falloff.far
			sound.PlaybackSpeed = falloff.pitch
			creature.voices[name] = sound
		end
	end
	setAlert(creature)
	for _, name in { "Alert", "Reacting", "Running", "Circling", "Lunging", "Focus" } do
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
		creature.hands = {} -- held where they were, which is back where it came from
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
	local function showOrHide()
		bodies.Parent = if player:GetAttribute("Practice") then nil else workspace
		for _, creature in creatures do
			setAlert(creature)
		end
	end
	player:GetAttributeChangedSignal("Practice"):Connect(showOrHide)
	showOrHide()

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
