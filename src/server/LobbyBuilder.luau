-- The lobby, z from -LobbyLength to 0: the reception of an old 1970s swim
-- club. It is warm and bright on purpose, so the flooded rooms feel darker
-- after it (client/Mood.luau does the lighting).
--
--   back wall    a bank of lockers, the pool rules, a clock, the club sign
--   left wall    the aquarium window (LobbyTank.luau) with a bench in front,
--                and the Swim Shop vending machine by the door
--   right wall   the record boards (Leaderboards.luau) under the Hall of
--                Fame sign, lifebuoys, a drinking fountain
--   door wall    a sunburst around the way in, under the game's sign
--
-- Everything is built from parts, so it lives in the repo like the rest of
-- the map. Returns the pieces other modules need.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Parts = require(script.Parent.Parts)

local block, box = Parts.block, Parts.box

-- Same measurements as MapBuilder.luau.
local ROOM = Config.Room
local HALF_WIDTH = ROOM.Width / 2
local SURFACE_Y = ROOM.SurfaceY
local TILE_TOP = SURFACE_Y + ROOM.TileHeight
local BASE_Y = SURFACE_Y - ROOM.PoolDepth - 1
local TOP = SURFACE_Y + ROOM.Height
local WALL = 2
local Z0, Z1 = -ROOM.LobbyLength, 0

local WAINSCOT = 4 -- height of the orange tiles along the walls
local FLOOR_TILE = 8

local C = {
	cream = Color3.fromRGB(240, 230, 206),
	creamDark = Color3.fromRGB(222, 208, 178),
	orange = Color3.fromRGB(214, 112, 52),
	mustard = Color3.fromRGB(232, 178, 58),
	coral = Color3.fromRGB(232, 98, 80),
	teal = Color3.fromRGB(40, 150, 150),
	tealDark = Color3.fromRGB(24, 92, 98),
	floorTeal = Color3.fromRGB(30, 118, 118), -- darker than the signs, or the floor glares
	brown = Color3.fromRGB(110, 70, 45),
	wood = Color3.fromRGB(176, 122, 72),
	leaf = Color3.fromRGB(70, 140, 70),
	ink = Color3.fromRGB(40, 36, 32),
	white = Color3.fromRGB(246, 244, 238),
	glass = Color3.fromRGB(190, 225, 235),
	lamp = Color3.fromRGB(255, 232, 190),
	tank = Color3.fromRGB(80, 124, 128),
	tankWater = Color3.fromRGB(40, 110, 120),
	tankLight = Color3.fromRGB(90, 220, 230),
	sand = Color3.fromRGB(226, 204, 150),
	rock = Color3.fromRGB(110, 116, 112),
	board = Color3.fromRGB(18, 52, 58),
}

local TILES = Enum.Material.CeramicTiles
local DECOR = { CanCollide = false, CanQuery = false, CastShadow = false }

local LobbyBuilder = {}

local function label(parent, props)
	local result = Instance.new("TextLabel")
	result.BackgroundTransparency = 1
	result.TextScaled = true
	for key, value in props do
		result[key] = value
	end
	result.Parent = parent
	return result
end

-- A chunky retro sign on one face of a part: a title, and a smaller line under it.
local function sign(part, face, title, subtitle, textColor)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.5
	label(gui, {
		Position = UDim2.fromScale(0.04, if subtitle then 0.06 else 0.12),
		Size = UDim2.fromScale(0.92, if subtitle then 0.56 else 0.76),
		Font = Enum.Font.FredokaOne,
		TextColor3 = textColor,
		Text = title,
	})
	if subtitle then
		label(gui, {
			Position = UDim2.fromScale(0.06, 0.64),
			Size = UDim2.fromScale(0.88, 0.26),
			Font = Enum.Font.GothamMedium,
			TextColor3 = textColor,
			Text = subtitle,
		})
	end
	gui.Parent = part
	return gui
end

-- Orange tiles to waist height with a mustard, coral and teal stripe above,
-- on the room side of a wall. The wall runs along "x" or "z"; plane is its
-- inside face and inward is +1 or -1, whichever way the room is.
local function dado(folder, along, plane, inward, from, to)
	local bands = {
		{ 0, WAINSCOT, C.orange, TILES },
		{ WAINSCOT, WAINSCOT + 0.35, C.mustard },
		{ WAINSCOT + 0.35, WAINSCOT + 0.7, C.coral },
		{ WAINSCOT + 0.7, WAINSCOT + 1.05, C.teal },
	}
	local near, far = math.min(plane, plane + inward * 0.2), math.max(plane, plane + inward * 0.2)
	for _, band in bands do
		local y0, y1 = TILE_TOP + band[1], TILE_TOP + band[2]
		if along == "z" then
			box(folder, "Dado", Vector3.new(near, y0, from), Vector3.new(far, y1, to), band[3], band[4], DECOR)
		else
			box(folder, "Dado", Vector3.new(from, y0, near), Vector3.new(to, y1, far), band[3], band[4], DECOR)
		end
	end
end

-- A lifebuoy flat against a wall: a ring of short segments in alternating
-- coral and white bands. normal points out of the wall into the room.
local function lifebuoy(folder, center, normal, radius)
	local up = Vector3.yAxis
	local side = up:Cross(normal).Unit
	local count = 16
	for i = 0, count - 1 do
		local angle = (i + 0.5) / count * math.pi * 2
		local position = center + (side * math.cos(angle) + up * math.sin(angle)) * radius
		local tangent = side * -math.sin(angle) + up * math.cos(angle)
		local color = if math.floor(i / 2) % 2 == 0 then C.coral else C.white
		block(folder, "Lifebuoy", Vector3.new(radius * 0.42, radius * 0.45, radius * 0.45), CFrame.fromMatrix(position, tangent, normal), color, nil, {
			Shape = Enum.PartType.Cylinder,
			CanCollide = false,
			CanQuery = false,
		})
	end
end

-- A potted palm, standing on the floor at x, z.
local function plant(folder, x, z)
	local base = Vector3.new(x, TILE_TOP, z)
	block(folder, "Pot", Vector3.new(1.8, 2, 2), CFrame.new(base + Vector3.new(0, 0.9, 0)) * CFrame.Angles(0, 0, math.pi / 2), C.orange, nil, {
		Shape = Enum.PartType.Cylinder,
	})
	block(folder, "Soil", Vector3.new(0.1, 1.7, 1.7), CFrame.new(base + Vector3.new(0, 1.82, 0)) * CFrame.Angles(0, 0, math.pi / 2), C.brown, Enum.Material.Ground, {
		Shape = Enum.PartType.Cylinder,
		CanCollide = false,
	})
	local top = base + Vector3.new(0, 4.6, 0)
	block(folder, "Trunk", Vector3.new(0.35, 2.9, 0.35), CFrame.new(base + Vector3.new(0, 3.2, 0)), C.brown, Enum.Material.Wood, DECOR)
	for i = 1, 7 do
		local turn = CFrame.Angles(0, i / 7 * math.pi * 2, 0) * CFrame.Angles(math.rad(-28), 0, 0)
		block(folder, "Leaf", Vector3.new(0.9, 0.08, 3.2), CFrame.new(top) * turn * CFrame.new(0, 0, -1.5), C.leaf, Enum.Material.Grass, DECOR)
	end
end

-- A slatted bench, its seat centred on cframe and running along its Z.
local function bench(folder, cframe, length)
	for i = -1, 1 do
		block(folder, "BenchSlat", Vector3.new(0.62, 0.18, length), cframe * CFrame.new(i * 0.72, 0, 0), C.wood, Enum.Material.WoodPlanks)
	end
	for _, side in { -1, 1 } do
		block(folder, "BenchLeg", Vector3.new(2.2, 1.6, 0.3), cframe * CFrame.new(0, -0.89, side * (length / 2 - 0.8)), C.tealDark, Enum.Material.Metal)
	end
end

local function buildRoom(folder)
	-- Checkerboard floor.
	for ix = 0, ROOM.Width / FLOOR_TILE - 1 do
		for iz = 0, ROOM.LobbyLength / FLOOR_TILE - 1 do
			local x, z = -HALF_WIDTH + ix * FLOOR_TILE, Z0 + iz * FLOOR_TILE
			local color = if (ix + iz) % 2 == 0 then C.cream else C.floorTeal
			box(folder, "Floor", Vector3.new(x, BASE_Y, z), Vector3.new(x + FLOOR_TILE, TILE_TOP, z + FLOOR_TILE), color, TILES)
		end
	end

	box(folder, "Ceiling", Vector3.new(-HALF_WIDTH - WALL, TOP, Z0 - 1), Vector3.new(HALF_WIDTH + WALL, TOP + 1, Z1), C.cream, TILES)
	box(folder, "RightWall", Vector3.new(HALF_WIDTH, BASE_Y, Z0), Vector3.new(HALF_WIDTH + WALL, TOP, Z1), C.cream, TILES)
	box(folder, "BackWall", Vector3.new(-HALF_WIDTH, TILE_TOP, Z0 - 1), Vector3.new(HALF_WIDTH, TOP, Z0), C.cream, TILES)
	dado(folder, "z", HALF_WIDTH, -1, Z0, Z1)
	dado(folder, "x", Z0, 1, -HALF_WIDTH, HALF_WIDTH)

	-- Globe lamps hanging from the ceiling.
	for _, x in { -9, 9 } do
		for _, z in { Z0 + 12, Z0 + 32, Z0 + 52 } do
			block(folder, "LampRod", Vector3.new(0.15, 2, 0.15), CFrame.new(x, TOP - 1, z), C.brown, nil, DECOR)
			local globe = block(folder, "Lamp", Vector3.one * 1.8, CFrame.new(x, TOP - 2.7, z), C.lamp, Enum.Material.Neon, {
				Shape = Enum.PartType.Ball,
				CanCollide = false,
				CanQuery = false,
				CastShadow = false,
			})
			-- Kept soft: any brighter and the cream ceiling burns out to white.
			local light = Instance.new("PointLight")
			light.Color = C.lamp
			light.Range = 22
			light.Brightness = 0.75
			light.Shadows = true
			light.Parent = globe
		end
	end
end

-- The door to stage 1 (its wall belongs to the stage): tiles over the
-- stage's grey, an orange door frame, a sunburst and the game's sign.
local function buildDoorWall(folder)
	local face = -0.5 -- the lobby side of stage 1's wall
	local half = ROOM.DoorWidth / 2
	local doorTop = TILE_TOP + ROOM.DoorHeight
	local frame = 0.6

	dado(folder, "x", face, -1, -HALF_WIDTH, -half - frame)
	dado(folder, "x", face, -1, half + frame, HALF_WIDTH)
	box(folder, "DoorWallTiles", Vector3.new(-HALF_WIDTH, TILE_TOP + WAINSCOT + 1.05, face - 0.2), Vector3.new(-half - frame, TOP, face), C.cream, TILES, DECOR)
	box(folder, "DoorWallTiles", Vector3.new(half + frame, TILE_TOP + WAINSCOT + 1.05, face - 0.2), Vector3.new(HALF_WIDTH, TOP, face), C.cream, TILES, DECOR)
	box(folder, "DoorWallTiles", Vector3.new(-half - frame, doorTop + frame, face - 0.2), Vector3.new(half + frame, TOP, face), C.cream, TILES, DECOR)
	box(folder, "DoorFrame", Vector3.new(-half - frame, TILE_TOP, face - 0.45), Vector3.new(-half, doorTop + frame, face), C.orange, nil, DECOR)
	box(folder, "DoorFrame", Vector3.new(half, TILE_TOP, face - 0.45), Vector3.new(half + frame, doorTop + frame, face), C.orange, nil, DECOR)
	box(folder, "DoorFrame", Vector3.new(-half, doorTop, face - 0.45), Vector3.new(half, doorTop + frame, face), C.orange, nil, DECOR)

	-- Rays fanning out from the top of the door, kept inside the wall.
	local center = Vector3.new(0, doorTop, face - 0.3)
	local colors = { C.orange, C.mustard, C.coral }
	local rays = 11
	for i = 0, rays - 1 do
		local angle = math.rad(6 + i * 168 / (rays - 1))
		local direction = Vector3.new(math.cos(angle), math.sin(angle), 0)
		local inner = 5.5 -- the club sign covers the rays' inner ends
		local length = math.min(11, (TOP - 0.4 - center.Y) / math.max(direction.Y, 0.01) - inner, (HALF_WIDTH - 0.5) / math.max(math.abs(direction.X), 0.01) - inner)
		if length > 1.5 then
			local middle = center + direction * (inner + length / 2)
			block(folder, "Sunray", Vector3.new(1.3, length, 0.15), CFrame.new(middle) * CFrame.Angles(0, 0, angle - math.pi / 2), colors[i % 3 + 1], nil, DECOR)
		end
	end

	local clubSign = block(folder, "ClubSign", Vector3.new(10, 3.6, 0.3), CFrame.new(0, doorTop + 2.6, face - 0.6), C.teal, nil, DECOR)
	sign(clubSign, Enum.NormalId.Front, string.upper(Config.GameName), Config.Tagline, C.cream)
end

-- Lockers along the back wall, with the pool rules, a clock and the club
-- sign above them.
local function buildBackWall(folder)
	local width, height, depth = 2.4, 7, 1.6
	local count = 12
	for i = 1, count do
		local x = -count * width / 2 + (i - 0.5) * width
		local front = Z0 + depth
		block(folder, "Locker", Vector3.new(width - 0.12, height, depth), CFrame.new(x, TILE_TOP + height / 2, Z0 + depth / 2), if i % 2 == 0 then C.teal else C.orange, nil, {
			Reflectance = 0.08,
		})
		for v = 0, 2 do
			block(folder, "LockerVent", Vector3.new(1.2, 0.12, 0.05), CFrame.new(x, TILE_TOP + height - 0.9 - v * 0.35, front + 0.02), C.ink, nil, DECOR)
		end
		block(folder, "LockerHandle", Vector3.new(0.15, 0.7, 0.12), CFrame.new(x + width / 2 - 0.5, TILE_TOP + 3.6, front + 0.05), C.creamDark, Enum.Material.Metal, DECOR)
		local plate = block(folder, "LockerNumber", Vector3.new(0.8, 0.45, 0.05), CFrame.new(x, TILE_TOP + height - 2.3, front + 0.03), C.cream, nil, DECOR)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Back
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 60
		label(gui, { Size = UDim2.fromScale(1, 1), Font = Enum.Font.FredokaOne, TextColor3 = C.ink, Text = ("%02d"):format(i) })
		gui.Parent = plate
	end

	-- The pool rules, in a teal frame.
	local rulesZ = Z0 + 0.15
	block(folder, "RulesFrame", Vector3.new(9.6, 5.6, 0.2), CFrame.new(-9.5, TILE_TOP + 11.3, rulesZ - 0.03), C.teal, nil, DECOR)
	local rules = block(folder, "PoolRules", Vector3.new(9, 5, 0.25), CFrame.new(-9.5, TILE_TOP + 11.3, rulesZ), C.cream, nil, DECOR)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.5
	label(gui, { Position = UDim2.fromScale(0.05, 0.04), Size = UDim2.fromScale(0.9, 0.2), Font = Enum.Font.FredokaOne, TextColor3 = C.orange, Text = "POOL RULES" })
	local lines = {
		"1. No running on the tiles.",
		"2. Do not enter the water after dark.",
		"3. If you hear it, keep still.",
		"4. Please do not tap the aquarium glass.",
	}
	-- One fixed size, so short rules don't come out bigger than long ones.
	for i, line in lines do
		label(gui, {
			Position = UDim2.fromScale(0.07, 0.28 + (i - 1) * 0.165),
			Size = UDim2.fromScale(0.86, 0.13),
			Font = Enum.Font.GothamMedium,
			TextColor3 = C.ink,
			TextScaled = false,
			TextSize = 17,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = line,
		})
	end
	gui.Parent = rules

	-- The club sign.
	local club = block(folder, "SwimClubSign", Vector3.new(9, 3.2, 0.25), CFrame.new(9.5, TILE_TOP + 11.3, Z0 + 0.15), C.orange, nil, DECOR)
	sign(club, Enum.NormalId.Back, "SWIM CLUB", "Members since 1974", C.cream)

	-- A wall clock, stopped at a quarter past four.
	local clock = CFrame.new(0, TILE_TOP + 11.3, Z0 + 0.25) * CFrame.Angles(0, math.pi / 2, 0)
	block(folder, "ClockRim", Vector3.new(0.2, 3.4, 3.4), clock, C.orange, nil, { Shape = Enum.PartType.Cylinder, CanCollide = false, CanQuery = false })
	block(folder, "ClockFace", Vector3.new(0.22, 3, 3), clock * CFrame.new(-0.02, 0, 0), C.white, nil, { Shape = Enum.PartType.Cylinder, CanCollide = false, CanQuery = false })
	local center = Vector3.new(0, TILE_TOP + 11.3, Z0 + 0.42)
	local function hand(length, angle, thickness)
		local direction = Vector3.new(math.sin(angle), math.cos(angle), 0)
		block(folder, "ClockHand", Vector3.new(thickness, length, 0.04), CFrame.new(center + direction * length / 2) * CFrame.Angles(0, 0, -angle), C.ink, nil, DECOR)
	end
	hand(0.9, math.rad(4 * 30 + 7.5), 0.14)
	hand(1.3, math.rad(90), 0.09)
end

-- The aquarium window and the tank behind it. Returns the tank's bounds.
local function buildAquarium(folder)
	local tank = {
		min = Vector3.new(-HALF_WIDTH - WALL - 14, TILE_TOP - 1, Z0 + 12),
		max = Vector3.new(-HALF_WIDTH - WALL, TILE_TOP + 12, Z1 - 12),
		glassX = -HALF_WIDTH, -- the room side of the window
	}
	tank.windowZ0, tank.windowZ1 = tank.min.Z + 2, tank.max.Z - 2
	local windowY0, windowY1 = TILE_TOP + 1, TILE_TOP + 10
	local wx0, wx1 = -HALF_WIDTH - WALL, -HALF_WIDTH
	local frame = 0.6

	-- The left wall around the window, and its tiles.
	box(folder, "LeftWall", Vector3.new(wx0, BASE_Y, Z0), Vector3.new(wx1, windowY0, Z1), C.cream, TILES)
	box(folder, "LeftWall", Vector3.new(wx0, windowY1, Z0), Vector3.new(wx1, TOP, Z1), C.cream, TILES)
	box(folder, "LeftWall", Vector3.new(wx0, windowY0, Z0), Vector3.new(wx1, windowY1, tank.windowZ0), C.cream, TILES)
	box(folder, "LeftWall", Vector3.new(wx0, windowY0, tank.windowZ1), Vector3.new(wx1, windowY1, Z1), C.cream, TILES)
	dado(folder, "z", wx1, 1, Z0, tank.windowZ0 - frame)
	dado(folder, "z", wx1, 1, tank.windowZ1 + frame, Z1)
	box(folder, "Glass", Vector3.new(wx0, windowY0, tank.windowZ0), Vector3.new(wx0 + 0.4, windowY1, tank.windowZ1), C.glass, Enum.Material.Glass, {
		Transparency = 0.7,
		Reflectance = 0.15,
		CastShadow = false,
	})

	-- A chunky orange frame with a mustard sill.
	local inner = wx1 + 0.4
	box(folder, "WindowFrame", Vector3.new(wx1, TILE_TOP, tank.windowZ0 - frame), Vector3.new(inner, windowY1 + frame, tank.windowZ0), C.orange, nil, DECOR)
	box(folder, "WindowFrame", Vector3.new(wx1, TILE_TOP, tank.windowZ1), Vector3.new(inner, windowY1 + frame, tank.windowZ1 + frame), C.orange, nil, DECOR)
	box(folder, "WindowFrame", Vector3.new(wx1, windowY1, tank.windowZ0), Vector3.new(inner, windowY1 + frame, tank.windowZ1), C.orange, nil, DECOR)
	box(folder, "WindowSill", Vector3.new(wx1, TILE_TOP, tank.windowZ0), Vector3.new(inner + 0.3, windowY0, tank.windowZ1), C.mustard, nil, DECOR)

	local plaque = block(folder, "AquariumSign", Vector3.new(0.25, 1.8, 13), CFrame.new(wx1 + 0.15, windowY1 + 1.9, (tank.windowZ0 + tank.windowZ1) / 2), C.teal, nil, DECOR)
	sign(plaque, Enum.NormalId.Right, "OBSERVATION WINDOW", "Please do not tap the glass", C.cream)

	-- The tank: tiled walls, a sand floor, rocks, weed and light from below.
	local t0, t1 = tank.min, tank.max
	box(folder, "TankBack", Vector3.new(t0.X - 1, t0.Y - 1, t0.Z - 1), Vector3.new(t0.X, t1.Y + 1, t1.Z + 1), C.tank, TILES)
	box(folder, "TankFloor", Vector3.new(t0.X, t0.Y - 1, t0.Z - 1), Vector3.new(t1.X, t0.Y, t1.Z + 1), C.sand, Enum.Material.Sand)
	box(folder, "TankTop", Vector3.new(t0.X, t1.Y, t0.Z - 1), Vector3.new(t1.X, t1.Y + 1, t1.Z + 1), C.tank, TILES)
	box(folder, "TankEnd", Vector3.new(t0.X, t0.Y, t0.Z - 1), Vector3.new(t1.X, t1.Y, t0.Z), C.tank, TILES)
	box(folder, "TankEnd", Vector3.new(t0.X, t0.Y, t1.Z), Vector3.new(t1.X, t1.Y, t1.Z + 1), C.tank, TILES)
	box(folder, "TankWater", t0, Vector3.new(t1.X, t1.Y - 0.6, t1.Z), C.tankWater, nil, {
		Transparency = 0.55,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	})
	local rng = Random.new(1974)
	for _ = 1, 6 do
		local size = rng:NextNumber(1, 2.2)
		local at = Vector3.new(rng:NextNumber(t0.X + 1.5, t1.X - 3), t0.Y + size * 0.3, rng:NextNumber(t0.Z + 2, t1.Z - 2))
		block(folder, "TankRock", Vector3.one * size, CFrame.new(at), C.rock, Enum.Material.Slate, { Shape = Enum.PartType.Ball, CanCollide = false, CanQuery = false })
	end
	for _ = 1, 10 do
		local height = rng:NextNumber(3, 7)
		local at = Vector3.new(rng:NextNumber(t0.X + 1, t0.X + 7), t0.Y + height / 2, rng:NextNumber(t0.Z + 1.5, t1.Z - 1.5))
		local lean = CFrame.Angles(rng:NextNumber(-0.15, 0.15), 0, rng:NextNumber(-0.15, 0.15))
		block(folder, "TankWeed", Vector3.new(0.3, height, 0.3), CFrame.new(at) * lean, C.leaf, Enum.Material.Grass, DECOR)
	end
	for _, along in { 0.25, 0.75 } do
		local holder = block(
			folder,
			"TankLight",
			Vector3.one,
			CFrame.new((t0.X + t1.X) / 2, t0.Y + 0.6, t0.Z + (t1.Z - t0.Z) * along),
			C.tankLight,
			nil,
			{ Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false }
		)
		local light = Instance.new("PointLight")
		light.Color = C.tankLight
		light.Range = 18
		light.Brightness = 1.6
		light.Parent = holder
	end

	bench(folder, CFrame.new(-HALF_WIDTH + 6.5, TILE_TOP + 1.7, (tank.windowZ0 + tank.windowZ1) / 2), 10)
	return tank
end

-- The Swim Shop: a vending machine by the door, with goods on lit shelves
-- behind a recessed window. Its prompt opens the shop (client/ShopUi.luau).
local function buildShop(folder)
	local back, front = -HALF_WIDTH + 0.2, -HALF_WIDTH + 3.2
	local recess = front - 0.8 -- the window is set back this far
	local z = Z1 - 6.5
	local z0, z1 = z - 2.7, z + 2.7
	local wz0, wz1 = z - 2.3, z + 1.1 -- the window
	local wy0, wy1 = TILE_TOP + 2.3, TILE_TOP + 6.9
	local top = TILE_TOP + 8

	local body = box(folder, "SwimShop", Vector3.new(back, TILE_TOP, z0), Vector3.new(recess, top, z1), C.coral, nil, { Reflectance = 0.05 })
	box(folder, "SwimShopFront", Vector3.new(recess, TILE_TOP, z0), Vector3.new(front, wy0, z1), C.coral)
	box(folder, "SwimShopFront", Vector3.new(recess, wy1, z0), Vector3.new(front, top, z1), C.coral)
	box(folder, "SwimShopFront", Vector3.new(recess, wy0, z0), Vector3.new(front, wy1, wz0), C.coral)
	box(folder, "SwimShopFront", Vector3.new(recess, wy0, wz1), Vector3.new(front, wy1, z1), C.coral)
	box(folder, "SwimShopBase", Vector3.new(back, TILE_TOP, z0 - 0.05), Vector3.new(front + 0.05, TILE_TOP + 0.5, z1 + 0.05), C.cream)

	local goods = { C.teal, C.mustard, C.orange, C.white, C.leaf, C.coral }
	box(folder, "SwimShopBacklight", Vector3.new(recess, wy0, wz0), Vector3.new(recess + 0.05, wy1, wz1), C.lamp, Enum.Material.Neon, DECOR)
	for row = 0, 2 do
		local shelfY = wy0 + 0.6 + row * 1.4
		box(folder, "SwimShopShelf", Vector3.new(recess + 0.05, shelfY - 0.04, wz0), Vector3.new(front - 0.1, shelfY + 0.04, wz1), C.creamDark, nil, DECOR)
		for col = 0, 2 do
			local at = Vector3.new(recess + 0.4, shelfY + 0.32, wz0 + 0.55 + col * 1.15)
			block(folder, "SwimShopItem", Vector3.new(0.4, 0.55, 0.6), CFrame.new(at), goods[(row * 3 + col) % #goods + 1], nil, DECOR)
		end
	end
	box(folder, "SwimShopWindow", Vector3.new(front - 0.06, wy0, wz0), Vector3.new(front - 0.01, wy1, wz1), C.glass, Enum.Material.Glass, {
		Transparency = 0.6,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	})
	block(folder, "SwimShopCoins", Vector3.new(0.12, 2.4, 1.2), CFrame.new(front + 0.06, TILE_TOP + 4.6, z + 1.9), C.creamDark, nil, DECOR)
	block(folder, "SwimShopSlot", Vector3.new(0.14, 0.5, 0.12), CFrame.new(front + 0.1, TILE_TOP + 5.2, z + 1.9), C.ink, nil, DECOR)
	block(folder, "SwimShopTray", Vector3.new(0.1, 0.8, 3), CFrame.new(front + 0.05, TILE_TOP + 1.4, z - 0.6), C.ink, nil, DECOR)
	local header = block(folder, "SwimShopSign", Vector3.new(0.3, 1.1, 5.4), CFrame.new(front + 0.15, TILE_TOP + 7.45, z), C.teal, nil, DECOR)
	sign(header, Enum.NormalId.Right, "SWIM SHOP", nil, C.cream)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OpenShop"
	prompt.ActionText = "Open shop"
	prompt.ObjectText = "Swim Shop"
	prompt.KeyboardKeyCode = Enum.KeyCode.G -- E throws a pebble
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = body
end

-- The record boards along the right wall, read left to right, under the
-- Hall of Fame sign, with lifebuoys either side and a drinking fountain.
local function buildRecordWall(folder)
	local boards = {}
	for i, id in { "Escapes", "Easy", "Normal", "Hard" } do
		local z = Z0 + 14 + (i - 1) * 12
		block(folder, "BoardFrame", Vector3.new(0.3, 8.6, 10.6), CFrame.new(HALF_WIDTH - 0.35, TILE_TOP + 5.6, z), C.orange)
		boards[id] = block(folder, "Board" .. id, Vector3.new(0.4, 8, 10), CFrame.new(HALF_WIDTH - 0.55, TILE_TOP + 5.6, z), C.board)
	end

	local hall = block(folder, "HallOfFame", Vector3.new(0.25, 2.2, 12), CFrame.new(HALF_WIDTH - 0.2, TILE_TOP + 12, Z0 + 32), C.teal, nil, DECOR)
	sign(hall, Enum.NormalId.Left, "HALL OF FAME", nil, C.cream)
	for _, z in { Z0 + 20, Z0 + 44 } do
		lifebuoy(folder, Vector3.new(HALF_WIDTH - 0.3, TILE_TOP + 12, z), -Vector3.xAxis, 1.3)
	end

	-- A drinking fountain by the door.
	local fx, fz = HALF_WIDTH - 1, Z1 - 4.5
	block(folder, "Fountain", Vector3.new(1.4, 3, 1.4), CFrame.new(fx, TILE_TOP + 1.5, fz), C.cream)
	block(folder, "FountainBasin", Vector3.new(1.9, 0.35, 1.7), CFrame.new(fx - 0.1, TILE_TOP + 3.15, fz), C.creamDark, Enum.Material.Metal)
	block(folder, "FountainSpout", Vector3.new(0.2, 0.35, 0.2), CFrame.new(fx - 0.3, TILE_TOP + 3.45, fz), C.creamDark, Enum.Material.Metal, DECOR)
	return boards
end

function LobbyBuilder.build(map)
	local folder = Instance.new("Folder")
	folder.Name = "Lobby"
	folder.Parent = map

	buildRoom(folder)
	buildDoorWall(folder)
	buildBackWall(folder)
	local tank = buildAquarium(folder)
	buildShop(folder)
	local boards = buildRecordWall(folder)
	plant(folder, -HALF_WIDTH + 2.5, Z0 + 3.2)
	plant(folder, HALF_WIDTH - 2.5, Z0 + 3.2)
	plant(folder, HALF_WIDTH - 2.5, Z1 - 2)
	bench(folder, CFrame.new(8, TILE_TOP + 1.7, Z0 + 32), 10)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(8, 0.2, 8)
	spawn.CFrame = CFrame.new(0, TILE_TOP + 0.05, Z0 + 10) * CFrame.Angles(0, math.pi, 0)
	spawn.Color = C.mustard
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = folder

	-- Walking through stage 1's door starts the run timer (Progress.luau).
	local runStart = block(folder, "RunStart", Vector3.new(ROOM.DoorWidth, ROOM.DoorHeight, 2), CFrame.new(0, TILE_TOP + ROOM.DoorHeight / 2, 1.5), C.mustard, nil, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})

	return { boards = boards, tank = tank, runStart = runStart }
end

return LobbyBuilder
