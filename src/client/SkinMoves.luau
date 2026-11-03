-- The premium skins' moves, posed on this screen each frame for every
-- character wearing one (its SkinMove attribute, set by server/
-- Cosmetics.luau), on top of Roblox's own walking and idle animations:
--
--   lantern  Swamp Survivor: the lantern held up out in front, swinging
--            gently from the hand, a little lower while walking; its flame
--            flickers
--   stalker  Bog Hunter: low and crouched, bent forward, the head slowly
--            scanning from side to side while it stands
--   spirit   Willow Wraith: floating off the ground, bobbing, the legs
--            hanging with the toes down, drifting rather than walking
--   roar     Rotwood Sentinel: chest out, arms held wide; now and then it
--            flings them up, throws its head back and the embers burst
--   bubbles  Cursed Diver: the helmet tilting as it looks about, bubbles
--            rising from it, a burst now and then
--
-- Looks only: none of them changes how anyone moves, or how loud they are.
-- Joints (Motor6Ds, or the AnimationConstraints Roblox's newer avatars have)
-- are posed through their Transform each frame, on top of the pose Roblox's
-- animation gave them that frame, or instead of it for joints a move takes
-- over. Every client works out the same moments from the server's clock and
-- who it is, so a roar comes at the same time for everyone. R15 avatars
-- only; an R6 one just wears the look.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local RANGE = 160 -- studs from the camera within which they are posed
local ROAR_EVERY = 9 -- seconds between roars, give or take
local ROAR_TIME = 1.6
local BUBBLE_RATE = 3 -- bubbles a second while standing (half that walking)
local BUBBLE_LIFE = 2.6
local BUBBLE_SEE = 0.55 -- how see-through a bubble is (glowing, so it shows at night)

local JOINTS = {
	Root = "LowerTorso",
	Waist = "UpperTorso",
	Neck = "Head",
	LeftShoulder = "LeftUpperArm",
	RightShoulder = "RightUpperArm",
	LeftElbow = "LeftLowerArm",
	RightElbow = "RightLowerArm",
	RightWrist = "RightHand",
	LeftHip = "LeftUpperLeg",
	RightHip = "RightUpperLeg",
	LeftKnee = "LeftLowerLeg",
	RightKnee = "RightLowerLeg",
	LeftAnkle = "LeftFoot",
	RightAnkle = "RightFoot",
}

local SkinMoves = {}

local tracked = {} -- [character] = { joints, base, written, seed, walk, bubbles = {}, lastBubble }
local bubbleFolder

local function angles(x, y, z)
	return CFrame.Angles(math.rad(x), math.rad(y or 0), math.rad(z or 0))
end

-- 0..1 from a slot of time and a salt: the same on every screen.
local function synced(slot, salt)
	local x = math.sin(slot * 12.9898 + salt * 78.233) * 43758.5453
	return x - math.floor(x)
end

local function smooth(edge0, edge1, value)
	local t = math.clamp((value - edge0) / (edge1 - edge0), 0, 1)
	return t * t * (3 - 2 * t)
end

local function isJoint(joint)
	return joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")
end

local function track(character, player)
	local joints = {}
	for name, partName in JOINTS do
		local part = character:FindFirstChild(partName)
		local joint = part and part:FindFirstChild(name)
		if joint and isJoint(joint) then
			joints[name] = joint
		end
	end
	if not joints.Root then
		return -- not an R15 avatar
	end
	tracked[character] = {
		joints = joints,
		base = {}, -- [joint] = the pose Roblox's animation gave it
		written = {}, -- [joint] = the pose set on top of that
		seed = player.UserId % 997,
		walk = 0,
		bubbles = {},
		lastBubble = 0,
	}
end

local function untrack(character)
	local state = tracked[character]
	if not state then
		return
	end
	tracked[character] = nil
	-- Back to the animation's pose, where it hasn't moved them since.
	for joint, base in state.base do
		if joint.Parent and joint.Transform:FuzzyEq(state.written[joint], 1e-4) then
			joint.Transform = base
		end
	end
	for _, bubble in state.bubbles do
		bubble.part:Destroy()
	end
end

-- Poses a joint this frame: offset on top of Roblox's animation, or with own
-- instead of it. Where the animation hasn't set the joint since last frame,
-- it is posed from the same base again, so nothing piles up.
local function pose(state, name, offset, own)
	local joint = state.joints[name]
	if joint then
		local base = joint.Transform
		local written = state.written[joint]
		if written and base:FuzzyEq(written, 1e-4) then
			base = state.base[joint]
		end
		local posed = if own then offset else offset * base
		state.base[joint] = base
		state.written[joint] = posed
		joint.Transform = posed
	end
end

local moves = {}

function moves.lantern(state, character, t, walk)
	pose(state, "RightShoulder", angles(62 - 22 * walk, 0, 8), true)
	pose(state, "RightElbow", angles(34 - 8 * walk), true)
	pose(state, "RightWrist", CFrame.identity, true)
	-- The lantern hangs straight down from the hand, swinging.
	local outfit = character:FindFirstChild("StillWaterOutfit")
	local lantern = outfit and outfit:FindFirstChild("SkinLantern")
	local hang = lantern and lantern:FindFirstChild("OutfitHang")
	local root = character:FindFirstChild("HumanoidRootPart")
	if hang and hang.Part0 and root then
		local swing = angles(math.sin(t * 1.7) * (10 + 10 * walk), 0, math.sin(t * 1.1) * 5)
		local upright = CFrame.lookAt(Vector3.zero, root.CFrame.LookVector * Vector3.new(1, 0, 1)) * swing
		hang.C0 = CFrame.new(hang.C0.Position) * (hang.Part0.CFrame.Rotation:Inverse() * upright)
		local flame = lantern:FindFirstChild("LanternLight")
		if flame then
			flame.Brightness = 1.6 * (0.85 + 0.1 * math.sin(t * 13) + 0.05 * math.sin(t * 31))
		end
	end
end

function moves.stalker(state, _, t, walk)
	local low = 0.45 + 0.55 * walk
	pose(state, "Root", CFrame.new(0, -0.95 * low, 0) * angles(-8 * low))
	pose(state, "Waist", angles(-22 * low))
	pose(state, "Neck", angles(20 * low) * angles(0, math.sin(t * 0.5) * 32 * (1 - walk)))
	for _, side in { "Left", "Right" } do
		pose(state, side .. "Hip", angles(42 * low))
		pose(state, side .. "Knee", angles(-62 * low))
		pose(state, side .. "Ankle", angles(18 * low))
	end
	pose(state, "LeftShoulder", angles(18 * low, 0, -8))
	pose(state, "RightShoulder", angles(18 * low, 0, 8))
end

function moves.spirit(state, _, t, walk)
	local bob = math.sin(t * 1.4) * 0.22
	pose(state, "Root", CFrame.new(0, 0.95 + bob, 0) * angles(-10 * walk))
	pose(state, "Waist", angles(-6 * walk + math.sin(t * 0.9) * 3))
	for i, side in { "Left", "Right" } do
		local sway = math.sin(t * 1.4 + i) * 4
		pose(state, side .. "Hip", angles(12 + sway), true)
		pose(state, side .. "Knee", angles(-26 - sway), true)
		pose(state, side .. "Ankle", angles(-40), true)
	end
	local reach = 24 - 30 * walk
	pose(state, "LeftShoulder", angles(reach + math.sin(t * 1.1) * 6, 0, -10), true)
	pose(state, "RightShoulder", angles(reach + math.sin(t * 1.1 + 1.5) * 6, 0, 10), true)
	pose(state, "LeftElbow", angles(12), true)
	pose(state, "RightElbow", angles(12), true)
end

function moves.roar(state, character, _, walk, serverNow)
	-- When it roars: on a beat of its own, the same on every screen.
	local slot = math.floor((serverNow + state.seed) / ROAR_EVERY)
	local since = (serverNow + state.seed) - slot * ROAR_EVERY - synced(slot, 7) * 3
	local roar = if since >= 0 and since < ROAR_TIME then smooth(0, 0.25, since) * (1 - smooth(ROAR_TIME - 0.4, ROAR_TIME, since)) else 0
	roar *= 1 - walk
	if roar > 0 and state.roared ~= slot then
		state.roared = slot
		local torso = character:FindFirstChild("UpperTorso")
		local embers = torso and torso:FindFirstChild("OutfitEmbers")
		if embers then
			embers:Emit(30)
		end
	end
	local wide = 12 * (1 - walk) + 8 * walk
	pose(state, "Waist", angles(6 - 12 * walk + 14 * roar))
	pose(state, "Neck", angles(26 * roar + math.sin(serverNow * 40) * 2 * roar))
	pose(state, "LeftShoulder", angles(28 * roar, 0, -(wide + 62 * roar)), roar > 0.05)
	pose(state, "RightShoulder", angles(28 * roar, 0, wide + 62 * roar), roar > 0.05)
	pose(state, "LeftElbow", angles(-14 + 4 * roar))
	pose(state, "RightElbow", angles(-14 + 4 * roar))
end

-- Bubbles: little faintly glowing green balls rising from the helmet,
-- wobbling, on this screen only.
local function bubble(state, from)
	local part = Instance.new("Part")
	part.Name = "Bubble"
	part.Shape = Enum.PartType.Ball
	local size = 0.12 + math.random() * 0.28
	part.Size = Vector3.one * size
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(150, 255, 200)
	part.Transparency = BUBBLE_SEE
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	local start = from + Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 0.8
	part.Position = start
	part.Parent = bubbleFolder
	table.insert(state.bubbles, { part = part, start = start, born = os.clock(), phase = math.random() * 6, speed = 1.6 + math.random() })
end

function moves.bubbles(state, character, t, walk)
	local amount = 1 - 0.6 * walk
	pose(state, "Neck", angles(math.sin(t * 0.53) * 8 * amount, math.sin(t * 0.37) * 22 * amount, math.sin(t * 0.7) * 14 * amount))
	local head = character:FindFirstChild("Head")
	if not head then
		return
	end
	local now = os.clock()
	local rate = BUBBLE_RATE * (1 - 0.5 * walk)
	if now - state.lastBubble > 1 / rate then
		state.lastBubble = now
		bubble(state, head.Position + Vector3.new(0, head.Size.Y * 0.9, 0))
		-- Now and then a burst.
		if math.random() < 0.06 then
			for _ = 1, 7 do
				bubble(state, head.Position + Vector3.new(0, head.Size.Y * 0.6, 0))
			end
		end
	end
end

local function stepBubbles(state)
	local now = os.clock()
	for i = #state.bubbles, 1, -1 do
		local b = state.bubbles[i]
		local age = now - b.born
		if age > BUBBLE_LIFE then
			b.part:Destroy()
			table.remove(state.bubbles, i)
		else
			local wobble = Vector3.new(math.sin(age * 5 + b.phase), 0, math.cos(age * 4 + b.phase)) * 0.18
			b.part.Position = b.start + Vector3.new(0, age * b.speed, 0) + wobble
			b.part.Transparency = BUBBLE_SEE + (1 - BUBBLE_SEE) * smooth(BUBBLE_LIFE - 0.6, BUBBLE_LIFE, age)
		end
	end
end

local function step(dt)
	local camera = workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position or Vector3.zero
	local serverNow = workspace:GetServerTimeNow()
	for character, state in tracked do
		local root = character:FindFirstChild("HumanoidRootPart")
		local move = moves[character:GetAttribute("SkinMove")]
		if not character.Parent or not root or not move then
			untrack(character)
		elseif (root.Position - eye).Magnitude <= RANGE then
			-- How much it's walking, eased so moves blend in and out.
			local velocity = root.AssemblyLinearVelocity
			local moving = if Vector3.new(velocity.X, 0, velocity.Z).Magnitude > 1.5 then 1 else 0
			state.walk += (moving - state.walk) * math.min(1, dt * 6)
			local t = serverNow + state.seed
			move(state, character, t, state.walk, serverNow)
			stepBubbles(state)
		end
	end
end

local function watch(player)
	local function onCharacter(character)
		local function check()
			-- Back to rest first, so nothing the last move bent stays bent.
			untrack(character)
			local move = character:GetAttribute("SkinMove")
			if move and moves[move] then
				track(character, player)
			end
		end
		character:GetAttributeChangedSignal("SkinMove"):Connect(check)
		check()
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
end

function SkinMoves.start()
	bubbleFolder = Instance.new("Folder")
	bubbleFolder.Name = "SkinBubbles"
	bubbleFolder.Parent = workspace
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	RunService.PreSimulation:Connect(step)
end

return SkinMoves
