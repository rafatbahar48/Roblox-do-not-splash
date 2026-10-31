-- The pieces the drowned forest is built from (MapBuilder.luau): dead trees,
-- stumps and the other stepping stones, islands, fallen logs, reeds, lanterns
-- and signposts. All anchored parts, except the trees near the trail: those
-- are the Meshy tree models in ServerStorage.ForestProps, when the place has
-- them (each standing on its own pivot, at the bottom of its roots). y values
-- are the water floor (FLOOR_Y), the surface (SURFACE_Y) and the top of an
-- island (TILE_TOP).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Parts = require(script.Parent.Parts)

local block, box = Parts.block, Parts.box

local ROOM = Config.Room
local SURFACE_Y = ROOM.SurfaceY
local FLOOR_Y = SURFACE_Y - ROOM.PoolDepth
local TILE_TOP = SURFACE_Y + ROOM.TileHeight
local BASE_Y = FLOOR_Y - 1

local Forest = {}

local C = {
	bark = Color3.fromRGB(62, 60, 58),
	barkDark = Color3.fromRGB(40, 40, 42),
	stump = Color3.fromRGB(84, 70, 58),
	cut = Color3.fromRGB(132, 110, 84), -- the pale top of a cut stump
	moss = Color3.fromRGB(56, 82, 48),
	mossMat = Color3.fromRGB(104, 118, 62), -- the floating moss that sinks: paler, so you can tell
	grass = Color3.fromRGB(42, 60, 40),
	mud = Color3.fromRGB(40, 34, 30),
	reed = Color3.fromRGB(84, 92, 58),
	rock = Color3.fromRGB(76, 80, 82),
	boards = Color3.fromRGB(150, 128, 96), -- the creaky boards: lighter than everything else
	raft = Color3.fromRGB(116, 86, 56),
	iron = Color3.fromRGB(28, 28, 32),
	lantern = Color3.fromRGB(125, 98, 45), -- dark: neon shows far brighter than its colour
	warm = Color3.fromRGB(255, 196, 120),
	sign = Color3.fromRGB(96, 78, 60),
	signText = Color3.fromRGB(232, 224, 204),
}
Forest.COLORS = C

local DECOR = { CanCollide = false, CanQuery = false, CastShadow = false }

-- A cylinder standing upright from y0 to y1.
local function column(folder, name, x, z, y0, y1, diameter, color, material, props)
	local part = block(folder, name, Vector3.new(y1 - y0, diameter, diameter), CFrame.new(x, (y0 + y1) / 2, z) * CFrame.Angles(0, 0, math.pi / 2), color, material, props)
	part.Shape = Enum.PartType.Cylinder
	return part
end

-- A cylinder lying from a to b.
local function rod(folder, name, a, b, diameter, color, material, props)
	local part = block(folder, name, Vector3.new((b - a).Magnitude, diameter, diameter), CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0), color, material, props)
	part.Shape = Enum.PartType.Cylinder
	return part
end

-- A thin block from a to b, for branches and reeds.
local function stick(folder, name, a, b, thickness, color, material, props)
	return block(folder, name, Vector3.new(thickness, thickness, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), color, material, props)
end

local treeModels -- the Meshy trees, found the first time a tree is planted

local function findTreeModels()
	if not treeModels then
		treeModels = {}
		local props = ServerStorage:FindFirstChild("ForestProps")
		for _, model in if props then props:GetChildren() else {} do
			if model:IsA("Model") then
				table.insert(treeModels, model)
			end
		end
		if #treeModels == 0 then
			warn("[Forest] No tree models in ServerStorage.ForestProps; building the trees from parts")
		end
	end
	return treeModels
end

-- One of the Meshy trees, height studs tall, roots at the waterline, turned
-- and leaning a little. Its branches don't collide (they'd catch you
-- mid-jump); an invisible post round the trunk stops you walking through it.
local function plantModel(folder, template, x, z, height, rng)
	local tree = template:Clone()
	local _, size = tree:GetBoundingBox()
	tree:ScaleTo(tree:GetScale() * height / size.Y)
	local turn = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0) * CFrame.Angles(rng:NextNumber(-0.05, 0.05), 0, rng:NextNumber(-0.05, 0.05))
	tree:PivotTo(CFrame.new(x, SURFACE_Y - 1.2, z) * turn)
	for _, part in tree:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
		end
	end
	tree.Parent = folder
	column(folder, "TreeTrunk", x, z, FLOOR_Y, SURFACE_Y + height * 0.6, height * 0.08, C.bark, nil, {
		Transparency = 1,
		CastShadow = false,
		CanQuery = false,
	})
end

-- A dead tree standing in the water at (x, z). Near the trail it is one of
-- the Meshy trees if there are any; otherwise, and far off in the fog, it is
-- built from parts: a leaning trunk, a few bare branches reaching up, and
-- roots at the waterline. far trees are simpler and cast no shadows.
function Forest.deadTree(folder, x, z, height, rng, far)
	local models = findTreeModels()
	if not far and #models > 0 then
		plantModel(folder, models[rng:NextInteger(1, #models)], x, z, height, rng)
		return
	end
	local lean = CFrame.Angles(rng:NextNumber(-0.08, 0.08), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.08, 0.08))
	local base = CFrame.new(x, FLOOR_Y, z) * lean
	local width = rng:NextNumber(1.3, 2.1) * (0.8 + height / 60)
	local shadows = if far then { CastShadow = false } else nil
	local split = height * rng:NextNumber(0.5, 0.65)
	local function point(y)
		return (base * CFrame.new(0, y, 0)).Position
	end
	rod(folder, "Trunk", point(0), point(split), width, C.bark, Enum.Material.Wood, shadows)
	rod(folder, "Trunk", point(split - 0.5), point(height), width * 0.55, C.bark, Enum.Material.Wood, shadows)

	for _ = 1, if far then 1 else rng:NextInteger(2, 4) do
		local from = point(height * rng:NextNumber(0.45, 0.9))
		local angle = rng:NextNumber(0, math.pi * 2)
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local length = rng:NextNumber(3, 7) * (0.6 + height / 50)
		local to = from + (out * rng:NextNumber(0.6, 1) + Vector3.new(0, rng:NextNumber(0.6, 1.3), 0)).Unit * length
		stick(folder, "Branch", from, to, width * 0.22, C.barkDark, Enum.Material.Wood, DECOR)
		if not far and rng:NextNumber() < 0.6 then
			local twig = to + (out * 0.5 + Vector3.new(rng:NextNumber(-0.6, 0.6), 1, rng:NextNumber(-0.6, 0.6))).Unit * length * 0.45
			stick(folder, "Twig", to, twig, width * 0.12, C.barkDark, Enum.Material.Wood, DECOR)
		end
	end
	if not far then
		for i = 1, 3 do
			local angle = i * 2.1 + rng:NextNumber(-0.4, 0.4)
			local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local top = Vector3.new(x, SURFACE_Y + 0.8, z) + out * width * 0.3
			stick(folder, "Root", top, Vector3.new(x, FLOOR_Y + 1, z) + out * width * 1.4, width * 0.3, C.barkDark, Enum.Material.Wood, DECOR)
		end
	end
end

-- A clump of reeds poking out of the water around (x, z).
function Forest.reeds(folder, x, z, rng)
	for _ = 1, rng:NextInteger(4, 7) do
		local at = Vector3.new(x + rng:NextNumber(-1.2, 1.2), FLOOR_Y + 1, z + rng:NextNumber(-1.2, 1.2))
		local top = at + Vector3.new(rng:NextNumber(-0.5, 0.5), rng:NextNumber(5, 7.5), rng:NextNumber(-0.5, 0.5))
		stick(folder, "Reed", at, top, 0.14, C.reed, Enum.Material.Grass, DECOR)
	end
end

-- A log lying half sunk in the water from a to b (both at the surface).
function Forest.fallenLog(folder, a, b, rng)
	local diameter = rng:NextNumber(1.6, 2.4)
	local sink = Vector3.new(0, -diameter * 0.2, 0)
	local log = rod(folder, "FallenLog", a + sink, b + sink, diameter, C.stump, Enum.Material.Wood)
	block(folder, "Moss", Vector3.new(diameter * 0.5, 0.2, (b - a).Magnitude * 0.6), CFrame.lookAt((a + b) / 2 + sink + Vector3.new(0, diameter * 0.48, 0), b + sink + Vector3.new(0, diameter * 0.48, 0)), C.moss, Enum.Material.Grass, DECOR)
	return log
end

-- An island: a flat grassy top with a muddy rim, from z0 to z1 and halfX
-- either side of x = 0, with rocks and reeds round its edge. Returns the
-- part you stand on.
function Forest.island(folder, name, z0, z1, halfX, rng)
	local top = box(folder, name, Vector3.new(-halfX, BASE_Y, z0), Vector3.new(halfX, TILE_TOP, z1), C.grass, Enum.Material.Grass)
	-- A muddy shelf just under the surface, a little wider than the island.
	box(folder, "Mud", Vector3.new(-halfX - 2, BASE_Y, z0 - 1.5), Vector3.new(halfX + 2, SURFACE_Y + 0.3, z1 + 1.5), C.mud, Enum.Material.Mud, DECOR)
	for _ = 1, math.floor(halfX / 4) do
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local x = side * (halfX + rng:NextNumber(-0.5, 1.5))
		local z = rng:NextNumber(z0 + 1, z1 - 1)
		if rng:NextNumber() < 0.5 then
			local size = rng:NextNumber(1.4, 2.6)
			block(folder, "Rock", Vector3.new(size * 1.3, size, size), CFrame.new(x, SURFACE_Y + size * 0.2, z) * CFrame.Angles(0, rng:NextNumber(0, 3), rng:NextNumber(-0.3, 0.3)), C.rock, Enum.Material.Slate)
		else
			Forest.reeds(folder, x, z, rng)
		end
	end
	return top
end

-- One stepping stone, from its spec { kind, size, x, z, raise } (see
-- MapBuilder.luau). Returns the part you stand on; moving ones (moss mats
-- and rafts) are a single part, so they carry nothing with them.
function Forest.steppingStone(folder, spec, rng)
	local top = TILE_TOP + spec.raise
	local size = spec.size
	local x, z = spec.x, spec.z

	if spec.kind == "sinking" then
		return block(folder, "SinkingTile", Vector3.new(size, 1, size), CFrame.new(x, top - 0.5, z) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0), C.mossMat, Enum.Material.Grass)
	elseif spec.kind == "raft" then
		return block(folder, "Raft", Vector3.new(size, 1, size), CFrame.new(x, top - 0.5, z), C.raft, Enum.Material.WoodPlanks, {
			Anchored = false,
			CustomPhysicalProperties = PhysicalProperties.new(2, 1, 0, 1, 1),
		})
	elseif spec.kind == "creaky" then
		-- Old boards on four posts.
		local boards = block(folder, "CreakyTile", Vector3.new(size, 0.6, size), CFrame.new(x, top - 0.3, z), C.boards, Enum.Material.WoodPlanks)
		for _, corner in { { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } } do
			local px, pz = x + corner[1] * (size / 2 - 0.4), z + corner[2] * (size / 2 - 0.4)
			column(folder, "Post", px, pz, FLOOR_Y, top - 0.6, 0.5, C.stump, Enum.Material.Wood, DECOR)
		end
		return boards
	end

	-- Stumps, mounds and broken trunks are round, as wide as the spec.
	local stump
	if spec.kind == "normal" and size > 6.5 then
		stump = column(folder, "Tile", x, z, BASE_Y, top, size, C.grass, Enum.Material.Grass)
		column(folder, "Mud", x, z, BASE_Y, SURFACE_Y + 0.4, size + 1.2, C.mud, Enum.Material.Mud, DECOR)
		if rng:NextNumber() < 0.6 then
			Forest.reeds(folder, x + size / 2, z + rng:NextNumber(-1, 1), rng)
		end
		return stump
	end
	local pillar = spec.kind == "pillar"
	stump = column(folder, if pillar then "Pillar" else "Tile", x, z, BASE_Y, top, size, if pillar then C.bark else C.stump, Enum.Material.Wood)
	column(folder, "Cut", x, z, top - 0.1, top + 0.02, size * 0.84, C.cut, Enum.Material.Wood, DECOR)
	for i = 1, 3 do
		local angle = i * 2.1 + rng:NextNumber(-0.5, 0.5)
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local at = Vector3.new(x, SURFACE_Y + 0.4, z) + out * size * 0.45
		block(folder, "Moss", Vector3.new(size * 0.35, 0.5, size * 0.35), CFrame.new(at), C.moss, Enum.Material.Grass, DECOR)
	end
	if pillar then
		-- A jagged broken top, round the edge so it doesn't get in the way.
		local angle = rng:NextNumber(0, math.pi * 2)
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local at = Vector3.new(x, top + 0.6, z) + out * size * 0.4
		block(folder, "Splinter", Vector3.new(0.35, 1.4, size * 0.25), CFrame.lookAt(at, at + out), C.bark, Enum.Material.Wood, DECOR)
	end
	return stump
end

-- A lantern hanging from a crooked post in the water at (x, z). Returns the
-- glowing glass (what flickers, see Hazards.luau and client/Fear.luau).
function Forest.lantern(folder, x, z, rng, facing)
	local height = rng:NextNumber(7, 9)
	local top = SURFACE_Y + height
	column(folder, "LanternPost", x, z, FLOOR_Y, top, 0.45, C.stump, Enum.Material.Wood, DECOR)
	local out = facing or Vector3.xAxis
	local arm = Vector3.new(x, top - 0.3, z) + out * 1.4
	stick(folder, "LanternArm", Vector3.new(x, top - 0.3, z), arm, 0.3, C.stump, Enum.Material.Wood, DECOR)
	block(folder, "LanternCap", Vector3.new(0.8, 0.25, 0.8), CFrame.new(arm - Vector3.new(0, 0.6, 0)), C.iron, Enum.Material.Metal, DECOR)
	local glass = block(folder, "Lantern", Vector3.new(0.6, 0.85, 0.6), CFrame.new(arm - Vector3.new(0, 1.15, 0)), C.lantern, Enum.Material.Neon, DECOR)
	local light = Instance.new("PointLight")
	light.Color = C.warm
	light.Range = 24
	light.Brightness = 1.1
	light.Shadows = true
	light.Parent = glass
	return glass
end

-- A wooden signpost on an island at (x, z), its board facing along facing.
function Forest.signpost(folder, x, z, facing, title, subtitle)
	column(folder, "SignPost", x, z, TILE_TOP, TILE_TOP + 4.6, 0.4, C.stump, Enum.Material.Wood)
	local center = Vector3.new(x, TILE_TOP + 3.6, z) + facing * 0.3
	local board = block(folder, "Sign", Vector3.new(4.6, 1.8, 0.2), CFrame.lookAt(center, center + facing), C.sign, Enum.Material.WoodPlanks, DECOR)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 1
	for i, line in { { title, 0.06, 0.5, Enum.Font.FredokaOne }, { subtitle, 0.58, 0.32, Enum.Font.GothamBold } } do
		local label = Instance.new("TextLabel")
		label.Name = if i == 1 then "Title" else "Subtitle"
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0.05, line[2])
		label.Size = UDim2.fromScale(0.9, line[3])
		label.Font = line[4]
		label.TextScaled = true
		label.TextColor3 = C.signText
		label.Text = line[1]
		label.Parent = gui
	end
	gui.Parent = board
	return board
end

return Forest
