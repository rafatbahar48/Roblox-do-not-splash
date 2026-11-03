-- How a premium skin's outfit looks on a character (Catalog items with
-- premium, keyed by id): its 3D piece from ReplicatedStorage.SkinModels
-- (made in Meshy, art/models/skins/), smaller pieces built from parts, and
-- its lights and effects. A piece worn as the head (the ghillie hood, the
-- wraith's face and hair, the skull, the diving helmet) hides the avatar's
-- own head and face while it is on, and every outfit hides the avatar's
-- hats, hair and other accessories. Its colours come from the skin itself
-- (SkinLook.luau). Used on real characters (server/Cosmetics.luau) and on the
-- shop's copies of your avatar (client/ShopPreview.luau); its moves are in
-- client/SkinMoves.luau.
--
-- Where a 3D piece sits can be tuned in Studio with attributes on its
-- template in SkinModels: Fit (how many head-heights tall), Offset (from the
-- head's middle, in head-heights) and Turn (degrees round X, Y and Z), and
-- EyeOffset (from the piece's middle, in head-heights, + forward), EyeSize
-- and EyeColor for glowing eyes (as on the creature). Head-heights, as the
-- piece is sized by the head's height alone.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AccessoryLook = require(script.Parent.AccessoryLook)

local OutfitLook = {}

OutfitLook.NAME = "StillWaterOutfit" -- the model it builds on a character

local HIDDEN = "OutfitTransparency" -- what a hidden part's transparency was

local piece, findAttachment = AccessoryLook.piece, AccessoryLook.findAttachment

-- Where each 3D piece goes when its template doesn't say. hand: it hangs
-- from the right hand (the lantern) on a joint SkinMoves keeps upright.
-- The eyes are where the Meshy models have them painted (or, in the hood,
-- just in front of the dark face inside it).
local SPOTS = {
	SkinLantern = { hand = true, fit = 1.15 },
	SkinGhillieHood = {
		fit = 2.4,
		offset = Vector3.new(0, -0.32, 0.06),
		eyes = { offset = Vector3.new(0.12, 0.58, 0.44), size = 0.1, color = Color3.fromRGB(255, 214, 100) },
	},
	SkinWraithHead = {
		fit = 2.7,
		offset = Vector3.new(0, -0.62, 0.04),
		eyes = { offset = Vector3.new(0.23, 0.54, 0.66), size = 0.15, color = Color3.fromRGB(190, 255, 210) },
	},
	SkinSentinelSkull = {
		fit = 2.9,
		offset = Vector3.new(0, 0.2, 0),
		eyes = { offset = Vector3.new(0.23, 0.08, 0.65), size = 0.12, color = Color3.fromRGB(255, 190, 80) },
	},
	SkinDiverHelmet = { fit = 1.95, offset = Vector3.new(0, -0.2, 0) },
}

-- The template of a 3D piece (a MeshPart, or a model holding one), or nil
-- until it has been imported.
local function template(name)
	local folder = ReplicatedStorage:FindFirstChild("SkinModels")
	local found = folder and folder:FindFirstChild(name)
	if found and not found:IsA("BasePart") then
		found = found:FindFirstChildWhichIsA("BasePart", true)
	end
	return found
end

local function light(parent, color, brightness, range)
	local glow = Instance.new("PointLight")
	glow.Color = color
	glow.Brightness = brightness
	glow.Range = range
	glow.Shadows = false
	glow.Parent = parent
	return glow
end

local function emitter(parent, props)
	local particles = Instance.new("ParticleEmitter")
	for key, value in props do
		particles[key] = value
	end
	particles.Parent = parent
	return particles
end

local function hide(part)
	if part:GetAttribute(HIDDEN) == nil then
		part:SetAttribute(HIDDEN, part.Transparency)
	end
	part.Transparency = 1
end

-- The avatar's own hats, hair and other accessories, out of sight.
local function hideAccessories(character)
	for _, accessory in character:GetChildren() do
		if accessory:IsA("Accessory") then
			for _, part in accessory:GetDescendants() do
				if part:IsA("BasePart") or part:IsA("Decal") then
					hide(part)
				end
			end
		end
	end
end

-- The avatar's own head and face, out of sight under a piece worn as the head.
local function hideHead(head)
	hide(head)
	for _, decal in head:GetChildren() do
		if decal:IsA("Decal") then
			hide(decal)
		end
	end
end

-- Puts one 3D piece on: sized to the head, where its template says.
-- Returns the part, or nil without the template or the body part it needs.
local function meshPiece(model, character, name)
	local source = template(name)
	local head = character:FindFirstChild("Head")
	local spot = SPOTS[name]
	if not source or not head or not spot then
		return nil
	end
	local part = source:Clone()
	local fit = part:GetAttribute("Fit") or spot.fit
	local offset = part:GetAttribute("Offset") or spot.offset or Vector3.zero
	local turn = part:GetAttribute("Turn") or Vector3.zero
	part.Size *= fit * head.Size.Y / math.max(part.Size.Y, 1e-3)
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	local rotation = CFrame.Angles(math.rad(turn.X), math.rad(turn.Y), math.rad(turn.Z))

	if spot.hand then
		local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
		if not hand then
			part:Destroy()
			return nil
		end
		-- Hung by its top from the bottom of the hand, on a joint SkinMoves
		-- turns to keep it hanging straight down as the arm moves.
		local joint = Instance.new("Motor6D")
		joint.Name = "OutfitHang"
		joint.Part0 = hand
		joint.Part1 = part
		joint.C0 = CFrame.new(0, -hand.Size.Y / 2, 0)
		joint.C1 = (CFrame.new(0, -part.Size.Y / 2, 0) * rotation):Inverse()
		joint.Parent = part
		part.CFrame = hand.CFrame * joint.C0 * joint.C1:Inverse()
	else
		part.CFrame = head.CFrame * CFrame.new(offset * head.Size.Y) * rotation
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = part
		weld.Part1 = head
		weld.Parent = part
		hideHead(head)
	end
	part.Parent = model

	-- Glowing eyes on it, where they are on its face.
	local eyes = spot.eyes
	local eyeOffset = part:GetAttribute("EyeOffset") or (eyes and eyes.offset)
	if eyeOffset then
		local eyeSize = (part:GetAttribute("EyeSize") or eyes.size) * head.Size.Y
		local color = part:GetAttribute("EyeColor") or eyes.color
		for _, side in { -1, 1 } do
			local at = part.CFrame * CFrame.new(Vector3.new(side * eyeOffset.X, eyeOffset.Y, -eyeOffset.Z) * head.Size.Y)
			piece(model, part, at, Vector3.one * eyeSize, color, Enum.Material.Neon, "Ball")
		end
	end
	return part
end

-- The outfits' own pieces, keyed by catalog id. Each gets the model to fill
-- and the character.
local builders = {}

function builders.swamp_survivor(model, character)
	local hat = findAttachment(character, "HatAttachment")
	if hat then
		-- A dark knitted beanie with a rolled cuff.
		local head = hat.Parent
		local size = head.Size
		local knit = Color3.fromRGB(46, 50, 56)
		piece(model, head, hat.WorldCFrame * CFrame.new(0, -size.Y * 0.06, 0), Vector3.new(size.X * 1.08, size.Y * 0.66, size.Z * 1.08), knit, Enum.Material.Fabric, "Ellipsoid")
		local cuff = hat.WorldCFrame * CFrame.new(0, -size.Y * 0.2, 0) * CFrame.Angles(0, 0, math.pi / 2)
		piece(model, head, cuff, Vector3.new(size.Y * 0.2, size.X * 1.1, size.X * 1.1), Color3.fromRGB(36, 38, 44), Enum.Material.Fabric, "Cylinder")
	end
	-- Pack straps over the shoulders and a belt with pouches.
	local torso = character:FindFirstChild("UpperTorso")
	local strap = Color3.fromRGB(84, 60, 38)
	if torso then
		for _, side in { -1, 1 } do
			piece(model, torso, torso.CFrame * CFrame.new(side * torso.Size.X * 0.24, 0, -torso.Size.Z * 0.52), Vector3.new(torso.Size.X * 0.12, torso.Size.Y * 1.02, 0.08), strap, Enum.Material.Leather)
		end
	end
	local waist = character:FindFirstChild("LowerTorso")
	if waist then
		piece(model, waist, waist.CFrame * CFrame.new(0, waist.Size.Y * 0.2, 0), Vector3.new(waist.Size.X * 1.04, waist.Size.Y * 0.28, waist.Size.Z * 1.08), strap, Enum.Material.Leather)
		for _, side in { -1, 1 } do
			piece(model, waist, waist.CFrame * CFrame.new(side * waist.Size.X * 0.32, 0, -waist.Size.Z * 0.58), Vector3.new(waist.Size.X * 0.24, waist.Size.Y * 0.5, 0.22), Color3.fromRGB(96, 92, 60), Enum.Material.Fabric)
		end
	end
	local lantern = meshPiece(model, character, "SkinLantern")
	if lantern then
		light(lantern, Color3.fromRGB(255, 186, 110), 1.6, 14).Name = "LanternLight"
	end
end

function builders.bog_hunter(model, character)
	meshPiece(model, character, "SkinGhillieHood")
	local torso = character:FindFirstChild("UpperTorso")
	local strap = Color3.fromRGB(70, 54, 36)
	if torso then
		-- A strap across the chest.
		local across = torso.CFrame * CFrame.new(0, 0, -torso.Size.Z * 0.52) * CFrame.Angles(0, 0, math.rad(38))
		piece(model, torso, across, Vector3.new(torso.Size.X * 0.14, torso.Size.Y * 1.3, 0.08), strap, Enum.Material.Leather)
	end
	local waist = character:FindFirstChild("LowerTorso")
	if waist then
		piece(model, waist, waist.CFrame * CFrame.new(0, waist.Size.Y * 0.2, 0), Vector3.new(waist.Size.X * 1.04, waist.Size.Y * 0.28, waist.Size.Z * 1.08), strap, Enum.Material.Leather)
		for i = -1, 1 do
			piece(model, waist, waist.CFrame * CFrame.new(i * waist.Size.X * 0.3, -waist.Size.Y * 0.02, -waist.Size.Z * 0.58), Vector3.new(waist.Size.X * 0.22, waist.Size.Y * 0.46, 0.2), Color3.fromRGB(74, 70, 44), Enum.Material.Fabric)
		end
	end
end

function builders.willow_wraith(model, character)
	local head = meshPiece(model, character, "SkinWraithHead")
	if head then
		light(head, Color3.fromRGB(140, 255, 180), 0.8, 7)
	end
	local waist = character:FindFirstChild("LowerTorso")
	if waist then
		-- Green mist trailing from under it, and wisps swirling round it.
		local low = Instance.new("Attachment")
		low.Name = "OutfitMist"
		low.Position = Vector3.new(0, -waist.Size.Y * 2.6, 0)
		low.Parent = waist
		emitter(low, {
			Texture = "rbxasset://textures/particles/smoke_main.dds",
			Color = ColorSequence.new(Color3.fromRGB(150, 220, 180)),
			LightEmission = 0.3,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 3.2) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.75), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(1.6, 2.4),
			Rate = 14,
			Speed = NumberRange.new(0.3, 0.9),
			SpreadAngle = Vector2.new(180, 30),
			Acceleration = Vector3.new(0, 0.6, 0),
			RotSpeed = NumberRange.new(-30, 30),
		})
		emitter(waist, {
			Name = "OutfitWisps",
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Color = ColorSequence.new(Color3.fromRGB(120, 255, 170)),
			LightEmission = 1,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) }),
			Transparency = NumberSequence.new(0.2),
			Lifetime = NumberRange.new(1.2, 1.8),
			Rate = 10,
			Speed = NumberRange.new(1.5, 2.5),
			Shape = Enum.ParticleEmitterShape.Disc,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			Acceleration = Vector3.new(0, 1.2, 0),
			RotSpeed = NumberRange.new(90, 180),
		})
	end
end

function builders.rotwood_sentinel(model, character)
	local skull = meshPiece(model, character, "SkinSentinelSkull")
	if skull then
		light(skull, Color3.fromRGB(255, 170, 70), 0.9, 6)
	end
	local bark, moss = Color3.fromRGB(70, 52, 34), Color3.fromRGB(86, 110, 46)
	for _, side in { "Left", "Right" } do
		local shoulder = findAttachment(character, side .. "ShoulderAttachment")
		if shoulder then
			-- Rounded pads of bark on each shoulder, two layers dipping
			-- outwards, moss on top.
			local arm = shoulder.Parent
			local size = arm.Size
			local tip = CFrame.Angles(0, 0, math.rad(if side == "Right" then -18 else 18))
			local at = shoulder.WorldCFrame * CFrame.new(0, size.Y * 0.04, 0) * tip
			piece(model, arm, at * CFrame.new(0, -size.Y * 0.1, 0), Vector3.new(size.X * 1.7, size.Y * 0.32, size.Z * 1.6), Color3.fromRGB(58, 42, 28), Enum.Material.Wood, "Ellipsoid")
			piece(model, arm, at, Vector3.new(size.X * 1.5, size.Y * 0.4, size.Z * 1.42), bark, Enum.Material.Wood, "Ellipsoid")
			piece(model, arm, at * CFrame.new(0, size.Y * 0.12, 0), Vector3.new(size.X * 1.2, size.Y * 0.24, size.Z * 1.12), moss, Enum.Material.Grass, "Ellipsoid")
		end
	end
	local torso = character:FindFirstChild("UpperTorso")
	if torso then
		-- Embers (SkinMoves bursts them when it roars) and fireflies.
		emitter(torso, {
			Name = "OutfitEmbers",
			Texture = "rbxasset://textures/particles/fire_sparks_main.dds",
			Color = ColorSequence.new(Color3.fromRGB(255, 150, 60)),
			LightEmission = 1,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22), NumberSequenceKeypoint.new(1, 0) }),
			Lifetime = NumberRange.new(1, 1.8),
			Rate = 4,
			Speed = NumberRange.new(1, 3),
			SpreadAngle = Vector2.new(180, 180),
			Acceleration = Vector3.new(0, 2, 0),
		})
		emitter(torso, {
			Name = "OutfitFireflies",
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Color = ColorSequence.new(Color3.fromRGB(210, 255, 120)),
			LightEmission = 1,
			Size = NumberSequence.new(0.18),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.1), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(2.5, 4),
			Rate = 3,
			Speed = NumberRange.new(0.4, 1),
			SpreadAngle = Vector2.new(180, 180),
			Shape = Enum.ParticleEmitterShape.Sphere,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		})
	end
end

function builders.cursed_diver(model, character)
	local helmet = meshPiece(model, character, "SkinDiverHelmet")
	if helmet then
		light(helmet, Color3.fromRGB(90, 255, 140), 1.2, 9)
	end
	local back = findAttachment(character, "BodyBackAttachment")
	if back then
		-- A rusted air tank on its back.
		local torso = back.Parent
		local size = torso.Size
		local upright = CFrame.Angles(0, 0, math.pi / 2)
		local at = back.WorldCFrame * CFrame.new(0, -size.Y * 0.05, size.Z * 0.42)
		piece(model, torso, at * upright, Vector3.new(size.Y * 1.05, size.X * 0.5, size.X * 0.5), Color3.fromRGB(122, 86, 52), Enum.Material.CorrodedMetal, "Cylinder")
		piece(model, torso, at * CFrame.new(0, size.Y * 0.6, 0), Vector3.new(size.X * 0.16, size.Y * 0.16, size.X * 0.16), Color3.fromRGB(150, 118, 70), Enum.Material.Metal)
	end
end

-- Takes a character's outfit off: its pieces gone, its own head, face and
-- accessories back.
function OutfitLook.restore(character)
	local old = character:FindFirstChild(OutfitLook.NAME)
	if old then
		old:Destroy()
	end
	for _, item in character:GetDescendants() do
		local was = item:GetAttribute(HIDDEN)
		if was ~= nil then
			item.Transparency = was
			item:SetAttribute(HIDDEN, nil)
		end
	end
end

-- Puts a premium skin's outfit (a Catalog item) on a character, or with nil
-- (or a plain skin) takes it off.
function OutfitLook.apply(character, skin)
	OutfitLook.restore(character)
	local build = skin and builders[skin.id]
	if not build then
		return
	end
	local model = Instance.new("Model")
	model.Name = OutfitLook.NAME
	hideAccessories(character)
	build(model, character)
	model.Parent = character
end

return OutfitLook
