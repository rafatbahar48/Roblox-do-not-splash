-- Builds the whole map from Config and Stages when the server starts: the
-- lobby (LobbyBuilder.luau), then behind its building a drowned forest at
-- dusk: murky water, dead trees and fog, with one stretch per stage along +Z
-- and the way out at the end. Each stretch runs from an island to an island
-- with its checkpoint: across a trail of stepping stones, or, for a swamp
-- stage, across an open swamp of scattered platforms (Swamp.luau). Stage 1
-- starts in the cave behind the building (CaveBuilder.luau).
-- Returns a layout table the other server modules use to find stages.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Stages = require(ReplicatedStorage.Shared.Stages)
local CaveBuilder = require(script.Parent.CaveBuilder)
local Forest = require(script.Parent.Forest)
local LobbyBuilder = require(script.Parent.LobbyBuilder)
local Parts = require(script.Parent.Parts)
local Swamp = require(script.Parent.Swamp)

local block, box = Parts.block, Parts.box

local ROOM = Config.Room
local FOREST = Config.Forest
local HALF_WIDTH = ROOM.Width / 2 -- the band the stepping stones are laid in
local SURFACE_Y = ROOM.SurfaceY
local FLOOR_Y = SURFACE_Y - ROOM.PoolDepth -- the bottom of the water
local TILE_TOP = SURFACE_Y + ROOM.TileHeight -- top of islands and ordinary stepping stones
local BASE_Y = FLOOR_Y - 1 -- underside of everything

local COLORS = {
	wall = Color3.fromRGB(70, 62, 74), -- the back of the lobby's building
	door = Color3.fromRGB(52, 38, 30), -- the backs of its doors
	floor = Color3.fromRGB(30, 28, 26),
	water = Color3.fromRGB(16, 24, 20), -- greenish black
	bank = Color3.fromRGB(46, 40, 32), -- the terrain mud of islands and banks
	bankGrass = Color3.fromRGB(42, 52, 36),
	checkpoint = Color3.fromRGB(70, 150, 112),
	shell = Color3.fromRGB(255, 186, 200),
	stone = Color3.fromRGB(96, 98, 104),
	exit = Color3.fromRGB(255, 238, 196),
	text = Color3.fromRGB(232, 224, 204),
}
local BARRIER = { Transparency = 1, CanQuery = false, CastShadow = false }
local FINAL_DOOR_SCALE = 1.5 -- the last stage's doorway, before the way out

local MapBuilder = {}

local function addSign(part, face, title, subtitle)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 1

	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = UDim2.fromScale(1, 0.55)
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextScaled = true
	titleLabel.TextColor3 = COLORS.text
	titleLabel.Text = title
	titleLabel.Parent = gui

	local subtitleLabel = titleLabel:Clone()
	subtitleLabel.Position = UDim2.fromScale(0, 0.6)
	subtitleLabel.Size = UDim2.fromScale(1, 0.3)
	subtitleLabel.Font = Enum.Font.GothamMedium
	subtitleLabel.Text = subtitle
	subtitleLabel.Parent = gui

	gui.Parent = part
end

-- The back wall of the lobby's building at z, with a doorway centred on each
-- x in doorXs, shut: stage 1's cave is on the other side, and parties are
-- brought through (Parties.luau).
local function buildDoorWall(folder, z, doorXs)
	local min, max = z - 0.5, z + 0.5
	local top = SURFACE_Y + ROOM.Height
	local half = ROOM.DoorWidth / 2
	local xs = table.clone(doorXs)
	table.sort(xs)
	local left = -HALF_WIDTH - 2
	for _, x in xs do
		box(folder, "DoorWall", Vector3.new(left, BASE_Y, min), Vector3.new(x - half, top, max), COLORS.wall, Enum.Material.Brick)
		box(folder, "Lintel", Vector3.new(x - half, TILE_TOP + ROOM.DoorHeight, min), Vector3.new(x + half, top, max), COLORS.wall, Enum.Material.Brick)
		-- The doors' backs, as seen from the cave. Solid: nobody walks through.
		box(folder, "DoorBack", Vector3.new(x - half, TILE_TOP, z - 0.1), Vector3.new(x + half, TILE_TOP + ROOM.DoorHeight, z + 0.5), COLORS.door, Enum.Material.WoodPlanks, {
			CanQuery = false,
		})
		left = x + half
	end
	box(folder, "DoorWall", Vector3.new(left, BASE_Y, min), Vector3.new(HALF_WIDTH + 2, top, max), COLORS.wall, Enum.Material.Brick)
end

local function pickKind(rng, mix)
	local total = 0
	for _, weight in mix do
		total += weight
	end
	local roll = rng:NextNumber() * total
	for kind, weight in mix do
		roll -= weight
		if roll <= 0 then
			return kind
		end
	end
	return "normal"
end

-- Lays a trail of stepping stones across the water. Every jump stays within
-- Config.MaxJump. Jumps are measured as if every stone were round (edge to
-- edge along the line between centres); square ones are never further apart.
local function generateTiles(rng, stage, poolStart, poolEnd)
	local specs = {}
	local z = poolStart
	local prev -- the last spec, or nil for the start island

	while poolEnd - z > stage.gap[2] do
		local kind = pickKind(rng, stage.mix)
		local size = rng:NextNumber(stage.tileSize[1], stage.tileSize[2])
		local gap = rng:NextNumber(stage.gap[1], stage.gap[2])
		if kind == "pillar" then
			size = math.min(size, 4)
		end

		-- Don't let the last stone crowd the end island.
		local remaining = poolEnd - z
		if remaining - gap - size < 1.5 then
			if kind == "raft" then
				kind = "normal"
			end
			size = remaining - gap - 1.5
			if size < 3 then
				size = 3
				gap = math.max(0.5, (remaining - size) / 2)
			end
		end

		local prevRaise = if prev then prev.raise else 0
		local raise = if kind == "pillar" then rng:NextNumber(0.5, 2.5) else 0
		local reach = Config.MaxJump - math.max(0, raise - prevRaise)
		gap = math.min(gap, reach)

		local limit = HALF_WIDTH - size / 2 - 1
		if kind == "raft" then
			limit -= Config.Raft.Range
		end
		local prevX = if prev then prev.x else 0
		local x = math.clamp(prevX + rng:NextNumber(-stage.shift, stage.shift), -limit, limit)
		local centerZ = z + gap + size / 2

		-- Pull it back in line if the jump from the last stone would be too long.
		if prev then
			local dz = centerZ - prev.z
			local maxDx = math.sqrt(math.max(0, (reach + (size + prev.size) / 2) ^ 2 - dz * dz))
			if math.abs(x - prevX) > maxDx then
				x = math.clamp(prevX + math.sign(x - prevX) * maxDx, -limit, limit)
			end
		end

		prev = { kind = kind, size = size, x = x, z = centerZ, raise = raise }
		table.insert(specs, prev)
		z += gap + size
	end

	return specs
end

-- Picks a tile in the middle of the path and puts a small side tile next to it
-- with a shell on top. Returns the side tile spec and the shell position, or nil.
local function placeShell(rng, specs)
	local candidates = {}
	for i = 2, #specs - 1 do
		if specs[i].kind ~= "raft" then
			table.insert(candidates, specs[i])
		end
	end
	if #candidates == 0 then
		return nil
	end

	local anchor = candidates[rng:NextInteger(1, #candidates)]
	local sideSize = 3
	local limit = HALF_WIDTH - sideSize / 2 - 1
	local offset = (anchor.size + sideSize) / 2 + 3
	local side = if anchor.x > 0 then -1 else 1
	local x = anchor.x + side * offset
	if math.abs(x) > limit then
		x = anchor.x - side * offset
		if math.abs(x) > limit then
			return nil
		end
	end

	local spec = { kind = "normal", size = sideSize, x = x, z = anchor.z, raise = anchor.raise }
	local shellPosition = Vector3.new(x, TILE_TOP + anchor.raise + 1.5, anchor.z)
	return spec, shellPosition
end

-- A swamp's rafts can sink or creak too (spec.hazard): Hazards.luau goes by
-- the TileKind attribute.
local function buildTile(folder, spec, stage, rng)
	local part = Forest.steppingStone(folder, spec, rng)
	local kind = spec.hazard or spec.kind
	if kind == "sinking" then
		part:SetAttribute("SinkDelay", stage.sinkDelay or Config.SinkingTile.DefaultDelay)
	elseif spec.kind == "raft" then
		local attachment = Instance.new("Attachment")
		attachment.Parent = part

		local alignPosition = Instance.new("AlignPosition")
		alignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
		alignPosition.Attachment0 = attachment
		alignPosition.Position = part.Position
		alignPosition.MaxForce = math.huge
		alignPosition.MaxVelocity = math.huge
		alignPosition.Responsiveness = 30
		alignPosition.Parent = part

		local alignOrientation = Instance.new("AlignOrientation")
		alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
		alignOrientation.Attachment0 = attachment
		alignOrientation.CFrame = CFrame.new()
		alignOrientation.RigidityEnabled = true
		alignOrientation.Parent = part

		part:SetAttribute("BaseX", spec.x)
		part:SetAttribute("Range", Config.Raft.Range)
		part:SetAttribute("Period", rng:NextNumber(Config.Raft.MinPeriod, Config.Raft.MaxPeriod))
		part:SetAttribute("Phase", rng:NextNumber(0, math.pi * 2))
	end
	part:SetAttribute("TileKind", kind)
	return part
end

-- True if a tree at (x, z) would stand on a platform or in the way of a
-- jump between two (links: pairs of platforms), with pad studs to spare.
local function inTheWay(platforms, links, x, z, pad)
	pad = pad or 0
	for _, spec in platforms do
		local dx, dz = x - spec.x, z - spec.z
		if math.sqrt(dx * dx + dz * dz) < spec.size / 2 + pad + (if spec.kind == "raft" then Config.Raft.Range + 3 else 3) then
			return true
		end
	end
	for _, pair in links do
		local a, b = pair[1], pair[2]
		if Swamp.distanceToSegment(x, z, a.x, a.z, b.x, b.z) < 3.5 + pad then
			return true
		end
	end
	return false
end

-- The jumps along a trail of stepping stones, for inTheWay.
local function trailLinks(specs)
	local links = {}
	for i = 1, #specs - 1 do
		table.insert(links, { specs[i], specs[i + 1] })
	end
	return links
end

-- Dead trees across the stretch z0..z1: thick out to roamHalf either side,
-- thinning out into the fog beyond, never on the islands (or clearings) or,
-- within nearHalf of the middle, in the way of a jump. open (if given)
-- makes it a pond instead: only that share of the trees within nearHalf,
-- and those well clear of the jumps. scale (1 if left out) makes the trees
-- taller.
local function plantTrees(folder, platforms, links, z0, z1, islands, rng, nearHalf, roamHalf, open, scale)
	local height = { FOREST.TreeHeight[1] * (scale or 1), FOREST.TreeHeight[2] * (scale or 1) }
	local function plant(x, z, far)
		for _, island in islands do
			if math.abs(x) < island.halfX + 4 and z > island.z0 - 4 and z < island.z1 + 4 then
				return
			end
		end
		if math.abs(x) < nearHalf + 4 and inTheWay(platforms, links, x, z, if open then 3 else 0) then
			return
		end
		Forest.deadTree(folder, x, z, rng:NextNumber(height[1], height[2]), rng, far)
	end
	local spacing = FOREST.TreeSpacing
	for z = z0 + spacing / 2, z1, spacing do
		for x = -roamHalf, roamHalf, spacing do
			local chance = if open and math.abs(x) < nearHalf then open else 0.7
			if rng:NextNumber() < chance then
				plant(x + rng:NextNumber(-spacing, spacing) * 0.45, z + rng:NextNumber(-spacing, spacing) * 0.45, false)
			end
		end
	end
	-- Far off, scattered rather than in rows (the water mirrors them).
	local farSpacing = spacing * 1.8
	for z = z0 + farSpacing / 2, z1, farSpacing do
		for _, side in { -1, 1 } do
			for x = roamHalf + farSpacing / 2, FOREST.SceneryHalfWidth, farSpacing do
				plant(side * (x + rng:NextNumber(-0.45, 0.45) * farSpacing), z + rng:NextNumber(-0.45, 0.45) * farSpacing, true)
			end
		end
	end
end

-- A few fallen logs and clumps of reeds in the water. Logs lie logBand[1]
-- to logBand[2] from the middle, out of the way of every jump and, in a
-- swamp, never a step across a far gap (guarded: its ends). Reeds go
-- anywhere out to wadeHalf that isn't in the way.
local function scatterDebris(folder, platforms, links, z0, z1, rng, logBand, wadeHalf, guarded)
	for _ = 1, math.floor((z1 - z0) / 25) do
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local x, z = side * rng:NextNumber(logBand[1], logBand[2]), rng:NextNumber(z0 + 8, z1 - 8)
		local angle = rng:NextNumber(0, math.pi)
		local half = Vector3.new(math.cos(angle), 0, math.sin(angle)) * rng:NextNumber(4, 7)
		local center = Vector3.new(x, SURFACE_Y, z)
		local clear = true
		for _, point in { center - half, center, center + half } do
			if inTheWay(platforms, links, point.X, point.Z) then
				clear = false
			end
			for _, spec in guarded or {} do
				if Vector2.new(point.X - spec.x, point.Z - spec.z).Magnitude < spec.size / 2 + Config.MaxJump + 2 then
					clear = false
				end
			end
		end
		if clear then
			Forest.fallenLog(folder, center - half, center + half, rng)
		end
	end
	for _ = 1, math.floor((z1 - z0) / 8) do
		local x, z = rng:NextNumber(-wadeHalf, wadeHalf), rng:NextNumber(z0, z1)
		if not inTheWay(platforms, links, x, z) then
			Forest.reeds(folder, x, z, rng)
		end
	end
end

-- Lanterns on posts beside the trail, every so often, swapping sides.
local function hangLanterns(folder, specs, z0, z1, lights, rng)
	local side = 1
	for z = z0 + FOREST.LanternSpacing / 2, z1, FOREST.LanternSpacing do
		local nearest
		for _, spec in specs do
			if not nearest or math.abs(spec.z - z) < math.abs(nearest.z - z) then
				nearest = spec
			end
		end
		if nearest and nearest.kind ~= "raft" then
			local x = nearest.x + side * (nearest.size / 2 + 2.5)
			table.insert(lights, Forest.lantern(folder, x, nearest.z, rng, Vector3.new(-side, 0, 0)))
			side = -side
		end
	end
end

-- What makes a swamp stage look like a swamp round its platforms: low muddy
-- islands out in the water, a shore of muddy banks wandering in and out
-- just past where you can wade (so it can't be walked along), mud round
-- the edges of the start and end islands, and cattails, lily pads and
-- algae, all clear of the platforms and out of reach of a far gap's ends
-- (guarded). Islands are more than a jump from every platform, so they're
-- never a way round; plants grow among the platforms, the tall ones clear
-- of the jumps between them (links).
local function dressSwamp(folder, platforms, links, guarded, poolStart, poolEnd, ends, wadeHalf, rng)
	local mounds = {}
	local function clearOf(x, z, radius, near, jumps)
		for _, spec in platforms do
			if Vector2.new(x - spec.x, z - spec.z).Magnitude < spec.size / 2 + radius + near then
				return false
			end
		end
		for _, spec in guarded do
			if Vector2.new(x - spec.x, z - spec.z).Magnitude < spec.size / 2 + radius + Config.MaxJump + 2 then
				return false
			end
		end
		for _, pair in if jumps then links else {} do
			if Swamp.distanceToSegment(x, z, pair[1].x, pair[1].z, pair[2].x, pair[2].z) < radius + 3 then
				return false
			end
		end
		for _, mound in mounds do
			if Vector2.new(x - mound.x, z - mound.z).Magnitude < radius + mound.radius + 3 then
				return false
			end
		end
		return true
	end

	-- Islands, some with a dead tree.
	local wanted = math.floor((poolEnd - poolStart) * wadeHalf / 900) + 2
	for _ = 1, wanted * 10 do
		if #mounds >= wanted then
			break
		end
		local radius = rng:NextNumber(3.5, 8)
		local x, z = rng:NextNumber(-wadeHalf + radius, wadeHalf - radius), rng:NextNumber(poolStart + radius, poolEnd - radius)
		if clearOf(x, z, radius, Config.MaxJump + 2, true) then
			Forest.mudIsland(x, z, radius, rng:NextNumber(0.4, 1.1), rng)
			table.insert(mounds, { x = x, z = z, radius = radius })
			if radius > 5 and rng:NextNumber() < 0.7 then
				Forest.deadTree(folder, x + rng:NextNumber(-1, 1), z + rng:NextNumber(-1, 1), rng:NextNumber(FOREST.TreeHeight[1], FOREST.TreeHeight[2]), rng, false)
			end
			if rng:NextNumber() < 0.6 then
				Forest.cattails(folder, x + radius * 0.8, z, rng)
			end
		end
	end

	-- The shore: banks whose inner edge wanders from just past the wading
	-- edge to a few studs further out.
	for z = poolStart - 10, poolEnd + 10, 8 do
		for _, side in { -1, 1 } do
			local radius = rng:NextNumber(6, 11)
			Forest.mudIsland(side * (wadeHalf + 0.5 + radius + rng:NextNumber(0, 6)), z, radius, rng:NextNumber(0.3, 1.2), rng)
		end
	end

	-- Mud lapping round the start and end islands' sides and the edges
	-- facing the water, so they don't end in straight lines.
	for _, island in ends do
		for z = island.z0 + 2, island.z1 - 2, 5 do
			for _, side in { -1, 1 } do
				local radius = rng:NextNumber(3, 4.5)
				Forest.mudIsland(side * (island.halfX + 0.5), z, radius, 0.9, rng)
			end
		end
		for x = -island.halfX + 2, island.halfX - 2, 5 do
			Forest.mudIsland(x, island.edge, 2, 0.9, rng)
		end
	end

	-- Plants and scum on the water, one of each about every so many square
	-- studs; the cattails, which stand tall, clear of the jumps.
	for _, plant in { { Forest.cattails, 500, true }, { Forest.lilyPads, 350 }, { Forest.algae, 500 } } do
		for _ = 1, math.floor((poolEnd - poolStart) * wadeHalf * 2 / plant[2]) do
			local x, z = rng:NextNumber(-wadeHalf, wadeHalf), rng:NextNumber(poolStart, poolEnd)
			if clearOf(x, z, 1, 1, plant[3]) then
				plant[1](folder, x, z, rng)
			end
		end
	end
end

-- Lanterns along a swamp's winding route, beside every so many platforms
-- (every), swapping sides, out of the way of the jumps, and on little
-- islands (some with a dead tree).
local function hangRouteLanterns(folder, route, platforms, links, lights, rng, every)
	-- A post in the water there wouldn't stand in a platform or a jump.
	local function clear(at)
		for _, spec in platforms do
			if Vector2.new(at.X - spec.x, at.Z - spec.z).Magnitude < spec.size / 2 + 1 then
				return false
			end
		end
		return not inTheWay({}, links, at.X, at.Z)
	end
	local onRoute = {}
	local side = 1
	for i = 2, #route - 1 do
		local spec = route[i]
		onRoute[spec] = true
		local ahead, behind = route[i + 1], route[i - 1]
		local across = Vector3.new(ahead.z - behind.z, 0, behind.x - ahead.x).Unit * side
		if spec.kind == "mound" then
			-- A little island to rest on gets its own, standing on it.
			local at = Vector3.new(spec.x, 0, spec.z) + across * spec.size * 0.3
			table.insert(lights, Forest.lantern(folder, at.X, at.Z, rng, -across))
		elseif (i - 2) % every == 0 then
			local at = Vector3.new(spec.x, 0, spec.z) + across * (spec.size / 2 + 2.5)
			if clear(at) then
				table.insert(lights, Forest.lantern(folder, at.X, at.Z, rng, -across))
			end
			side = -side
		end
	end
	-- Out among the rest, most little islands have one too, so the lights
	-- don't give the way away, and big ones a dead tree across from it.
	for _, spec in platforms do
		if not onRoute[spec] and spec.kind == "mound" then
			local angle = rng:NextNumber(0, math.pi * 2)
			local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local middle = Vector3.new(spec.x, 0, spec.z)
			if rng:NextNumber() < 0.7 then
				local at = middle + out * spec.size * 0.3
				table.insert(lights, Forest.lantern(folder, at.X, at.Z, rng, -out))
			end
			local at = middle - out * spec.size * 0.22
			if spec.size >= 8 and rng:NextNumber() < 0.6 and not inTheWay({}, links, at.X, at.Z) then
				Forest.deadTree(folder, at.X, at.Z, rng:NextNumber(FOREST.TreeHeight[1], FOREST.TreeHeight[2]), rng, false)
			end
		end
	end
end

local function buildRoom(map, index, stage, z0)
	local folder = Instance.new("Folder")
	folder.Name = string.format("Stage%02d", index)
	folder.Parent = map

	local z1 = z0 + stage.length
	local poolStart = z0 + (stage.startLanding or ROOM.StartLanding)
	local poolEnd = z1 - ROOM.EndLanding
	local lights = {}
	local rng = Random.new(index * 7919)
	local scenery = Random.new(index * 3571) -- its own seed, so trees don't change the trail

	-- Stage 1 starts behind the lobby's building, in a cave that opens onto
	-- an island as wide as the passage.
	local cave
	if index == 1 then
		buildDoorWall(folder, z0, ROOM.EntranceDoors)
		cave = CaveBuilder.build(folder, z0)
	end
	local landingStart = if cave then cave.zEnd else z0
	local startHalf = if index == 1 then HALF_WIDTH else FOREST.IslandHalfWidth
	local islands = {
		{ halfX = startHalf, z0 = landingStart, z1 = poolStart },
		{ halfX = FOREST.IslandHalfWidth, z0 = poolEnd, z1 = z1 },
	}
	if cave then
		table.insert(islands, { halfX = cave.halfWidth, z0 = z0, z1 = cave.zEnd }) -- no trees through its rock
	end
	Forest.island(folder, "StartLanding", landingStart, poolStart, startHalf, scenery)
	Forest.island(folder, "EndLanding", poolEnd, z1, FOREST.IslandHalfWidth, scenery)
	Forest.signpost(folder, startHalf - 4, poolStart - 2.5, Vector3.new(0, 0, -1), "STAGE " .. index, stage.name)

	-- A trail of stepping stones, or an open swamp of platforms.
	local swamp = stage.layout == "swamp"
	local nearHalf = if swamp then stage.halfWidth else HALF_WIDTH -- where the platforms are
	local wadeHalf = if swamp then stage.halfWidth + 8 else FOREST.HalfWidth
	local roamHalf = math.max(FOREST.CreatureHalfWidth, wadeHalf + 16)
	local specs, trail, links, hooks, guarded, shellPosition
	if swamp then
		local layout = Swamp.layout(index * 7919, stage, {
			poolStart = poolStart,
			poolEnd = poolEnd,
			startHalf = startHalf,
			endHalf = FOREST.IslandHalfWidth,
			raise = (stage.platformHeight or ROOM.TileHeight) - ROOM.TileHeight,
		})
		specs, trail, links, hooks, guarded = layout.platforms, layout.route, layout.links, layout.hooks, layout.guarded
		if layout.shell then
			shellPosition = Vector3.new(layout.shell.x, TILE_TOP + layout.shell.raise + 1.5, layout.shell.z)
		end
	else
		specs = generateTiles(rng, stage, poolStart, poolEnd)
		local shellSpec
		shellSpec, shellPosition = placeShell(rng, specs)
		trail = table.clone(specs)
		if shellSpec then
			table.insert(specs, shellSpec)
		end
		links = trailLinks(specs)
		hooks = {}
	end

	local tileFolder = Instance.new("Folder")
	tileFolder.Name = "Tiles"
	tileFolder.Parent = folder
	local tiles, parts = {}, {}
	for _, spec in specs do
		local part = buildTile(tileFolder, spec, stage, rng)
		parts[spec] = part
		table.insert(tiles, part)
	end
	if swamp then
		-- Each route platform knows its place along the route; neighbouring
		-- rafts are roped together, unless a far gap or a sinking raft is in it.
		local rafts = { deck = true, logRaft = true }
		for step, spec in trail do
			parts[spec]:SetAttribute("RouteStep", step)
			local nextOne = trail[step + 1]
			if nextOne and rafts[spec.kind] and rafts[nextOne.kind] and not nextOne.hooked and spec.hazard ~= "sinking" and nextOne.hazard ~= "sinking" then
				Forest.rope(tileFolder, spec, nextOne)
			end
		end
	end

	local shell
	if shellPosition then
		shell = block(folder, "Shell", Vector3.new(1.2, 1.2, 1.2), CFrame.new(shellPosition), COLORS.shell, Enum.Material.Neon, {
			Shape = Enum.PartType.Ball,
			CanCollide = false,
			CanQuery = false,
		})
		shell:SetAttribute("ShellStage", index)
		local glow = Instance.new("PointLight")
		glow.Color = COLORS.shell
		glow.Range = 6
		glow.Brightness = 1
		glow.Parent = shell
	end

	-- The checkpoint: a glowing pad, or at the end of a swamp stage the
	-- STAGE COMPLETE doorway, over an unseen pad right across the island.
	local padZ = z1 - ROOM.EndLanding / 2
	local padWidth = if swamp then FOREST.IslandHalfWidth * 2 else 8
	local checkpointPad = block(folder, "Checkpoint", Vector3.new(padWidth, 0.2, 4), CFrame.new(0, TILE_TOP + 0.1, padZ), COLORS.checkpoint, Enum.Material.Neon, {
		CanCollide = false,
		CanQuery = false,
		Transparency = if swamp then 1 else 0.35,
	})
	checkpointPad:SetAttribute("Checkpoint", index)
	if swamp then
		Forest.stageDoor(folder, padZ, scenery, if index == #Stages then FINAL_DOOR_SCALE else nil)
	end

	for _, hook in hooks do
		Forest.grappleHook(folder, hook.from, hook.to, scenery, hook.side, hook.free)
	end

	if swamp then
		hangRouteLanterns(folder, trail, specs, links, lights, scenery, stage.lanterns or 4)
		dressSwamp(folder, specs, links, guarded, poolStart, poolEnd, {
			{ halfX = startHalf, z0 = landingStart, z1 = poolStart, edge = poolStart },
			{ halfX = FOREST.IslandHalfWidth, z0 = poolEnd, z1 = z1, edge = poolEnd },
		}, wadeHalf, scenery)
	else
		hangLanterns(folder, trail, poolStart, poolEnd, lights, scenery)
	end
	if swamp then
		-- A clearing at the start, so the first platforms are in plain sight.
		table.insert(islands, { halfX = 12, z0 = poolStart, z1 = poolStart + 14 })
	end
	plantTrees(folder, specs, links, z0, z1, islands, scenery, nearHalf, roamHalf, if swamp then stage.trees or 0.35 else nil, stage.treeScale)
	local logBand = if swamp then { 0, wadeHalf - 4 } else { HALF_WIDTH + 6, FOREST.HalfWidth - 4 }
	scatterDebris(folder, specs, links, poolStart, poolEnd, scenery, logBand, wadeHalf, guarded)

	-- Players can wade out so far and no further. A swamp wider or narrower
	-- than the stages either side is closed off at its ends too.
	for _, side in { -1, 1 } do
		local x = side * wadeHalf
		box(folder, "Edge", Vector3.new(math.min(x, x + side), BASE_Y, z0), Vector3.new(math.max(x, x + side), SURFACE_Y + 40, z1), COLORS.floor, nil, BARRIER)
		if wadeHalf ~= FOREST.HalfWidth then
			local inner = side * math.min(wadeHalf, FOREST.HalfWidth)
			local outer = side * (math.max(wadeHalf, FOREST.HalfWidth) + 1)
			for _, z in { z0, z1 - 1 } do
				box(folder, "Edge", Vector3.new(math.min(inner, outer), BASE_Y, z), Vector3.new(math.max(inner, outer), SURFACE_Y + 40, z + 1), COLORS.floor, nil, BARRIER)
			end
		end
	end

	local standAt = Vector3.new(0, TILE_TOP + 3, padZ)
	return {
		index = index,
		stage = stage,
		folder = folder,
		zStart = z0,
		zEnd = z1,
		poolStart = poolStart,
		poolEnd = poolEnd,
		surfaceY = SURFACE_Y,
		floorY = FLOOR_Y,
		halfWidth = wadeHalf, -- how far players can wade
		roamHalfWidth = roamHalf, -- how far the creature can go
		tiles = tiles,
		lights = lights,
		shell = shell,
		checkpointPad = checkpointPad,
		checkpointCFrame = CFrame.lookAt(standAt, standAt + Vector3.zAxis),
		cave = cave,
	}
end

-- The way out: an island past the last stage with an old stone gateway, and
-- light through it.
local function buildExit(map, z0, z1)
	local folder = Instance.new("Folder")
	folder.Name = "Exit"
	folder.Parent = map
	local rng = Random.new(4421)
	Forest.island(folder, "Floor", z0, z1, FOREST.IslandHalfWidth, rng)

	local half = ROOM.DoorWidth / 2
	local doorTop = TILE_TOP + ROOM.DoorHeight
	local back = z1 - 2
	for _, side in { -1, 1 } do
		box(folder, "GatePillar", Vector3.new(math.min(side * half, side * (half + 2.5)), TILE_TOP, back - 1.5), Vector3.new(math.max(side * half, side * (half + 2.5)), doorTop + 1, back + 1.5), COLORS.stone, Enum.Material.Slate)
	end
	local lintel = box(folder, "GateLintel", Vector3.new(-half - 3, doorTop + 1, back - 1.7), Vector3.new(half + 3, doorTop + 4, back + 1.7), COLORS.stone, Enum.Material.Slate)
	addSign(lintel, Enum.NormalId.Front, "THE WAY OUT", "Walk into the light")
	local door = block(folder, "ExitDoor", Vector3.new(ROOM.DoorWidth, ROOM.DoorHeight, 0.5), CFrame.new(0, TILE_TOP + ROOM.DoorHeight / 2, back), COLORS.exit, Enum.Material.Neon)
	local glow = Instance.new("PointLight")
	glow.Color = COLORS.exit
	glow.Range = 30
	glow.Brightness = 1.4
	glow.Parent = door
	-- Nobody wanders off past it.
	box(folder, "Edge", Vector3.new(-FOREST.HalfWidth, BASE_Y, z1 + 4), Vector3.new(FOREST.HalfWidth, SURFACE_Y + 40, z1 + 5), COLORS.floor, nil, BARRIER)

	plantTrees(folder, {}, {}, z1 + 6, z1 + 80, {}, rng, HALF_WIDTH, FOREST.CreatureHalfWidth)
	return door
end

local LAKE_REACH = FOREST.SceneryHalfWidth + 20 -- how far the water goes either side

-- The water under the whole forest: Roblox's own terrain water, nearly
-- black, rippling just enough that the moonlight glints across it and the
-- platforms mirror in it, so what wades in it is mostly legs and a pair of
-- eyes. Two terrain cells deep (a single cell shows seams);
-- the bottom you stand on is a part (buildLake). Filled before the stages,
-- so their muddy islands (Forest.mudIsland) can rise out of it.
local function fillWater(zEnd)
	local terrain = workspace.Terrain
	local bottom = FLOOR_Y - 4
	terrain:FillBlock(
		CFrame.new(0, (bottom + SURFACE_Y) / 2, zEnd / 2),
		Vector3.new(LAKE_REACH * 2, SURFACE_Y - bottom, zEnd),
		Enum.Material.Water
	)
	terrain.WaterColor = COLORS.water
	terrain.WaterTransparency = 0.05
	terrain.WaterReflectance = 1
	terrain.WaterWaveSize = 0.2
	terrain.WaterWaveSpeed = 6
	terrain:SetMaterialColor(Enum.Material.Mud, COLORS.bank)
	terrain:SetMaterialColor(Enum.Material.LeafyGrass, COLORS.bankGrass)
end

-- The bottom of the water: waist-deep where you stand if you fall in
-- (Config.Room.WadeDepth), with the creature's feet further down. An
-- invisible part at the surface, named Water, is what pebbles land on
-- (Pebbles.luau). It mustn't be Glass: Roblox doesn't draw terrain water
-- behind glass, so the water's surface came and went in patches.
local function buildLake(map, zEnd)
	local folder = Instance.new("Folder")
	folder.Name = "Lake"
	folder.Parent = map
	local reach = LAKE_REACH
	box(folder, "LakeFloor", Vector3.new(-reach, BASE_Y, 0), Vector3.new(reach, SURFACE_Y - ROOM.WadeDepth, zEnd), COLORS.floor, Enum.Material.Mud)
	box(folder, "Water", Vector3.new(-reach, FLOOR_Y, 0), Vector3.new(reach, SURFACE_Y, zEnd), COLORS.water, Enum.Material.SmoothPlastic, {
		Transparency = 1,
		CanCollide = false,
		CanTouch = false,
		CastShadow = false,
	})
end

local function setupLighting()
	for _, child in Lighting:GetChildren() do
		-- Template atmospheres and post effects are replaced by ours below.
		if child:IsA("Atmosphere") or child:IsA("PostEffect") then
			child:Destroy()
		end
	end
	-- Midnight in the swamp: a big moon low over the trees ahead (the
	-- latitude swings it round to the far end of the stages), blue-grey
	-- light you can still see the platforms by, and a fog the trees round
	-- you show through and everything further off is lost in, so whatever
	-- is out there is only a shape when it is already close. client/Mood.luau
	-- adds mist drifting over the water round you, and lighter, warmer
	-- light in the courtyard.
	Lighting.ClockTime = 0
	Lighting.GeographicLatitude = 78
	Lighting.Brightness = 2.5
	Lighting.Ambient = Color3.fromRGB(58, 66, 86)
	Lighting.OutdoorAmbient = Color3.fromRGB(92, 106, 132)
	Lighting.EnvironmentDiffuseScale = 0.35
	Lighting.EnvironmentSpecularScale = 0.9 -- the water and wet wood catch the moon
	Lighting.ExposureCompensation = 0.3
	Lighting.GlobalShadows = true

	local sky = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky")
	sky.MoonAngularSize = 18
	sky.StarCount = 2500
	sky.Parent = Lighting

	-- The fog: thin enough that the platforms and trees round you are clear,
	-- while further off fades to blue and a bank of thick fog round you hides
	-- the rest (client/Mood.luau); the doorway at the end stays dark until
	-- you're near. Named so Mood can thin it in the lobby and cave.
	local fog = Instance.new("Atmosphere")
	fog.Name = "Fog"
	fog.Density = 0.5
	fog.Offset = 0.05
	fog.Color = Color3.fromRGB(116, 136, 164)
	fog.Decay = Color3.fromRGB(70, 88, 112)
	fog.Glare = 0
	fog.Haze = 1.2
	fog.Parent = Lighting

	-- Cold, a little washed out, and a soft glow around anything neon. Named
	-- so client/Mood.luau can warm it up in the lobby.
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "Grade"
	grade.Saturation = -0.2
	grade.Contrast = 0.12
	grade.TintColor = Color3.fromRGB(206, 220, 240)
	grade.Parent = Lighting

	-- Named so client/Mood.luau can soften it in the lobby.
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "Glow"
	bloom.Intensity = 0.7
	bloom.Size = 28
	bloom.Threshold = 1.4
	bloom.Parent = Lighting
end

-- The Baseplate template ships with its own SpawnLocation, which would let
-- players spawn outside the map.
local function removeTemplateSpawns()
	for _, child in workspace:GetChildren() do
		if child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end
end

function MapBuilder.build()
	setupLighting()
	removeTemplateSpawns()

	local map = Instance.new("Folder")
	map.Name = "Map"

	local lobby = LobbyBuilder.build(map)

	local stagesEnd = 0
	for _, stage in Stages do
		stagesEnd += stage.length
	end
	local lakeEnd = stagesEnd + ROOM.ExitLength + 90
	fillWater(lakeEnd)

	-- Stages
	local layout = {
		rooms = {},
		boards = lobby.boards,
		partyDoors = lobby.partyDoors,
		snowPiles = lobby.snowPiles, -- the Christmas lobby's (Snowballs.luau)
	}
	local z = 0
	for index, stage in Stages do
		local room = buildRoom(map, index, stage, z)
		layout.rooms[index] = room
		z = room.zEnd
	end
	-- Where parties arrive, and the run timer's start across its mouth.
	layout.cave = layout.rooms[1].cave
	layout.runStart = layout.cave.runStart

	local exitEnd = z + ROOM.ExitLength
	layout.exitDoor = buildExit(map, z, exitEnd)
	buildLake(map, lakeEnd)

	map.Parent = workspace

	function layout.roomAt(position)
		for _, room in layout.rooms do
			if position.Z >= room.zStart and position.Z < room.zEnd then
				return room
			end
		end
		return nil
	end

	-- Anywhere in a stage's stretch of water (standing on a stone or an
	-- island keeps you above it; Noise.luau checks the height).
	function layout.inPool(room, position)
		return math.abs(position.X) < room.halfWidth and position.Z > room.zStart and position.Z < room.zEnd
	end

	return layout
end

return MapBuilder
