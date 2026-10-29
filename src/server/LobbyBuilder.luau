-- The lobby, z from -LobbyLength to 0: an open courtyard at night in front of
-- the old building the stages are in. No roof, just the night sky; lamp posts,
-- string lights and neon instead (client/Mood.luau does the lighting).
--
--   the building   brick, with lit windows and the game's sign in neon. Three
--                  stone archways into stage 1, one per difficulty, each with
--                  a glowing pad and a screen (server/LobbyDoors.luau), and a
--                  party door either side (server/Parties.luau)
--   west wing      a flooded ground-floor window; the creature inside comes
--                  to stare at anyone by the glass (LobbyTank.luau)
--   east wall      the record boards (Leaderboards.luau), and the float hut,
--                  which is the shop
--   courtyard      paving, a lit path to the doors, grass beds with palms,
--                  benches, puddles, and wet footprints leading inside
--   beyond         an iron fence, trees and a dark skyline
--
-- Everything is built from parts here except the props made in Meshy (hut,
-- palms, planters), which are imported into the place and kept in
-- ServerStorage.LobbyProps; a missing one is skipped. Returns the pieces other
-- modules need.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Parts = require(script.Parent.Parts)

local block, box = Parts.block, Parts.box

-- Same measurements as MapBuilder.luau.
local ROOM = Config.Room
local STAGE_HALF = ROOM.Width / 2 + 2 -- the stages and their walls
local HALF = ROOM.LobbyWidth / 2
local SURFACE_Y = ROOM.SurfaceY
local TILE_TOP = SURFACE_Y + ROOM.TileHeight
local BASE_Y = SURFACE_Y - ROOM.PoolDepth - 1
local FACADE_TOP = TILE_TOP + ROOM.FacadeHeight
local WING_TOP = TILE_TOP + 24
local FACE = -1.2 -- the courtyard side of the building's front
local WALL = 2
local Z0 = -ROOM.LobbyLength

local C = {
	brick = Color3.fromRGB(86, 60, 92),
	stone = Color3.fromRGB(150, 146, 172),
	paving = Color3.fromRGB(54, 58, 82),
	pavingAlt = Color3.fromRGB(62, 66, 92),
	path = Color3.fromRGB(96, 98, 130),
	grass = Color3.fromRGB(40, 78, 62),
	ground = Color3.fromRGB(24, 44, 40),
	iron = Color3.fromRGB(30, 28, 42),
	wood = Color3.fromRGB(120, 84, 60),
	trunk = Color3.fromRGB(44, 34, 32),
	leaves = Color3.fromRGB(26, 52, 44),
	skyline = Color3.fromRGB(22, 24, 42),
	warm = Color3.fromRGB(255, 214, 150),
	-- Neon shows far brighter than its colour, so the glowing bits are set
	-- dark: these come out as a warm glow instead of solid yellow.
	globe = Color3.fromRGB(120, 85, 50), -- lamp globes
	amber = Color3.fromRGB(125, 98, 45), -- lantern glass
	windowLit = Color3.fromRGB(100, 70, 32),
	windowDark = Color3.fromRGB(34, 38, 62),
	aqua = Color3.fromRGB(47, 230, 224),
	pink = Color3.fromRGB(255, 79, 163),
	mint = Color3.fromRGB(111, 227, 180),
	lemon = Color3.fromRGB(255, 221, 74),
	candy = Color3.fromRGB(255, 111, 177),
	ink = Color3.fromRGB(43, 34, 87),
	white = Color3.fromRGB(250, 252, 252),
	door = Color3.fromRGB(70, 76, 110),
	glass = Color3.fromRGB(90, 130, 160),
	puddle = Color3.fromRGB(110, 140, 200),
	tank = Color3.fromRGB(40, 70, 72),
	tankWater = Color3.fromRGB(30, 96, 110),
	tankLight = Color3.fromRGB(90, 220, 230),
	sand = Color3.fromRGB(150, 140, 110),
	rock = Color3.fromRGB(90, 96, 92),
	weed = Color3.fromRGB(50, 120, 70),
}

-- One colour per difficulty door, and what its screen says.
local DOORS = {
	Easy = { color = C.mint, blurb = "Quieter steps. A slower creature." },
	Normal = { color = C.lemon, blurb = "The water as it was meant to be." },
	Hard = { color = C.candy, blurb = "Every step is louder. It's faster." },
}

local BRICK = Enum.Material.Brick
local DECOR = { CanCollide = false, CanQuery = false, CastShadow = false }
local NEON = { CanCollide = false, CanQuery = false, CastShadow = false, CanTouch = false }
local BARRIER = { Transparency = 1, CanQuery = false, CastShadow = false }

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

local function surface(part, face, pixelsPerStud)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud or 40
	gui.LightInfluence = 0.3
	gui.Parent = part
	return gui
end

-- Chunky cartoon lettering: a fill colour with a thick ink outline.
local function bubbleText(gui, thickness, props)
	local text = label(gui, props)
	local stroke = Instance.new("UIStroke")
	stroke.Color = C.ink
	stroke.Thickness = thickness
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = text
	return text
end

-- A white sign board with an ink border, flat against a wall. normal points
-- out of the wall; returns the SurfaceGui on its front.
local function signBoard(folder, name, size, center, normal)
	local look = CFrame.lookAt(center, center + normal)
	block(folder, name .. "Border", size + Vector3.new(0.5, 0.5, -0.05), look * CFrame.new(0, 0, 0.02), C.ink, nil, DECOR)
	local board = block(folder, name, size, look * CFrame.new(0, 0, -0.05), C.white, nil, DECOR)
	return surface(board, Enum.NormalId.Front)
end

-- A lit screen with a neon border, flat against a wall. normal points out of
-- the wall; returns the SurfaceGui on its front.
local function screen(folder, name, size, center, normal, color)
	local look = CFrame.lookAt(center, center + normal)
	block(folder, name .. "Glow", size + Vector3.new(0.6, 0.6, -0.1), look * CFrame.new(0, 0, 0.05), color, Enum.Material.Neon, NEON)
	local part = block(folder, name, size, look * CFrame.new(0, 0, -0.05), C.ink, nil, DECOR)
	local gui = surface(part, Enum.NormalId.Front, 30)
	gui.LightInfluence = 0
	return gui
end

-- A glowing outline on the floor, centred on (x, z), with a faint fill.
-- Returns the invisible space above it, for noticing who stands on it.
local function glowPad(folder, x, z, width, length, color)
	local y = TILE_TOP + 0.04
	local bar = 0.3
	block(folder, "PadGlow", Vector3.new(width, 0.06, bar), CFrame.new(x, y, z - length / 2), color, Enum.Material.Neon, NEON)
	block(folder, "PadGlow", Vector3.new(width, 0.06, bar), CFrame.new(x, y, z + length / 2), color, Enum.Material.Neon, NEON)
	block(folder, "PadGlow", Vector3.new(bar, 0.06, length), CFrame.new(x - width / 2, y, z), color, Enum.Material.Neon, NEON)
	block(folder, "PadGlow", Vector3.new(bar, 0.06, length), CFrame.new(x + width / 2, y, z), color, Enum.Material.Neon, NEON)
	block(folder, "PadFill", Vector3.new(width, 0.03, length), CFrame.new(x, y - 0.01, z), color, Enum.Material.Neon, {
		Transparency = 0.82,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
		CanTouch = false,
	})
	return block(folder, "PadZone", Vector3.new(width, 6, length), CFrame.new(x, TILE_TOP + 3, z), color, nil, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	})
end

-- A coloured light with nothing to see, for lighting up a prop or a corner.
local function glow(folder, at, color, range, brightness)
	local holder = block(folder, "Glow", Vector3.one, CFrame.new(at), color, nil, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Parent = holder
end

-- A globe lamp on a wall bracket. normal points out of the wall.
local function wallLamp(folder, at, normal)
	block(folder, "LampBracket", Vector3.new(0.6, 0.6, 1.2), CFrame.lookAt(at, at + normal) * CFrame.new(0, 0, -0.6), C.iron, nil, DECOR)
	local globe = block(folder, "Lamp", Vector3.one * 1.2, CFrame.new(at + normal * 1.3), C.globe, Enum.Material.Neon, {
		Shape = Enum.PartType.Ball,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	})
	local light = Instance.new("PointLight")
	light.Color = C.warm
	light.Range = 16
	light.Brightness = 0.6
	light.Parent = globe
end

-- A window in a wall: a stone frame round a pane, lit warm or dark. normal
-- points out of the wall.
local function window(folder, center, normal, lit)
	local look = CFrame.lookAt(center, center + normal)
	block(folder, "WindowFrame", Vector3.new(3.4, 4.4, 0.3), look * CFrame.new(0, 0, -0.1), C.stone, Enum.Material.Concrete, DECOR)
	block(folder, "WindowPane", Vector3.new(2.6, 3.6, 0.1), look * CFrame.new(0, 0, -0.28), if lit then C.windowLit else C.windowDark, if lit then Enum.Material.Neon else Enum.Material.Glass, NEON)
	block(folder, "WindowBar", Vector3.new(0.18, 3.6, 0.1), look * CFrame.new(0, 0, -0.35), C.stone, nil, DECOR)
	block(folder, "WindowBar", Vector3.new(2.6, 0.18, 0.1), look * CFrame.new(0, 0, -0.35), C.stone, nil, DECOR)
end

-- A neon strip along a wall face, from a to b.
local function strip(folder, a, b, color)
	box(folder, "Strip", Vector3.new(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z)), Vector3.new(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z)), color, Enum.Material.Neon, NEON)
end

-- A flat puddle on the paving.
local function puddle(folder, x, z, size)
	block(folder, "Puddle", Vector3.new(0.06, size, size), CFrame.new(x, TILE_TOP + 0.03, z) * CFrame.Angles(0, 0, math.pi / 2), C.puddle, Enum.Material.Glass, {
		Shape = Enum.PartType.Cylinder,
		Transparency = 0.45,
		Reflectance = 0.45,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	})
end

-- An iron lamp post with a warm lantern, standing at (x, z).
local function lampPost(folder, x, z)
	block(folder, "LampBase", Vector3.new(1.2, 0.6, 1.2), CFrame.new(x, TILE_TOP + 0.3, z), C.iron, Enum.Material.Metal)
	block(folder, "LampPost", Vector3.new(0.35, 10, 0.35), CFrame.new(x, TILE_TOP + 5.3, z), C.iron, Enum.Material.Metal)
	block(folder, "LampCap", Vector3.new(1.1, 0.3, 1.1), CFrame.new(x, TILE_TOP + 11.6, z), C.iron, Enum.Material.Metal, DECOR)
	local lantern = block(folder, "Lantern", Vector3.new(0.75, 1.1, 0.75), CFrame.new(x, TILE_TOP + 10.9, z), C.amber, Enum.Material.Neon, NEON)
	local light = Instance.new("PointLight")
	light.Color = C.warm
	light.Range = 20
	light.Brightness = 0.7
	light.Parent = lantern
end

-- A park bench, its seat centred on cframe and running along its X; whoever
-- sits on it faces cframe's look direction.
local function bench(folder, cframe)
	for i = -1, 1 do
		block(folder, "BenchSlat", Vector3.new(5, 0.18, 0.5), cframe * CFrame.new(0, 0, i * 0.6), C.wood, Enum.Material.WoodPlanks)
	end
	block(folder, "BenchBack", Vector3.new(5, 1.1, 0.18), cframe * CFrame.new(0, 0.85, 0.9) * CFrame.Angles(math.rad(-10), 0, 0), C.wood, Enum.Material.WoodPlanks)
	for _, side in { -1, 1 } do
		block(folder, "BenchLeg", Vector3.new(0.3, 1.6, 2), cframe * CFrame.new(side * 2.1, -0.75, 0.1), C.iron, Enum.Material.Metal)
	end
end

-- A dark tree, for the edges of the world.
local function tree(folder, x, z, scale)
	local y = TILE_TOP - 0.2
	block(folder, "Trunk", Vector3.new(1, 7 * scale, 1), CFrame.new(x, y + 3.5 * scale, z), C.trunk, Enum.Material.Wood, DECOR)
	block(folder, "Canopy", Vector3.one * 8 * scale, CFrame.new(x, y + 9 * scale, z), C.leaves, Enum.Material.LeafyGrass, { Shape = Enum.PartType.Ball, CanCollide = false, CanQuery = false })
	block(folder, "Canopy", Vector3.one * 6 * scale, CFrame.new(x + 2 * scale, y + 11.5 * scale, z - scale), C.leaves, Enum.Material.LeafyGrass, { Shape = Enum.PartType.Ball, CanCollide = false, CanQuery = false })
end

-- A line of coloured bulbs on a sagging wire from a to b.
local function stringLights(folder, a, b, sag)
	local colors = { C.warm, C.pink, C.aqua, C.lemon }
	local count = math.floor((b - a).Magnitude / 3)
	local last
	for i = 0, count do
		local t = i / count
		local at = a:Lerp(b, t) - Vector3.new(0, sag * 4 * t * (1 - t), 0)
		if last then
			block(folder, "Wire", Vector3.new(0.08, 0.08, (at - last).Magnitude), CFrame.lookAt((at + last) / 2, at), C.iron, nil, NEON)
		end
		-- Half as bright, so a line of bulbs twinkles instead of glaring.
		local color = colors[i % #colors + 1]:Lerp(Color3.new(), 0.5)
		local bulb = block(folder, "Bulb", Vector3.one * 0.45, CFrame.new(at - Vector3.new(0, 0.3, 0)), color, Enum.Material.Neon, {
			Shape = Enum.PartType.Ball,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
			CanTouch = false,
		})
		if i % 6 == 3 then
			local light = Instance.new("PointLight")
			light.Color = bulb.Color
			light.Range = 10
			light.Brightness = 0.35
			light.Parent = bulb
		end
		last = at
	end
end

-- One of the Meshy props from ServerStorage.LobbyProps, scaled to height
-- studs, turned yaw degrees and standing on the floor centred on (x, z).
-- Returns nil if the place doesn't have it.
local function prop(folder, name, height, x, z, yaw)
	local source = ServerStorage:FindFirstChild("LobbyProps") and ServerStorage.LobbyProps:FindFirstChild(name)
	if not source then
		warn("[LobbyBuilder] No " .. name .. " in ServerStorage.LobbyProps; skipping it")
		return nil
	end
	local model = source:Clone()
	if model:IsA("BasePart") then
		local wrapper = Instance.new("Model")
		wrapper.Name = name
		model.Parent = wrapper
		model = wrapper
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end
	local _, size = model:GetBoundingBox()
	model:ScaleTo(model:GetScale() * height / size.Y)
	model:PivotTo(model:GetPivot() * CFrame.Angles(0, math.rad(yaw), 0))
	local center, scaled = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() + Vector3.new(x - center.X, TILE_TOP - (center.Y - scaled.Y / 2), z - center.Z))
	model.Parent = folder
	return model
end

-- Paving for the courtyard, a lighter path to the doors, and grass out to the
-- horizon (but not under the stages).
local function buildGround(folder)
	local slab = 10
	for ix = 0, ROOM.LobbyWidth / slab - 1 do
		for iz = 0, ROOM.LobbyLength / slab - 1 do
			local x, z = -HALF + ix * slab, Z0 + iz * slab
			local color = if (ix + iz) % 2 == 0 then C.paving else C.pavingAlt
			box(folder, "Paving", Vector3.new(x, BASE_Y, z), Vector3.new(x + slab, TILE_TOP, z + slab), color, Enum.Material.Pavement, { Reflectance = 0.05 })
		end
	end
	box(folder, "Path", Vector3.new(-6, TILE_TOP, Z0), Vector3.new(6, TILE_TOP + 0.04, -14), C.path, Enum.Material.Slate, DECOR)
	box(folder, "Path", Vector3.new(-STAGE_HALF, TILE_TOP, -14), Vector3.new(STAGE_HALF, TILE_TOP + 0.04, FACE), C.path, Enum.Material.Slate, DECOR)

	local y0, y1 = TILE_TOP - 1.3, TILE_TOP - 0.3
	local grass = { Reflectance = 0 }
	box(folder, "Ground", Vector3.new(-400, y0, -500), Vector3.new(400, y1, Z0), C.ground, Enum.Material.LeafyGrass, grass)
	box(folder, "Ground", Vector3.new(-400, y0, Z0), Vector3.new(-HALF - 20, y1, 0), C.ground, Enum.Material.LeafyGrass, grass)
	box(folder, "Ground", Vector3.new(HALF, y0, Z0), Vector3.new(400, y1, 0), C.ground, Enum.Material.LeafyGrass, grass)
	box(folder, "Ground", Vector3.new(-400, y0, 0), Vector3.new(-STAGE_HALF - 2, y1, 400), C.ground, Enum.Material.LeafyGrass, grass)
	box(folder, "Ground", Vector3.new(STAGE_HALF + 2, y0, 0), Vector3.new(400, y1, 400), C.ground, Enum.Material.LeafyGrass, grass)
end

-- A stone archway round a doorway centred on x: a smooth band of blocks cut
-- by joints, framing exactly the door opening. Its back sits on the wall at
-- face; returns the z of its front.
local function buildArch(folder, face, x, color)
	local w, h = ROOM.DoorWidth, ROOM.DoorHeight
	local thickness, depth = 2, 4
	local r = w / 2
	local straight = h - r
	local line, proud = 0.14, 0.05
	local joints = color:Lerp(C.ink, 0.45)
	local origin = CFrame.new(x, TILE_TOP, face - depth / 2)
	local stone = { Reflectance = 0.02 }

	-- A joint line round the ring's cross-section. at is on the joint with its
	-- Y axis pointing away from the opening.
	local function joint(at)
		local mid = r + thickness / 2
		for _, z in { -depth / 2 - proud / 2, depth / 2 + proud / 2 } do
			block(folder, "ArchJoint", Vector3.new(line, thickness, proud), origin * at * CFrame.new(0, mid, z), joints, nil, DECOR)
		end
		block(folder, "ArchJoint", Vector3.new(line, proud, depth), origin * at * CFrame.new(0, r + thickness + proud / 2, 0), joints, nil, DECOR)
		block(folder, "ArchJoint", Vector3.new(line, proud, depth), origin * at * CFrame.new(0, r - proud / 2, 0), joints, nil, DECOR)
	end

	local rows = 4
	for _, side in { -1, 1 } do
		block(folder, "Arch", Vector3.new(thickness, straight, depth), origin * CFrame.new(side * (r + thickness / 2), straight / 2, 0), color, Enum.Material.Concrete, stone)
		for i = 1, rows do
			joint(CFrame.new(0, i * straight / rows, 0) * CFrame.Angles(0, 0, -side * math.pi / 2))
		end
	end

	local segments, blocks = 36, 9
	local mid = r + thickness / 2
	for i = 0, segments - 1 do
		local a = (i + 0.5) * math.pi / segments
		local at = CFrame.new(mid * math.cos(a), straight + mid * math.sin(a), 0) * CFrame.Angles(0, 0, a - math.pi / 2)
		block(folder, "Arch", Vector3.new(2 * mid * math.sin(math.pi / segments / 2) + 0.08, thickness, depth), origin * at, color, Enum.Material.Concrete, stone)
	end
	for i = 1, blocks - 1 do
		joint(CFrame.new(0, straight, 0) * CFrame.Angles(0, 0, i * math.pi / blocks - math.pi / 2))
	end
	return face - depth
end

-- The building's front: brick, lit windows, the game's sign, a stone archway
-- into stage 1 per difficulty and a party door either side. Returns the
-- doors and party doors, and the z of the archways' fronts.
local function buildFacade(folder)
	local half = ROOM.DoorWidth / 2
	local doorTop = TILE_TOP + ROOM.DoorHeight
	local back = -0.5 -- stage 1's own wall starts here

	-- The middle, over stage 1's wall, with the three doorways.
	local xs = {}
	for _, x in ROOM.EntranceDoors do
		table.insert(xs, x)
	end
	table.sort(xs)
	local left = -STAGE_HALF
	for _, x in xs do
		box(folder, "Facade", Vector3.new(left, TILE_TOP, FACE), Vector3.new(x - half, FACADE_TOP, back), C.brick, BRICK)
		box(folder, "Facade", Vector3.new(x - half, doorTop, FACE), Vector3.new(x + half, FACADE_TOP, back), C.brick, BRICK)
		strip(folder, Vector3.new(left, TILE_TOP, FACE - 0.15), Vector3.new(x - half, TILE_TOP + 0.3, FACE), C.aqua)
		left = x + half
	end
	box(folder, "Facade", Vector3.new(left, TILE_TOP, FACE), Vector3.new(STAGE_HALF, FACADE_TOP, back), C.brick, BRICK)
	strip(folder, Vector3.new(left, TILE_TOP, FACE - 0.15), Vector3.new(STAGE_HALF, TILE_TOP + 0.3, FACE), C.aqua)

	-- The wings either side are solid, and the roof edge runs along the top.
	box(folder, "FacadeWing", Vector3.new(-HALF - WALL, BASE_Y, FACE), Vector3.new(-STAGE_HALF, FACADE_TOP, 10), C.brick, BRICK)
	box(folder, "FacadeWing", Vector3.new(STAGE_HALF, BASE_Y, FACE), Vector3.new(HALF + WALL, FACADE_TOP, 10), C.brick, BRICK)
	box(folder, "Cornice", Vector3.new(-HALF - WALL - 0.6, FACADE_TOP, FACE - 0.8), Vector3.new(HALF + WALL + 0.6, FACADE_TOP + 1.2, 10), C.stone, Enum.Material.Concrete)
	strip(folder, Vector3.new(-HALF - WALL, FACADE_TOP - 0.3, FACE - 0.15), Vector3.new(HALF + WALL, FACADE_TOP, FACE), C.pink)
	for _, side in { -1, 1 } do
		strip(folder, Vector3.new(side * STAGE_HALF, TILE_TOP, FACE - 0.15), Vector3.new(side * HALF, TILE_TOP + 0.3, FACE), C.aqua)
	end

	-- Two rows of windows on the wings, some still lit.
	local rng = Random.new(1931)
	for _, y in { TILE_TOP + 20.5, TILE_TOP + 26 } do
		for _, side in { -1, 1 } do
			for x = STAGE_HALF + 3.5, HALF - 2, 5.5 do
				window(folder, Vector3.new(side * x, y, FACE), -Vector3.zAxis, rng:NextNumber() < 0.45)
			end
		end
	end
	for _, x in { -STAGE_HALF - 1.5, STAGE_HALF + 1.5, -HALF + 3, HALF - 3 } do
		wallLamp(folder, Vector3.new(x, TILE_TOP + 8, FACE), -Vector3.zAxis)
	end

	-- The game's sign in neon, over the archways.
	local sign = screen(folder, "GameSign", Vector3.new(36, 7, 0.4), Vector3.new(0, TILE_TOP + 22.8, FACE - 0.3), -Vector3.zAxis, C.pink)
	bubbleText(sign, 6, { Position = UDim2.fromScale(0.03, 0.06), Size = UDim2.fromScale(0.94, 0.62), Font = Enum.Font.FredokaOne, TextColor3 = C.lemon, Text = string.upper(Config.GameName) })
	label(sign, { Position = UDim2.fromScale(0.08, 0.72), Size = UDim2.fromScale(0.84, 0.2), Font = Enum.Font.FredokaOne, TextColor3 = C.aqua, Text = Config.Tagline })
	glow(folder, Vector3.new(0, TILE_TOP + 22, FACE - 6), C.pink, 22, 0.4)

	-- The archways, one per difficulty, each with a screen and a pad.
	local doors = {}
	local front
	for name, x in ROOM.EntranceDoors do
		local info = DOORS[name]
		front = buildArch(folder, FACE, x, C.stone:Lerp(info.color, 0.3))
		local gui = screen(folder, name .. "Screen", Vector3.new(10, 4.4, 0.4), Vector3.new(x, doorTop + 4.8, FACE - 0.3), -Vector3.zAxis, info.color)
		bubbleText(gui, 4, {
			Name = "Title",
			Position = UDim2.fromScale(0.05, 0.05),
			Size = UDim2.fromScale(0.9, 0.42),
			Font = Enum.Font.FredokaOne,
			TextColor3 = info.color,
			Text = string.upper(name),
		})
		label(gui, {
			Name = "Info",
			Position = UDim2.fromScale(0.06, 0.5),
			Size = UDim2.fromScale(0.88, 0.2),
			Font = Enum.Font.FredokaOne,
			TextColor3 = C.white,
			Text = info.blurb,
		})
		local status = label(gui, {
			Name = "Status",
			Position = UDim2.fromScale(0.06, 0.74),
			Size = UDim2.fromScale(0.88, 0.18),
			Font = Enum.Font.FredokaOne,
			TextColor3 = C.aqua,
			Text = "",
		})
		local pad = glowPad(folder, x, front - 3.8, ROOM.DoorWidth, 6, info.color)
		pad.Name = name .. "Pad"
		table.insert(doors, { difficulty = name, pad = pad, status = status })
	end

	-- A party door on each wing: closed doors in a neon frame, a screen, a pad.
	local partyDoors = {}
	for i, x in { -33, 33 } do
		local width, height = 7, 10
		box(folder, "PartyFrame", Vector3.new(x - width / 2 - 0.8, TILE_TOP, FACE - 0.5), Vector3.new(x + width / 2 + 0.8, TILE_TOP + height + 0.8, FACE), C.iron)
		for _, side in { -1, 1 } do
			block(folder, "PartyDoor", Vector3.new(width / 2 - 0.05, height, 0.3), CFrame.new(x + side * width / 4, TILE_TOP + height / 2, FACE - 0.6), C.door, Enum.Material.Metal, {
				Reflectance = 0.15,
			})
		end
		strip(folder, Vector3.new(x - width / 2 - 0.8, TILE_TOP + height + 0.55, FACE - 0.6), Vector3.new(x + width / 2 + 0.8, TILE_TOP + height + 0.8, FACE - 0.5), C.aqua)
		for _, side in { -1, 1 } do
			local edge = x + side * (width / 2 + 0.8)
			strip(folder, Vector3.new(edge - 0.125, TILE_TOP, FACE - 0.6), Vector3.new(edge + 0.125, TILE_TOP + height + 0.8, FACE - 0.5), C.aqua)
		end

		local gui = screen(folder, "PartyScreen" .. i, Vector3.new(9, 3.8, 0.4), Vector3.new(x, TILE_TOP + height + 3.4, FACE - 0.3), -Vector3.zAxis, C.aqua)
		local title = bubbleText(gui, 4, {
			Name = "Title",
			Position = UDim2.fromScale(0.05, 0.06),
			Size = UDim2.fromScale(0.9, 0.48),
			Font = Enum.Font.FredokaOne,
			TextColor3 = C.aqua,
			Text = "PARTY",
		})
		local status = label(gui, {
			Name = "Status",
			Position = UDim2.fromScale(0.06, 0.6),
			Size = UDim2.fromScale(0.88, 0.3),
			Font = Enum.Font.FredokaOne,
			TextColor3 = C.white,
			Text = "Step on the pad to start a party",
		})
		local pad = glowPad(folder, x, FACE - 4.6, 7, 5, C.aqua)
		pad.Name = "PartyPad" .. i
		table.insert(partyDoors, { pad = pad, title = title, status = status })
	end

	prop(folder, "Planter", 2, -24.5, FACE - 2, 0)
	prop(folder, "Planter", 2, 24.5, FACE - 2, 0)
	return doors, partyDoors, front
end

-- The west wing: a tall brick wall with a flooded ground-floor window, and
-- the tank behind it. Returns the tank's bounds.
local function buildWestWing(folder)
	local tank = {
		min = Vector3.new(-HALF - WALL - 14, TILE_TOP - 1, Z0 + 28),
		max = Vector3.new(-HALF - WALL, TILE_TOP + 12, Z0 + 62),
		glassX = -HALF, -- the courtyard side of the window
	}
	tank.windowZ0, tank.windowZ1 = tank.min.Z + 2, tank.max.Z - 2
	local windowY0, windowY1 = TILE_TOP + 1, TILE_TOP + 10
	local wx0, wx1 = -HALF - WALL, -HALF
	local frame = 0.8

	box(folder, "WestWing", Vector3.new(wx0, BASE_Y, Z0), Vector3.new(wx1, windowY0, FACE), C.brick, BRICK)
	box(folder, "WestWing", Vector3.new(wx0, windowY1, Z0), Vector3.new(wx1, WING_TOP, FACE), C.brick, BRICK)
	box(folder, "WestWing", Vector3.new(wx0, windowY0, Z0), Vector3.new(wx1, windowY1, tank.windowZ0), C.brick, BRICK)
	box(folder, "WestWing", Vector3.new(wx0, windowY0, tank.windowZ1), Vector3.new(wx1, windowY1, FACE), C.brick, BRICK)
	box(folder, "WingCornice", Vector3.new(wx0 - 0.5, WING_TOP, Z0), Vector3.new(wx1 + 0.8, WING_TOP + 1, FACE), C.stone, Enum.Material.Concrete)
	strip(folder, Vector3.new(wx1, WING_TOP - 0.3, Z0), Vector3.new(wx1 + 0.15, WING_TOP, FACE), C.pink)
	strip(folder, Vector3.new(wx1, TILE_TOP, Z0), Vector3.new(wx1 + 0.15, TILE_TOP + 0.3, tank.windowZ0 - frame), C.aqua)
	strip(folder, Vector3.new(wx1, TILE_TOP, tank.windowZ1 + frame), Vector3.new(wx1 + 0.15, TILE_TOP + 0.3, FACE), C.aqua)
	box(folder, "Glass", Vector3.new(wx0, windowY0, tank.windowZ0), Vector3.new(wx0 + 0.4, windowY1, tank.windowZ1), C.glass, Enum.Material.Glass, {
		Transparency = 0.7,
		Reflectance = 0.2,
		CastShadow = false,
	})

	-- A stone frame and sill, with a thin aqua neon edge.
	local inner = wx1 + 0.5
	box(folder, "WindowFrame", Vector3.new(wx1, TILE_TOP, tank.windowZ0 - frame), Vector3.new(inner, windowY1 + frame, tank.windowZ0), C.stone, Enum.Material.Concrete, DECOR)
	box(folder, "WindowFrame", Vector3.new(wx1, TILE_TOP, tank.windowZ1), Vector3.new(inner, windowY1 + frame, tank.windowZ1 + frame), C.stone, Enum.Material.Concrete, DECOR)
	box(folder, "WindowFrame", Vector3.new(wx1, windowY1, tank.windowZ0), Vector3.new(inner, windowY1 + frame, tank.windowZ1), C.stone, Enum.Material.Concrete, DECOR)
	box(folder, "WindowSill", Vector3.new(wx1, TILE_TOP, tank.windowZ0), Vector3.new(inner + 0.4, windowY0, tank.windowZ1), C.stone, Enum.Material.Concrete, DECOR)
	local z0, z1, top = tank.windowZ0 - frame, tank.windowZ1 + frame, windowY1 + frame
	box(folder, "WindowEdge", Vector3.new(inner, TILE_TOP, z0 - 0.25), Vector3.new(inner + 0.1, top + 0.25, z0), C.aqua, Enum.Material.Neon, NEON)
	box(folder, "WindowEdge", Vector3.new(inner, TILE_TOP, z1), Vector3.new(inner + 0.1, top + 0.25, z1 + 0.25), C.aqua, Enum.Material.Neon, NEON)
	box(folder, "WindowEdge", Vector3.new(inner, top, z0), Vector3.new(inner + 0.1, top + 0.25, z1), C.aqua, Enum.Material.Neon, NEON)

	local plaque = signBoard(folder, "WindowSign", Vector3.new(14, 1.9, 0.2), Vector3.new(wx1 + 0.3, windowY1 + 2.3, (tank.windowZ0 + tank.windowZ1) / 2), Vector3.xAxis)
	label(plaque, { Position = UDim2.fromScale(0.04, 0.06), Size = UDim2.fromScale(0.92, 0.56), Font = Enum.Font.FredokaOne, TextColor3 = C.ink, Text = "FLOODED WING" })
	label(plaque, { Position = UDim2.fromScale(0.04, 0.64), Size = UDim2.fromScale(0.92, 0.3), Font = Enum.Font.FredokaOne, TextColor3 = C.pink, Text = "Please don't tap the glass" })

	-- Upstairs windows along the wing.
	local rng = Random.new(1958)
	for z = Z0 + 6, FACE - 4, 8 do
		window(folder, Vector3.new(wx1, TILE_TOP + 17, z), Vector3.xAxis, rng:NextNumber() < 0.35)
	end
	for _, z in { tank.windowZ0 - 5, tank.windowZ1 + 5 } do
		wallLamp(folder, Vector3.new(wx1 + 0.2, TILE_TOP + 9, z), Vector3.xAxis)
	end

	-- The tank: dark walls, a silty floor, rocks, weed and a glow from below.
	local t0, t1 = tank.min, tank.max
	box(folder, "TankBack", Vector3.new(t0.X - 1, t0.Y - 1, t0.Z - 1), Vector3.new(t0.X, t1.Y + 1, t1.Z + 1), C.tank, Enum.Material.CeramicTiles)
	box(folder, "TankFloor", Vector3.new(t0.X, t0.Y - 1, t0.Z - 1), Vector3.new(t1.X, t0.Y, t1.Z + 1), C.sand, Enum.Material.Sand)
	box(folder, "TankTop", Vector3.new(t0.X, t1.Y, t0.Z - 1), Vector3.new(t1.X, t1.Y + 1, t1.Z + 1), C.tank, Enum.Material.CeramicTiles)
	box(folder, "TankEnd", Vector3.new(t0.X, t0.Y, t0.Z - 1), Vector3.new(t1.X, t1.Y, t0.Z), C.tank, Enum.Material.CeramicTiles)
	box(folder, "TankEnd", Vector3.new(t0.X, t0.Y, t1.Z), Vector3.new(t1.X, t1.Y, t1.Z + 1), C.tank, Enum.Material.CeramicTiles)
	box(folder, "TankWater", t0, Vector3.new(t1.X, t1.Y - 0.6, t1.Z), C.tankWater, nil, {
		Transparency = 0.55,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	})
	for _ = 1, 6 do
		local size = rng:NextNumber(1, 2.2)
		local at = Vector3.new(rng:NextNumber(t0.X + 1.5, t1.X - 3), t0.Y + size * 0.3, rng:NextNumber(t0.Z + 2, t1.Z - 2))
		block(folder, "TankRock", Vector3.one * size, CFrame.new(at), C.rock, Enum.Material.Slate, { Shape = Enum.PartType.Ball, CanCollide = false, CanQuery = false })
	end
	for _ = 1, 10 do
		local height = rng:NextNumber(3, 7)
		local at = Vector3.new(rng:NextNumber(t0.X + 1, t0.X + 7), t0.Y + height / 2, rng:NextNumber(t0.Z + 1.5, t1.Z - 1.5))
		local lean = CFrame.Angles(rng:NextNumber(-0.15, 0.15), 0, rng:NextNumber(-0.15, 0.15))
		block(folder, "TankWeed", Vector3.new(0.3, height, 0.3), CFrame.new(at) * lean, C.weed, Enum.Material.Grass, DECOR)
	end
	for _, along in { 0.25, 0.75 } do
		glow(folder, Vector3.new((t0.X + t1.X) / 2, t0.Y + 0.6, t0.Z + (t1.Z - t0.Z) * along), C.tankLight, 18, 1.6)
	end

	-- Benches facing the window.
	for _, z in { tank.windowZ0 + 8, tank.windowZ1 - 8 } do
		bench(folder, CFrame.new(wx1 + 9, TILE_TOP + 1.6, z) * CFrame.Angles(0, math.pi / 2, 0))
	end
	return tank
end

-- The east side: a low wall with railings, the record boards on a tall
-- stretch of it under the RECORDS sign, and the float hut, which is the shop.
-- The shop's prompt sits on its own part, so it still works without the hut.
local function buildEastSide(folder)
	box(folder, "EastWall", Vector3.new(HALF, BASE_Y, Z0), Vector3.new(HALF + WALL, TILE_TOP + 3, FACE), C.brick, BRICK)
	box(folder, "EastCap", Vector3.new(HALF - 0.3, TILE_TOP + 3, Z0), Vector3.new(HALF + WALL + 0.3, TILE_TOP + 3.5, FACE), C.stone, Enum.Material.Concrete)
	for z = Z0 + 1, FACE - 1, 2 do
		block(folder, "Railing", Vector3.new(0.18, 3, 0.18), CFrame.new(HALF + 1, TILE_TOP + 5, z), C.iron, Enum.Material.Metal, DECOR)
	end
	block(folder, "RailingTop", Vector3.new(0.3, 0.3, FACE - Z0), CFrame.new(HALF + 1, TILE_TOP + 6.5, (Z0 + FACE) / 2), C.iron, Enum.Material.Metal, DECOR)
	box(folder, "EastBarrier", Vector3.new(HALF, TILE_TOP, Z0), Vector3.new(HALF + 1, TILE_TOP + 40, FACE), C.brick, nil, BARRIER)

	-- The record boards, on a tall stretch of the wall.
	local boards = {}
	local first, spacing, y = Z0 + 36, 12, TILE_TOP + 8.5
	local z0, z1 = first - 7, first + spacing * 3 + 7
	box(folder, "RecordsWall", Vector3.new(HALF - 0.5, BASE_Y, z0), Vector3.new(HALF + WALL, TILE_TOP + 18, z1), C.brick, BRICK)
	box(folder, "RecordsCornice", Vector3.new(HALF - 1, TILE_TOP + 18, z0 - 0.5), Vector3.new(HALF + WALL + 0.5, TILE_TOP + 19, z1 + 0.5), C.stone, Enum.Material.Concrete)
	strip(folder, Vector3.new(HALF - 0.65, TILE_TOP + 17.6, z0), Vector3.new(HALF - 0.5, TILE_TOP + 17.9, z1), C.pink)
	for i, id in { "Escapes", "Easy", "Normal", "Hard" } do
		local z = first + (i - 1) * spacing
		block(folder, "BoardGlow", Vector3.new(0.2, 8.6, 10.1), CFrame.new(HALF - 0.6, y, z), C.lemon, Enum.Material.Neon, NEON)
		block(folder, "BoardFrame", Vector3.new(0.3, 8.1, 9.6), CFrame.new(HALF - 0.8, y, z), C.ink)
		boards[id] = block(folder, "Board" .. id, Vector3.new(0.4, 7.5, 9), CFrame.new(HALF - 1, y, z), C.ink)
	end
	local holder = block(folder, "RecordsSign", Vector3.new(0.2, 3, 26), CFrame.new(HALF - 0.8, TILE_TOP + 15, first + spacing * 1.5), C.white, nil, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	})
	local gui = surface(holder, Enum.NormalId.Left, 30)
	gui.LightInfluence = 0
	bubbleText(gui, 5, { Size = UDim2.fromScale(1, 1), Font = Enum.Font.FredokaOne, TextColor3 = C.mint, Text = "RECORDS" })
	glow(folder, Vector3.new(HALF - 8, TILE_TOP + 10, first + spacing * 1.5), C.lemon, 24, 0.35)

	-- The shop.
	local hutX, hutZ = HALF - 10, FACE - 17
	prop(folder, "FloatHut", 8, hutX, hutZ, 90)
	glow(folder, Vector3.new(hutX - 5, TILE_TOP + 6, hutZ), C.warm, 14, 0.7)
	local counter = block(folder, "SwimShop", Vector3.new(3, 6, 8), CFrame.new(hutX - 1, TILE_TOP + 3, hutZ), C.lemon, nil, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OpenShop"
	prompt.ActionText = "Open shop"
	prompt.ObjectText = "Shop"
	prompt.KeyboardKeyCode = Enum.KeyCode.G -- E throws a pebble
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter
	return boards
end

-- The south side: an iron fence between stone pillars, a taller one in the
-- middle, with lamps on top.
local function buildSouthSide(folder)
	local z = Z0
	box(folder, "FenceBase", Vector3.new(-HALF - WALL, BASE_Y, z - 1), Vector3.new(HALF + WALL, TILE_TOP + 1.2, z), C.stone, Enum.Material.Concrete)
	for x = -HALF, HALF, 10 do
		local gatepost = math.abs(x) == 0
		local height = if gatepost then 9 else 7
		block(folder, "Pillar", Vector3.new(1.8, height, 1.8), CFrame.new(x, TILE_TOP + height / 2, z - 0.5), C.stone, Enum.Material.Concrete)
		local cap = block(folder, "PillarLamp", Vector3.one * 1.1, CFrame.new(x, TILE_TOP + height + 0.6, z - 0.5), C.globe, Enum.Material.Neon, {
			Shape = Enum.PartType.Ball,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
		})
		if x % 20 == 0 then
			local light = Instance.new("PointLight")
			light.Color = C.warm
			light.Range = 12
			light.Brightness = 0.45
			light.Parent = cap
		end
	end
	for x = -HALF + 1.2, HALF - 1.2, 1.2 do
		if math.abs(x % 10) > 1 and math.abs(x % 10) < 9 then
			block(folder, "FenceBar", Vector3.new(0.16, 5.6, 0.16), CFrame.new(x, TILE_TOP + 4, z - 0.5), C.iron, Enum.Material.Metal, DECOR)
		end
	end
	for _, y in { TILE_TOP + 1.8, TILE_TOP + 6.4 } do
		block(folder, "FenceRail", Vector3.new(ROOM.LobbyWidth, 0.25, 0.25), CFrame.new(0, y, z - 0.5), C.iron, Enum.Material.Metal, DECOR)
	end
	box(folder, "SouthBarrier", Vector3.new(-HALF, TILE_TOP, z - 1), Vector3.new(HALF, TILE_TOP + 40, z), C.stone, nil, BARRIER)
end

-- The courtyard: grass beds with palms, the lit path, benches, string lights,
-- puddles and the wet footprints.
local function buildCourtyard(folder, doorFront)
	local beds = {
		{ -40, -14, Z0 + 12, Z0 + 40 },
		{ 14, 40, Z0 + 12, Z0 + 40 },
		{ -40, -14, Z0 + 52, Z0 + 80 },
		{ 14, 34, Z0 + 52, Z0 + 76 },
	}
	for _, bed in beds do
		local x0, x1, z0, z1 = bed[1], bed[2], bed[3], bed[4]
		box(folder, "Curb", Vector3.new(x0, TILE_TOP, z0), Vector3.new(x1, TILE_TOP + 0.6, z1), C.stone, Enum.Material.Concrete)
		box(folder, "Grass", Vector3.new(x0 + 0.5, TILE_TOP + 0.6, z0 + 0.5), Vector3.new(x1 - 0.5, TILE_TOP + 0.65, z1 - 0.5), C.grass, Enum.Material.LeafyGrass)
		local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
		prop(folder, "PottedPalm", 8, cx - (x1 - x0) / 4, cz, 0)
		prop(folder, "PottedPalm", 7, cx + (x1 - x0) / 4, cz + 4, 40)
	end

	-- Stopping short of the building, so no lamp hides a door's screen.
	for z = Z0 + 14, -30, 16 do
		lampPost(folder, -8, z)
		lampPost(folder, 8, z)
	end
	for _, z in { Z0 + 30, Z0 + 62 } do
		bench(folder, CFrame.new(-10.5, TILE_TOP + 1.6, z) * CFrame.Angles(0, -math.pi / 2, 0))
		bench(folder, CFrame.new(10.5, TILE_TOP + 1.6, z) * CFrame.Angles(0, math.pi / 2, 0))
	end

	-- String lights from four tall poles, criss-crossing over the courtyard
	-- and up to the building. The poles keep clear of the window and boards.
	local height = TILE_TOP + 15
	local poles = {
		Vector3.new(-HALF + 3, height, Z0 + 6),
		Vector3.new(HALF - 3, height, Z0 + 6),
		Vector3.new(-HALF + 3, height, Z0 + 84),
		Vector3.new(HALF - 3, height, Z0 + 84),
	}
	for _, top in poles do
		block(folder, "LightPole", Vector3.new(0.4, top.Y - TILE_TOP, 0.4), CFrame.new(top.X, (TILE_TOP + top.Y) / 2, top.Z), C.iron, Enum.Material.Metal)
	end
	-- Tied to the roof edge, so they hang above the doors' screens.
	local anchors = { Vector3.new(-STAGE_HALF - 4, FACADE_TOP - 0.5, FACE - 0.9), Vector3.new(STAGE_HALF + 4, FACADE_TOP - 0.5, FACE - 0.9) }
	stringLights(folder, poles[1], poles[4], 3)
	stringLights(folder, poles[2], poles[3], 3)
	stringLights(folder, poles[3], poles[4], 2.5)
	stringLights(folder, poles[3], anchors[2], 3)
	stringLights(folder, poles[4], anchors[1], 3)

	for _, spot in { { -3, Z0 + 46, 5 }, { 12, Z0 + 20, 4 }, { -24, -18, 6 }, { 28, Z0 + 46, 4 }, { 2, -20, 3.5 } } do
		puddle(folder, spot[1], spot[2], spot[3])
	end
	local steps = 26
	local fromZ, toZ = Z0 + 26, doorFront - 8
	for i = 0, steps - 1 do
		local z = fromZ + (toZ - fromZ) * i / (steps - 1)
		local x = if i % 2 == 0 then -0.55 else 0.55
		block(folder, "Footprint", Vector3.new(0.04, 0.6, 0.6), CFrame.new(x, TILE_TOP + 0.06, z) * CFrame.Angles(0, 0, math.pi / 2), C.puddle, Enum.Material.Glass, {
			Shape = Enum.PartType.Cylinder,
			Transparency = 0.45,
			Reflectance = 0.4,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
		})
	end
end

-- Beyond the fence and walls: trees, and a dark skyline with a few lit windows.
local function buildSurroundings(folder)
	local rng = Random.new(2006)
	for x = -HALF - 10, HALF + 10, 11 do
		tree(folder, x + rng:NextNumber(-3, 3), Z0 - 12 - rng:NextNumber(0, 10), rng:NextNumber(0.9, 1.4))
	end
	for z = Z0, -10, 12 do
		tree(folder, HALF + 14 + rng:NextNumber(0, 10), z + rng:NextNumber(-3, 3), rng:NextNumber(0.9, 1.4))
		tree(folder, -HALF - 26 - rng:NextNumber(0, 10), z + rng:NextNumber(-3, 3), rng:NextNumber(0.9, 1.4))
	end
	for x = -180, 180, 45 do
		local width, height = rng:NextNumber(22, 40), rng:NextNumber(30, 75)
		local z = Z0 - 120 - rng:NextNumber(0, 60)
		box(folder, "Skyline", Vector3.new(x - width / 2, TILE_TOP - 1, z - 20), Vector3.new(x + width / 2, TILE_TOP + height, z), C.skyline, Enum.Material.Concrete, DECOR)
		for _ = 1, 10 do
			if rng:NextNumber() < 0.6 then
				local at = Vector3.new(x + rng:NextNumber(-width / 2 + 2, width / 2 - 2), TILE_TOP + rng:NextNumber(6, height - 4), z + 0.1)
				block(folder, "SkylineWindow", Vector3.new(1.6, 2.2, 0.1), CFrame.new(at), if rng:NextNumber() < 0.8 then C.windowLit else C.aqua, Enum.Material.Neon, NEON)
			end
		end
	end
end

function LobbyBuilder.build(map)
	local folder = Instance.new("Folder")
	folder.Name = "Lobby"
	folder.Parent = map

	buildGround(folder)
	local doors, partyDoors, doorFront = buildFacade(folder)
	local tank = buildWestWing(folder)
	local boards = buildEastSide(folder)
	buildSouthSide(folder)
	buildCourtyard(folder, doorFront)
	buildSurroundings(folder)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(8, 0.2, 8)
	spawn.CFrame = CFrame.new(0, TILE_TOP + 0.1, Z0 + 20) * CFrame.Angles(0, math.pi, 0)
	spawn.Color = C.lemon
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = folder

	-- Walking through any of stage 1's doors starts the run timer (Progress.luau).
	local runStart = block(folder, "RunStart", Vector3.new(ROOM.Width, ROOM.DoorHeight, 2), CFrame.new(0, TILE_TOP + ROOM.DoorHeight / 2, 1.5), C.lemon, nil, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})

	return { boards = boards, tank = tank, runStart = runStart, doors = doors, partyDoors = partyDoors }
end

return LobbyBuilder
