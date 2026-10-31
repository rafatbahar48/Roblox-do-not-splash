-- The shop's accessories: small builds welded to the avatar's own attachment
-- points, so they fit R6 and R15 rigs at any body scale. Used on real
-- characters (server/Cosmetics.luau) and on the shop's copies of your avatar
-- (client/ShopPreview.luau).

local AccessoryLook = {}

AccessoryLook.NAME = "StillWaterAccessory" -- the model it builds on a character

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

function builders.santa_hat(model, character)
	local hat = findAttachment(character, "HatAttachment")
	if not hat then
		return false
	end
	local head = hat.Parent
	local size = head.Size
	local red = Color3.fromRGB(222, 32, 48)
	local fur = Color3.fromRGB(250, 250, 252)
	-- A wide, fluffy white band, sitting high enough to show over hair
	-- (cylinders lie along X, so each is stood up on end).
	local upright = CFrame.Angles(0, 0, math.pi / 2)
	local base = hat.WorldCFrame * CFrame.new(0, size.Y * 0.12, 0)
	piece(model, head, base * upright, Vector3.new(size.Y * 0.32, size.X * 1.4, size.X * 1.4), fur, Enum.Material.Snow, "Cylinder")
	-- The red body: drums getting smaller as it flops over to one side, and
	-- a big pompom on the end.
	local at = base * CFrame.new(0, size.Y * 0.1, 0)
	local radius = size.X * 0.62
	for i = 1, 5 do
		local height = size.Y * 0.26
		at = at * CFrame.new(0, height * 0.8, 0) * CFrame.Angles(math.rad(-8), 0, math.rad(6 + i * 5))
		piece(model, head, at * upright, Vector3.new(height, radius * 2, radius * 2), red, Enum.Material.SmoothPlastic, "Cylinder")
		radius *= 0.76
	end
	piece(model, head, at * CFrame.new(0, size.Y * 0.18, 0), Vector3.one * size.X * 0.4, fur, Enum.Material.Snow, "Ball")
	return true
end

-- Puts the accessory with this catalog id on a character, or with nil takes
-- the shop's accessory off.
function AccessoryLook.apply(character, id)
	local old = character:FindFirstChild(AccessoryLook.NAME)
	if old then
		old:Destroy()
	end
	local build = id and builders[id]
	if not build then
		return
	end
	local model = Instance.new("Model")
	model.Name = AccessoryLook.NAME
	if build(model, character) then
		model.Parent = character
	else
		model:Destroy()
	end
end

return AccessoryLook
