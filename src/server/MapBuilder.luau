-- Builds the whole map from Config and Stages when the server starts:
-- a lobby (LobbyBuilder.luau), one flooded room per stage, and an exit room,
-- in a line along +Z. Returns a layout table the other server modules use to
-- find rooms.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Stages = require(ReplicatedStorage.Shared.Stages)
local LobbyBuilder = require(script.Parent.LobbyBuilder)
local Parts = require(script.Parent.Parts)

local block, box = Parts.block, Parts.box

local ROOM = Config.Room
local HALF_WIDTH = ROOM.Width / 2
local SURFACE_Y = ROOM.SurfaceY
local FLOOR_Y = SURFACE_Y - ROOM.PoolDepth -- top of the pool floor
local TILE_TOP = SURFACE_Y + ROOM.TileHeight -- top of landings and ordinary tiles
local BASE_Y = FLOOR_Y - 1 -- underside of everything
local WALL = 2

local COLORS = {
	wall = Color3.fromRGB(196, 206, 202),
	floor = Color3.fromRGB(164, 184, 184),
	tile = Color3.fromRGB(214, 222, 220),
	creaky = Color3.fromRGB(222, 210, 170),
	sinking = Color3.fromRGB(170, 198, 222),
	raft = Color3.fromRGB(226, 170, 96),
	water = Color3.fromRGB(26, 70, 80),
	light = Color3.fromRGB(236, 238, 214),
	deadLight = Color3.fromRGB(84, 88, 86),
	checkpoint = Color3.fromRGB(120, 230, 170),
	shell = Color3.fromRGB(255, 186, 200),
	exit = Color3.fromRGB(255, 238, 196),
	text = Color3.fromRGB(40, 70, 80),
}

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

-- Side walls, ceiling and ceiling lights for the stretch z0..z1. With an rng,
-- some of the panels have died: they stay dark and are left out of lights.
local function buildShell(folder, z0, z1, lights, rng)
	local wallMaterial = Enum.Material.CeramicTiles
	box(folder, "LeftWall", Vector3.new(-HALF_WIDTH - WALL, BASE_Y, z0), Vector3.new(-HALF_WIDTH, SURFACE_Y + ROOM.Height, z1), COLORS.wall, wallMaterial)
	box(folder, "RightWall", Vector3.new(HALF_WIDTH, BASE_Y, z0), Vector3.new(HALF_WIDTH + WALL, SURFACE_Y + ROOM.Height, z1), COLORS.wall, wallMaterial)
	box(
		folder,
		"Ceiling",
		Vector3.new(-HALF_WIDTH - WALL, SURFACE_Y + ROOM.Height, z0),
		Vector3.new(HALF_WIDTH + WALL, SURFACE_Y + ROOM.Height + 1, z1),
		COLORS.wall,
		wallMaterial
	)

	local count = math.max(1, math.floor((z1 - z0) / ROOM.LightSpacing))
	for i = 1, count do
		local z = z0 + (i - 0.5) * (z1 - z0) / count
		local dead = rng ~= nil and rng:NextNumber() < 0.22
		local panel = block(
			folder,
			if dead then "DeadPanel" else "LightPanel",
			Vector3.new(6, 0.3, 2),
			CFrame.new(0, SURFACE_Y + ROOM.Height - 0.15, z),
			if dead then COLORS.deadLight else COLORS.light,
			if dead then Enum.Material.SmoothPlastic else Enum.Material.Neon,
			{ CanCollide = false, CanQuery = false, CastShadow = false }
		)
		if not dead then
			local light = Instance.new("PointLight")
			light.Range = 24
			light.Brightness = 1.1
			light.Color = COLORS.light
			light.Shadows = true
			light.Parent = panel
			table.insert(lights, panel)
		end
	end
end

-- The wall across the corridor at z, with a doorway centred on each x in
-- doorXs, or solid without them. Returns the piece above the door nearest the
-- middle (or the whole wall) for signs.
local function buildCrossWall(folder, z, doorXs)
	local min, max = z - 0.5, z + 0.5
	local top = SURFACE_Y + ROOM.Height
	if not doorXs then
		return box(folder, "EndWall", Vector3.new(-HALF_WIDTH, TILE_TOP, min), Vector3.new(HALF_WIDTH, top, max), COLORS.wall, Enum.Material.CeramicTiles)
	end
	local half = ROOM.DoorWidth / 2
	local xs = table.clone(doorXs)
	table.sort(xs)
	local left = -HALF_WIDTH
	local middle, middleX
	for _, x in xs do
		box(folder, "DoorWall", Vector3.new(left, TILE_TOP, min), Vector3.new(x - half, top, max), COLORS.wall, Enum.Material.CeramicTiles)
		local lintel = box(folder, "Lintel", Vector3.new(x - half, TILE_TOP + ROOM.DoorHeight, min), Vector3.new(x + half, top, max), COLORS.wall, Enum.Material.CeramicTiles)
		if not middle or math.abs(x) < math.abs(middleX) then
			middle, middleX = lintel, x
		end
		left = x + half
	end
	box(folder, "DoorWall", Vector3.new(left, TILE_TOP, min), Vector3.new(HALF_WIDTH, top, max), COLORS.wall, Enum.Material.CeramicTiles)
	return middle
end

local function landing(folder, name, z0, z1)
	return box(folder, name, Vector3.new(-HALF_WIDTH, BASE_Y, z0), Vector3.new(HALF_WIDTH, TILE_TOP, z1), COLORS.floor, Enum.Material.CeramicTiles)
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

-- Lays a path of tiles across the pool. Every jump stays within Config.MaxJump.
local function generateTiles(rng, stage, poolStart, poolEnd)
	local specs = {}
	local z = poolStart
	local prevX, prevSize, prevRaise = 0, ROOM.Width, 0

	while poolEnd - z > stage.gap[2] do
		local kind = pickKind(rng, stage.mix)
		local size = rng:NextNumber(stage.tileSize[1], stage.tileSize[2])
		local gap = rng:NextNumber(stage.gap[1], stage.gap[2])
		if kind == "pillar" then
			size = math.min(size, 4)
		end

		-- Don't let the last tile crowd the end landing.
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

		local raise = if kind == "pillar" then rng:NextNumber(0.5, 2.5) else 0
		local reach = Config.MaxJump - math.max(0, raise - prevRaise)
		gap = math.min(gap, reach)

		local limit = HALF_WIDTH - size / 2 - 1
		if kind == "raft" then
			limit -= Config.Raft.Range
		end
		local x = math.clamp(prevX + rng:NextNumber(-stage.shift, stage.shift), -limit, limit)

		-- Pull the tile back in line if the diagonal jump would be too long.
		local sideways = math.sqrt(math.max(0, reach * reach - gap * gap))
		local edgeGap = math.abs(x - prevX) - (size + prevSize) / 2
		if edgeGap > sideways then
			x = prevX + math.sign(x - prevX) * ((size + prevSize) / 2 + sideways)
			x = math.clamp(x, -limit, limit)
		end

		table.insert(specs, { kind = kind, size = size, x = x, z = z + gap + size / 2, raise = raise })
		z += gap + size
		prevX, prevSize, prevRaise = x, size, raise
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
	local top = TILE_TOP + spec.raise
	local half = spec.size / 2
	local part

	if spec.kind == "sinking" then
		part = block(folder, "SinkingTile", Vector3.new(spec.size, 1, spec.size), CFrame.new(spec.x, top - 0.5, spec.z), COLORS.sinking, Enum.Material.CeramicTiles)
		part:SetAttribute("SinkDelay", stage.sinkDelay or Config.SinkingTile.DefaultDelay)
	elseif spec.kind == "raft" then
		part = block(folder, "Raft", Vector3.new(spec.size, 1, spec.size), CFrame.new(spec.x, top - 0.5, spec.z), COLORS.raft, Enum.Material.Plastic, {
			Anchored = false,
			CustomPhysicalProperties = PhysicalProperties.new(2, 1, 0, 1, 1),
		})
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
	else
		local color = if spec.kind == "creaky" then COLORS.creaky else COLORS.tile
		local name = if spec.kind == "creaky" then "CreakyTile" elseif spec.kind == "pillar" then "Pillar" else "Tile"
		part = box(
			folder,
			name,
			Vector3.new(spec.x - half, FLOOR_Y, spec.z - half),
			Vector3.new(spec.x + half, top, spec.z + half),
			color,
			Enum.Material.CeramicTiles
		)
	end

	part:SetAttribute("TileKind", spec.kind)
	return part
end

local function buildRoom(map, index, stage, z0)
	local folder = Instance.new("Folder")
	folder.Name = string.format("Stage%02d", index)
	folder.Parent = map

	local z1 = z0 + stage.length
	local poolStart = z0 + ROOM.StartLanding
	local poolEnd = z1 - ROOM.EndLanding
	local lights = {}

	-- Its own seed, so dead lights don't change the tile layout.
	buildShell(folder, z0, z1, lights, Random.new(index * 3571))
	-- Stage 1 opens onto the lobby through one doorway per difficulty.
	local doorXs = { 0 }
	if index == 1 then
		doorXs = {}
		for _, x in ROOM.EntranceDoors do
			table.insert(doorXs, x)
		end
	end
	local lintel = buildCrossWall(folder, z0, doorXs)
	addSign(lintel, Enum.NormalId.Back, "STAGE " .. index, stage.name)

	landing(folder, "StartLanding", z0, poolStart)
	landing(folder, "EndLanding", poolEnd, z1)
	box(folder, "PoolFloor", Vector3.new(-HALF_WIDTH, BASE_Y, poolStart), Vector3.new(HALF_WIDTH, FLOOR_Y, poolEnd), COLORS.floor, Enum.Material.CeramicTiles)
	box(folder, "Water", Vector3.new(-HALF_WIDTH, FLOOR_Y, poolStart), Vector3.new(HALF_WIDTH, SURFACE_Y, poolEnd), COLORS.water, Enum.Material.Glass, {
		-- Murky enough that what lives in it is mostly a shape and a pair of eyes.
		Transparency = 0.22,
		Reflectance = 0.08,
		CanCollide = false,
		CanTouch = false,
		CastShadow = false,
	})

	local rng = Random.new(index * 7919)
	local specs = generateTiles(rng, stage, poolStart, poolEnd)
	local shellSpec, shellPosition = placeShell(rng, specs)
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
	})
	checkpointPad:SetAttribute("Checkpoint", index)

	local standAt = Vector3.new(0, TILE_TOP + 3, padZ)
	return {
		index = index,
		stage = stage,
		folder = folder,
		lintel = lintel,
		zStart = z0,
		zEnd = z1,
		poolStart = poolStart,
		poolEnd = poolEnd,
		surfaceY = SURFACE_Y,
		halfWidth = HALF_WIDTH,
		tiles = tiles,
		lights = lights,
		shell = shell,
		checkpointPad = checkpointPad,
		checkpointCFrame = CFrame.lookAt(standAt, standAt + Vector3.zAxis),
	}
end

local function setupLighting()
	for _, child in Lighting:GetChildren() do
		-- An Atmosphere overrides fog, and the fog is most of the mood. Template
		-- post effects are replaced by ours below.
		if child:IsA("Atmosphere") or child:IsA("PostEffect") then
			child:Destroy()
		end
	end
	Lighting.ClockTime = 0
	Lighting.Brightness = 0.6
	Lighting.Ambient = Color3.fromRGB(34, 42, 46)
	Lighting.OutdoorAmbient = Color3.fromRGB(28, 34, 38)
	Lighting.EnvironmentDiffuseScale = 0.15
	Lighting.EnvironmentSpecularScale = 0.6 -- wet tiles catch the light
	Lighting.FogColor = Color3.fromRGB(22, 38, 42)
	Lighting.FogStart = 8
	Lighting.FogEnd = 100
	Lighting.GlobalShadows = true

	-- Cold, washed-out colours, and a soft glow around anything neon.
	-- Named so client/Mood.luau can warm it up in the lobby.
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "Grade"
	grade.Saturation = -0.25
	grade.Contrast = 0.12
	grade.TintColor = Color3.fromRGB(214, 232, 236)
	grade.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
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
		tank = lobby.tank,
		runStart = lobby.runStart,
		doors = lobby.doors,
		partyDoors = lobby.partyDoors,
	}
	local z = 0
	for index, stage in Stages do
		local room = buildRoom(map, index, stage, z)
		layout.rooms[index] = room
		z = room.zEnd
	end

	-- Exit
	local exit = Instance.new("Folder")
	exit.Name = "Exit"
	exit.Parent = map
	local exitEnd = z + ROOM.ExitLength
	buildShell(exit, z, exitEnd, {})
	landing(exit, "Floor", z, exitEnd)
	local exitLintel = buildCrossWall(exit, z, { 0 })
	addSign(exitLintel, Enum.NormalId.Back, "THE WAY OUT", "Walk into the light")
	buildCrossWall(exit, exitEnd)
	layout.exitDoor = block(
		exit,
		"ExitDoor",
		Vector3.new(ROOM.DoorWidth, ROOM.DoorHeight, 0.5),
		CFrame.new(0, TILE_TOP + ROOM.DoorHeight / 2, exitEnd - 0.75),
		COLORS.exit,
		Enum.Material.Neon
	)

	map.Parent = workspace

	function layout.roomAt(position)
		for _, room in layout.rooms do
			if position.Z >= room.zStart and position.Z < room.zEnd then
				return room
			end
		end
		return nil
	end

	function layout.inPool(room, position)
		return math.abs(position.X) < room.halfWidth and position.Z > room.poolStart and position.Z < room.poolEnd
	end

	return layout
end

return MapBuilder
