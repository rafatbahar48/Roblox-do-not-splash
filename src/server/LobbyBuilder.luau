-- The lobby, z from -LobbyLength to 0: an open courtyard at night in front of
-- the old building the stages are in. No roof, just the night sky; lamp posts,
-- string lights and neon instead (client/Mood.luau does the lighting).
--
--   the building   brick, with lit windows and the game's sign in neon, and
--                  five shut doors (Config.Doors), each with a glowing pad
--                  and a screen (server/Parties.luau): three stone archways
--                  in the middle for parties, an Easy door on the left wing
--                  and a practice door on the right
--   west wing      more of the building: brick, rows of mostly dark windows
--   east wall      the record boards (Leaderboards.luau), and the shop: a
--                  snowy log cottage with Christmas lights
--   courtyard      paving, a lit path to the doors, grass beds with palms,
--                  benches, puddles, and wet footprints leading inside
--   beyond         an iron fence, trees and a dark skyline
--
-- While Config.Christmas is on it is winter: snow on the ground and on
-- every ledge (a path shovelled to the doors), Christmas trees in the beds
-- instead of palms, presents, wreaths on the doors, and piles of snowballs
-- (Christmas.luau, Snowballs.luau).
--
-- Everything is built from parts here except the props made in Meshy (the
-- shop's cottage, palms, planters), which are imported into the place and kept in
-- ServerStorage.LobbyProps; a missing one is skipped. Returns the pieces other
-- modules need.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Christmas = require(script.Parent.Christmas)
local Parts = require(script.Parent.Parts)
local UiArt = require(ReplicatedStorage.Shared.UiArt)

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
local XMAS = Config.Christmas
local CLEARED = -16 -- in winter, the snow stops this far from the building, clear of every pad

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
	sky = Color3.fromRGB(99, 201, 255),
	lemon = Color3.fromRGB(255, 221, 74),
	candy = Color3.fromRGB(255, 111, 177),
	ink = Color3.fromRGB(43, 34, 87),
	white = Color3.fromRGB(250, 252, 252),
	door = Color3.fromRGB(70, 76, 110),
	oak = Color3.fromRGB(78, 56, 44), -- the archways' doors
	puddle = Color3.fromRGB(110, 140, 200),
	ice = Color3.fromRGB(190, 220, 245),
	snowGround = Color3.fromRGB(214, 224, 242),
}

-- Each kind of door's colour and what its screen says (Config.Doors). The
-- screens never say what is inside.
local DOOR_LOOKS = {
	easy = { title = "EASY", color = C.mint, blurb = "Quieter steps. More room for mistakes." },
	party = { title = "PARTY", color = C.lemon, blurb = "Normal or Hard, up to " .. Config.Party.MaxSize .. " together." },
	practice = { title = "PRACTICE", color = C.sky, blurb = "Nothing out there. No coins or records." },
}

-- The shop's cottage, a Meshy model (CottageShop): where its middle stands,
-- how tall it is (chimney included), how far it turns so its front faces the
-- courtyard, and, measured from its middle on the ground, where the board
-- above its awning is (the SHOP sign goes there), where its counter window
-- is, and where its painted Christmas lights run along the front.
-- It fits between the Easy door's pad and the string lights' pole behind it.
local SHOP = {
	at = Vector3.new(HALF - 6.8, TILE_TOP, FACE - 15.8),
	height = 15,
	yaw = 90, -- the model's front faces -Z; this turns it to -X
	sign = { at = Vector3.new(-5.6, 9, -3.75), width = 7.5 },
	counter = Vector3.new(-5.4, 4.2, -4.2),
	lights = { Vector3.new(-5.7, 9.6, 5.8), Vector3.new(-5.7, 9.6, 2.1), Vector3.new(-5.7, 9.6, -1.7), Vector3.new(-5.7, 9.6, -5.4) },
}
local LIGHT_COLORS = { Color3.fromRGB(255, 80, 80), Color3.fromRGB(110, 255, 140), Color3.fromRGB(255, 210, 90), Color3.fromRGB(120, 160, 255) }

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
	block(folder, "Puddle", Vector3.new(0.06, size, size), CFrame.new(x, TILE_TOP + 0.03, z) * CFrame.Angles(0, 0, math.pi / 2), if XMAS then C.ice else C.puddle, if XMAS then Enum.Material.Ice else Enum.Material.Glass, {
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
	if XMAS then
		Christmas.snow(folder, Vector3.new(x - 0.6, TILE_TOP + 11.75, z - 0.6), Vector3.new(x + 0.6, TILE_TOP + 12, z + 0.6))
	end
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
	if XMAS then
		Christmas.snowSlab(folder, Vector3.new(4.8, 0.16, 1.6), cframe * CFrame.new(0, 0.16, 0))
		Christmas.snowSlab(folder, Vector3.new(4.8, 0.14, 0.3), cframe * CFrame.new(0, 1.45, 0.98) * CFrame.Angles(math.rad(-10), 0, 0))
	end
end

-- A dark tree, for the edges of the world.
local function tree(folder, x, z, scale)
	local y = TILE_TOP - 0.2
	block(folder, "Trunk", Vector3.new(1, 7 * scale, 1), CFrame.new(x, y + 3.5 * scale, z), C.trunk, Enum.Material.Wood, DECOR)
	block(folder, "Canopy", Vector3.one * 8 * scale, CFrame.new(x, y + 9 * scale, z), C.leaves, Enum.Material.LeafyGrass, { Shape = Enum.PartType.Ball, CanCollide = false, CanQuery = false })
	block(folder, "Canopy", Vector3.one * 6 * scale, CFrame.new(x + 2 * scale, y + 11.5 * scale, z - scale), C.leaves, Enum.Material.LeafyGrass, { Shape = Enum.PartType.Ball, CanCollide = false, CanQuery = false })
	if XMAS then
		Christmas.snowBall(folder, Vector3.new(x, y + 10.4 * scale, z), 6.4 * scale)
		Christmas.snowBall(folder, Vector3.new(x + 2 * scale, y + 12.6 * scale, z - scale), 4.6 * scale)
	end
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
	-- Around the courtyard: grass, or in winter snow.
	local outside = if XMAS then C.snowGround else C.ground
	local outsideMaterial = if XMAS then Enum.Material.Snow else Enum.Material.LeafyGrass
	box(folder, "Ground", Vector3.new(-400, y0, -500), Vector3.new(400, y1, Z0), outside, outsideMaterial, grass)
	box(folder, "Ground", Vector3.new(-400, y0, Z0), Vector3.new(-HALF - 20, y1, 0), outside, outsideMaterial, grass)
	box(folder, "Ground", Vector3.new(HALF, y0, Z0), Vector3.new(400, y1, 0), outside, outsideMaterial, grass)
	box(folder, "Ground", Vector3.new(-400, y0, 0), Vector3.new(-STAGE_HALF - 2, y1, 400), C.ground, Enum.Material.LeafyGrass, grass)
	box(folder, "Ground", Vector3.new(STAGE_HALF + 2, y0, 0), Vector3.new(400, y1, 400), C.ground, Enum.Material.LeafyGrass, grass)

	if XMAS then
		-- Snow over the courtyard, either side of the path, stopping short
		-- of the building so every door's pad stays clear; drifts along the
		-- walls and fence.
		local top = TILE_TOP + 0.25
		Christmas.snow(folder, Vector3.new(-HALF, TILE_TOP, Z0), Vector3.new(-6, top, CLEARED), true)
		Christmas.snow(folder, Vector3.new(6, TILE_TOP, Z0), Vector3.new(HALF, top, CLEARED), true)
		local rng = Random.new(1225)
		for z = Z0 + 4, -30, 9 do -- short of the shop's cottage
			Christmas.mound(folder, -HALF + rng:NextNumber(1.5, 3), z + rng:NextNumber(-2, 2), rng:NextNumber(2, 3.4), top)
			Christmas.mound(folder, HALF - rng:NextNumber(1.5, 3), z + rng:NextNumber(-2, 2), rng:NextNumber(2, 3.4), top)
		end
		for x = -HALF + 6, HALF - 6, 9 do
			if math.abs(x) > 9 then
				Christmas.mound(folder, x + rng:NextNumber(-2, 2), Z0 + rng:NextNumber(1.5, 3), rng:NextNumber(2, 3.4), top)
			end
		end
	end
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
	if XMAS then
		-- Snow lying along the top of the arch, where it is flat enough to stay.
		for i = 0, segments - 1 do
			local a = (i + 0.5) * math.pi / segments
			if a > math.rad(30) and a < math.rad(150) then
				local at = CFrame.new(mid * math.cos(a), straight + mid * math.sin(a), 0) * CFrame.Angles(0, 0, a - math.pi / 2)
				Christmas.snowSlab(folder, Vector3.new(2 * mid * math.sin(math.pi / segments / 2) + 0.12, 0.3, depth + 0.1), origin * at * CFrame.new(0, thickness / 2 + 0.12, 0))
			end
		end
	end
	return face - depth
end

-- A pair of heavy oak doors, shut, filling the doorway behind an archway at
-- x, with iron bands and knobs.
local function shutDoors(folder, x)
	local w, h = ROOM.DoorWidth, ROOM.DoorHeight
	local z = FACE + 0.3
	for _, side in { -1, 1 } do
		local cx = x + side * w / 4
		block(folder, "ArchDoor", Vector3.new(w / 2 - 0.06, h, 0.4), CFrame.new(cx, TILE_TOP + h / 2, z), C.oak, Enum.Material.WoodPlanks)
		for _, y in { 2.2, h - 3.4 } do
			block(folder, "DoorBand", Vector3.new(w / 2 - 0.3, 0.35, 0.1), CFrame.new(cx, TILE_TOP + y, z - 0.25), C.iron, Enum.Material.Metal, DECOR)
		end
		block(folder, "DoorKnob", Vector3.one * 0.5, CFrame.new(x + side * 0.6, TILE_TOP + 4.6, z - 0.35), C.iron, Enum.Material.Metal, {
			Shape = Enum.PartType.Ball,
			CanCollide = false,
			CanQuery = false,
		})
	end
	if XMAS then
		Christmas.wreath(folder, Vector3.new(x, TILE_TOP + 7.2, z - 0.45), -Vector3.zAxis, 1.1)
	end
end

-- A door on a wing at x: shut metal doors in a frame lined with neon.
local function wingDoor(folder, x, color)
	local width, height = 7, 10
	box(folder, "WingDoorFrame", Vector3.new(x - width / 2 - 0.8, TILE_TOP, FACE - 0.5), Vector3.new(x + width / 2 + 0.8, TILE_TOP + height + 0.8, FACE), C.iron)
	for _, side in { -1, 1 } do
		block(folder, "WingDoor", Vector3.new(width / 2 - 0.05, height, 0.3), CFrame.new(x + side * width / 4, TILE_TOP + height / 2, FACE - 0.6), C.door, Enum.Material.Metal, {
			Reflectance = 0.15,
		})
	end
	strip(folder, Vector3.new(x - width / 2 - 0.8, TILE_TOP + height + 0.55, FACE - 0.6), Vector3.new(x + width / 2 + 0.8, TILE_TOP + height + 0.8, FACE - 0.5), color)
	for _, side in { -1, 1 } do
		local edge = x + side * (width / 2 + 0.8)
		strip(folder, Vector3.new(edge - 0.125, TILE_TOP, FACE - 0.6), Vector3.new(edge + 0.125, TILE_TOP + height + 0.8, FACE - 0.5), color)
	end
	if XMAS then
		Christmas.wreath(folder, Vector3.new(x, TILE_TOP + 7.2, FACE - 0.95), -Vector3.zAxis, 1.1)
	end
end

-- The building's front: brick, lit windows, the game's sign, and the doors
-- (Config.Doors), each with a screen and a pad. Returns the doors, for
-- Parties.luau, and the z of the archways' fronts.
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
	-- They carry on far past the courtyard, so nothing behind the building
	-- (the forest, and what lives there) can be seen from the lobby.
	local wingEnd = Config.Forest.SceneryHalfWidth + 20
	box(folder, "FacadeWing", Vector3.new(-wingEnd, BASE_Y, FACE), Vector3.new(-STAGE_HALF, FACADE_TOP, 10), C.brick, BRICK)
	box(folder, "FacadeWing", Vector3.new(STAGE_HALF, BASE_Y, FACE), Vector3.new(wingEnd, FACADE_TOP, 10), C.brick, BRICK)
	box(folder, "Cornice", Vector3.new(-wingEnd - 0.6, FACADE_TOP, FACE - 0.8), Vector3.new(wingEnd + 0.6, FACADE_TOP + 1.2, 10), C.stone, Enum.Material.Concrete)
	if XMAS then
		Christmas.snow(folder, Vector3.new(-wingEnd - 0.6, FACADE_TOP + 1.2, FACE - 1), Vector3.new(wingEnd + 0.6, FACADE_TOP + 1.8, 10))
	end
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
	local sign = screen(folder, "GameSign", Vector3.new(40, 7, 0.4), Vector3.new(0, TILE_TOP + 22.8, FACE - 0.3), -Vector3.zAxis, C.pink)
	bubbleText(sign, 6, { Position = UDim2.fromScale(0.03, 0.06), Size = UDim2.fromScale(0.94, 0.62), Font = Enum.Font.FredokaOne, TextColor3 = C.lemon, Text = string.upper(Config.GameName) })
	label(sign, { Position = UDim2.fromScale(0.08, 0.72), Size = UDim2.fromScale(0.84, 0.2), Font = Enum.Font.FredokaOne, TextColor3 = C.aqua, Text = Config.Tagline })
	glow(folder, Vector3.new(0, TILE_TOP + 22, FACE - 6), C.pink, 22, 0.4)

	-- The doors, each with a screen over it and a pad in front.
	local doors = {}
	local front = FACE
	for i, spec in Config.Doors do
		local look = DOOR_LOOKS[spec.mode]
		local x = spec.x
		local padZ
		if table.find(ROOM.EntranceDoors, x) then
			front = buildArch(folder, FACE, x, C.stone:Lerp(look.color, 0.3))
			shutDoors(folder, x)
			padZ = front - 3.8
		else
			wingDoor(folder, x, look.color)
			padZ = FACE - 4.6
		end
		local gui = screen(folder, "DoorScreen" .. i, Vector3.new(10, 4.4, 0.4), Vector3.new(x, doorTop + 4.8, FACE - 0.3), -Vector3.zAxis, look.color)
		local title = bubbleText(gui, 4, {
			Name = "Title",
			Position = UDim2.fromScale(0.05, 0.05),
			Size = UDim2.fromScale(0.9, 0.42),
			Font = Enum.Font.FredokaOne,
			TextColor3 = look.color,
			Text = look.title,
		})
		label(gui, {
			Name = "Info",
			Position = UDim2.fromScale(0.06, 0.5),
			Size = UDim2.fromScale(0.88, 0.2),
			Font = Enum.Font.FredokaOne,
			TextColor3 = C.white,
			Text = look.blurb,
		})
		local status = label(gui, {
			Name = "Status",
			Position = UDim2.fromScale(0.06, 0.74),
			Size = UDim2.fromScale(0.88, 0.18),
			Font = Enum.Font.FredokaOne,
			TextColor3 = C.aqua,
			Text = "",
		})
		local pad = glowPad(folder, x, padZ, ROOM.DoorWidth, 6, look.color)
		pad.Name = "DoorPad" .. i
		table.insert(doors, { mode = spec.mode, x = x, pad = pad, title = title, status = status })
	end

	if XMAS then
		local treeRng = Random.new(2512)
		for _, x in { -24.5, 24.5 } do
			Christmas.tree(folder, x, FACE - 3, 7, treeRng)
		end
	else
		prop(folder, "Planter", 2, -24.5, FACE - 2, 0)
		prop(folder, "Planter", 2, 24.5, FACE - 2, 0)
	end
	return doors, front
end

-- The west wing: more of the old building, a tall brick wall with two rows of
-- windows, most of them dark.
local function buildWestWing(folder)
	local wx0, wx1 = -HALF - WALL, -HALF
	box(folder, "WestWing", Vector3.new(wx0, BASE_Y, Z0), Vector3.new(wx1, WING_TOP, FACE), C.brick, BRICK)
	box(folder, "WingCornice", Vector3.new(wx0 - 0.5, WING_TOP, Z0), Vector3.new(wx1 + 0.8, WING_TOP + 1, FACE), C.stone, Enum.Material.Concrete)
	if XMAS then
		Christmas.snow(folder, Vector3.new(wx0 - 0.5, WING_TOP + 1, Z0), Vector3.new(wx1 + 1, WING_TOP + 1.5, FACE))
	end
	strip(folder, Vector3.new(wx1, WING_TOP - 0.3, Z0), Vector3.new(wx1 + 0.15, WING_TOP, FACE), C.pink)
	strip(folder, Vector3.new(wx1, TILE_TOP, Z0), Vector3.new(wx1 + 0.15, TILE_TOP + 0.3, FACE), C.aqua)

	local rng = Random.new(1958)
	for z = Z0 + 6, FACE - 4, 8 do
		window(folder, Vector3.new(wx1, TILE_TOP + 6, z), Vector3.xAxis, rng:NextNumber() < 0.2)
		window(folder, Vector3.new(wx1, TILE_TOP + 17, z), Vector3.xAxis, rng:NextNumber() < 0.35)
	end
	for _, z in { Z0 + 25, Z0 + 65 } do
		wallLamp(folder, Vector3.new(wx1 + 0.2, TILE_TOP + 10, z), Vector3.xAxis)
	end
end

-- The shop (SHOP): the cottage, its SHOP sign (SpriteCook art) on the board
-- above its awning, light glowing from its window and its painted Christmas
-- lights, and the shop's prompt at its counter, which works even without the
-- model.
local function buildShop(folder)
	prop(folder, "CottageShop", SHOP.height, SHOP.at.X, SHOP.at.Z, SHOP.yaw)
	local function spot(offset)
		return SHOP.at + offset
	end
	local function lightAt(at, color, range, brightness)
		local holder = block(folder, "ShopLight", Vector3.one * 0.2, CFrame.new(at), color, nil, {
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

	-- The sign, flat on the board, facing the courtyard (-X).
	local art = UiArt.size("shop_sign")
	local width = SHOP.sign.width
	local board = block(folder, "ShopSign", Vector3.new(0.1, width * art.Y / art.X, width), CFrame.new(spot(SHOP.sign.at)), C.white, nil, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	local gui = surface(board, Enum.NormalId.Left, 40)
	gui.LightInfluence = 0.25
	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(1, 1)
	UiArt.apply(image, "shop_sign")
	image.Parent = gui

	lightAt(spot(SHOP.counter) + Vector3.new(1.5, 1.5, 0), C.warm, 14, 1)
	lightAt(spot(SHOP.counter) - Vector3.new(5, -4, 0), C.warm, 20, 0.5)
	for i, offset in SHOP.lights do
		lightAt(spot(offset), LIGHT_COLORS[(i - 1) % #LIGHT_COLORS + 1], 9, 0.6)
	end

	local counter = block(folder, "ShopCounter", Vector3.new(3, 6, 7), CFrame.new(spot(SHOP.counter) - Vector3.new(1.5, 0, 0)), C.lemon, nil, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OpenShop"
	prompt.ActionText = "Open shop"
	prompt.ObjectText = "Shop"
	prompt.KeyboardKeyCode = Enum.KeyCode.G -- E throws
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter
end

-- The east side: a low wall with railings, the record boards on a tall
-- stretch of it under the RECORDS sign, and the shop (buildShop).
local function buildEastSide(folder)
	box(folder, "EastWall", Vector3.new(HALF, BASE_Y, Z0), Vector3.new(HALF + WALL, TILE_TOP + 3, FACE), C.brick, BRICK)
	box(folder, "EastCap", Vector3.new(HALF - 0.3, TILE_TOP + 3, Z0), Vector3.new(HALF + WALL + 0.3, TILE_TOP + 3.5, FACE), C.stone, Enum.Material.Concrete)
	if XMAS then
		Christmas.snow(folder, Vector3.new(HALF - 0.4, TILE_TOP + 3.5, Z0), Vector3.new(HALF + WALL + 0.4, TILE_TOP + 3.85, FACE))
	end
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
	if XMAS then
		Christmas.snow(folder, Vector3.new(HALF - 1.1, TILE_TOP + 19, z0 - 0.5), Vector3.new(HALF + WALL + 0.5, TILE_TOP + 19.5, z1 + 0.5))
	end
	strip(folder, Vector3.new(HALF - 0.65, TILE_TOP + 17.6, z0), Vector3.new(HALF - 0.5, TILE_TOP + 17.9, z1), C.pink)
	-- Each board glows softly in its header's colour (Leaderboards.luau).
	local glows = { Escapes = C.sky, Easy = C.mint, Normal = C.lemon, Hard = C.candy }
	for i, id in { "Escapes", "Easy", "Normal", "Hard" } do
		local z = first + (i - 1) * spacing
		block(folder, "BoardGlow", Vector3.new(0.2, 8.6, 10.1), CFrame.new(HALF - 0.6, y, z), glows[id]:Lerp(Color3.new(), 0.45), Enum.Material.Neon, NEON)
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

	buildShop(folder)
	return boards
end

-- The south side: an iron fence between stone pillars, a taller one in the
-- middle, with lamps on top.
local function buildSouthSide(folder)
	local z = Z0
	box(folder, "FenceBase", Vector3.new(-HALF - WALL, BASE_Y, z - 1), Vector3.new(HALF + WALL, TILE_TOP + 1.2, z), C.stone, Enum.Material.Concrete)
	if XMAS then
		Christmas.snow(folder, Vector3.new(-HALF - WALL, TILE_TOP + 1.2, z - 1.05), Vector3.new(HALF + WALL, TILE_TOP + 1.5, z + 0.05))
	end
	for x = -HALF, HALF, 10 do
		local gatepost = math.abs(x) == 0
		local height = if gatepost then 9 else 7
		block(folder, "Pillar", Vector3.new(1.8, height, 1.8), CFrame.new(x, TILE_TOP + height / 2, z - 0.5), C.stone, Enum.Material.Concrete)
		if XMAS then
			Christmas.snow(folder, Vector3.new(x - 0.95, TILE_TOP + height, z - 1.45), Vector3.new(x + 0.95, TILE_TOP + height + 0.3, z + 0.45))
		end
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

-- The courtyard: grass beds with palms (Christmas trees in winter), the lit
-- path, benches, string lights, puddles and the wet footprints, and in
-- winter piles of snowballs. Returns the piles' prompts.
local function buildCourtyard(folder, doorFront)
	local beds = {
		{ -40, -14, Z0 + 12, Z0 + 40 },
		{ 14, 40, Z0 + 12, Z0 + 40 },
		{ -40, -14, Z0 + 52, Z0 + 80 },
		{ 14, 34, Z0 + 52, Z0 + 76 },
	}
	local rng = Random.new(2412)
	for i, bed in beds do
		local x0, x1, z0, z1 = bed[1], bed[2], bed[3], bed[4]
		box(folder, "Curb", Vector3.new(x0, TILE_TOP, z0), Vector3.new(x1, TILE_TOP + 0.6, z1), C.stone, Enum.Material.Concrete)
		box(folder, "Grass", Vector3.new(x0 + 0.5, TILE_TOP + 0.6, z0 + 0.5), Vector3.new(x1 - 0.5, TILE_TOP + 0.65, z1 - 0.5), C.grass, Enum.Material.LeafyGrass)
		local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
		if not XMAS then
			prop(folder, "PottedPalm", 8, cx - (x1 - x0) / 4, cz, 0)
			prop(folder, "PottedPalm", 7, cx + (x1 - x0) / 4, cz + 4, 40)
		else
			local bedTop = TILE_TOP + 0.65
			Christmas.snow(folder, Vector3.new(x0, TILE_TOP + 0.6, z0), Vector3.new(x1, bedTop + 0.25, z1), true)
			if i == 3 then
				-- The big one, nearest the doors, with presents under it.
				Christmas.tree(folder, cx, cz, 20, rng, bedTop + 0.25)
				Christmas.presents(folder, cx, cz, 6.5, 9, rng, bedTop + 0.25)
			else
				Christmas.tree(folder, cx - (x1 - x0) / 4, cz, 11, rng, bedTop + 0.25)
				Christmas.tree(folder, cx + (x1 - x0) / 4, cz + 4, 9, rng, bedTop + 0.25)
				Christmas.presents(folder, cx + (x1 - x0) / 4, cz + 4, 3.2, 3, rng, bedTop + 0.25)
			end
		end
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
	-- and up to the building. The poles keep clear of the record boards.
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

	-- Piles of snowballs to grab from: near the spawn, by the benches and
	-- near the doors, all in the snow.
	local piles = {}
	if XMAS then
		for _, spot in { { 11, Z0 + 6 }, { -11, -58 }, { -30, -22 } } do
			table.insert(piles, Christmas.snowballPile(folder, spot[1], spot[2]))
		end
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
	return piles
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
		if XMAS then
			Christmas.snow(folder, Vector3.new(x - width / 2 - 0.3, TILE_TOP + height, z - 20.3), Vector3.new(x + width / 2 + 0.3, TILE_TOP + height + 0.8, z + 0.3))
		end
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
	local doors, doorFront = buildFacade(folder)
	buildWestWing(folder)
	local boards = buildEastSide(folder)
	buildSouthSide(folder)
	local snowPiles = buildCourtyard(folder, doorFront)
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

	return { boards = boards, partyDoors = doors, snowPiles = snowPiles }
end

return LobbyBuilder
