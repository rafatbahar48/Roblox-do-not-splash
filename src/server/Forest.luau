-- The pieces the drowned forest is built from (MapBuilder.luau): dead trees,
-- stumps and the other stepping stones, islands, fallen logs, reeds and
-- cattails, lily pads and algae, lanterns, grapple hooks, signposts and the
-- STAGE COMPLETE doorway. All anchored parts, except the muddy islands
-- (Roblox terrain) and the trees near the trail: those
-- are the Meshy tree models in ServerStorage.ForestProps, when the place has
-- them (each standing on its own pivot, at the bottom of its roots). y values
-- are the water floor (FLOOR_Y), the surface (SURFACE_Y) and the top of an
-- island (TILE_TOP).

local CollectionService = game:GetService("CollectionService")
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
	rock = Color3.fromRGB(76, 80, 82),
	boards = Color3.fromRGB(150, 128, 96), -- the creaky boards: lighter than everything else
	raft = Color3.fromRGB(116, 86, 56),
	iron = Color3.fromRGB(28, 28, 32),
	lantern = Color3.fromRGB(125, 98, 45), -- dark: neon shows far brighter than its colour
	warm = Color3.fromRGB(255, 196, 120),
	sign = Color3.fromRGB(96, 78, 60),
	signText = Color3.fromRGB(232, 224, 204),
	lily = Color3.fromRGB(46, 82, 40),
	flower = Color3.fromRGB(236, 222, 230),
	algae = Color3.fromRGB(38, 54, 30),
	cattail = Color3.fromRGB(92, 58, 34),
	reedStem = Color3.fromRGB(58, 66, 40), -- plain, so thin stems don't look spotted
	rope = Color3.fromRGB(120, 98, 66),
	doorGlow = Color3.fromRGB(255, 150, 60), -- the STAGE COMPLETE doorway's amber
	doorText = Color3.fromRGB(255, 182, 96),
	rust = Color3.fromRGB(96, 62, 44),
	hookLamp = Color3.fromRGB(120, 160, 90), -- pale green: not a lantern
	hookLight = Color3.fromRGB(200, 255, 160),
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
		stick(folder, "Reed", at, top, 0.14, C.reedStem, Enum.Material.SmoothPlastic, DECOR)
	end
end

-- Cattails: reeds with brown heads, poking out of the water round (x, z).
function Forest.cattails(folder, x, z, rng)
	for _ = 1, rng:NextInteger(4, 8) do
		local at = Vector3.new(x + rng:NextNumber(-1.5, 1.5), FLOOR_Y + 1, z + rng:NextNumber(-1.5, 1.5))
		local top = at + Vector3.new(rng:NextNumber(-0.4, 0.4), rng:NextNumber(6, 8.5), rng:NextNumber(-0.4, 0.4))
		stick(folder, "Reed", at, top, 0.12, C.reedStem, Enum.Material.SmoothPlastic, DECOR)
		if rng:NextNumber() < 0.7 then
			local up = (top - at).Unit
			rod(folder, "Cattail", top - up * 1.4, top - up * 0.3, 0.32, C.cattail, Enum.Material.Fabric, DECOR)
		end
	end
end

-- A loose clump of lily pads floating round (x, z), now and then with a
-- pale flower.
function Forest.lilyPads(folder, x, z, rng)
	for i = 1, rng:NextInteger(3, 6) do
		local px, pz = x + rng:NextNumber(-2.5, 2.5), z + rng:NextNumber(-2.5, 2.5)
		local color = C.lily:Lerp(C.moss, rng:NextNumber(0, 0.5))
		column(folder, "LilyPad", px, pz, SURFACE_Y, SURFACE_Y + 0.06, rng:NextNumber(0.9, 1.8), color, Enum.Material.SmoothPlastic, DECOR)
		if i == 1 and rng:NextNumber() < 0.5 then
			block(folder, "Flower", Vector3.new(0.35, 0.3, 0.35), CFrame.new(px, SURFACE_Y + 0.2, pz), C.flower, Enum.Material.SmoothPlastic, DECOR)
		end
	end
end

-- Green scum lying on the still water round (x, z).
function Forest.algae(folder, x, z, rng)
	-- Lots of small overlapping scraps, so the patch has a ragged edge.
	for _ = 1, rng:NextInteger(5, 9) do
		local at = CFrame.new(x + rng:NextNumber(-2.5, 2.5), SURFACE_Y + 0.03, z + rng:NextNumber(-2.5, 2.5)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
		block(folder, "Algae", Vector3.new(rng:NextNumber(0.8, 2.4), 0.04, rng:NextNumber(0.6, 1.8)), at, C.algae, Enum.Material.SmoothPlastic, {
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Transparency = 0.5,
		})
	end
end

-- A low muddy island of Roblox terrain at (x, z), about radius across and
-- rising height out of the water, lumpy round its edge; big ones have a
-- grassy top. The terrain water must be filled first (MapBuilder.luau).
function Forest.mudIsland(x, z, radius, height, rng)
	local terrain = workspace.Terrain
	terrain:FillBall(Vector3.new(x, SURFACE_Y + height - radius, z), radius, Enum.Material.Mud)
	for _ = 1, 3 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local lump = radius * rng:NextNumber(0.45, 0.7)
		local at = Vector3.new(x + math.cos(angle) * radius * 0.6, 0, z + math.sin(angle) * radius * 0.6)
		terrain:FillBall(Vector3.new(at.X, SURFACE_Y + height * rng:NextNumber(0.3, 0.8) - lump, at.Z), lump, Enum.Material.Mud)
	end
	if radius >= 6 then
		local cap = radius * 0.6
		terrain:FillBall(Vector3.new(x, SURFACE_Y + height + 0.15 - cap, z), cap, Enum.Material.LeafyGrass)
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

-- What you stand on when the look is lumpy (logs): an unseen flat top, so
-- landing and walking are as steady as on planks.
local function walkway(folder, size, cframe)
	return block(folder, "Walkway", size, cframe, C.raft, Enum.Material.Wood, {
		Transparency = 1,
		CastShadow = false,
	})
end

-- The swamp's platforms in 3D: Meshy models (art/models/swamp) kept in
-- ServerStorage.SwampProps, one MeshPart each, standing as they were made.
-- They are only the look: you stand on an unseen top the spec's exact size,
-- so every jump measures the same. A stump's TopShare attribute says how
-- much of its width its flat top is (its roots spread wider). Without the
-- models, platforms are built from parts.
local SWAMP_MODELS = {
	stump = { "StumpA", "StumpB" },
	deck = { "PlankRaft" },
	logRaft = { "LogRaft" },
	log = { "FallenLog" },
}
local swampModels

-- A copy of one of kind's models to place, or nil.
local function swampModel(kind, rng)
	if not swampModels then
		swampModels = {}
		local props = ServerStorage:FindFirstChild("SwampProps")
		for name, models in SWAMP_MODELS do
			swampModels[name] = {}
			for _, modelName in models do
				local found = props and props:FindFirstChild(modelName)
				local mesh = found and (if found:IsA("MeshPart") then found else found:FindFirstChildWhichIsA("MeshPart", true))
				if mesh then
					table.insert(swampModels[name], mesh)
				end
			end
		end
		if not props then
			warn("[Forest] No platform models in ServerStorage.SwampProps; building the platforms from parts")
		end
	end
	local models = swampModels[kind]
	if not models or #models == 0 then
		return nil
	end
	local mesh = models[rng:NextInteger(1, #models)]:Clone()
	mesh.Anchored = true
	mesh.CanCollide = false
	mesh.CanQuery = false
	mesh.CanTouch = false
	return mesh
end

-- A raft model (deck or logRaft) stretched to a side by side square, its top
-- at turn (the raft's middle, turned its way). Returns its flat top, or nil
-- without a model. A sinking one (spec.hazard, see Hazards.luau) is
-- waterlogged: lower in the water and tipped a little, so you can tell, and
-- fixed to its top so it goes under with it.
local function raftModel(folder, kind, side, turn, rng, sinking)
	local mesh = swampModel(kind, rng)
	if not mesh then
		return nil
	end
	local size = mesh.Size
	local height = size.Y * side * 2 / (size.X + size.Z)
	mesh.Size = Vector3.new(side, height, side)
	mesh.CFrame = turn * CFrame.new(0, 0.05 - height / 2, 0)
	if sinking then
		mesh.CFrame = turn * CFrame.Angles(rng:NextNumber(-0.07, 0.07), 0, rng:NextNumber(0.04, 0.08) * (if rng:NextNumber() < 0.5 then -1 else 1)) * CFrame.new(0, -0.3 - height / 2, 0)
	end
	mesh.Parent = folder
	local top = walkway(folder, Vector3.new(side, 0.2, side), turn * CFrame.new(0, -0.1, 0))
	if sinking then
		mesh.Anchored = false
		mesh.Massless = true
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = top
		weld.Part1 = mesh
		weld.Parent = top
	end
	return top
end

-- A rough raft of planks resting low on the water, turned any which way,
-- for a swamp (kind "deck"). Its spec size is the circle the jumps are
-- measured to; the planks make a square a little smaller. A creaky one
-- (spec.hazard) is a piece of old dock, its broken posts still standing at
-- its corners. Returns the middle plank.
local function deck(folder, spec, top, rng)
	local side = spec.size * 0.8
	local turn = CFrame.new(spec.x, top, spec.z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
	if spec.hazard == "creaky" then
		for _, corner in { { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } } do
			if rng:NextNumber() < 0.75 then
				local at = turn * Vector3.new(corner[1] * (side / 2 + 0.1), 0, corner[2] * (side / 2 + 0.1))
				column(folder, "DockPost", at.X, at.Z, FLOOR_Y, top + rng:NextNumber(0.3, 1.2), 0.55, C.barkDark, Enum.Material.Wood, DECOR)
			end
		end
	end
	local modelTop = raftModel(folder, "deck", side, turn, rng, spec.hazard == "sinking")
	if modelTop then
		return modelTop
	end
	local count = 5
	local width = side / count
	local middle
	for i = 1, count do
		local offset = (i - (count + 1) / 2) * width
		local length = side + rng:NextNumber(-0.6, 0.4)
		local at = turn * CFrame.new(offset, -0.25 + rng:NextNumber(-0.04, 0.02), rng:NextNumber(-0.3, 0.3)) * CFrame.Angles(0, rng:NextNumber(-0.03, 0.03), 0)
		local plank = block(folder, "Deck", Vector3.new(width - 0.1, 0.5, length), at, C.raft:Lerp(C.barkDark, rng:NextNumber(0, 0.35)), Enum.Material.Wood)
		if i == math.ceil(count / 2) then
			middle = plank
		end
	end
	for _, across in { -side * 0.32, side * 0.32 } do
		block(folder, "Beam", Vector3.new(side + 0.4, 0.4, 0.6), turn * CFrame.new(0, -0.7, across), C.barkDark, Enum.Material.Wood, DECOR)
	end
	if rng:NextNumber() < 0.6 then
		local at = turn * CFrame.new(rng:NextNumber(-0.25, 0.25) * side, 0.02, rng:NextNumber(-0.25, 0.25) * side)
		block(folder, "Moss", Vector3.new(side * 0.35, 0.05, side * 0.25), at, C.moss, Enum.Material.Grass, DECOR)
	end
	return middle
end

-- A raft of logs lashed together with rope, resting low on the water, for a
-- swamp (kind "logRaft"). Like a deck, the logs make a square a little
-- smaller than its spec size. Returns its flat top.
local function logRaft(folder, spec, top, rng)
	local side = spec.size * 0.8
	local turn = CFrame.new(spec.x, top, spec.z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
	local modelTop = raftModel(folder, "logRaft", side, turn, rng, spec.hazard == "sinking")
	if modelTop then
		return modelTop
	end
	local count = 5
	local thick = side / count
	for i = 1, count do
		local offset = (i - (count + 1) / 2) * thick
		local length = side + rng:NextNumber(-0.5, 0.6)
		local a = turn * Vector3.new(offset, -thick / 2, -length / 2)
		local b = turn * Vector3.new(offset, -thick / 2, length / 2)
		rod(folder, "RaftLog", a, b, thick * 0.96, C.raft:Lerp(C.bark, rng:NextNumber(0.2, 0.6)), Enum.Material.Wood, DECOR)
	end
	for _, across in { -side * 0.33, side * 0.33 } do
		block(folder, "Lashing", Vector3.new(side + 0.1, thick * 0.3, 0.3), turn * CFrame.new(0, -thick * 0.08, across), C.rope, Enum.Material.Fabric, DECOR)
	end
	return walkway(folder, Vector3.new(side, 0.2, side), turn * CFrame.new(0, -0.1, 0))
end

-- A fallen log lying half sunk along spec.dir, to walk along (kind "log"):
-- its spec size is its length. Returns its flat top.
local function walkLog(folder, spec, top, rng)
	local diameter = 2.4 -- Swamp.luau's LOG_WIDTH
	local center = Vector3.new(spec.x, top - diameter / 2, spec.z)
	local along = Vector3.new(spec.dir.X, 0, spec.dir.Y)
	local half = along * spec.size / 2
	local walkTop = CFrame.lookAt(Vector3.new(spec.x, top - 0.1, spec.z), Vector3.new(spec.x, top - 0.1, spec.z) + along)
	local mesh = swampModel("log", rng)
	if mesh then
		-- Stretched to the log's length and thickness along its longer side;
		-- its branch stub sticks up, so it stands that much taller.
		local size = mesh.Size
		local alongX = size.X >= size.Z
		local height = diameter * size.Y / (if alongX then size.Z else size.X)
		mesh.Size = if alongX then Vector3.new(spec.size, height, diameter) else Vector3.new(diameter, height, spec.size)
		local flip = if rng:NextNumber() < 0.5 then -1 else 1
		local right = if alongX then along * flip else Vector3.new(along.Z, 0, -along.X) * flip
		mesh.CFrame = CFrame.fromMatrix(Vector3.new(spec.x, top - diameter + height / 2, spec.z), right, Vector3.yAxis)
		mesh.Parent = folder
		return walkway(folder, Vector3.new(1.8, 0.2, spec.size), walkTop)
	end
	rod(folder, "FallenLog", center - half, center + half, diameter, C.stump, Enum.Material.Wood, DECOR)
	-- A snapped-off branch near one end, and moss along the top.
	local stubAt = center + half * rng:NextNumber(0.4, 0.8) + Vector3.new(0, diameter * 0.3, 0)
	local out = Vector3.new(-along.Z, 0.6, along.X) * (if rng:NextNumber() < 0.5 then -1 else 1)
	stick(folder, "Branch", stubAt, stubAt + out.Unit * rng:NextNumber(1.5, 2.5), 0.35, C.barkDark, Enum.Material.Wood, DECOR)
	local mossAt = center + Vector3.new(0, diameter * 0.47, 0) - half * 0.3
	block(folder, "Moss", Vector3.new(diameter * 0.45, 0.12, spec.size * 0.4), CFrame.lookAt(mossAt, mossAt + along), C.moss, Enum.Material.Grass, DECOR)
	return walkway(folder, Vector3.new(1.8, 0.2, spec.size), walkTop)
end

-- A rope sagging between two neighbouring rafts (a and b specs), just over
-- the water: tying the route together, as old swamp crossings are.
function Forest.rope(folder, a, b)
	local from, to = Vector3.new(a.x, 0, a.z), Vector3.new(b.x, 0, b.z)
	local across = (to - from).Unit
	local y = TILE_TOP + math.min(a.raise, b.raise) - 0.25
	local p0 = from + across * (a.size * 0.38) + Vector3.new(0, y, 0)
	local p1 = to - across * (b.size * 0.38) + Vector3.new(0, y, 0)
	local segments = 4
	local last = p0
	for i = 1, segments do
		local t = i / segments
		local point = p0:Lerp(p1, t) - Vector3.new(0, math.sin(t * math.pi) * 0.5, 0)
		stick(folder, "Rope", last, point, 0.12, C.rope, Enum.Material.Fabric, DECOR)
		last = point
	end
end

-- One stepping stone, from its spec { kind, size, x, z, raise } (see
-- MapBuilder.luau). Returns the part you stand on; moving ones (moss mats
-- and rafts) are a single part, so they carry nothing with them. A swamp's
-- are "stump" (a cut stump, however wide), "deck" and "logRaft" (rafts of
-- planks or logs that stay put), "log" (a fallen log) and "mound"; all but
-- mounds are the 3D models in ServerStorage.SwampProps when it has them.
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
	elseif spec.kind == "deck" then
		return deck(folder, spec, top, rng)
	elseif spec.kind == "logRaft" then
		return logRaft(folder, spec, top, rng)
	elseif spec.kind == "log" then
		return walkLog(folder, spec, top, rng)
	elseif spec.kind == "stump" then
		local mesh = swampModel("stump", rng)
		if mesh then
			-- Its flat top as wide as the stump, and deep enough to stand on
			-- the bottom; its roots spread out under the water.
			local scale = size / ((mesh:GetAttribute("TopShare") or 0.6) * math.max(mesh.Size.X, mesh.Size.Z))
			local height = math.max(mesh.Size.Y * scale, top - FLOOR_Y + 1)
			mesh.Size = Vector3.new(mesh.Size.X * scale, height, mesh.Size.Z * scale)
			mesh.CFrame = CFrame.new(x, top + 0.05 - height / 2, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			mesh.Parent = folder
			return column(folder, "Tile", x, z, BASE_Y, top, size, C.stump, Enum.Material.Wood, { Transparency = 1, CastShadow = false })
		end
	end

	-- Stumps, mounds and broken trunks are round, as wide as the spec. A
	-- swamp's stumps are always stumps, however wide.
	local stump
	if (spec.kind == "normal" and size > 6.5) or spec.kind == "mound" then
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
	-- Moss clinging round the waterline.
	for i = 1, 3 do
		local angle = i * 2.1 + rng:NextNumber(-0.5, 0.5)
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local along = Vector3.new(-out.Z, 0, out.X)
		local at = Vector3.new(x, SURFACE_Y + 0.12, z) + out * size * 0.5
		block(folder, "Moss", Vector3.new(0.35, 0.3, size * rng:NextNumber(0.3, 0.5)), CFrame.lookAt(at, at + along), C.moss, Enum.Material.Grass, DECOR)
	end
	if spec.kind == "stump" and rng:NextNumber() < 0.6 then
		-- Moss creeping over the cut top from one edge.
		local angle = rng:NextNumber(0, math.pi * 2)
		local at = Vector3.new(x, top + 0.03, z) + Vector3.new(math.cos(angle), 0, math.sin(angle)) * size * 0.3
		block(folder, "Moss", Vector3.new(size * 0.3, 0.06, size * 0.22), CFrame.new(at) * CFrame.Angles(0, -angle, 0), C.moss, Enum.Material.Grass, DECOR)
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

-- A hook for the grapple (Config.Grapple) over platform `to`, across a gap
-- too far to jump from platform `from` (specs, see MapBuilder.luau): an old
-- iron ring hanging from the arm of a tall crooked post in the water past
-- the platform, with a pale lamp on the post so it shows through the fog.
-- Returns the hook: an invisible part in the middle of the ring, tagged
-- GrappleHook, whose LandAt attribute is the middle of the platform's top
-- (and From, the middle of the top of the one before the gap). leanFrom (1
-- or -1, or random) is which side of the way across the post leans in from.
-- A free hook (over a stage's route, not a shortcut) swings you over without
-- using up a grapple (server/Shop.luau); its Free attribute says so.
-- client/Grapple.luau lights it up while it's in reach.
function Forest.grappleHook(folder, from, to, rng, leanFrom, free)
	local model = Instance.new("Model")
	model.Name = "GrappleHook"
	model.Parent = folder

	local top = TILE_TOP + to.raise
	local ring = Vector3.new(to.x, top + Config.Grapple.HookHeight, to.z)
	local across = Vector3.new(to.x - from.x, 0, to.z - from.z).Unit
	local side = Vector3.new(-across.Z, 0, across.X) * (leanFrom or (if rng:NextNumber() < 0.5 then -1 else 1))

	-- The post, in the water past the platform and a little to one side,
	-- leaning in over it, and its arm out over the middle.
	local foot = Vector3.new(to.x, FLOOR_Y, to.z) + across * (to.size / 2 + 2.2) + side * 1.6
	local head = Vector3.new(to.x, ring.Y + 2.4, to.z) + across * (to.size / 2 + 1.2) + side * 1.2
	rod(model, "Post", foot, head, 1, C.bark, Enum.Material.Wood)
	local armEnd = ring + Vector3.new(0, 1.9, 0)
	rod(model, "Arm", head - Vector3.new(0, 0.5, 0), armEnd, 0.6, C.barkDark, Enum.Material.Wood, DECOR)
	stick(model, "Chain", armEnd, ring + Vector3.new(0, 0.8, 0), 0.16, C.iron, Enum.Material.Metal, DECOR)

	-- The ring, facing the way you come from.
	local segments, radius = 10, 0.8
	for i = 0, segments - 1 do
		local angle = i / segments * math.pi * 2
		local at = ring + (side * math.cos(angle) + Vector3.yAxis * math.sin(angle)) * radius
		local tangent = side * -math.sin(angle) + Vector3.yAxis * math.cos(angle)
		local length = radius * 2 * math.pi / segments * 1.15
		block(model, "Ring", Vector3.new(0.22, 0.22, length), CFrame.lookAt(at, at + tangent), C.rust, Enum.Material.CorrodedMetal, DECOR)
	end

	local lamp = block(model, "Lamp", Vector3.new(0.5, 0.7, 0.5), CFrame.new(head - Vector3.new(0, 1.6, 0) - across * 0.7), C.hookLamp, Enum.Material.Neon, DECOR)
	local light = Instance.new("PointLight")
	light.Color = C.hookLight
	light.Range = 12
	light.Brightness = 0.8
	light.Parent = lamp

	local hook = block(model, "Hook", Vector3.new(1.6, 1.6, 0.4), CFrame.lookAt(ring, ring + across), C.rust, nil, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	})
	hook:SetAttribute("LandAt", Vector3.new(to.x, top, to.z))
	hook:SetAttribute("From", Vector3.new(from.x, TILE_TOP + from.raise, from.z))
	if free then
		hook:SetAttribute("Free", true)
	end
	local rope = Instance.new("Attachment")
	rope.Name = "Rope"
	rope.Parent = hook
	CollectionService:AddTag(hook, "GrappleHook")
	model.PrimaryPart = hook
	return hook
end

-- The STAGE COMPLETE doorway at the end of a swamp stage, on its end island
-- at x = 0, z, facing back down the stage: an archway of rough logs with
-- its sign on top, a warm amber glow filling the opening and a lantern on
-- either side. Walking through it crosses the stage's checkpoint
-- (MapBuilder.luau). Tagged StageDoor: its glow only shows as you come near
-- (client/Mood.luau), so it doesn't give the end away through the fog. The
-- last stage's is grand: scale times the size, between two great dead trees.
function Forest.stageDoor(folder, z, rng, scale)
	local model = Instance.new("Model")
	model.Name = "StageDoor"
	model.Parent = folder
	local base = TILE_TOP
	local half, height = 4.6, 8.5 -- the opening

	for _, side in { -1, 1 } do
		local foot = Vector3.new(side * (half + 0.6), base - 1, z)
		rod(model, "Post", foot, Vector3.new(side * (half + 0.5), base + height + 0.6, z + rng:NextNumber(-0.2, 0.2)), 1.2, C.bark, Enum.Material.Wood)
	end
	rod(model, "Lintel", Vector3.new(-half - 1.8, base + height + 0.1, z), Vector3.new(half + 1.8, base + height + 0.5, z), 1.1, C.bark, Enum.Material.Wood)

	local signAt = Vector3.new(0, base + height + 1.9, z - 0.15)
	local sign = block(model, "Sign", Vector3.new(8.4, 2, 0.3), CFrame.lookAt(signAt, signAt - Vector3.zAxis) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-2.5, 2.5))), C.sign, Enum.Material.WoodPlanks)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0 -- the letters glow
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(0.04, 0.1)
	label.Size = UDim2.fromScale(0.92, 0.8)
	label.Font = Enum.Font.Creepster
	label.TextScaled = true
	label.TextColor3 = C.doorText
	label.TextStrokeColor3 = Color3.fromRGB(40, 16, 6)
	label.TextStrokeTransparency = 0.2
	label.Text = "STAGE COMPLETE"
	label.Parent = gui
	gui.Parent = sign

	-- The glow: amber strips just inside the posts and lintel, and a haze
	-- filling the opening.
	for _, side in { -1, 1 } do
		block(model, "Glow", Vector3.new(0.2, height - 0.4, 0.2), CFrame.new(side * (half - 0.1), base + (height - 0.4) / 2, z), C.doorGlow, Enum.Material.Neon, DECOR)
	end
	block(model, "Glow", Vector3.new(half * 2 - 0.2, 0.2, 0.2), CFrame.new(0, base + height - 0.5, z), C.doorGlow, Enum.Material.Neon, DECOR)
	local haze = block(model, "Haze", Vector3.new(half * 2 - 0.4, height - 0.6, 0.1), CFrame.new(0, base + (height - 0.6) / 2, z), C.doorGlow, Enum.Material.Neon, {
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Transparency = 0.86,
	})
	local light = Instance.new("PointLight")
	light.Color = C.doorGlow
	light.Range = 20
	light.Brightness = 1.6
	light.Parent = haze

	for _, side in { -1, 1 } do
		local hang = Vector3.new(side * (half + 1.6), base + 6, z - 0.7)
		stick(model, "LanternArm", Vector3.new(side * (half + 0.6), base + 6.4, z), hang + Vector3.new(0, 0.4, 0), 0.25, C.stump, Enum.Material.Wood, DECOR)
		block(model, "LanternCap", Vector3.new(0.8, 0.25, 0.8), CFrame.new(hang + Vector3.new(0, 0.2, 0)), C.iron, Enum.Material.Metal, DECOR)
		local glass = block(model, "Lantern", Vector3.new(0.6, 0.85, 0.6), CFrame.new(hang - Vector3.new(0, 0.3, 0)), C.lantern, Enum.Material.Neon, DECOR)
		local lamp = Instance.new("PointLight")
		lamp.Color = C.warm
		lamp.Range = 16
		lamp.Brightness = 1
		lamp.Parent = glass
	end
	if scale and scale ~= 1 then
		model.WorldPivot = CFrame.new(0, base, z) -- grows up from the ground
		model:ScaleTo(scale)
		for _, side in { -1, 1 } do
			-- Far enough out and back that their branches don't cross the sign.
			Forest.deadTree(folder, side * (half * scale + 8), z + rng:NextNumber(4, 6), rng:NextNumber(32, 38), rng, false)
		end
	end
	CollectionService:AddTag(model, "StageDoor")
	return model
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
