-- Builds the whole map from Config and Stages when the server starts: the
-- lobby (LobbyBuilder.luau), then behind its building a drowned forest at
-- night: black still water, dead trees and fog, with one stretch per stage
-- along +Z and the way out at the end. Each stretch runs from an island,
-- across a trail of stepping stones, to an island with its checkpoint.
-- Stage 1 starts in the cave behind the building (CaveBuilder.luau).
-- Returns a layout table the other server modules use to find stages.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Stages = require(ReplicatedStorage.Shared.Stages)
local CaveBuilder = require(script.Parent.CaveBuilder)
local Forest = require(script.Parent.Forest)
local LobbyBuilder = require(script.Parent.LobbyBuilder)
local Parts = require(script.Parent.Parts)

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
	water = Color3.fromRGB(14, 20, 26),
	checkpoint = Color3.fromRGB(70, 150, 112),
	shell = Color3.fromRGB(255, 186, 200),
	stone = Color3.fromRGB(96, 98, 104),
	exit = Color3.fromRGB(255, 238, 196),
	text = Color3.fromRGB(232, 224, 204),
}
local BARRIER = { Transparency = 1, CanQuery = false, CastShadow = false }

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

local function buildTile(folder, spec, stage, rng)
	local part = Forest.steppingStone(folder, spec, rng)
	if spec.kind == "sinking" then
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
	part:SetAttribute("TileKind", spec.kind)
	return part
end

-- Distance from point p to the segment a-b, on the ground plane.
local function distanceToSegment(px, pz, ax, az, bx, bz)
	local dx, dz = bx - ax, bz - az
	local lengthSquared = dx * dx + dz * dz
	local t = if lengthSquared > 0 then math.clamp(((px - ax) * dx + (pz - az) * dz) / lengthSquared, 0, 1) else 0
	local cx, cz = ax + dx * t - px, az + dz * t - pz
	return math.sqrt(cx * cx + cz * cz)
end

-- True if a tree at (x, z) would stand on or between the stepping stones.
local function inTheWay(specs, x, z)
	for i, spec in specs do
		local dx, dz = x - spec.x, z - spec.z
		if math.sqrt(dx * dx + dz * dz) < spec.size / 2 + (if spec.kind == "raft" then Config.Raft.Range + 3 else 3) then
			return true
		end
		local nextSpec = specs[i + 1]
		if nextSpec and distanceToSegment(x, z, spec.x, spec.z, nextSpec.x, nextSpec.z) < 3.5 then
			return true
		end
	end
	return false
end

-- Dead trees across the stretch z0..z1: thick near the trail, thinning out
-- into the fog, never on the islands or in the way of a jump.
local function plantTrees(folder, specs, z0, z1, islands, rng)
	local height = FOREST.TreeHeight
	local function plant(x, z, far)
		for _, island in islands do
			if math.abs(x) < island.halfX + 4 and z > island.z0 - 4 and z < island.z1 + 4 then
				return
			end
		end
		if math.abs(x) < HALF_WIDTH + 4 and inTheWay(specs, x, z) then
			return
		end
		Forest.deadTree(folder, x, z, rng:NextNumber(height[1], height[2]), rng, far)
	end
	local spacing = FOREST.TreeSpacing
	for z = z0 + spacing / 2, z1, spacing do
		for x = -FOREST.CreatureHalfWidth, FOREST.CreatureHalfWidth, spacing do
			if rng:NextNumber() < 0.7 then
				plant(x + rng:NextNumber(-spacing, spacing) * 0.45, z + rng:NextNumber(-spacing, spacing) * 0.45, false)
			end
		end
	end
	local farSpacing = spacing * 1.8
	for z = z0 + farSpacing / 2, z1, farSpacing do
		for _, side in { -1, 1 } do
			for x = FOREST.CreatureHalfWidth + farSpacing / 2, FOREST.SceneryHalfWidth, farSpacing do
				plant(side * (x + rng:NextNumber(-4, 4)), z + rng:NextNumber(-5, 5), true)
			end
		end
	end
end

-- A few fallen logs and clumps of reeds off to the sides of the trail.
local function scatterDebris(folder, specs, z0, z1, rng)
	for _ = 1, math.floor((z1 - z0) / 25) do
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local x, z = side * rng:NextNumber(HALF_WIDTH + 6, FOREST.HalfWidth - 4), rng:NextNumber(z0 + 8, z1 - 8)
		local angle = rng:NextNumber(0, math.pi)
		local half = Vector3.new(math.cos(angle), 0, math.sin(angle)) * rng:NextNumber(4, 7)
		local center = Vector3.new(x, SURFACE_Y, z)
		Forest.fallenLog(folder, center - half, center + half, rng)
	end
	for _ = 1, math.floor((z1 - z0) / 8) do
		local x, z = rng:NextNumber(-FOREST.HalfWidth, FOREST.HalfWidth), rng:NextNumber(z0, z1)
		if not inTheWay(specs, x, z) then
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

	local specs = generateTiles(rng, stage, poolStart, poolEnd)
	local shellSpec, shellPosition = placeShell(rng, specs)
	local trail = table.clone(specs)
	if shellSpec then
		table.insert(specs, shellSpec)
	end

	local tileFolder = Instance.new("Folder")
	tileFolder.Name = "Tiles"
	tileFolder.Parent = folder
	local tiles = {}
	for _, spec in specs do
		table.insert(tiles, buildTile(tileFolder, spec, stage, rng))
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

	local padZ = z1 - ROOM.EndLanding / 2
	local checkpointPad = block(folder, "Checkpoint", Vector3.new(8, 0.2, 4), CFrame.new(0, TILE_TOP + 0.1, padZ), COLORS.checkpoint, Enum.Material.Neon, {
		CanCollide = false,
		CanQuery = false,
		Transparency = 0.35,
	})
	checkpointPad:SetAttribute("Checkpoint", index)

	hangLanterns(folder, trail, poolStart, poolEnd, lights, scenery)
	plantTrees(folder, specs, z0, z1, islands, scenery)
	scatterDebris(folder, specs, poolStart, poolEnd, scenery)

	-- Players can wade out so far and no further.
	for _, side in { -1, 1 } do
		local x = side * FOREST.HalfWidth
		box(folder, "Edge", Vector3.new(math.min(x, x + side), BASE_Y, z0), Vector3.new(math.max(x, x + side), SURFACE_Y + 40, z1), COLORS.floor, nil, BARRIER)
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
		halfWidth = FOREST.HalfWidth, -- how far players can wade
		roamHalfWidth = FOREST.CreatureHalfWidth, -- how far the creature can go
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

	plantTrees(folder, {}, z1 + 6, z1 + 80, {}, rng)
	return door
end

-- The black water and the mud under it, under the whole forest.
local function buildLake(map, zEnd)
	local folder = Instance.new("Folder")
	folder.Name = "Lake"
	folder.Parent = map
	local reach = FOREST.SceneryHalfWidth + 20
	box(folder, "LakeFloor", Vector3.new(-reach, BASE_Y, 0), Vector3.new(reach, FLOOR_Y, zEnd), COLORS.floor, Enum.Material.Mud)
	box(folder, "Water", Vector3.new(-reach, FLOOR_Y, 0), Vector3.new(reach, SURFACE_Y, zEnd), COLORS.water, Enum.Material.Glass, {
		-- Black and still: what wades in it is mostly legs and a pair of eyes.
		Transparency = 0.06,
		Reflectance = 0.2,
		CanCollide = false,
		CanTouch = false,
		CastShadow = false,
	})
end

local function setupLighting()
	for _, child in Lighting:GetChildren() do
		-- An Atmosphere overrides fog (and at night only fades things to
		-- black), and the fog is most of the mood. Template post effects are
		-- replaced by ours below.
		if child:IsA("Atmosphere") or child:IsA("PostEffect") then
			child:Destroy()
		end
	end
	-- A cold moonlit night in thick blue-grey fog: you see the trees round
	-- you and the lanterns' glow, and everything further off is gone, so
	-- whatever is out there is only a shape when it is already close.
	-- client/Mood.luau adds mist drifting over the water round you.
	Lighting.ClockTime = 0
	Lighting.Brightness = 1.6
	Lighting.Ambient = Color3.fromRGB(46, 54, 70)
	Lighting.OutdoorAmbient = Color3.fromRGB(84, 98, 126)
	Lighting.EnvironmentDiffuseScale = 0.3
	Lighting.EnvironmentSpecularScale = 0.7 -- the water and wet wood catch the moon
	Lighting.FogColor = Color3.fromRGB(34, 42, 56)
	Lighting.FogStart = 5
	Lighting.FogEnd = 70
	Lighting.GlobalShadows = true

	-- Cold, washed-out colours, and a soft glow around anything neon.
	-- Named so client/Mood.luau can warm it up in the lobby.
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "Grade"
	grade.Saturation = -0.25
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

	-- Stages
	local layout = {
		rooms = {},
		boards = lobby.boards,
		partyDoors = lobby.partyDoors,
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
	buildLake(map, exitEnd + 90)

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
