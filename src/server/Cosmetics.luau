-- Puts skins and accessories on characters. Skins recolour body regions (see
-- Catalog.luau) and hide shirts and pants. Accessories are small builds
-- welded to the avatar's own attachment points, so they fit R6 and R15 rigs
-- at any body scale.
--
-- Both can be changed mid-life: clothing is tucked into a folder and each
-- recoloured part remembers its original look in attributes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)

local APPEARANCE_WAIT = 6 -- seconds to wait for the avatar to finish loading
local ACCESSORY_NAME = "StillWaterAccessory"
local STASH_NAME = "StillWaterClothing"

local Cosmetics = {}

local function regionOf(part)
	local name = part.Name
	if name == "Head" then
		return "head"
	elseif name == "UpperTorso" or name == "LowerTorso" or name == "Torso" then
		return "torso"
	elseif string.find(name, "Arm") or string.find(name, "Hand") then
		return "arms"
	elseif string.find(name, "Leg") or string.find(name, "Foot") then
		return "legs"
	end
	return nil
end

local function restoreSkin(character)
	for _, part in character:GetChildren() do
		if part:IsA("BasePart") and part:GetAttribute("OriginalColor") ~= nil then
			part.Color = part:GetAttribute("OriginalColor")
			part.Material = Enum.Material[part:GetAttribute("OriginalMaterial")]
			part.Transparency = part:GetAttribute("OriginalTransparency")
			part:SetAttribute("OriginalColor", nil)
			part:SetAttribute("OriginalMaterial", nil)
			part:SetAttribute("OriginalTransparency", nil)
		end
	end
	local stash = character:FindFirstChild(STASH_NAME)
	if stash then
		for _, clothing in stash:GetChildren() do
			clothing.Parent = character
		end
		stash:Destroy()
	end
end

local function applySkin(character, skin)
	restoreSkin(character)
	if not skin then
		return
	end

	local stash = Instance.new("Folder")
	stash.Name = STASH_NAME
	for _, child in character:GetChildren() do
		if child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") then
			child.Parent = stash
		end
	end
	stash.Parent = character

	for _, part in character:GetChildren() do
		local region = part:IsA("BasePart") and regionOf(part)
		local look = region and skin[region]
		if look then
			part:SetAttribute("OriginalColor", part.Color)
			part:SetAttribute("OriginalMaterial", part.Material.Name)
			part:SetAttribute("OriginalTransparency", part.Transparency)
			part.Color = look.color
			if look.material then
				part.Material = look.material
			end
			if look.transparency then
				part.Transparency = look.transparency
			end
		end
	end
end

local function findAttachment(character, name)
	for _, part in character:GetChildren() do
		if part:IsA("BasePart") then
			local attachment = part:FindFirstChild(name)
			if attachment and attachment:IsA("Attachment") then
				return attachment
			end
		end
	end
	return nil
end

-- One welded, massless piece of an accessory. shape is nil, "Ball",
-- "Cylinder", "Wedge" or "Ellipsoid".
local function piece(model, weldTo, cframe, size, color, material, shape)
	local part = Instance.new(if shape == "Wedge" then "WedgePart" else "Part")
	part.Name = "Piece"
	if shape == "Ball" then
		part.Shape = Enum.PartType.Ball
	elseif shape == "Cylinder" then
		part.Shape = Enum.PartType.Cylinder
	elseif shape == "Ellipsoid" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.CFrame = cframe
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part
	weld.Part1 = weldTo
	weld.Parent = part
	part.Parent = model
	return part
end

-- Accessory builders, keyed by catalog id. Each gets the model to fill and
-- the character, and returns false if the avatar lacks what it needs.
local builders = {}

function builders.swim_cap(model, character)
	local hat = findAttachment(character, "HatAttachment")
	if not hat then
		return false
	end
	local head = hat.Parent
	local size = head.Size
	piece(
		model,
		head,
		hat.WorldCFrame * CFrame.new(0, -size.Y * 0.08, 0),
		Vector3.new(size.X * 1.1, size.Y * 0.62, size.Z * 1.1),
		Color3.fromRGB(246, 196, 52),
		nil,
		"Ellipsoid"
	)
	return true
end

function builders.dive_goggles(model, character)
	local face = findAttachment(character, "FaceFrontAttachment")
	if not face then
		return false
	end
	local head = face.Parent
	local size = head.Size
	local lens = Color3.fromRGB(70, 170, 220)
	local rim = Color3.fromRGB(30, 34, 38)
	for _, side in { -1, 1 } do
		local at = face.WorldCFrame * CFrame.new(side * size.X * 0.2, size.Y * 0.12, -0.04) * CFrame.Angles(0, math.pi / 2, 0)
		piece(model, head, at, Vector3.new(0.1, size.X * 0.38, size.X * 0.38), rim, nil, "Cylinder")
		-- The cylinder's axis points forward here, so +X is out in front of the rim.
		piece(model, head, at * CFrame.new(0.04, 0, 0), Vector3.new(0.06, size.X * 0.3, size.X * 0.3), lens, Enum.Material.Glass, "Cylinder")
	end
	piece(model, head, face.WorldCFrame * CFrame.new(0, size.Y * 0.12, -0.05), Vector3.new(size.X * 0.12, 0.08, 0.08), rim)
	return true
end

function builders.float_ring(model, character)
	local waist = findAttachment(character, "WaistCenterAttachment")
	if not waist then
		return false
	end
	local torso = waist.Parent
	local radius = math.max(torso.Size.X, torso.Size.Z) * 0.62 + 0.2
	local count = 14
	for i = 1, count do
		local angle = (i / count) * math.pi * 2
		local offset = CFrame.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local color = if i % 2 == 0 then Color3.fromRGB(230, 70, 60) else Color3.fromRGB(240, 240, 236)
		piece(model, torso, waist.WorldCFrame * offset, Vector3.one * 0.62, color, nil, "Ball")
	end
	return true
end

function builders.dorsal_fin(model, character)
	local back = findAttachment(character, "BodyBackAttachment")
	if not back then
		return false
	end
	-- Turned so the wedge sticks straight out of the back, tapering upward.
	local at = back.WorldCFrame * CFrame.new(0, 0.1, 0.62) * CFrame.Angles(math.pi / 2, 0, 0)
	piece(model, back.Parent, at, Vector3.new(0.14, 1.25, 1.4), Color3.fromRGB(90, 100, 110), nil, "Wedge")
	return true
end

function builders.head_lamp(model, character)
	local face = findAttachment(character, "FaceFrontAttachment")
	if not face then
		return false
	end
	local head = face.Parent
	local size = head.Size
	local housing = piece(model, head, face.WorldCFrame * CFrame.new(0, size.Y * 0.34, -0.08), Vector3.new(0.42, 0.28, 0.2), Color3.fromRGB(40, 42, 46))
	piece(
		model,
		head,
		face.WorldCFrame * CFrame.new(0, size.Y * 0.34, -0.19) * CFrame.Angles(0, math.pi / 2, 0),
		Vector3.new(0.04, 0.22, 0.22),
		Color3.fromRGB(255, 236, 190),
		Enum.Material.Neon,
		"Cylinder"
	)
	local beam = Instance.new("SpotLight")
	beam.Face = Enum.NormalId.Front
	beam.Color = Color3.fromRGB(255, 236, 200)
	beam.Brightness = 4
	beam.Range = 40
	beam.Angle = 55
	beam.Shadows = true
	beam.Parent = housing
	return true
end

function builders.drowned_halo(model, character)
	local hat = findAttachment(character, "HatAttachment")
	if not hat then
		return false
	end
	local head = hat.Parent
	local radius = head.Size.X * 0.62
	local count = 12
	local first
	for i = 1, count do
		local angle = (i / count) * math.pi * 2
		local at = hat.WorldCFrame * CFrame.new(math.cos(angle) * radius, 0.55, math.sin(angle) * radius)
		local bead = piece(model, head, at, Vector3.one * 0.18, Color3.fromRGB(150, 240, 255), Enum.Material.Neon, "Ball")
		first = first or bead
	end
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(150, 240, 255)
	glow.Brightness = 1.2
	glow.Range = 8
	glow.Parent = first
	return true
end

local function applyAccessory(character, id)
	local old = character:FindFirstChild(ACCESSORY_NAME)
	if old then
		old:Destroy()
	end
	local build = id and builders[id]
	if not build then
		return
	end
	local model = Instance.new("Model")
	model.Name = ACCESSORY_NAME
	if build(model, character) then
		model.Parent = character
	else
		model:Destroy()
	end
end

local function waitForAppearance(player)
	if player:HasAppearanceLoaded() then
		return
	end
	local loaded = false
	local connection = player.CharacterAppearanceLoaded:Connect(function()
		loaded = true
	end)
	local deadline = os.clock() + APPEARANCE_WAIT
	while not loaded and os.clock() < deadline do
		task.wait(0.1)
	end
	connection:Disconnect()
end

-- Dresses a character in what the player has equipped. Waits for the avatar
-- to load first, so its own clothes and colours don't land on top.
function Cosmetics.apply(player, character, equipped)
	if not character then
		return
	end
	waitForAppearance(player)
	if player.Character ~= character or not character.Parent then
		return
	end
	applySkin(character, equipped.skin and Catalog.byId[equipped.skin])
	applyAccessory(character, equipped.accessory)
end

return Cosmetics
