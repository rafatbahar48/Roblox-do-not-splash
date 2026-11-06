-- The lobby, z < 0: an abandoned expedition outpost on boardwalks over a
-- black swamp at night, in front of the wooded ridge that hides the stages
-- (the forest, and what lives there, is on the other side of it, z > 0).
-- You arrive on the boardwalk at the front, facing the lodge.
--
--   the lodge          old timber, two floors: the game's sign on its gable,
--                      a balcony across the front, inside a hall with a fire
--                      and a stair up to a gallery; the record boards
--                      (Leaderboards.luau) on its left side
--   skins              under the balcony, the premium skins on lit
--                      mannequins with their prices; their prompts open the
--                      shop's Premium tab (client/ShopUi.luau), and
--                      client/SkinMoves.luau gives them their moves
--   shop               a supply store against the lodge's right side; its
--                      counter's prompt opens the shop
--   party station      on the left, under an awning: two party pads
--                      (Config.Doors), each with its board
--   launch adventure   on the right, a mine tunnel into the rock with a
--                      green glow far inside: two party pads and the practice
--                      pad in its mouth. A party that sets
--                      off from any pad goes to the cave at the start of
--                      stage 1, as always (server/Parties.luau).
--   watchtowers        two, each joined to the lodge's upper floor by a
--                      rope bridge
--   the swamp          terrain water all round, mud islands, dead trees,
--                      reeds and lily pads, mist lying on the water and
--                      fireflies; the ridge is terrain, with trees along it
--
-- Everyone stays on the boardwalks: their edges have railings and invisible
-- walls, and anyone who gets into the water anyway is put back at the
-- spawn. client/Mood.luau does the lighting, client/LobbyLife.luau makes the
-- lanterns flicker.
--
-- While Config.Christmas is on there are piles of snowballs on the
-- boardwalks (Snowballs.luau); the outpost itself has no snow. Everything is
-- parts and terrain except the dead trees, the Meshy models in
-- ServerStorage.ForestProps (Forest.luau builds them from parts without).
-- Returns the pieces other modules need.

local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config)
local OutfitLook = require(ReplicatedStorage.Shared.OutfitLook)
local SkinLook = require(ReplicatedStorage.Shared.SkinLook)
local Christmas = require(script.Parent.Christmas)
local Forest = require(script.Parent.Forest)
local Parts = require(script.Parent.Parts)

local block, box = Parts.block, Parts.box

local ROOM = Config.Room
local SURFACE_Y = ROOM.SurfaceY
local FLOOR_Y = SURFACE_Y - ROOM.PoolDepth
local DECK = SURFACE_Y + ROOM.TileHeight -- the boardwalks' top, where the snowball piles stand too
local FOOT = FLOOR_Y - 1 -- where posts stand in the mud
local WALL = 0.8 -- how thick the buildings' walls are

-- Where everything is. x is across (+x is on your left as you face the
-- lodge from the spawn); z runs back toward the ridge.
local LODGE = {
	x0 = -24, -- its right wall
	x1 = 32, -- its left wall
	front = -60,
	back = -26,
	floor2 = DECK + 14, -- the top of the upper floor and the balcony
	eave = DECK + 25,
	gallery = -44, -- the upper floor covers the front of the hall, from the front wall to here
	balcony = -66, -- the balcony's front edge
	over = 2, -- how far the roof reaches past the side walls
}
LODGE.mid = (LODGE.x0 + LODGE.x1) / 2
LODGE.peak = LODGE.eave + 16
LODGE.slope = (LODGE.peak - LODGE.eave) / (LODGE.x1 - LODGE.mid)
local BAY = { x0 = 3, x1 = 27, back = -55, top = DECK + 10 } -- the skins' display, in the lodge's front
local DOOR = { x0 = -9, x1 = -3, top = DECK + 9 } -- the lodge's front door
local SHOP = { x0 = -44, x1 = -24, front = -64, back = -46 }
local PARTY = { x0 = 44, x1 = 72, z0 = -104, z1 = -70, top = DECK + 0.4 }
local GATE = { x = -70, z = -70, half = 9, height = 13, depth = 33 } -- x, z: the middle of the tunnel's mouth
-- The two watchtowers, and their bridges from the lodge's upper floor.
local TOWERS = {
	{ x = 60, z = -54, from = Vector3.new(34, 0, -63), to = Vector3.new(54, 0, -57.5) },
	{ x = -34, z = -36, from = Vector3.new(-24.4, 0, -52), to = Vector3.new(-31.5, 0, -42) },
}
local SPAWN = Vector3.new(8, DECK, -124)

local C = {
	plank = Color3.fromRGB(86, 70, 54),
	plankGray = Color3.fromRGB(98, 92, 82),
	under = Color3.fromRGB(20, 18, 16),
	post = Color3.fromRGB(54, 44, 36),
	siding = Color3.fromRGB(72, 55, 42),
	sidingGray = Color3.fromRGB(86, 80, 72),
	beam = Color3.fromRGB(50, 38, 30),
	trim = Color3.fromRGB(40, 31, 25),
	shingle = Color3.fromRGB(72, 68, 64),
	roofMoss = Color3.fromRGB(58, 74, 46),
	moss = Color3.fromRGB(62, 80, 46),
	hangingMoss = Color3.fromRGB(104, 112, 84),
	rope = Color3.fromRGB(122, 100, 70),
	iron = Color3.fromRGB(30, 29, 30),
	rust = Color3.fromRGB(92, 58, 40),
	stone = Color3.fromRGB(82, 80, 78),
	bark = Color3.fromRGB(56, 52, 48),
	barkDark = Color3.fromRGB(38, 36, 34),
	crate = Color3.fromRGB(104, 82, 58),
	barrel = Color3.fromRGB(84, 60, 42),
	banner = Color3.fromRGB(96, 30, 28),
	bannerPale = Color3.fromRGB(176, 156, 132),
	awning = Color3.fromRGB(104, 42, 34),
	cloth = Color3.fromRGB(34, 40, 36), -- behind the mannequins
	rug = Color3.fromRGB(86, 34, 30),
	paper = Color3.fromRGB(190, 172, 134),
	ink = Color3.fromRGB(70, 52, 38),
	signBoard = Color3.fromRGB(62, 46, 34),
	signText = Color3.fromRGB(234, 224, 202),
	signStroke = Color3.fromRGB(26, 18, 12),
	blood = Color3.fromRGB(156, 22, 18),
	bottleGreen = Color3.fromRGB(46, 84, 52),
	bottleBrown = Color3.fromRGB(96, 60, 30),
	-- Neon shows far brighter than its colour, so the glowing bits are set dark.
	glass = Color3.fromRGB(125, 92, 44), -- lantern glass
	windowLit = Color3.fromRGB(104, 66, 30),
	windowDark = Color3.fromRGB(22, 26, 32),
	ember = Color3.fromRGB(150, 60, 20),
	greenGlow = Color3.fromRGB(24, 80, 50),
	-- Lights
	warm = Color3.fromRGB(255, 184, 110),
	fire = Color3.fromRGB(255, 140, 70),
	green = Color3.fromRGB(110, 255, 160),
	spot = Color3.fromRGB(255, 214, 170),
	-- The pads: parties lemon, practice sky; the record boards' glows too.
	mint = Color3.fromRGB(111, 227, 180),
	lemon = Color3.fromRGB(255, 221, 74),
	sky = Color3.fromRGB(99, 201, 255),
	pink = Color3.fromRGB(255, 111, 177),
}

-- Each kind of pad (Config.Doors): its title, colour and what its board says.
-- The boards never say what is out there.
local DOOR_LOOKS = {
	party = { title = "NEW PARTY", color = C.lemon, blurb = "Alone or up to " .. Config.Party.MaxSize .. " together." },
	practice = { title = "PRACTICE", color = C.sky, blurb = "Nothing out there. No coins or records." },
}

local SIGN_FONT = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold)
local TITLE_FONT = Font.new("rbxasset://fonts/families/Creepster.json")

local DECOR = { CanCollide = false, CanQuery = false, CastShadow = false }
local NEON = { CanCollide = false, CanQuery = false, CastShadow = false, CanTouch = false }
local HIDDEN = { Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false, CanTouch = false }
local BARRIER = { Transparency = 1, CanQuery = false, CastShadow = false, CanTouch = false }
local FOOTING = { Transparency = 1, CastShadow = false } -- invisible, but walked on

local rng = Random.new(1847)

local LobbyBuilder = {}

-- color made a little darker or paler, by up to amount.
local function vary(color, amount)
	local toward = if rng:NextNumber() < 0.5 then Color3.new() else Color3.fromRGB(160, 156, 150)
	return color:Lerp(toward, rng:NextNumber() * amount)
end

-- A CFrame halfway from a to b with its Z axis along the line.
local function along(a, b)
	local middle = (a + b) / 2
	if math.abs((b - a).Unit.Y) > 0.999 then
		return CFrame.new(middle) * CFrame.Angles(math.pi / 2, 0, 0)
	end
	return CFrame.lookAt(middle, b)
end

-- A square beam from a to b.
local function beam(folder, name, a, b, width, color, material, props)
	return block(folder, name, Vector3.new(width, width, (b - a).Magnitude), along(a, b), color, material or Enum.Material.Wood, props)
end

-- A round rod (a rope, a pole, a branch) from a to b.
local function rod(folder, name, a, b, diameter, color, material, props)
	local part = block(folder, name, Vector3.new((b - a).Magnitude, diameter, diameter), along(a, b) * CFrame.Angles(0, math.pi / 2, 0), color, material or Enum.Material.Wood, props)
	part.Shape = Enum.PartType.Cylinder
	return part
end

-- An upright cylinder, standing on bottom.
local function drum(folder, name, bottom, height, diameter, color, material, props)
	local part = block(folder, name, Vector3.new(height, diameter, diameter), CFrame.new(bottom + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, material or Enum.Material.Wood, props)
	part.Shape = Enum.PartType.Cylinder
	return part
end

local function wedge(folder, name, size, cframe, color, material, props)
	local part = Instance.new("WedgePart")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for key, value in props do
			part[key] = value
		end
	end
	part.Parent = folder
	return part
end

-- A flat triangle between a, b and c, thick studs thick: two wedges.
local function triangle(folder, name, a, b, c, thick, color, material, props)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	wedge(folder, name, Vector3.new(thick, height, math.abs(ab:Dot(back))), CFrame.fromMatrix((a + b) / 2, right, up, back), color, material, props)
	wedge(folder, name, Vector3.new(thick, height, math.abs(ac:Dot(back))), CFrame.fromMatrix((a + c) / 2, -right, up, -back), color, material, props)
end

-- Letters painted on a sign: off-white with a dark edge.
local function letters(gui, props, stroke)
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.TextScaled = true
	text.FontFace = SIGN_FONT
	text.TextColor3 = C.signText
	for key, value in props do
		text[key] = value
	end
	local edge = Instance.new("UIStroke")
	edge.Color = C.signStroke
	edge.Thickness = stroke or 3
	edge.Parent = text
	text.Parent = gui
	return text
end

-- A wooden sign at cframe, facing along its -Z: boards in a dark frame.
-- Returns the SurfaceGui on its front, for the letters.
local function sign(folder, cframe, width, height, light)
	local rows = math.max(1, math.round(height / 1.4))
	for i = 1, rows do
		local y = -height / 2 + height / rows * (i - 0.5)
		block(folder, "SignBoard", Vector3.new(width, height / rows - 0.05, 0.3), cframe * CFrame.new(rng:NextNumber(-0.05, 0.05), y, 0), vary(C.signBoard, 0.15), Enum.Material.Wood, DECOR)
	end
	for _, y in { -1, 1 } do
		block(folder, "SignFrame", Vector3.new(width + 0.6, 0.32, 0.45), cframe * CFrame.new(0, y * (height / 2 + 0.14), 0), C.trim, Enum.Material.Wood, DECOR)
	end
	for _, x in { -1, 1 } do
		block(folder, "SignFrame", Vector3.new(0.32, height + 0.6, 0.45), cframe * CFrame.new(x * (width / 2 + 0.14), 0, 0), C.trim, Enum.Material.Wood, DECOR)
	end
	local face = block(folder, "SignFace", Vector3.new(width, height, 0.05), cframe * CFrame.new(0, 0, -0.2), C.signBoard, nil, HIDDEN)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = light or 0.35
	gui.Parent = face
	return gui
end

-- A lantern: warm glass between an iron cap and base, with its light. Tagged
-- LobbyLantern, for client/LobbyLife.luau's flicker.
local function lantern(folder, at, size, range, brightness)
	size = size or 1
	local glass = block(folder, "Lantern", Vector3.new(0.6, 0.85, 0.6) * size, CFrame.new(at), C.glass, Enum.Material.Neon, NEON)
	block(folder, "LanternCap", Vector3.new(0.85, 0.22, 0.85) * size, CFrame.new(at + Vector3.new(0, 0.53 * size, 0)), C.iron, Enum.Material.Metal, DECOR)
	block(folder, "LanternBase", Vector3.new(0.8, 0.16, 0.8) * size, CFrame.new(at - Vector3.new(0, 0.5 * size, 0)), C.iron, Enum.Material.Metal, DECOR)
	block(folder, "LanternRing", Vector3.new(0.3, 0.3, 0.06) * size, CFrame.new(at + Vector3.new(0, 0.76 * size, 0)), C.iron, Enum.Material.Metal, DECOR)
	for _, corner in { Vector3.new(1, 0, 1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, -1) } do
		block(folder, "LanternBar", Vector3.new(0.07, 0.85, 0.07) * size, CFrame.new(at + corner * 0.32 * size), C.iron, Enum.Material.Metal, DECOR)
	end
	local light = Instance.new("PointLight")
	light.Color = C.warm
	light.Range = range or 14
	light.Brightness = brightness or 1.2
	light.Parent = glass
	CollectionService:AddTag(glass, "LobbyLantern")
	return glass
end

-- A lantern hanging on a chain drop studs below from.
local function hangingLantern(folder, from, drop, size, range, brightness)
	size = size or 1
	rod(folder, "Chain", from, from - Vector3.new(0, drop, 0), 0.07, C.iron, Enum.Material.Metal, DECOR)
	return lantern(folder, from - Vector3.new(0, drop + 0.85 * size, 0), size, range, brightness)
end

-- A tall post standing at base with a lantern hanging from an arm toward out.
local function postLantern(folder, base, out)
	local height = 7.6
	block(folder, "LanternPost", Vector3.new(0.65, height, 0.65), CFrame.new(base + Vector3.new(0, height / 2 - 0.2, 0)), vary(C.post, 0.12), Enum.Material.Wood)
	local top = base + Vector3.new(0, height - 0.6, 0)
	local arm = top + out * 1.4
	beam(folder, "LanternArm", top, arm, 0.3, C.post, Enum.Material.Wood, DECOR)
	return hangingLantern(folder, arm - Vector3.new(0, 0.1, 0), 0.5, 1, 16, 1.3)
end

-- Spanish moss hanging from at: a few grey-green strands of uneven length.
local function moss(folder, at, length)
	for _ = 1, rng:NextInteger(3, 6) do
		local strand = length * rng:NextNumber(0.45, 1)
		local top = at + Vector3.new(rng:NextNumber(-0.6, 0.6), 0, rng:NextNumber(-0.6, 0.6))
		local turn = CFrame.Angles(0, rng:NextNumber(0, math.pi), 0) * CFrame.Angles(rng:NextNumber(-0.1, 0.1), 0, rng:NextNumber(-0.1, 0.1))
		block(folder, "Moss", Vector3.new(rng:NextNumber(0.25, 0.55), strand, 0.06), CFrame.new(top) * turn * CFrame.new(0, -strand / 2, 0), vary(C.hangingMoss, 0.25), Enum.Material.Grass, DECOR)
	end
end

-- A torn cloth banner hanging from a rod at top, facing normal: ragged along
-- the bottom, with a pale dead tree on it.
local function banner(folder, top, width, length, normal)
	local look = CFrame.lookAt(top, top + normal)
	rod(folder, "BannerRod", (look * CFrame.new(-width / 2 - 0.4, 0, 0)).Position, (look * CFrame.new(width / 2 + 0.4, 0, 0)).Position, 0.22, C.beam, Enum.Material.Wood, DECOR)
	local body = length * 0.8
	block(folder, "Banner", Vector3.new(width, body, 0.08), look * CFrame.new(0, -body / 2, 0), C.banner, Enum.Material.Fabric, DECOR)
	local tails = 4
	for i = 1, tails do
		local tail = length * rng:NextNumber(0.06, 0.24)
		local w = width / tails * rng:NextNumber(0.55, 0.95)
		block(folder, "Banner", Vector3.new(w, tail, 0.08), look * CFrame.new(-width / 2 + width / tails * (i - 0.5), -body - tail / 2 + 0.02, 0), C.banner, Enum.Material.Fabric, DECOR)
	end
	local tree = look * CFrame.new(0, -body * 0.55, -0.06)
	block(folder, "BannerTree", Vector3.new(width * 0.07, body * 0.5, 0.02), tree * CFrame.new(0, -body * 0.08, 0), C.bannerPale, Enum.Material.Fabric, DECOR)
	for _, side in { -1, 1 } do
		block(folder, "BannerTree", Vector3.new(width * 0.34, width * 0.05, 0.02), tree * CFrame.new(side * width * 0.13, body * 0.12, 0) * CFrame.Angles(0, 0, side * 0.7), C.bannerPale, Enum.Material.Fabric, DECOR)
		block(folder, "BannerTree", Vector3.new(width * 0.24, width * 0.045, 0.02), tree * CFrame.new(side * width * 0.1, body * 0.02, 0) * CFrame.Angles(0, 0, side * 0.35), C.bannerPale, Enum.Material.Fabric, DECOR)
	end
	-- Roots at its foot, like the tree on the old expedition's flag.
	block(folder, "BannerTree", Vector3.new(width * 0.4, width * 0.04, 0.02), tree * CFrame.new(0, -body * 0.32, 0), C.bannerPale, Enum.Material.Fabric, DECOR)
end

-- A window in a hole in a wall: cframe is the hole's middle in the wall's
-- middle, its -Z pointing out. Lit ones glow warm.
local function window(folder, cframe, width, height, lit)
	local out = -(WALL / 2 + 0.12)
	block(folder, "WindowPane", Vector3.new(width, height, 0.1), cframe, if lit then vary(C.windowLit, 0.3) else C.windowDark, if lit then Enum.Material.Neon else Enum.Material.Glass, NEON)
	for _, side in { -1, 1 } do
		block(folder, "WindowTrim", Vector3.new(0.35, height + 0.7, 0.3), cframe * CFrame.new(side * (width / 2 + 0.17), 0, out), C.trim, Enum.Material.Wood, DECOR)
	end
	block(folder, "WindowTrim", Vector3.new(width + 0.7, 0.35, 0.3), cframe * CFrame.new(0, height / 2 + 0.17, out), C.trim, Enum.Material.Wood, DECOR)
	block(folder, "WindowSill", Vector3.new(width + 1.1, 0.3, 0.7), cframe * CFrame.new(0, -height / 2 - 0.15, out - 0.15), C.trim, Enum.Material.Wood, DECOR)
	block(folder, "WindowBar", Vector3.new(0.14, height, 0.14), cframe * CFrame.new(0, 0, -0.08), C.trim, nil, DECOR)
	block(folder, "WindowBar", Vector3.new(width, 0.14, 0.14), cframe * CFrame.new(0, 0, -0.08), C.trim, nil, DECOR)
end

-- A wall along the ground from a to b, from y0 up to y1, with openings
-- { from, to, bottom, top } (measured along it from a; heights), each a
-- window if it has window = "lit" or "dark", else a doorway with a frame.
-- out points out of the building. Its boards come in panels a few studs
-- wide that vary a little, with timber studs between them outside.
local function wall(folder, a, b, y0, y1, openings, out, color)
	a, b = Vector3.new(a.X, 0, a.Z), Vector3.new(b.X, 0, b.Z)
	local dir = (b - a).Unit
	local length = (b - a).Magnitude
	local function at(s, y)
		return a + dir * s + Vector3.new(0, y, 0)
	end
	local function stud(s, h0, h1)
		local middle = at(s, (h0 + h1) / 2) + out * (WALL / 2 + 0.18)
		block(folder, "Stud", Vector3.new(0.36, h1 - h0, 0.7), CFrame.lookAt(middle, middle + dir), C.beam, Enum.Material.Wood, DECOR)
	end
	local function panel(s0, s1, h0, h1, studs)
		if s1 - s0 < 0.05 or h1 - h0 < 0.05 then
			return
		end
		local count = math.ceil((s1 - s0) / 7)
		for i = 0, count - 1 do
			local p0, p1 = s0 + (s1 - s0) * i / count, s0 + (s1 - s0) * (i + 1) / count
			local middle = at((p0 + p1) / 2, (h0 + h1) / 2)
			block(folder, "Wall", Vector3.new(WALL, h1 - h0, p1 - p0), CFrame.lookAt(middle, middle + dir), vary(color, 0.12), Enum.Material.WoodPlanks)
			if studs and i > 0 then
				stud(p0, h0, h1)
			end
		end
	end
	table.sort(openings, function(p, q)
		return p[1] < q[1]
	end)
	local s = 0
	for _, opening in openings do
		local from, to, bottom, top = opening[1], opening[2], opening[3], opening[4]
		panel(s, from, y0, y1, true)
		panel(from, to, y0, bottom)
		panel(from, to, top, y1)
		local middle = at((from + to) / 2, (bottom + top) / 2)
		if opening.window then
			window(folder, CFrame.lookAt(middle, middle + out), to - from, top - bottom, opening.window == "lit")
		else
			stud(from - 0.2, bottom, top + 0.5)
			stud(to + 0.2, bottom, top + 0.5)
			local lintel = at((from + to) / 2, top + 0.25) + out * (WALL / 2 + 0.18)
			block(folder, "Lintel", Vector3.new(0.36, 0.5, to - from + 1.1), CFrame.lookAt(lintel, lintel + dir), C.beam, Enum.Material.Wood, DECOR)
		end
		s = to
	end
	panel(s, length, y0, y1, true)
end

-- One slope of a roof, from its eave (e0 to e1) up to its ridge (r0 to
-- r1): rows of shingles, each lapping over the one below, here and there a
-- greener one and a patch of moss.
local function roofSide(folder, e0, e1, r0, r1, rows)
	local across = (e1 - e0).Unit
	for i = 0, rows - 1 do
		local t0, t1 = i / rows, (i + 1) / rows
		local lower = e0:Lerp(r0, t0):Lerp(e1:Lerp(r1, t0), 0.5)
		local upper = e0:Lerp(r0, t1):Lerp(e1:Lerp(r1, t1), 0.5)
		local up = (upper - lower).Unit
		local normal = across:Cross(up)
		if normal.Y < 0 then
			normal = -normal
		end
		local center = (lower + upper) / 2 + normal * (0.2 + (i % 2) * 0.1) - up * 0.2
		local color = if rng:NextNumber() < 0.15 then vary(C.roofMoss, 0.2) else vary(C.shingle, 0.2)
		local frame = CFrame.fromMatrix(center, across, normal)
		block(folder, "Shingles", Vector3.new((e1 - e0).Magnitude + 0.4, 0.4, (upper - lower).Magnitude + 0.5), frame, color, Enum.Material.WoodPlanks)
		if rng:NextNumber() < 0.25 then
			local spot = (rng:NextNumber() - 0.5) * ((e1 - e0).Magnitude - 4)
			block(folder, "RoofMoss", Vector3.new(rng:NextNumber(2, 5), 0.16, (upper - lower).Magnitude * rng:NextNumber(0.6, 1.2)), frame * CFrame.new(spot, 0.26, 0), vary(C.moss, 0.2), Enum.Material.Grass, DECOR)
		end
	end
end

-- A wooden crate centred on cframe, darker slats round it.
local function crate(folder, cframe, size)
	block(folder, "Crate", Vector3.one * size, cframe, vary(C.crate, 0.2), Enum.Material.WoodPlanks)
	for _, y in { -1, 1 } do
		block(folder, "CrateSlat", Vector3.new(size + 0.06, size * 0.14, size + 0.06), cframe * CFrame.new(0, y * size * 0.43, 0), C.beam, Enum.Material.Wood, DECOR)
	end
end

-- A barrel standing on bottom, with iron hoops.
local function barrel(folder, bottom, height)
	local diameter = height * 0.68
	drum(folder, "Barrel", bottom, height, diameter, vary(C.barrel, 0.15), Enum.Material.Wood)
	for _, y in { 0.18, 0.82 } do
		drum(folder, "Hoop", bottom + Vector3.new(0, height * y - 0.06, 0), 0.12, diameter + 0.06, C.iron, Enum.Material.Metal, DECOR)
	end
end

-- A boardwalk from (x0, z0) to (x1, z1), its top at top: planks side by side
-- (running along x if alongX, else along z) in pieces of uneven length,
-- thin dark gaps between them, over a dark underlayer; and, unless posts is
-- false (floors indoors), a beam round its edge and posts in the mud.
local function deck(folder, x0, z0, x1, z1, top, alongX, posts)
	box(folder, "DeckUnder", Vector3.new(x0 + 0.1, top - 1.1, z0 + 0.1), Vector3.new(x1 - 0.1, top - 0.35, z1 - 0.1), C.under, Enum.Material.Wood, DECOR)
	local u0, u1 = if alongX then z0 else x0, if alongX then z1 else x1
	local s0, s1 = if alongX then x0 else z0, if alongX then x1 else z1
	local u = u0
	while u < u1 - 0.3 do
		local w = math.min(1.5, u1 - u)
		local s = s0
		while s < s1 - 0.3 do
			local piece = math.min(s1 - s, rng:NextNumber(6, 14))
			if s1 - s - piece < 3 then
				piece = s1 - s
			end
			local color = vary(if rng:NextNumber() < 0.3 then C.plankGray else C.plank, 0.22)
			local a, b = s + 0.04, s + piece - 0.04
			local c, d = u + 0.05, u + w - 0.05
			local sink = if rng:NextNumber() < 0.06 then 0.06 else 0 -- one here and there sits a little lower
			if alongX then
				box(folder, "Plank", Vector3.new(a, top - 0.35 - sink, c), Vector3.new(b, top - sink, d), color, Enum.Material.Wood)
			else
				box(folder, "Plank", Vector3.new(c, top - 0.35 - sink, a), Vector3.new(d, top - sink, b), color, Enum.Material.Wood)
			end
			s += piece
		end
		u += 1.5
	end
	if posts == false then
		return
	end
	local edge = vary(C.post, 0.1)
	box(folder, "DeckEdge", Vector3.new(x0 - 0.15, top - 1.1, z0 - 0.15), Vector3.new(x1 + 0.15, top - 0.4, z0 + 0.35), edge, Enum.Material.Wood, DECOR)
	box(folder, "DeckEdge", Vector3.new(x0 - 0.15, top - 1.1, z1 - 0.35), Vector3.new(x1 + 0.15, top - 0.4, z1 + 0.15), edge, Enum.Material.Wood, DECOR)
	box(folder, "DeckEdge", Vector3.new(x0 - 0.15, top - 1.1, z0), Vector3.new(x0 + 0.35, top - 0.4, z1), edge, Enum.Material.Wood, DECOR)
	box(folder, "DeckEdge", Vector3.new(x1 - 0.35, top - 1.1, z0), Vector3.new(x1 + 0.15, top - 0.4, z1), edge, Enum.Material.Wood, DECOR)
	local function postsAlong(a, b)
		local count = math.max(1, math.floor((b - a).Magnitude / 5.5))
		for i = 0, count do
			local p = a:Lerp(b, i / count)
			block(folder, "DeckPost", Vector3.new(0.9, top - 0.4 - FOOT, 0.9), CFrame.new(p.X, (FOOT + top - 0.4) / 2, p.Z) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0), vary(C.post, 0.12), Enum.Material.Wood, DECOR)
		end
	end
	postsAlong(Vector3.new(x0 + 0.4, 0, z0 + 0.4), Vector3.new(x1 - 0.4, 0, z0 + 0.4))
	postsAlong(Vector3.new(x0 + 0.4, 0, z1 - 0.4), Vector3.new(x1 - 0.4, 0, z1 - 0.4))
	postsAlong(Vector3.new(x0 + 0.4, 0, z0 + 0.4), Vector3.new(x0 + 0.4, 0, z1 - 0.4))
	postsAlong(Vector3.new(x1 - 0.4, 0, z0 + 0.4), Vector3.new(x1 - 0.4, 0, z1 - 0.4))
end

-- An invisible wall from a to b (at floor height), high studs tall.
local function barrier(folder, a, b, high)
	local middle = (a + b) / 2 + Vector3.new(0, high / 2, 0)
	block(folder, "Barrier", Vector3.new(0.6, high, (b - a).Magnitude), CFrame.lookAt(middle, middle + (b - a)), C.post, nil, BARRIER)
end

-- A rope railing along a boardwalk's edge from a to b (on the edge, at its
-- top): posts every few studs with two sagging ropes, and an invisible wall
-- nobody gets over. lamps: every how many posts one is a lantern post, its
-- lantern hanging toward out.
local function railing(folder, a, b, lamps, out)
	local length = (b - a).Magnitude
	local count = math.max(1, math.ceil(length / 6))
	local last
	for i = 0, count do
		local p = a:Lerp(b, i / count)
		if lamps and out and i % lamps == math.floor(lamps / 2) then
			postLantern(folder, p, out)
		else
			block(folder, "RailPost", Vector3.new(0.7, 3.8, 0.7), CFrame.new(p + Vector3.new(0, 1.7, 0)) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0), vary(C.post, 0.15), Enum.Material.Wood)
		end
		if last then
			for _, h in { 1.6, 3.1 } do
				local p0, p1 = last + Vector3.new(0, h, 0), p + Vector3.new(0, h, 0)
				local sag = (p0 + p1) / 2 - Vector3.new(0, 0.35, 0)
				rod(folder, "Rope", p0, sag, 0.17, C.rope, Enum.Material.Fabric, DECOR)
				rod(folder, "Rope", sag, p1, 0.17, C.rope, Enum.Material.Fabric, DECOR)
			end
		end
		last = p
	end
	barrier(folder, a, b, 12)
end

-- A wooden railing from a to b (at floor height): posts, a top and a middle
-- rail and thin balusters, and an invisible wall unless wall is false.
local function woodRailing(folder, a, b, wall)
	local length = (b - a).Magnitude
	local posts = math.max(1, math.ceil(length / 4))
	for i = 0, posts do
		block(folder, "RailPost", Vector3.new(0.45, 3.5, 0.45), CFrame.new(a:Lerp(b, i / posts) + Vector3.new(0, 1.75, 0)), C.beam, Enum.Material.Wood)
	end
	beam(folder, "Rail", a + Vector3.new(0, 3.35, 0), b + Vector3.new(0, 3.35, 0), 0.32, vary(C.post, 0.1), Enum.Material.Wood)
	beam(folder, "Rail", a + Vector3.new(0, 1.6, 0), b + Vector3.new(0, 1.6, 0), 0.22, vary(C.post, 0.1), Enum.Material.Wood, DECOR)
	local balusters = math.floor(length / 1.25)
	for i = 1, balusters - 1 do
		local p = a:Lerp(b, i / balusters)
		block(folder, "Baluster", Vector3.new(0.18, 3.1, 0.18), CFrame.new(p + Vector3.new(0, 1.7, 0)), C.beam, Enum.Material.Wood, DECOR)
	end
	if wall ~= false then
		barrier(folder, a, b, 8)
	end
end

-- A glowing outline on the floor at (x, y, z), with a faint fill. Returns
-- the invisible space above it, for noticing who stands on it.
local function glowPad(folder, x, y, z, width, length, color)
	local glow = color:Lerp(Color3.new(), 0.35)
	local bar = 0.3
	local top = y + 0.04
	block(folder, "PadGlow", Vector3.new(width, 0.06, bar), CFrame.new(x, top, z - length / 2), glow, Enum.Material.Neon, NEON)
	block(folder, "PadGlow", Vector3.new(width, 0.06, bar), CFrame.new(x, top, z + length / 2), glow, Enum.Material.Neon, NEON)
	block(folder, "PadGlow", Vector3.new(bar, 0.06, length), CFrame.new(x - width / 2, top, z), glow, Enum.Material.Neon, NEON)
	block(folder, "PadGlow", Vector3.new(bar, 0.06, length), CFrame.new(x + width / 2, top, z), glow, Enum.Material.Neon, NEON)
	block(folder, "PadFill", Vector3.new(width, 0.03, length), CFrame.new(x, top - 0.01, z), glow, Enum.Material.Neon, {
		Transparency = 0.86,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
		CanTouch = false,
	})
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 9
	light.Brightness = 0.5
	light.Parent = block(folder, "PadLight", Vector3.one * 0.2, CFrame.new(x, y + 1.5, z), color, nil, HIDDEN)
	return block(folder, "PadZone", Vector3.new(width, 6, length), CFrame.new(x, y + 3, z), color, nil, HIDDEN)
end

-- A board over a party pad, at cframe (facing its -Z): its title in the
-- pad's colour, what it is, and a line Parties.luau keeps up to date.
-- Returns the title and that line.
local function padBoard(folder, cframe, width, height, look, title)
	local gui = sign(folder, cframe, width, height, 0.1)
	local titleLabel = letters(gui, {
		Name = "Title",
		Position = UDim2.fromScale(0.05, 0.07),
		Size = UDim2.fromScale(0.9, 0.36),
		TextColor3 = look.color,
		Text = title or look.title,
	})
	letters(gui, { Name = "Info", Position = UDim2.fromScale(0.07, 0.48), Size = UDim2.fromScale(0.86, 0.17), Text = look.blurb }, 1.5)
	local status = letters(gui, {
		Name = "Status",
		Position = UDim2.fromScale(0.07, 0.7),
		Size = UDim2.fromScale(0.86, 0.2),
		TextColor3 = look.color:Lerp(C.signText, 0.45),
		Text = "",
	}, 1.5)
	return titleLabel, status
end

-- One of the Meshy dead trees (ServerStorage.ForestProps), height studs
-- tall with its roots at (x, y, z), turned and leaning a little; nothing
-- collides with it. Without them, Forest builds one at the waterline.
local treeModels
local function deadTree(folder, x, y, z, height)
	if not treeModels then
		treeModels = {}
		local props = ServerStorage:FindFirstChild("ForestProps")
		for _, model in if props then props:GetChildren() else {} do
			if model:IsA("Model") then
				table.insert(treeModels, model)
			end
		end
	end
	if #treeModels == 0 then
		Forest.deadTree(folder, x, z, height, rng, true)
		return
	end
	local tree = treeModels[rng:NextInteger(1, #treeModels)]:Clone()
	local _, size = tree:GetBoundingBox()
	tree:ScaleTo(tree:GetScale() * height / size.Y)
	tree:PivotTo(CFrame.new(x, y, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0) * CFrame.Angles(rng:NextNumber(-0.06, 0.06), 0, rng:NextNumber(-0.06, 0.06)))
	for _, part in tree:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
		end
	end
	tree.Parent = folder
end

-- A big old swamp tree built from parts, standing in the water at (x, z):
-- a thick leaning trunk flaring into roots, long crooked limbs, and moss
-- hanging off them.
local function oldTree(folder, x, z, height)
	local lean = Vector3.new(rng:NextNumber(-0.25, 0.25), 1, rng:NextNumber(-0.25, 0.25)).Unit
	local base = Vector3.new(x, FLOOR_Y, z)
	local width = 2.6 + height / 18
	local points = { base, base + lean * height * 0.35, base + lean * height * 0.7 + Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2)), base + lean * height }
	for i = 1, #points - 1 do
		local w = width * (1 - (i - 1) * 0.25)
		rod(folder, "Trunk", points[i], points[i + 1] + (points[i + 1] - points[i]).Unit * 0.5, w, vary(C.bark, 0.15), Enum.Material.Wood, { CanCollide = false, CanQuery = false })
	end
	for i = 1, 6 do
		local angle = i * math.pi / 3 + rng:NextNumber(-0.3, 0.3)
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		rod(folder, "Root", Vector3.new(x, SURFACE_Y + 2.5, z) + out * width * 0.2, Vector3.new(x, FLOOR_Y + 0.5, z) + out * width * 1.9, width * 0.32, C.barkDark, Enum.Material.Wood, DECOR)
	end
	for _ = 1, rng:NextInteger(4, 6) do
		local from = base + lean * height * rng:NextNumber(0.5, 0.95)
		local angle = rng:NextNumber(0, math.pi * 2)
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local reach = height * rng:NextNumber(0.3, 0.5)
		local elbow = from + (out + Vector3.new(0, rng:NextNumber(0.1, 0.5), 0)).Unit * reach * 0.55
		local tip = elbow + (out + Vector3.new(rng:NextNumber(-0.4, 0.4), rng:NextNumber(-0.15, 0.3), rng:NextNumber(-0.4, 0.4))).Unit * reach * 0.5
		rod(folder, "Limb", from, elbow, width * 0.3, vary(C.bark, 0.15), Enum.Material.Wood, DECOR)
		rod(folder, "Limb", elbow, tip, width * 0.18, vary(C.barkDark, 0.15), Enum.Material.Wood, DECOR)
		moss(folder, elbow, rng:NextNumber(3, 6))
		moss(folder, elbow:Lerp(tip, 0.6), rng:NextNumber(2.5, 5))
		moss(folder, tip, rng:NextNumber(2, 4))
	end
end

-- The swamp's water: Roblox terrain, as in the forest (MapBuilder.luau sets
-- its colour), up to the ridge and far out into the fog all round, with a
-- muddy bottom under it.
local function buildWater(folder)
	local bottom = FLOOR_Y - 4
	workspace.Terrain:FillBlock(CFrame.new(0, (bottom + SURFACE_Y) / 2, -300), Vector3.new(840, SURFACE_Y - bottom, 600), Enum.Material.Water)
	box(folder, "SwampFloor", Vector3.new(-420, bottom - 2, -600), Vector3.new(420, bottom, 0), C.under, Enum.Material.Mud, DECOR)
end

-- The ridge behind the outpost: a long wooded bank of mud and grass, higher
-- than anyone can see from in the lobby (the towers and balcony included),
-- with dead trees all along its top. It stops just short of z = 0, where the
-- forest's water starts (MapBuilder fills that in afterwards).
local function buildRidge(folder)
	local terrain = workspace.Terrain
	local r = Random.new(808)
	-- Each ball's front stays behind z = -16, clear of the boardwalk behind
	-- the lodge (its railing is at -18); its top is still about 30 studs up
	-- where z < 0.
	for x = -420, 420, 11 do
		local radius = r:NextNumber(24, 28)
		local center = Vector3.new(x + r:NextNumber(-3, 3), SURFACE_Y + 10 + r:NextNumber(-1, 2), 12 + r:NextNumber(0, 2))
		terrain:FillBall(center, radius, Enum.Material.Mud)
		terrain:FillBall(center + Vector3.new(r:NextNumber(-4, 4), radius - 9, -6), 10, Enum.Material.LeafyGrass)
	end
	-- Lumps along its foot, so it isn't one smooth wall.
	for x = -414, 414, 17 do
		terrain:FillBall(Vector3.new(x + r:NextNumber(-5, 5), SURFACE_Y - 2, -10 + r:NextNumber(-1, 1)), r:NextNumber(3.5, 6), Enum.Material.Mud)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { terrain }
	for x = -410, 410, 7 do
		local z = r:NextNumber(-9, -2)
		local hit = workspace:Raycast(Vector3.new(x + r:NextNumber(-2, 2), SURFACE_Y + 120, z), Vector3.new(0, -140, 0), params)
		if hit and hit.Position.Y > SURFACE_Y + 6 then
			deadTree(folder, hit.Position.X, hit.Position.Y - 1, hit.Position.Z, r:NextNumber(22, 40))
		end
	end
end

-- The swamp round the outpost: dead trees standing in the water, thicker
-- further out, a few great old ones near the boardwalks, mud islands with
-- reeds, cattails and lily pads, fallen logs and algae.
local function buildSwamp(folder)
	local r = Random.new(2611)
	-- Somewhere in the open water: not on (or right by) a boardwalk or
	-- building, nor in front of the stations.
	local keepClear = {
		{ -92, -112, 80, -14 }, -- the outpost
		{ -10, -144, 26, -96 }, -- the spawn's walk
	}
	local function open(x, z, margin)
		for _, area in keepClear do
			if x > area[1] - margin and x < area[3] + margin and z > area[2] - margin and z < area[4] + margin then
				return false
			end
		end
		return z < -18
	end
	for _ = 1, 280 do
		local x, z = r:NextNumber(-330, 330), r:NextNumber(-420, -20)
		if open(x, z, 6) then
			local far = math.max(math.abs(x) - 80, -110 - z)
			deadTree(folder, x, SURFACE_Y - 1.2, z, r:NextNumber(16, 26) + math.clamp(far / 6, 0, 18))
		end
	end
	for _, spot in { { -26, -124, 34 }, { 46, -122, 30 }, { 92, -66, 34 }, { -104, -92, 32 }, { 30, -170, 26 } } do
		oldTree(folder, spot[1], spot[2], spot[3])
	end
	local islands = {
		{ -40, -120, 7 }, { 32, -116, 6 }, { 84, -98, 8 }, { -100, -122, 9 }, { 66, -136, 7 },
		{ -60, -150, 8 }, { 104, -40, 9 }, { -118, -66, 8 }, { 10, -178, 9 }, { -20, -160, 5 },
	}
	for _, island in islands do
		local x, z, radius = island[1], island[2], island[3]
		Forest.mudIsland(x, z, radius, r:NextNumber(0.6, 1.4), r)
		Forest.cattails(folder, x + radius * 0.6, z + r:NextNumber(-2, 2), r)
		Forest.reeds(folder, x - radius * 0.7, z + r:NextNumber(-2, 2), r)
	end
	for _ = 1, 70 do
		local x, z = r:NextNumber(-130, 130), r:NextNumber(-200, -20)
		if open(x, z, 1) or (math.abs(x - 8) > 14 and z < -98 and z > -140) then
			local roll = r:NextNumber()
			if roll < 0.45 then
				Forest.lilyPads(folder, x, z, r)
			elseif roll < 0.65 then
				Forest.cattails(folder, x, z, r)
			elseif roll < 0.8 then
				Forest.reeds(folder, x, z, r)
			else
				Forest.algae(folder, x, z, r)
			end
		end
	end
	for _ = 1, 10 do
		local x, z = r:NextNumber(-140, 140), r:NextNumber(-210, -30)
		if open(x, z, 4) then
			local angle = r:NextNumber(0, math.pi * 2)
			local half = Vector3.new(math.cos(angle), 0, math.sin(angle)) * r:NextNumber(4, 8)
			Forest.fallenLog(folder, Vector3.new(x, SURFACE_Y, z) - half, Vector3.new(x, SURFACE_Y, z) + half, r)
		end
	end
end

-- The boardwalks joining everything, their railings, and the lanterns along
-- them. Each deck meets the next edge to edge.
local function buildBoardwalks(folder)
	deck(folder, -56, -98, 44, -66, DECK, false) -- the main boardwalk in front of the lodge
	deck(folder, LODGE.x0, LODGE.balcony, LODGE.x1, LODGE.front, DECK, false) -- under the balcony
	deck(folder, LODGE.x1, LODGE.balcony, 48, -18, DECK, true) -- along the lodge's left side
	deck(folder, -44, LODGE.back, LODGE.x1, -18, DECK, false) -- behind it
	deck(folder, 44, -70, 48, -66, DECK, true) -- to the party station
	deck(folder, 2, -118, 14, -98, DECK, true) -- from the spawn
	deck(folder, -4, -138, 20, -118, DECK, true) -- the spawn
	deck(folder, -84, -98, -56, -70, DECK, false) -- to the adventure's tunnel

	local function at(x, z, y)
		return Vector3.new(x, y or DECK, z)
	end
	local south, west, east, north = -Vector3.zAxis, -Vector3.xAxis, Vector3.xAxis, Vector3.zAxis
	railing(folder, at(-84, -98), at(2, -98), 3, south)
	railing(folder, at(14, -98), at(44, -98), 3, south)
	railing(folder, at(-84, -98), at(-84, -70), 2, west)
	railing(folder, at(-84, -70), at(-79, -70))
	railing(folder, at(-61, -70), at(-56, -70))
	railing(folder, at(-56, -66), at(-44, -66))
	railing(folder, at(-44, -66), at(-44, SHOP.front))
	railing(folder, at(48, -70), at(48, -66))
	railing(folder, at(48, -66), at(48, -18), 3, east)
	railing(folder, at(48, -18), at(LODGE.x1, -18))
	railing(folder, at(LODGE.x1, -18), at(-44, -18), 4, north)
	railing(folder, at(-44, -18), at(-44, LODGE.back))
	railing(folder, at(-44, LODGE.back), at(LODGE.x0, LODGE.back))
	railing(folder, at(2, -118), at(2, -98), 2, east)
	railing(folder, at(14, -118), at(14, -98), 2, west)
	railing(folder, at(-4, -138), at(20, -138))
	railing(folder, at(-4, -138), at(-4, -118))
	railing(folder, at(20, -138), at(20, -118))
	railing(folder, at(-4, -118), at(2, -118), 2, west)
	railing(folder, at(14, -118), at(20, -118), 2, east)

	-- Odds and ends left on the boards.
	crate(folder, CFrame.new(-52, DECK + 1.1, -94) * CFrame.Angles(0, 0.3, 0), 2.2)
	crate(folder, CFrame.new(-49.6, DECK + 0.9, -95.2) * CFrame.Angles(0, -0.2, 0), 1.8)
	crate(folder, CFrame.new(-51, DECK + 3, -94.4) * CFrame.Angles(0, 0.8, 0), 1.6)
	barrel(folder, at(40.5, -95.5), 2.6)
	barrel(folder, at(38.2, -96.2), 2.4)
	crate(folder, CFrame.new(45.6, DECK + 1, -22) * CFrame.Angles(0, 0.5, 0), 2)
	drum(folder, "RopeCoil", at(-41.5, -20.8), 0.5, 2.2, C.rope, Enum.Material.Fabric, DECOR)
	drum(folder, "RopeCoil", at(-41.5, -20.8, DECK + 0.5), 0.4, 1.7, C.rope:Lerp(Color3.new(), 0.2), Enum.Material.Fabric, DECOR)
	-- A rowing boat tied up at the spawn, half full of rainwater.
	local boat = CFrame.new(-8.5, SURFACE_Y + 0.35, -125) * CFrame.Angles(0, 0.12, 0)
	block(folder, "Boat", Vector3.new(3.4, 1.2, 9), boat, vary(C.barrel, 0.1), Enum.Material.WoodPlanks, DECOR)
	block(folder, "BoatWater", Vector3.new(2.8, 0.1, 8.2), boat * CFrame.new(0, 0.4, 0), C.under, Enum.Material.Glass, DECOR)
	wedge(folder, "BoatBow", Vector3.new(3.4, 1.2, 2.4), boat * CFrame.new(0, 0, -5.7) * CFrame.Angles(0, math.pi, 0), C.barrel, Enum.Material.WoodPlanks, DECOR)
	rod(folder, "Oar", (boat * CFrame.new(-1, 0.9, -1)).Position, (boat * CFrame.new(1.4, 0.7, 3)).Position, 0.2, C.plank, Enum.Material.Wood, DECOR)
	rod(folder, "Rope", (boat * CFrame.new(1.2, 0.6, -4.5)).Position, at(-3.6, -124, DECK + 0.6), 0.14, C.rope, Enum.Material.Fabric, DECOR)
end

-- The lodge: walls of old boards on a timber frame, windows mostly lit, a
-- big gabled roof of shingles reaching out over the balcony, a cupola and a
-- chimney; the game's sign on the gable and banners hanging off it. Inside,
-- a hall with a fire, tables and a stair up to the gallery and the balcony
-- door. Returns the record boards on its left side.
local function buildLodge(folder)
	local L = LODGE
	local x0, x1, front, back = L.x0, L.x1, L.front, L.back
	local f2, eave, peak, mid = L.floor2, L.eave, L.peak, L.mid
	local function roofAt(x)
		return peak - math.abs(x - mid) * L.slope
	end

	-- Ground floor. Openings are measured along each wall from its first end.
	wall(folder, Vector3.new(x1, 0, front), Vector3.new(x0, 0, front), DECK, f2, {
		{ 1, 4, DECK + 4, DECK + 8, window = "lit" },
		{ x1 - BAY.x1, x1 - BAY.x0, DECK, BAY.top },
		{ x1 - DOOR.x1, x1 - DOOR.x0, DECK, DOOR.top },
		{ 43, 46, DECK + 4, DECK + 8, window = "dark" },
		{ 50, 53, DECK + 4, DECK + 8, window = "lit" },
	}, -Vector3.zAxis, C.siding)
	wall(folder, Vector3.new(x1, 0, front), Vector3.new(x1, 0, back), DECK, f2, {
		{ 1, 5, DECK, DECK + 8.5 },
		{ 28, 31, DECK + 4, DECK + 8, window = "lit" },
	}, Vector3.xAxis, C.siding)
	wall(folder, Vector3.new(x0, 0, front), Vector3.new(x0, 0, back), DECK, f2, {
		{ 20, 23, DECK + 4, DECK + 8, window = "lit" },
		{ 28, 31, DECK + 4, DECK + 8, window = "dark" },
	}, -Vector3.xAxis, C.siding)
	wall(folder, Vector3.new(x0, 0, back), Vector3.new(x1, 0, back), DECK, f2, {
		{ 5, 8, DECK + 4, DECK + 8, window = "lit" },
		{ 13, 16, DECK + 4, DECK + 8, window = "dark" },
		{ 40, 44, DECK, DECK + 8.5 },
		{ 48, 51, DECK + 4, DECK + 8, window = "lit" },
	}, Vector3.zAxis, C.siding)

	-- Upper floor: the balcony door, and the door to the right bridge.
	local w0, w1 = f2 + 3, f2 + 7
	wall(folder, Vector3.new(x1, 0, front), Vector3.new(x0, 0, front), f2, eave, {
		{ 4, 7, w0, w1, window = "lit" },
		{ 13, 16, w0, w1, window = "lit" },
		{ x1 - 6.5, x1 - 1.5, f2, f2 + 8 },
		{ 38, 41, w0, w1, window = "dark" },
		{ 47, 50, w0, w1, window = "lit" },
	}, -Vector3.zAxis, C.sidingGray)
	wall(folder, Vector3.new(x1, 0, front), Vector3.new(x1, 0, back), f2, eave, {
		{ 1.5, 4.5, w0, w1, window = "lit" },
		{ 24, 27, w0, w1, window = "dark" },
		{ 29.5, 32.5, w0, w1, window = "lit" },
	}, Vector3.xAxis, C.sidingGray)
	wall(folder, Vector3.new(x0, 0, front), Vector3.new(x0, 0, back), f2, eave, {
		{ 6, 10, f2, f2 + 8 },
		{ 18, 21, w0, w1, window = "lit" },
		{ 28, 31, w0, w1, window = "dark" },
	}, -Vector3.xAxis, C.sidingGray)
	wall(folder, Vector3.new(x0, 0, back), Vector3.new(x1, 0, back), f2, eave, {
		{ 10, 13, w0, w1, window = "lit" },
		{ 42, 45, w0, w1, window = "lit" },
	}, Vector3.zAxis, C.sidingGray)
	for _, z in { front, back } do
		triangle(folder, "Gable", Vector3.new(x0, eave, z), Vector3.new(x1, eave, z), Vector3.new(mid, peak, z), WALL, vary(C.sidingGray, 0.1), Enum.Material.WoodPlanks)
	end

	-- The timber frame: corner posts, a beam round the upper floor and the
	-- eaves.
	for _, x in { x0, x1 } do
		for _, z in { front, back } do
			block(folder, "CornerPost", Vector3.new(1.3, eave - DECK + 0.4, 1.3), CFrame.new(x, (DECK + eave) / 2, z), C.beam, Enum.Material.Wood)
		end
	end
	for _, y in { f2 - 0.4, eave - 0.4 } do
		box(folder, "Belt", Vector3.new(x0 - 0.65, y - 0.4, front - 0.65), Vector3.new(x1 + 0.65, y + 0.4, front - 0.3), C.beam, Enum.Material.Wood, DECOR)
		box(folder, "Belt", Vector3.new(x0 - 0.65, y - 0.4, back + 0.3), Vector3.new(x1 + 0.65, y + 0.4, back + 0.65), C.beam, Enum.Material.Wood, DECOR)
		box(folder, "Belt", Vector3.new(x0 - 0.65, y - 0.4, front), Vector3.new(x0 - 0.3, y + 0.4, back), C.beam, Enum.Material.Wood, DECOR)
		box(folder, "Belt", Vector3.new(x1 + 0.3, y - 0.4, front), Vector3.new(x1 + 0.65, y + 0.4, back), C.beam, Enum.Material.Wood, DECOR)
	end

	-- The roof, out over the balcony at the front.
	local z0, z1 = L.balcony - 0.5, back + L.over
	local eaveY = roofAt(x1 + L.over)
	roofSide(folder, Vector3.new(x1 + L.over, eaveY, z0), Vector3.new(x1 + L.over, eaveY, z1), Vector3.new(mid, peak, z0), Vector3.new(mid, peak, z1), 14)
	roofSide(folder, Vector3.new(x0 - L.over, eaveY, z0), Vector3.new(x0 - L.over, eaveY, z1), Vector3.new(mid, peak, z0), Vector3.new(mid, peak, z1), 14)
	beam(folder, "RidgeBeam", Vector3.new(mid, peak + 0.55, z0 - 0.1), Vector3.new(mid, peak + 0.55, z1 + 0.1), 1, C.beam)
	for _, z in { z0 - 0.15, z1 + 0.15 } do
		beam(folder, "BargeBoard", Vector3.new(x1 + L.over + 0.2, eaveY - 0.2, z), Vector3.new(mid, peak + 0.3, z), 0.7, C.trim)
		beam(folder, "BargeBoard", Vector3.new(x0 - L.over - 0.2, eaveY - 0.2, z), Vector3.new(mid, peak + 0.3, z), 0.7, C.trim)
	end
	-- Brackets under the front of the roof, from the gable out to its edge.
	for _, x in { mid - 14, mid, mid + 14 } do
		local y = roofAt(x) - 0.6
		beam(folder, "RoofBeam", Vector3.new(x, y, front - 0.4), Vector3.new(x, y, z0), 0.7, C.beam, Enum.Material.Wood, DECOR)
	end
	for _, z in { -64, -47, -33 } do
		moss(folder, Vector3.new(x1 + L.over, eaveY - 0.3, z + rng:NextNumber(-2, 2)), rng:NextNumber(2, 4))
		moss(folder, Vector3.new(x0 - L.over, eaveY - 0.3, z + rng:NextNumber(-2, 2)), rng:NextNumber(2, 4))
	end

	-- The cupola on the ridge, lit.
	local cz = -46
	box(folder, "Cupola", Vector3.new(mid - 3, peak - 3, cz - 3), Vector3.new(mid + 3, peak + 2.6, cz + 3), C.sidingGray, Enum.Material.WoodPlanks)
	for _, side in { -1, 1 } do
		block(folder, "CupolaWindow", Vector3.new(3, 2.2, 0.1), CFrame.new(mid, peak + 0.9, cz + side * 3.05), C.windowLit, Enum.Material.Neon, NEON)
		block(folder, "CupolaWindow", Vector3.new(0.1, 2.2, 3), CFrame.new(mid + side * 3.05, peak + 0.9, cz), C.windowLit, Enum.Material.Neon, NEON)
	end
	local cupolaTop = peak + 5.2
	roofSide(folder, Vector3.new(mid + 3.8, peak + 2.4, cz - 3.8), Vector3.new(mid + 3.8, peak + 2.4, cz + 3.8), Vector3.new(mid, cupolaTop, cz - 3.8), Vector3.new(mid, cupolaTop, cz + 3.8), 3)
	roofSide(folder, Vector3.new(mid - 3.8, peak + 2.4, cz - 3.8), Vector3.new(mid - 3.8, peak + 2.4, cz + 3.8), Vector3.new(mid, cupolaTop, cz - 3.8), Vector3.new(mid, cupolaTop, cz + 3.8), 3)
	for _, z in { cz - 3, cz + 3 } do
		triangle(folder, "Gable", Vector3.new(mid - 3, peak + 2.6, z), Vector3.new(mid + 3, peak + 2.6, z), Vector3.new(mid, cupolaTop - 0.4, z), 0.4, C.sidingGray, Enum.Material.WoodPlanks)
	end

	-- The chimney, up the back of the hall and out through the roof.
	box(folder, "Chimney", Vector3.new(mid - 1.7, peak - 4, back - 1.2), Vector3.new(mid + 1.7, peak + 4.5, back + 1.6), C.stone, Enum.Material.Cobblestone)
	box(folder, "ChimneyCap", Vector3.new(mid - 2, peak + 4.5, back - 1.5), Vector3.new(mid + 2, peak + 5, back + 1.9), C.stone, Enum.Material.Slate)

	-- The game's sign on the gable: THE SILENT in old white, SWAMP in red,
	-- with roots and moss hanging off it and branches along its top.
	local title = Vector3.new(mid, eave + 3.9, front - WALL / 2 - 0.3)
	local titleHeight = 7
	local titleGui = sign(folder, CFrame.lookAt(title, title - Vector3.zAxis), 27, titleHeight, 0.25)
	letters(titleGui, {
		Name = "The",
		Position = UDim2.fromScale(0.05, 0.03),
		Size = UDim2.fromScale(0.9, 0.38),
		Text = "THE SILENT",
	}, 4)
	letters(titleGui, {
		Name = "Swamp",
		Position = UDim2.fromScale(0.03, 0.38),
		Size = UDim2.fromScale(0.94, 0.6),
		FontFace = TITLE_FONT,
		TextColor3 = C.blood,
		Text = "SWAMP",
	}, 4)
	for x = -11, 11, 3.2 do
		moss(folder, Vector3.new(mid + x + rng:NextNumber(-0.8, 0.8), title.Y - titleHeight / 2 - 0.4, title.Z - 0.2), rng:NextNumber(1.2, 3.2))
	end
	for _, side in { -1, 1 } do
		local foot = Vector3.new(mid + side * 12, title.Y + titleHeight / 2 + 0.1, title.Z - 0.3)
		rod(folder, "Branch", foot, foot + Vector3.new(-side * 5, 2.2, 0), 0.35, C.barkDark, Enum.Material.Wood, DECOR)
		rod(folder, "Branch", foot + Vector3.new(-side * 2.5, 1.1, 0), foot + Vector3.new(-side * 3.2, 3.6, -0.2), 0.22, C.barkDark, Enum.Material.Wood, DECOR)
	end
	local titleLight = Instance.new("SpotLight")
	titleLight.Face = Enum.NormalId.Top
	titleLight.Angle = 70
	titleLight.Range = 14
	titleLight.Brightness = 1.6
	titleLight.Color = C.warm
	local lamp = Vector3.new(mid, title.Y - titleHeight / 2 - 2, title.Z - 2)
	titleLight.Parent = block(folder, "TitleLight", Vector3.new(1, 0.4, 1), CFrame.new(lamp) * CFrame.Angles(math.rad(25), 0, 0), C.iron, Enum.Material.Metal, DECOR)
	beam(folder, "LampBracket", lamp, Vector3.new(mid, lamp.Y, front - WALL / 2), 0.3, C.iron, Enum.Material.Metal, DECOR)

	-- Banners off the upper floor and the balcony rail.
	for _, x in { x1 - 1.8, x0 + 1.8 } do
		banner(folder, Vector3.new(x, eave - 0.6, front - WALL / 2 - 0.2), 3.2, 10, -Vector3.zAxis)
	end
	for _, x in { -16, 30.2 } do
		banner(folder, Vector3.new(x, f2 + 3.35, L.balcony - 0.35), 3, 8, -Vector3.zAxis)
	end

	-- The balcony across the front, on posts, with the porch under it.
	deck(folder, x0, L.balcony, 34, front, f2, false, false)
	box(folder, "BalconyBeam", Vector3.new(x0, f2 - 1.7, L.balcony), Vector3.new(34, f2 - 0.8, L.balcony + 0.7), C.beam, Enum.Material.Wood)
	for x = x0 + 1.5, 34, 3 do
		box(folder, "Joist", Vector3.new(x - 0.2, f2 - 1.4, L.balcony + 0.7), Vector3.new(x + 0.2, f2 - 0.8, front), C.beam, Enum.Material.Wood, DECOR)
	end
	for _, x in { x0 + 0.5, -10, 2.4, 27.6, 33.5 } do
		local post = Vector3.new(x, 0, L.balcony + 0.4)
		block(folder, "PorchPost", Vector3.new(0.9, f2 - 1.7 - DECK, 0.9), CFrame.new(x, (DECK + f2 - 1.7) / 2, post.Z), vary(C.post, 0.1), Enum.Material.Wood)
		for _, side in { -1, 1 } do
			if x + side * 2 > x0 and x + side * 2 < 34 then
				beam(folder, "Brace", Vector3.new(x, f2 - 4.2, post.Z), Vector3.new(x + side * 2.2, f2 - 1.7, post.Z), 0.4, C.beam, Enum.Material.Wood, DECOR)
			end
		end
	end
	-- The roof's front edge rests on posts along the balcony.
	for _, x in { x0 + 0.6, -6, 14, 33.4 } do
		local top = roofAt(x) - 0.4
		block(folder, "RoofPost", Vector3.new(0.7, top - f2, 0.7), CFrame.new(x, (f2 + top) / 2, L.balcony + 0.4), vary(C.post, 0.1), Enum.Material.Wood)
	end
	local rail = L.balcony + 0.25
	woodRailing(folder, Vector3.new(x0, f2, rail), Vector3.new(34, f2, rail))
	woodRailing(folder, Vector3.new(x0 + 0.25, f2, rail), Vector3.new(x0 + 0.25, f2, front))
	woodRailing(folder, Vector3.new(33.75, f2, rail), Vector3.new(33.75, f2, -64.6))
	woodRailing(folder, Vector3.new(33.75, f2, -61.4), Vector3.new(33.75, f2, front))
	for _, x in { -17, -6.5, 9, 21, 30.5 } do
		hangingLantern(folder, Vector3.new(x, f2 - 1.7, -63), 0.6, 1, 16, 1.1)
	end
	for _, x in { DOOR.x0 - 1.4, DOOR.x1 + 1.4 } do
		block(folder, "LampBracket", Vector3.new(0.3, 0.3, 1.2), CFrame.new(x, DECK + 7.8, front - 0.9), C.iron, Enum.Material.Metal, DECOR)
		hangingLantern(folder, Vector3.new(x, DECK + 7.8, front - 1.4), 0.3, 0.8, 12, 1)
	end
	-- Steady footing in the doorways, over the walls' foot.
	for _, door in { { DOOR.x0, DOOR.x1, front }, { 16, 20, back } } do
		box(folder, "Threshold", Vector3.new(door[1], DECK - 0.35, door[3] - 0.5), Vector3.new(door[2], DECK, door[3] + 0.5), C.beam, Enum.Material.Wood)
	end

	-- Inside: the floor, the gallery over the front of the hall and the stair
	-- up to it along the left wall.
	deck(folder, x0, front, x1, back, DECK, true, false)
	deck(folder, x0 + WALL / 2, front + WALL / 2, x1 - WALL / 2, L.gallery, f2, true, false)
	for _, z in { -56, -50, L.gallery - 0.6 } do
		box(folder, "GalleryBeam", Vector3.new(x0, f2 - 1.9, z - 0.45), Vector3.new(x1, f2 - 1.1, z + 0.45), C.beam, Enum.Material.Wood, DECOR)
	end
	for _, x in { -12, 4, 20 } do
		block(folder, "GalleryPost", Vector3.new(0.9, f2 - 1.9 - DECK, 0.9), CFrame.new(x, (DECK + f2 - 1.9) / 2, L.gallery - 0.6), C.beam, Enum.Material.Wood)
		hangingLantern(folder, Vector3.new(x + 4, f2 - 1.9, L.gallery - 0.6), 0.8, 0.9, 18, 1.2)
	end
	woodRailing(folder, Vector3.new(x0 + 0.5, f2, L.gallery + 0.2), Vector3.new(26.8, f2, L.gallery + 0.2))
	local stairX, stairWidth, stairFoot, run = x1 - WALL / 2 - 2.2, 4, -28, 16
	local steps = 14
	for i = 1, steps do
		local z = stairFoot - run * (i - 0.5) / steps
		block(folder, "Step", Vector3.new(stairWidth, i, run / steps + 0.02), CFrame.new(stairX, DECK + i / 2, z), vary(C.plank, 0.12), Enum.Material.Wood, DECOR)
	end
	wedge(folder, "StairRamp", Vector3.new(stairWidth, f2 - DECK, run), CFrame.new(stairX, (DECK + f2) / 2, stairFoot - run / 2) * CFrame.Angles(0, math.pi, 0), C.plank, Enum.Material.Wood, FOOTING)
	beam(folder, "StairRail", Vector3.new(stairX - 2.1, DECK + 3.4, stairFoot), Vector3.new(stairX - 2.1, f2 + 3.4, stairFoot - run), 0.3, C.post, Enum.Material.Wood, DECOR)
	for i = 0, 3 do
		local z = stairFoot - run * i / 3
		local y = DECK + (f2 - DECK) * i / 3
		block(folder, "RailPost", Vector3.new(0.4, 3.4, 0.4), CFrame.new(stairX - 2.1, y + 1.7, z), C.beam, Enum.Material.Wood, DECOR)
	end

	-- Tie beams across the hall under the roof, with lanterns down from them.
	for _, z in { -38, -30 } do
		beam(folder, "TieBeam", Vector3.new(x0, eave - 0.6, z), Vector3.new(x1, eave - 0.6, z), 1, C.beam)
		hangingLantern(folder, Vector3.new(mid - 9, eave - 1.1, z), 6, 1.1, 20, 1.2)
		hangingLantern(folder, Vector3.new(mid + 9, eave - 1.1, z), 6, 1.1, 20, 1.2)
	end

	-- The fire, in a stone hearth on the back wall.
	local hz = back - WALL / 2
	box(folder, "Hearth", Vector3.new(mid - 4.5, DECK, hz - 2.4), Vector3.new(mid + 4.5, DECK + 0.6, hz), C.stone, Enum.Material.Slate)
	for _, side in { -1, 1 } do
		box(folder, "Fireplace", Vector3.new(mid + side * 3, DECK, hz - 2), Vector3.new(mid + side * 4.5, DECK + 7, hz), C.stone, Enum.Material.Cobblestone)
	end
	box(folder, "Fireplace", Vector3.new(mid - 4.8, DECK + 7, hz - 2.3), Vector3.new(mid + 4.8, DECK + 8, hz), C.stone, Enum.Material.Cobblestone)
	box(folder, "Mantle", Vector3.new(mid - 5.2, DECK + 8, hz - 2.6), Vector3.new(mid + 5.2, DECK + 8.5, hz), C.beam, Enum.Material.Wood)
	box(folder, "Chimney", Vector3.new(mid - 3.5, DECK + 8.5, hz - 1.8), Vector3.new(mid + 3.5, peak - 3, hz), C.stone, Enum.Material.Cobblestone)
	box(folder, "Firebox", Vector3.new(mid - 3, DECK + 0.6, hz - 0.5), Vector3.new(mid + 3, DECK + 7, hz - 0.2), C.under, Enum.Material.Slate, DECOR)
	for i = 0, 2 do
		rod(folder, "Log", Vector3.new(mid - 2, DECK + 0.9 + i * 0.35, hz - 1.4 + i * 0.3), Vector3.new(mid + 2, DECK + 0.9 + i * 0.35, hz - 1.1 - i * 0.2), 0.6, C.barkDark, Enum.Material.Wood, DECOR)
	end
	local embers = block(folder, "Embers", Vector3.new(4, 0.3, 1.4), CFrame.new(mid, DECK + 0.75, hz - 1.2), C.ember, Enum.Material.Neon, NEON)
	local fire = Instance.new("Fire")
	fire.Size = 4
	fire.Heat = 7
	fire.Color = Color3.fromRGB(255, 120, 40)
	fire.SecondaryColor = Color3.fromRGB(255, 200, 90)
	fire.Parent = embers
	local fireLight = Instance.new("PointLight")
	fireLight.Color = C.fire
	fireLight.Range = 26
	fireLight.Brightness = 2
	fireLight.Shadows = true
	fireLight.Parent = embers
	CollectionService:AddTag(embers, "LobbyLantern")

	-- Tables with old maps, benches, a rug, and the expedition's supplies.
	box(folder, "Rug", Vector3.new(mid - 7, DECK, -41), Vector3.new(mid + 7, DECK + 0.05, -31), C.rug, Enum.Material.Fabric, DECOR)
	for _, spot in { { 15, -34 }, { -9, -36 } } do
		local x, z = spot[1], spot[2]
		box(folder, "Table", Vector3.new(x - 4.5, DECK + 2.8, z - 1.7), Vector3.new(x + 4.5, DECK + 3.2, z + 1.7), vary(C.plank, 0.15), Enum.Material.Wood)
		for _, corner in { { -4, -1.3 }, { 4, -1.3 }, { -4, 1.3 }, { 4, 1.3 } } do
			box(folder, "TableLeg", Vector3.new(x + corner[1] - 0.2, DECK, z + corner[2] - 0.2), Vector3.new(x + corner[1] + 0.2, DECK + 2.8, z + corner[2] + 0.2), C.beam, Enum.Material.Wood)
		end
		for _, side in { -1, 1 } do
			box(folder, "Bench", Vector3.new(x - 4, DECK + 1.6, z + side * 2.6 - 0.55), Vector3.new(x + 4, DECK + 1.9, z + side * 2.6 + 0.55), vary(C.plank, 0.15), Enum.Material.Wood)
			for _, end_ in { -3.5, 3.5 } do
				box(folder, "BenchLeg", Vector3.new(x + end_ - 0.2, DECK, z + side * 2.6 - 0.4), Vector3.new(x + end_ + 0.2, DECK + 1.6, z + side * 2.6 + 0.4), C.beam, Enum.Material.Wood)
			end
		end
		local map = CFrame.new(x - 1.2, DECK + 3.23, z + 0.2) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0)
		block(folder, "Map", Vector3.new(3.4, 0.04, 2.4), map, C.paper, Enum.Material.Fabric, DECOR)
		for i = 1, 3 do
			block(folder, "MapLine", Vector3.new(rng:NextNumber(1.2, 2.6), 0.02, 0.07), map * CFrame.new(rng:NextNumber(-0.5, 0.5), 0.03, -0.8 + i * 0.4) * CFrame.Angles(0, rng:NextNumber(-0.5, 0.5), 0), C.ink, nil, DECOR)
		end
		lantern(folder, Vector3.new(x + 2.6, DECK + 3.65, z - 0.4), 0.7, 10, 0.8)
	end
	crate(folder, CFrame.new(-20.5, DECK + 1.25, -29.6) * CFrame.Angles(0, 0.2, 0), 2.5)
	crate(folder, CFrame.new(-17.8, DECK + 1, -29.5) * CFrame.Angles(0, -0.3, 0), 2)
	crate(folder, CFrame.new(-20.2, DECK + 3.4, -29.8) * CFrame.Angles(0, 0.7, 0), 1.8)
	barrel(folder, Vector3.new(-21, DECK, -41), 2.6)
	barrel(folder, Vector3.new(-21.2, DECK, -43.8), 2.4)
	crate(folder, CFrame.new(-20.6, DECK + 1.1, -51) * CFrame.Angles(0, 0.4, 0), 2.2)
	crate(folder, CFrame.new(29, DECK + 1, -51) * CFrame.Angles(0, -0.2, 0), 2)
	for _, z in { -47, -45.6 } do
		rod(folder, "Oar", Vector3.new(x1 - 0.7, DECK + 0.2, z), Vector3.new(x1 - 0.9, DECK + 7.5, z + 0.6), 0.25, C.plank, Enum.Material.Wood, DECOR)
	end

	-- The record boards, on the left side wall under a sign, two by two.
	local boards = {}
	local spots = {
		Escapes = { -38.5, DECK + 13.4 },
		Easy = { -49.5, DECK + 13.4 },
		Normal = { -38.5, DECK + 5.2 },
		Hard = { -49.5, DECK + 5.2 },
	}
	local glows = { Escapes = C.sky, Easy = C.mint, Normal = C.lemon, Hard = C.pink }
	local face = x1 + WALL / 2
	for id, spot in spots do
		local z, y = spot[1], spot[2]
		local turn = CFrame.Angles(0, math.pi, 0) -- so its left face, where Leaderboards draws, faces out
		block(folder, "BoardGlow", Vector3.new(0.2, 8.6, 10.1), CFrame.new(face + 0.1, y, z) * turn, glows[id]:Lerp(Color3.new(), 0.6), Enum.Material.Neon, NEON)
		block(folder, "BoardFrame", Vector3.new(0.3, 8.1, 9.6), CFrame.new(face + 0.3, y, z) * turn, C.trim, Enum.Material.Wood)
		boards[id] = block(folder, "Board" .. id, Vector3.new(0.4, 7.5, 9), CFrame.new(face + 0.5, y, z) * turn, C.signBoard)
	end
	local recordsAt = Vector3.new(face + 0.6, DECK + 19.4, -44)
	letters(sign(folder, CFrame.lookAt(recordsAt, recordsAt + Vector3.xAxis), 13, 2.6), { Size = UDim2.fromScale(1, 1), Text = "Records" })
	for _, z in { -56, -32 } do
		block(folder, "LampBracket", Vector3.new(1.2, 0.3, 0.3), CFrame.new(face + 0.6, DECK + 10, z), C.iron, Enum.Material.Metal, DECOR)
		hangingLantern(folder, Vector3.new(face + 1.1, DECK + 10, z), 0.3, 0.9, 14, 1.1)
	end
	local glow = Instance.new("PointLight")
	glow.Color = C.warm
	glow.Range = 18
	glow.Brightness = 0.5
	glow.Parent = block(folder, "Glow", Vector3.one * 0.2, CFrame.new(face + 6, DECK + 10, -44), C.warm, nil, HIDDEN)
	return boards
end

-- The premium skins' display, in a bay in the lodge's front under the
-- balcony: a lit plinth with a pedestal for each, a plaque with its name and
-- price, a prompt that opens the shop's Premium tab, and the SKINS sign
-- hanging from the balcony. The mannequins come after (buildMannequins).
-- Returns where each one stands, left to right as you face it.
local function buildSkins(folder)
	local front = LODGE.front
	box(folder, "BayBack", Vector3.new(BAY.x0, DECK, BAY.back - WALL / 2), Vector3.new(BAY.x1, BAY.top, BAY.back + WALL / 2), C.siding, Enum.Material.WoodPlanks)
	box(folder, "BayCloth", Vector3.new(BAY.x0 + 0.4, DECK + 1.2, BAY.back - WALL / 2 - 0.1), Vector3.new(BAY.x1 - 0.4, BAY.top - 0.4, BAY.back - WALL / 2), C.cloth, Enum.Material.Fabric, DECOR)
	for _, x in { BAY.x0, BAY.x1 } do
		box(folder, "BaySide", Vector3.new(x - WALL / 2, DECK, front), Vector3.new(x + WALL / 2, BAY.top, BAY.back), C.siding, Enum.Material.WoodPlanks)
	end
	box(folder, "BayCeiling", Vector3.new(BAY.x0, BAY.top - 0.4, front - 0.2), Vector3.new(BAY.x1, BAY.top + 0.4, BAY.back), C.beam, Enum.Material.Wood)
	box(folder, "Plinth", Vector3.new(BAY.x0 + 0.4, DECK, front + 0.6), Vector3.new(BAY.x1 - 0.4, DECK + 1.2, BAY.back - 0.4), vary(C.beam, 0.1), Enum.Material.Wood)
	box(folder, "PlinthTrim", Vector3.new(BAY.x0 + 0.3, DECK + 1.1, front + 0.5), Vector3.new(BAY.x1 - 0.3, DECK + 1.3, front + 0.75), C.trim, Enum.Material.Wood, DECOR)
	-- Nobody climbs in among them; their prompts reach through.
	box(folder, "BayBarrier", Vector3.new(BAY.x0, DECK, front - 0.4), Vector3.new(BAY.x1, BAY.top, front - 0.1), C.post, nil, BARRIER)

	local skins = {}
	for _, item in Catalog.items do
		if item.premium then
			table.insert(skins, item)
		end
	end
	local slotWidth = (BAY.x1 - BAY.x0) / #skins
	local slots = {}
	for i, item in skins do
		local x = BAY.x1 - slotWidth * (i - 0.5)
		local z = (front + BAY.back) / 2 - 0.2
		local pedestal = drum(folder, "Pedestal", Vector3.new(x, DECK + 1.2, z), 0.5, 3.4, C.stone, Enum.Material.Slate)
		drum(folder, "PedestalRim", Vector3.new(x, DECK + 1.62, z), 0.1, 3.6, C.trim, Enum.Material.Wood, DECOR)
		if i > 1 then
			local edge = x + slotWidth / 2
			box(folder, "BayDivider", Vector3.new(edge - 0.2, DECK + 1.2, BAY.back - 1.6), Vector3.new(edge + 0.2, BAY.top - 0.4, BAY.back - 0.4), C.beam, Enum.Material.Wood, DECOR)
		end

		-- A spotlight from above, and a soft glow of the skin's own colour behind it.
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Bottom
		spot.Angle = 70
		spot.Range = 15
		spot.Brightness = 3.4
		spot.Color = C.spot
		spot.Parent = block(folder, "SpotLamp", Vector3.new(0.8, 0.4, 0.8), CFrame.new(x, BAY.top - 0.65, front + 0.9) * CFrame.Angles(math.rad(-20), 0, 0), C.iron, Enum.Material.Metal, DECOR)
		local back = Instance.new("PointLight")
		back.Color = item.swatch:Lerp(Color3.new(1, 1, 1), 0.3)
		back.Range = 7
		back.Brightness = 0.9
		back.Parent = block(folder, "Glow", Vector3.one * 0.2, CFrame.new(x, DECK + 5.5, BAY.back - 1.6), C.warm, nil, HIDDEN)

		-- Its plaque: name, PREMIUM and its price (from its Game Pass, once known).
		local plaque = block(folder, "Plaque", Vector3.new(slotWidth - 0.9, 0.95, 0.12), CFrame.new(x, DECK + 0.6, front + 0.52), C.signBoard, Enum.Material.Wood, DECOR)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.LightInfluence = 0.2
		gui.Parent = plaque
		letters(gui, { Position = UDim2.fromScale(0.04, 0.04), Size = UDim2.fromScale(0.92, 0.52), Text = string.upper(item.name) }, 1.5)
		local price = letters(gui, {
			Position = UDim2.fromScale(0.04, 0.58),
			Size = UDim2.fromScale(0.92, 0.38),
			TextColor3 = C.lemon,
			Text = ("PREMIUM  ·  R$ %d"):format(item.robux),
		}, 1.5)
		local passId = Config.Passes[item.premium]
		if passId and passId ~= 0 then
			task.spawn(function()
				local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, passId, Enum.InfoType.GamePass)
				if ok and info and info.PriceInRobux then
					price.Text = ("PREMIUM  ·  R$ %d"):format(info.PriceInRobux)
				end
			end)
		end

		local chest = Instance.new("Attachment")
		chest.Name = "PromptAt"
		chest.Parent = pedestal
		chest.WorldCFrame = CFrame.new(x, DECK + 5, z)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ViewSkin"
		prompt.ActionText = "See in shop"
		prompt.ObjectText = item.name
		prompt.KeyboardKeyCode = Enum.KeyCode.G -- E throws
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("SkinId", item.id)
		prompt.Parent = chest
		table.insert(slots, { item = item, at = Vector3.new(x, DECK + 1.72, z) })
	end

	local signAt = Vector3.new((BAY.x0 + BAY.x1) / 2, DECK + 10.9, LODGE.balcony + 0.25)
	letters(sign(folder, CFrame.lookAt(signAt, signAt - Vector3.zAxis), 9, 2.6, 0.3), { Size = UDim2.fromScale(1, 1), Text = "Skins" })
	for _, side in { -1, 1 } do
		rod(folder, "Chain", signAt + Vector3.new(side * 3.6, 1.45, 0), signAt + Vector3.new(side * 3.6, LODGE.floor2 - 1.7 - signAt.Y, 0), 0.08, C.iron, Enum.Material.Metal, DECOR)
	end
	return slots
end

-- The mannequins, one in each premium skin, dressed the way a player who
-- owns it would be (SkinLook and OutfitLook) and tagged so every client
-- gives them its move (client/SkinMoves.luau). They take a moment to make,
-- so they are made after the rest; one that fails is skipped.
local function buildMannequins(folder, slots)
	for i, slot in slots do
		task.spawn(function()
			local ok, model = pcall(Players.CreateHumanoidModelFromDescription, Players, Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
			if not ok then
				warn("[LobbyBuilder] Couldn't make the " .. slot.item.name .. " mannequin:", model)
				return
			end
			model.Name = "Mannequin_" .. slot.item.id
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
				humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
				humanoid.BreakJointsOnDeath = false
				humanoid.EvaluateStateMachine = false
			end
			local animate = model:FindFirstChild("Animate")
			if animate then
				animate:Destroy()
			end
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") then
					part.CanCollide = false
					part.CanTouch = false
					part.CanQuery = false
				end
			end
			local root = model:FindFirstChild("HumanoidRootPart")
			if root then
				root.Anchored = true
			end
			model:ScaleTo(1.25)
			model:PivotTo(CFrame.new(slot.at))
			local center, size = model:GetBoundingBox()
			model:PivotTo(model:GetPivot() + Vector3.new(0, slot.at.Y - (center.Y - size.Y / 2), 0))
			model:SetAttribute("Seed", i * 211)
			model.Parent = folder
			SkinLook.apply(model, slot.item)
			OutfitLook.apply(model, slot.item)
			model:SetAttribute("SkinMove", slot.item.move)
			CollectionService:AddTag(model, "SkinMannequin")
		end)
	end
end

-- The supply store against the lodge's right side: boards with a false front
-- carrying its sign, a counter under an awning (its prompt opens the shop),
-- shelves of bottles and jars behind, tools, a lantern.
local function buildShop(folder)
	local S = SHOP
	local frontTop, sideTop, backTop = DECK + 13, DECK + 9.4, DECK + 11
	wall(folder, Vector3.new(S.x1, 0, S.front), Vector3.new(S.x0, 0, S.front), DECK, frontTop, {
		{ 4, 16, DECK + 3.4, DECK + 7 },
	}, -Vector3.zAxis, C.sidingGray)
	wall(folder, Vector3.new(S.x0, 0, S.front), Vector3.new(S.x0, 0, S.back), DECK, sideTop, {
		{ 7, 10, DECK + 4, DECK + 7, window = "lit" },
	}, -Vector3.xAxis, C.sidingGray)
	wall(folder, Vector3.new(S.x0, 0, S.back), Vector3.new(S.x1, 0, S.back), DECK, backTop, {}, Vector3.zAxis, C.sidingGray)
	triangle(folder, "Wall", Vector3.new(S.x0, sideTop, S.front), Vector3.new(S.x0, backTop, S.back), Vector3.new(S.x0, sideTop, S.back), WALL, C.sidingGray, Enum.Material.WoodPlanks)
	box(folder, "FalseFrontCap", Vector3.new(S.x0 - 0.5, frontTop, S.front - 0.7), Vector3.new(S.x1 + 0.3, frontTop + 0.5, S.front + 0.5), C.trim, Enum.Material.Wood)
	for _, x in { S.x0, S.x1 } do
		block(folder, "CornerPost", Vector3.new(1.1, frontTop - DECK, 1.1), CFrame.new(x, (DECK + frontTop) / 2, S.front), C.beam, Enum.Material.Wood)
	end
	roofSide(folder, Vector3.new(S.x0 - 0.4, sideTop + 0.1, S.front + 0.4), Vector3.new(S.x1 + 0.2, sideTop + 0.1, S.front + 0.4), Vector3.new(S.x0 - 0.4, backTop + 0.4, S.back + 0.8), Vector3.new(S.x1 + 0.2, backTop + 0.4, S.back + 0.8), 7)

	local signAt = Vector3.new((S.x0 + S.x1) / 2, DECK + 10.6, S.front - WALL / 2 - 0.25)
	letters(sign(folder, CFrame.lookAt(signAt, signAt - Vector3.zAxis), 10, 2.8), { Size = UDim2.fromScale(1, 1), Text = "Shop" })
	for _, x in { S.x0 + 2, S.x1 - 2 } do
		block(folder, "LampBracket", Vector3.new(0.3, 0.3, 1.2), CFrame.new(x, DECK + 8.4, S.front - 0.9), C.iron, Enum.Material.Metal, DECOR)
		hangingLantern(folder, Vector3.new(x, DECK + 8.4, S.front - 1.4), 0.3, 0.8, 14, 1.1)
	end

	-- The counter, and an awning over it.
	local cx0, cx1 = S.x1 - 16, S.x1 - 4
	box(folder, "Counter", Vector3.new(cx0 - 0.2, DECK, S.front - 1.2), Vector3.new(cx1 + 0.2, DECK + 3.4, S.front + 0.4), vary(C.plank, 0.1), Enum.Material.WoodPlanks)
	box(folder, "CounterTop", Vector3.new(cx0 - 0.6, DECK + 3.4, S.front - 1.6), Vector3.new(cx1 + 0.6, DECK + 3.75, S.front + 0.8), C.beam, Enum.Material.Wood)
	local awning = CFrame.new((cx0 + cx1) / 2, DECK + 7.7, S.front - 1.8) * CFrame.Angles(math.rad(-18), 0, 0)
	block(folder, "Awning", Vector3.new(cx1 - cx0 + 1.6, 0.12, 3.4), awning, C.awning, Enum.Material.Fabric, DECOR)
	for i = 0, 8 do
		local x = cx0 - 0.8 + (cx1 - cx0 + 1.6) * (i + 0.5) / 9
		block(folder, "AwningFringe", Vector3.new((cx1 - cx0 + 1.6) / 9 - 0.12, 0.55, 0.08), awning * CFrame.new(x - (cx0 + cx1) / 2, -0.1, -1.7) * CFrame.Angles(math.rad(18), 0, 0) * CFrame.new(0, -0.28, 0), if i % 2 == 0 then C.awning else C.bannerPale:Lerp(C.awning, 0.4), Enum.Material.Fabric, DECOR)
	end
	drum(folder, "Bell", Vector3.new(cx1 - 1.2, DECK + 3.75, S.front - 0.6), 0.35, 0.6, Color3.fromRGB(150, 120, 60), Enum.Material.Metal, DECOR)
	lantern(folder, Vector3.new(cx0 + 1.2, DECK + 4.2, S.front - 0.5), 0.7, 10, 0.8)
	local counter = block(folder, "ShopCounter", Vector3.new(cx1 - cx0, 6, 3), CFrame.new((cx0 + cx1) / 2, DECK + 3, S.front - 1), C.lemon, nil, HIDDEN)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OpenShop"
	prompt.ActionText = "Open shop"
	prompt.ObjectText = "Shop"
	prompt.KeyboardKeyCode = Enum.KeyCode.G -- E throws
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter

	-- Behind the counter: shelves of bottles and jars, crates, tools, a lantern.
	local shelfZ = S.back - WALL / 2
	for _, y in { DECK + 2.6, DECK + 5, DECK + 7.4 } do
		box(folder, "Shelf", Vector3.new(S.x0 + 1, y - 0.2, shelfZ - 1.3), Vector3.new(S.x1 - 1, y, shelfZ), C.beam, Enum.Material.Wood)
		local x = S.x0 + 1.6
		while x < S.x1 - 1.6 do
			local tall = rng:NextNumber(0.7, 1.3)
			local color = if rng:NextNumber() < 0.5 then C.bottleGreen else C.bottleBrown
			drum(folder, "Bottle", Vector3.new(x, y, shelfZ - rng:NextNumber(0.4, 0.9)), tall, rng:NextNumber(0.35, 0.6), vary(color, 0.2), Enum.Material.Glass, { CanCollide = false, CanQuery = false, Transparency = 0.15 })
			x += rng:NextNumber(0.7, 1.4)
		end
	end
	for _, x in { S.x0 + 0.8, S.x1 - 0.8 } do
		block(folder, "ShelfPost", Vector3.new(0.3, 8, 0.3), CFrame.new(x, DECK + 4, shelfZ - 0.6), C.beam, Enum.Material.Wood, DECOR)
	end
	crate(folder, CFrame.new(S.x0 + 2.2, DECK + 1.1, S.front + 3) * CFrame.Angles(0, 0.3, 0), 2.2)
	barrel(folder, Vector3.new(S.x1 - 2, DECK, S.back - 3), 2.6)
	rod(folder, "Shovel", Vector3.new(S.x1 - 1.2, DECK + 0.3, S.back - 1.4), Vector3.new(S.x1 - 1.4, DECK + 5.6, S.back - 1.1), 0.2, C.plank, Enum.Material.Wood, DECOR)
	block(folder, "ShovelHead", Vector3.new(0.9, 1.2, 0.1), CFrame.new(S.x1 - 1.2, DECK + 0.9, S.back - 1.4), C.rust, Enum.Material.Metal, DECOR)
	hangingLantern(folder, Vector3.new((S.x0 + S.x1) / 2, DECK + 9.6, (S.front + S.back) / 2), 1, 1, 16, 1.2)
	-- Supplies stacked outside by the porch.
	crate(folder, CFrame.new(S.x1 - 1.6, DECK + 1, S.front - 2.6) * CFrame.Angles(0, 0.2, 0), 2)
	barrel(folder, Vector3.new(S.x0 + 1.6, DECK, S.front - 1.4), 2.4)
end

-- The party station on the left: a deck under an awning, two pads in front
-- of a notice board with a painted board over each, a table of maps.
-- Returns its doors (see buildDoors).
local function buildPartyStation(folder, specs)
	local P = PARTY
	deck(folder, P.x0, P.z0, P.x1, P.z1, P.top, true)
	local function at(x, z)
		return Vector3.new(x, P.top, z)
	end
	railing(folder, at(P.x0, P.z0), at(P.x1, P.z0), 3, -Vector3.zAxis)
	railing(folder, at(P.x1, P.z0), at(P.x1, P.z1), 3, Vector3.xAxis)
	railing(folder, at(P.x1, P.z1), at(48, P.z1))
	railing(folder, at(P.x0, -98), at(P.x0, P.z0))

	-- The awning: four posts and a sloping roof, its high side at the back.
	local high, low = P.top + 11.6, P.top + 9.4
	for _, x in { P.x0 + 2, P.x1 - 2 } do
		for _, z in { P.z1 - 2, P.z1 - 18 } do
			local top = if z < P.z1 - 10 then low else high
			block(folder, "AwningPost", Vector3.new(0.9, top - P.top, 0.9), CFrame.new(x, (P.top + top) / 2, z), vary(C.post, 0.1), Enum.Material.Wood)
		end
	end
	roofSide(folder, Vector3.new(P.x0 + 0.5, low - 0.3, P.z1 - 20), Vector3.new(P.x1 - 0.5, low - 0.3, P.z1 - 20), Vector3.new(P.x0 + 0.5, high + 0.2, P.z1 - 0.5), Vector3.new(P.x1 - 0.5, high + 0.2, P.z1 - 0.5), 8)
	beam(folder, "AwningBeam", Vector3.new(P.x0 + 1, low - 0.6, P.z1 - 18), Vector3.new(P.x1 - 1, low - 0.6, P.z1 - 18), 0.7, C.beam)
	for _, x in { P.x0 + 6, P.x1 - 6 } do
		hangingLantern(folder, Vector3.new(x, low - 1, P.z1 - 18), 0.8, 1, 18, 1.3)
	end
	moss(folder, Vector3.new(P.x0 + 1.5, low - 0.6, P.z1 - 19.6), 3)
	moss(folder, Vector3.new(P.x1 - 9, low - 0.6, P.z1 - 19.6), 2.4)

	-- The PARTY sign, up on the awning's front edge.
	local signAt = Vector3.new((P.x0 + P.x1) / 2, low + 2, P.z1 - 19.9)
	letters(sign(folder, CFrame.lookAt(signAt, signAt - Vector3.zAxis), 11, 3, 0.3), { Size = UDim2.fromScale(1, 1), Text = "Party" })
	for _, side in { -1, 1 } do
		block(folder, "SignPost", Vector3.new(0.4, 2.6, 0.4), CFrame.new(signAt.X + side * 4.5, low + 0.3, signAt.Z + 0.4), C.beam, Enum.Material.Wood, DECOR)
	end

	-- The notice board along the back, with old papers pinned round the edges.
	local boardZ = P.z1 - 2.6
	box(folder, "NoticeBoard", Vector3.new(P.x0 + 3, P.top + 1, boardZ - 0.2), Vector3.new(P.x1 - 3, P.top + 9.6, boardZ + 0.3), C.beam, Enum.Material.WoodPlanks)
	for _ = 1, 9 do
		local x = rng:NextNumber(P.x0 + 4, P.x1 - 4)
		local y = if rng:NextNumber() < 0.5 then P.top + rng:NextNumber(1.6, 2.4) else P.top + rng:NextNumber(8.4, 9)
		block(folder, "Paper", Vector3.new(rng:NextNumber(0.9, 1.5), rng:NextNumber(1, 1.4), 0.04), CFrame.new(x, y, boardZ - 0.24) * CFrame.Angles(0, 0, rng:NextNumber(-0.2, 0.2)), vary(C.paper, 0.2), Enum.Material.Fabric, DECOR)
	end

	-- The pads and their boards, the first on the left as you face them.
	local doors = {}
	for i, spec in specs do
		local x = P.x1 - 8 - (i - 1) * 12
		local look = DOOR_LOOKS[spec.mode]
		local boardAt = Vector3.new(x, P.top + 5.6, boardZ - 0.45)
		local title, status = padBoard(folder, CFrame.lookAt(boardAt, boardAt - Vector3.zAxis), 10, 5.8, look, if spec.mode == "party" then "PARTY" else nil)
		local pad = glowPad(folder, x, P.top, P.z1 - 9.5, ROOM.DoorWidth, 6, look.color)
		table.insert(doors, { spec = spec, pad = pad, title = title, status = status })
	end

	-- A table of maps and a couple of stools to the side.
	local tx, tz = P.x1 - 6, P.z0 + 6
	box(folder, "Table", Vector3.new(tx - 2.8, P.top + 2.8, tz - 1.6), Vector3.new(tx + 2.8, P.top + 3.2, tz + 1.6), vary(C.plank, 0.15), Enum.Material.Wood)
	for _, corner in { { -2.4, -1.2 }, { 2.4, -1.2 }, { -2.4, 1.2 }, { 2.4, 1.2 } } do
		box(folder, "TableLeg", Vector3.new(tx + corner[1] - 0.2, P.top, tz + corner[2] - 0.2), Vector3.new(tx + corner[1] + 0.2, P.top + 2.8, tz + corner[2] + 0.2), C.beam, Enum.Material.Wood)
	end
	block(folder, "Map", Vector3.new(3, 0.04, 2.2), CFrame.new(tx - 0.4, P.top + 3.23, tz) * CFrame.Angles(0, 0.25, 0), C.paper, Enum.Material.Fabric, DECOR)
	lantern(folder, Vector3.new(tx + 1.9, P.top + 3.65, tz - 0.5), 0.7, 10, 0.8)
	for _, side in { -1, 1 } do
		drum(folder, "Stool", Vector3.new(tx + side * 1.6, P.top, tz - 2.8), 1.8, 1.3, vary(C.plank, 0.15), Enum.Material.Wood)
	end
	crate(folder, CFrame.new(P.x0 + 2.4, P.top + 1.1, P.z0 + 2.6) * CFrame.Angles(0, 0.4, 0), 2.2)
	barrel(folder, Vector3.new(P.x0 + 5.2, P.top, P.z0 + 2.2), 2.4)
	return doors
end

-- The way to the adventure: a mine tunnel into a crag of rock on the right,
-- framed in massive timbers under its LAUNCH ADVENTURE sign, timber sets
-- and old rails going in, and far inside, where the way caves in, a green
-- glow and mist drifting out. Its three pads are in the mouth, each with
-- its board hanging over it. Returns its doors (see buildDoors).
local function buildGate(folder, specs)
	local G = GATE
	local x, z, half, height, depth = G.x, G.z, G.half, G.height, G.depth
	local floor = DECK + 0.25
	local terrain = workspace.Terrain
	terrain:SetMaterialColor(Enum.Material.Basalt, Color3.fromRGB(62, 64, 70))

	-- The crag: rock round the tunnel and up into the ridge, then the tunnel
	-- and the space in front of its mouth cut out of it.
	local r = Random.new(4433)
	for d = 2, depth + 6, 6 do
		for _, side in { -1, 1 } do
			terrain:FillBall(Vector3.new(x + side * (half + 5), DECK + 3 + r:NextNumber(-1, 2), z + d), r:NextNumber(8.5, 10), Enum.Material.Basalt)
		end
		terrain:FillBall(Vector3.new(x + r:NextNumber(-3, 3), floor + height + 6, z + d), r:NextNumber(9, 11), Enum.Material.Basalt)
	end
	-- x, y (over the boardwalk), z (into the crag) and size of each lump: a
	-- cliff over the mouth, stepping up and back into the ridge, and spreading
	-- off to the right into the swamp.
	local lumps = {
		{ -6, 22, 16, 15 }, { -18, 10, 30, 18 }, { 10, 16, 32, 12 }, { -28, 18, 50, 20 }, { 2, 24, 44, 16 },
		{ -26, 6, 8, 12 }, { -40, 14, 22, 19 }, { -62, 12, 34, 22 }, { -20, 32, 30, 16 }, { 0, 36, 54, 18 },
		{ -48, 30, 56, 22 }, { -84, 8, 40, 20 }, { 12, 6, 12, 7 },
	}
	for _, lump in lumps do
		terrain:FillBall(Vector3.new(x + lump[1], DECK + lump[2], z + lump[3]), lump[4], Enum.Material.Basalt)
	end
	terrain:FillBlock(CFrame.new(x, (DECK - 0.6 + floor + height + 0.5) / 2, z + depth / 2 + 0.5), Vector3.new(half * 2, floor + height + 0.5 - (DECK - 0.6), depth + 1), Enum.Material.Air)
	terrain:FillBlock(CFrame.new(x, DECK + 15, -84), Vector3.new(40, 30, 28), Enum.Material.Air)

	-- The tunnel's floor, and its end: a fall of rock with the glow behind.
	box(folder, "TunnelFloor", Vector3.new(x - half, DECK - 0.6, z), Vector3.new(x + half, floor, z + depth), Color3.fromRGB(58, 54, 50), Enum.Material.Slate)
	box(folder, "TunnelEnd", Vector3.new(x - half, floor, z + depth - 0.5), Vector3.new(x + half, floor + height, z + depth + 1), Color3.fromRGB(44, 46, 48), Enum.Material.Basalt)
	box(folder, "TunnelEndBarrier", Vector3.new(x - half, floor, z + depth - 6), Vector3.new(x + half, floor + height, z + depth - 5.4), C.post, nil, BARRIER)
	for _ = 1, 7 do
		local size = r:NextNumber(1.6, 3.4)
		block(folder, "FallenRock", Vector3.new(size * 1.3, size, size), CFrame.new(x + r:NextNumber(-half + 2, half - 2), floor + size * 0.35, z + depth - r:NextNumber(1, 4)) * CFrame.Angles(r:NextNumber(0, 1), r:NextNumber(0, 3), r:NextNumber(0, 1)), Color3.fromRGB(56, 58, 62), Enum.Material.Basalt, DECOR)
	end
	local glow = block(folder, "DeepGlow", Vector3.new(half * 1.2, height * 0.5, 0.2), CFrame.new(x, floor + height * 0.45, z + depth - 0.7), C.greenGlow, Enum.Material.Neon, { CanCollide = false, CanQuery = false, CastShadow = false, CanTouch = false, Transparency = 0.35 })
	local green = Instance.new("PointLight")
	green.Color = C.green
	green.Range = 30
	green.Brightness = 1.4
	green.Parent = block(folder, "GreenLight", Vector3.one * 0.2, CFrame.new(x, floor + 5, z + depth - 4), C.green, nil, HIDDEN)
	local mist = Instance.new("ParticleEmitter")
	mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
	mist.Color = ColorSequence.new(Color3.fromRGB(120, 170, 140))
	mist.LightEmission = 0.25
	mist.LightInfluence = 0.5
	mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.86), NumberSequenceKeypoint.new(0.75, 0.9), NumberSequenceKeypoint.new(1, 1) })
	mist.Size = NumberSequence.new(5, 11)
	mist.Lifetime = NumberRange.new(9, 13)
	mist.Rate = 5
	mist.Speed = NumberRange.new(1.6, 2.6)
	mist.SpreadAngle = Vector2.new(20, 8)
	mist.Rotation = NumberRange.new(0, 360)
	mist.RotSpeed = NumberRange.new(-8, 8)
	mist.EmissionDirection = Enum.NormalId.Front -- toward the mouth
	mist.Parent = glow

	-- Timber sets every few studs into the dark, and rails along the floor.
	for d = 4, depth - 6, 6 do
		for _, side in { -1, 1 } do
			block(folder, "TunnelPost", Vector3.new(1.1, height - 1, 1.1), CFrame.new(x + side * (half - 0.8), floor + (height - 1) / 2, z + d) * CFrame.Angles(0, 0, side * 0.04), vary(C.post, 0.1), Enum.Material.Wood)
		end
		block(folder, "TunnelCap", Vector3.new(half * 2 - 0.4, 1.1, 1.2), CFrame.new(x, floor + height - 0.9, z + d), vary(C.post, 0.1), Enum.Material.Wood)
	end
	for _, side in { -0.9, 0.9 } do
		box(folder, "Rail", Vector3.new(x + side - 0.1, floor, z + 10), Vector3.new(x + side + 0.1, floor + 0.2, z + depth - 6), C.rust, Enum.Material.Metal, DECOR)
	end
	for d = 10.5, depth - 6.5, 1.6 do
		box(folder, "Sleeper", Vector3.new(x - 1.5, floor - 0.02, z + d - 0.25), Vector3.new(x + 1.5, floor + 0.1, z + d + 0.25), C.beam, Enum.Material.Wood, DECOR)
	end
	local cart = CFrame.new(x + 0.2, floor + 1.4, z + depth - 10) * CFrame.Angles(0, 0.06, 0)
	block(folder, "MineCart", Vector3.new(2.6, 1.8, 3.6), cart, C.rust, Enum.Material.CorrodedMetal, DECOR)
	for _, wheel in { { -1.3, -1.1 }, { 1.3, -1.1 }, { -1.3, 1.1 }, { 1.3, 1.1 } } do
		local part = block(folder, "Wheel", Vector3.new(0.3, 1, 1), cart * CFrame.new(wheel[1], -1, wheel[2]), C.iron, Enum.Material.Metal, DECOR)
		part.Shape = Enum.PartType.Cylinder
	end
	for _, d in { 9, 21 } do
		block(folder, "LampBracket", Vector3.new(1.2, 0.3, 0.3), CFrame.new(x - half + 1.2, floor + 8.5, z + d), C.iron, Enum.Material.Metal, DECOR)
		hangingLantern(folder, Vector3.new(x - half + 1.7, floor + 8.5, z + d), 0.3, 0.8, 12, 0.9)
	end

	-- The frame round the mouth: two great posts, a lintel, braces, and the
	-- sign over it all on its own posts.
	-- It stands a little out from the rock, so no bulge of it hides the sign.
	local postX, frameZ = half + 1.3, z - 1.4
	for _, side in { -1, 1 } do
		block(folder, "GatePost", Vector3.new(2.2, height + 4, 2.2), CFrame.new(x + side * postX, floor + (height + 4) / 2 - 0.6, frameZ), vary(C.beam, 0.08), Enum.Material.Wood)
		beam(folder, "GateBrace", Vector3.new(x + side * postX, floor + height - 4, frameZ), Vector3.new(x + side * (postX - 4), floor + height + 0.6, frameZ), 0.9, C.beam)
		block(folder, "LampBracket", Vector3.new(0.3, 0.3, 1.4), CFrame.new(x + side * postX, floor + 8.5, frameZ - 1.6), C.iron, Enum.Material.Metal, DECOR)
		hangingLantern(folder, Vector3.new(x + side * postX, floor + 8.5, frameZ - 2.2), 0.3, 1.1, 18, 1.4)
		moss(folder, Vector3.new(x + side * (postX + 0.4), floor + height + 2.1, frameZ - 0.9), 3)
	end
	block(folder, "Lintel", Vector3.new(postX * 2 + 4, 2.2, 2.4), CFrame.new(x, floor + height + 1.1, frameZ), vary(C.beam, 0.08), Enum.Material.Wood)
	box(folder, "MouthCover", Vector3.new(x - postX, floor + height, frameZ + 1.2), Vector3.new(x + postX, floor + height + 2.2, z + 0.6), vary(C.beam, 0.08), Enum.Material.WoodPlanks, DECOR)
	local signAt = Vector3.new(x, floor + height + 4.6, frameZ - 0.9)
	for _, side in { -1, 1 } do
		block(folder, "SignPost", Vector3.new(0.6, 3.2, 0.6), CFrame.new(x + side * 7, floor + height + 3.6, frameZ - 0.2), C.beam, Enum.Material.Wood, DECOR)
	end
	letters(sign(folder, CFrame.lookAt(signAt, signAt - Vector3.zAxis), 17, 4.2, 0.3), {
		Position = UDim2.fromScale(0.04, 0.08),
		Size = UDim2.fromScale(0.92, 0.84),
		Text = "Launch Adventure",
	})

	-- The pads in the mouth, side by side, the first on the left as you face it.
	local doors = {}
	local width = (half * 2 - 1.2) / #specs
	box(folder, "BoardBeam", Vector3.new(x - half, floor + height - 1.6, z + 1.2), Vector3.new(x + half, floor + height - 0.8, z + 2), C.beam, Enum.Material.Wood, DECOR)
	for i, spec in specs do
		local px = x + half - 0.6 - width * (i - 0.5)
		local look = DOOR_LOOKS[spec.mode]
		local boardAt = Vector3.new(px, floor + height - 3.7, z + 1.1)
		local title, status = padBoard(folder, CFrame.lookAt(boardAt, boardAt - Vector3.zAxis), width - 0.7, 3.6, look)
		for _, side in { -1, 1 } do
			rod(folder, "Chain", boardAt + Vector3.new(side * (width / 2 - 0.8), 1.95, 0.1), boardAt + Vector3.new(side * (width / 2 - 0.8), 2.9, 0.4), 0.07, C.iron, Enum.Material.Metal, DECOR)
		end
		local pad = glowPad(folder, px, floor, z + 6.5, width - 0.6, 6, look.color)
		table.insert(doors, { spec = spec, pad = pad, title = title, status = status })
	end
	return doors
end

-- A watchtower standing in the water at (x, z): four tall legs with cross
-- braces, a deck at the lodge's upper floor (its bridge comes in at bridgeAt,
-- where its railing has a gap), and above it a lookout with lit windows and
-- a pointed roof, which nobody can reach.
local function buildTower(folder, x, z, bridgeAt)
	local deckY = LODGE.floor2
	local lookout = deckY + 10
	local roofFoot, roofTop = lookout + 6.5, lookout + 12
	local legs = 5
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			block(folder, "TowerLeg", Vector3.new(1.4, roofFoot - FOOT, 1.4), CFrame.new(x + sx * legs, (FOOT + roofFoot) / 2, z + sz * legs), vary(C.post, 0.1), Enum.Material.Wood)
		end
	end
	-- Cross braces on every side below the deck; above it only knee braces,
	-- so the deck has its view.
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local leg = Vector3.new(x + sx * legs, 0, z + sz * legs)
			for _, along in { Vector3.new(-sx, 0, 0), Vector3.new(0, 0, -sz) } do
				beam(folder, "TowerBrace", leg + Vector3.new(0, lookout - 3.4, 0), leg + along * 2.8 + Vector3.new(0, lookout - 0.6, 0), 0.45, C.beam, Enum.Material.Wood, DECOR)
			end
		end
	end
	for _, band in { { SURFACE_Y + 1, deckY - 1.5 } } do
		for _, side in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local a, b
			if side[1] ~= 0 then
				a, b = Vector3.new(x + side[1] * legs, 0, z - legs), Vector3.new(x + side[1] * legs, 0, z + legs)
			else
				a, b = Vector3.new(x - legs, 0, z + side[2] * legs), Vector3.new(x + legs, 0, z + side[2] * legs)
			end
			beam(folder, "TowerBrace", a + Vector3.new(0, band[1], 0), b + Vector3.new(0, band[2], 0), 0.5, C.beam, Enum.Material.Wood, DECOR)
			beam(folder, "TowerBrace", b + Vector3.new(0, band[1], 0), a + Vector3.new(0, band[2], 0), 0.5, C.beam, Enum.Material.Wood, DECOR)
		end
	end
	deck(folder, x - 6, z - 6, x + 6, z + 6, deckY, true, false)
	-- Its railing, with a gap where the bridge comes in.
	local corners = { Vector3.new(x - 6, deckY, z - 6), Vector3.new(x + 6, deckY, z - 6), Vector3.new(x + 6, deckY, z + 6), Vector3.new(x - 6, deckY, z + 6) }
	for i = 1, 4 do
		local a, b = corners[i], corners[i % 4 + 1]
		local dir = (b - a).Unit
		local s = (Vector3.new(bridgeAt.X, deckY, bridgeAt.Z) - a):Dot(dir)
		local off = (Vector3.new(bridgeAt.X, deckY, bridgeAt.Z) - (a + dir * s)).Magnitude
		if off < 0.8 and s > 0 and s < 12 then
			if s - 1.8 > 0.4 then
				woodRailing(folder, a, a + dir * (s - 1.8))
			end
			if 12 - (s + 1.8) > 0.4 then
				woodRailing(folder, a + dir * (s + 1.8), b)
			end
		else
			woodRailing(folder, a, b)
		end
	end
	hangingLantern(folder, Vector3.new(x, lookout - 0.8, z), 1, 1, 18, 1.2)

	-- The lookout: a floor, low walls with lit windows over them, a roof.
	box(folder, "LookoutFloor", Vector3.new(x - 6, lookout - 0.6, z - 6), Vector3.new(x + 6, lookout, z + 6), C.plank, Enum.Material.WoodPlanks)
	for i = 1, 4 do
		local a = Vector3.new(corners[i].X, 0, corners[i].Z)
		local b = Vector3.new(corners[i % 4 + 1].X, 0, corners[i % 4 + 1].Z)
		local out = ((a + b) / 2 - Vector3.new(x, 0, z)).Unit
		wall(folder, a, b, lookout, lookout + 2.4, {}, out, C.sidingGray)
		local middle = (a + b) / 2 + Vector3.new(0, lookout + 4.3, 0)
		block(folder, "LookoutWindow", Vector3.new(0.12, 2.6, 9), CFrame.lookAt(middle, middle + (b - a)), vary(C.windowLit, 0.3), Enum.Material.Neon, NEON)
		beam(folder, "LookoutSill", a + Vector3.new(0, lookout + 2.6, 0), b + Vector3.new(0, lookout + 2.6, 0), 0.4, C.beam, Enum.Material.Wood, DECOR)
	end
	local light = Instance.new("PointLight")
	light.Color = C.warm
	light.Range = 16
	light.Brightness = 1
	light.Parent = block(folder, "Glow", Vector3.one * 0.2, CFrame.new(x, lookout + 3.5, z), C.warm, nil, HIDDEN)
	local apex = Vector3.new(x, roofTop, z)
	for i = 1, 4 do
		local a = Vector3.new(corners[i].X, roofFoot, corners[i].Z) + (Vector3.new(corners[i].X, 0, corners[i].Z) - Vector3.new(x, 0, z)).Unit * 1.2
		local b = Vector3.new(corners[i % 4 + 1].X, roofFoot, corners[i % 4 + 1].Z) + (Vector3.new(corners[i % 4 + 1].X, 0, corners[i % 4 + 1].Z) - Vector3.new(x, 0, z)).Unit * 1.2
		triangle(folder, "TowerRoof", a, b, apex, 0.4, vary(C.shingle, 0.15), Enum.Material.WoodPlanks)
		moss(folder, a:Lerp(b, rng:NextNumber(0.3, 0.7)) - Vector3.new(0, 0.2, 0), rng:NextNumber(1.6, 3))
	end
	banner(folder, Vector3.new(x, lookout - 1.4, z - 6.2), 2.4, 6, -Vector3.zAxis)
end

-- A rope bridge from a to b (both on its middle line at floor height):
-- planks across it on a sagging curve, with steady footing just under them,
-- rope handrails tied to posts at both ends, and invisible walls along its
-- sides.
local function buildBridge(folder, a, b, sag)
	local width = 4
	local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local length = flat.Magnitude
	local dir = flat.Unit
	local side = dir:Cross(Vector3.yAxis)
	local function at(t)
		return a:Lerp(b, t) - Vector3.new(0, sag * 4 * t * (1 - t), 0)
	end
	local planks = math.floor(length / 0.95)
	for i = 0, planks - 1 do
		local t = (i + 0.5) / planks
		local p = at(t)
		local tangent = (at(math.min(1, t + 0.02)) - at(math.max(0, t - 0.02))).Unit
		local frame = CFrame.lookAt(p, p + tangent) * CFrame.Angles(0, rng:NextNumber(-0.06, 0.06), rng:NextNumber(-0.03, 0.03))
		block(folder, "BridgePlank", Vector3.new(width + rng:NextNumber(-0.3, 0.3), 0.25, 0.78), frame * CFrame.new(0, -0.13, 0), vary(C.plank, 0.25), Enum.Material.Wood, DECOR)
	end
	local pieces = 8
	for i = 0, pieces - 1 do
		local p0, p1 = at(i / pieces), at((i + 1) / pieces)
		block(folder, "BridgeFooting", Vector3.new(width, 0.3, (p1 - p0).Magnitude + 0.15), along(p0, p1) * CFrame.new(0, -0.16, 0), C.plank, nil, FOOTING)
	end
	-- Ropes: the handrails and the ropes along the planks' ends, and ties
	-- between them.
	local segments = 10
	for _, s in { -1, 1 } do
		local edge = side * s * (width / 2 + 0.1)
		local lastRail, lastFoot
		for i = 0, segments do
			local t = i / segments
			local foot = at(t) + edge
			local rail = a:Lerp(b, t) - Vector3.new(0, sag * 0.6 * 4 * t * (1 - t), 0) + edge + Vector3.new(0, 3.3, 0)
			if lastRail then
				rod(folder, "Rope", lastRail, rail, 0.2, C.rope, Enum.Material.Fabric, DECOR)
				rod(folder, "Rope", lastFoot, foot, 0.16, C.rope, Enum.Material.Fabric, DECOR)
			end
			if i > 0 and i < segments then
				rod(folder, "Rope", foot, rail, 0.1, C.rope, Enum.Material.Fabric, DECOR)
			end
			lastRail, lastFoot = rail, foot
		end
		for _, p in { a, b } do
			block(folder, "BridgePost", Vector3.new(0.7, 4.4, 0.7), CFrame.new(p + edge + Vector3.new(0, 1.9, 0)), C.beam, Enum.Material.Wood)
		end
		local middle = a:Lerp(b, 0.5) + edge * 1.05 + Vector3.new(0, (8 - sag) / 2, 0)
		block(folder, "Barrier", Vector3.new(0.6, 8 + sag, length), CFrame.lookAt(middle, middle + dir), C.post, nil, BARRIER)
	end
	lantern(folder, a + side * (width / 2 + 0.1) + Vector3.new(0, 4.6, 0), 0.8, 12, 1)
	lantern(folder, b - side * (width / 2 + 0.1) + Vector3.new(0, 4.6, 0), 0.8, 12, 1)
end

-- What can't be built from parts alone: mist lying on the open water, thin
-- near the boardwalks and thicker out in the trees, and fireflies drifting
-- over the water round the outpost.
local function buildAmbience(folder)
	local mistTexture = "rbxasset://textures/particles/smoke_main.dds"
	local spots = {
		{ -40, -126, 34 }, { 50, -126, 34 }, { 96, -80, 30 }, { -110, -86, 30 }, { 0, -190, 50 },
		{ -120, -170, 50 }, { 120, -170, 50 }, { 110, -30, 30 }, { -112, -30, 28 }, { 70, -20, 18 },
	}
	for _, spot in spots do
		local holder = block(folder, "Mist", Vector3.new(spot[3], 1, spot[3]), CFrame.new(spot[1], SURFACE_Y + 1.2, spot[2]), C.under, nil, HIDDEN)
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = mistTexture
		emitter.Color = ColorSequence.new(Color3.fromRGB(120, 136, 160))
		emitter.LightEmission = 0.05
		emitter.LightInfluence = 0.6
		emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.88), NumberSequenceKeypoint.new(0.7, 0.9), NumberSequenceKeypoint.new(1, 1) })
		emitter.Size = NumberSequence.new(12, 20)
		emitter.Lifetime = NumberRange.new(12, 16)
		emitter.Rate = spot[3] / 20
		emitter.Speed = NumberRange.new(0.3, 0.9)
		emitter.SpreadAngle = Vector2.new(180, 8)
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-5, 5)
		emitter.Parent = holder
	end
	for _, spot in { { -30, -112 }, { 60, -112 }, { 22, -20 }, { -60, -50 }, { 84, -50 } } do
		local holder = block(folder, "Fireflies", Vector3.new(24, 4, 24), CFrame.new(spot[1], SURFACE_Y + 3.5, spot[2]), C.under, nil, HIDDEN)
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Color = ColorSequence.new(Color3.fromRGB(220, 255, 140))
		emitter.LightEmission = 1
		emitter.LightInfluence = 0
		emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.2), NumberSequenceKeypoint.new(0.5, 0.7), NumberSequenceKeypoint.new(0.8, 0.15), NumberSequenceKeypoint.new(1, 1) })
		emitter.Size = NumberSequence.new(0.22)
		emitter.Lifetime = NumberRange.new(5, 9)
		emitter.Rate = 2.5
		emitter.Speed = NumberRange.new(0.3, 0.9)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Acceleration = Vector3.new(0, 0.05, 0)
		emitter.RotSpeed = NumberRange.new(-20, 20)
		emitter.Parent = holder
	end
end

-- Puts anyone who gets into the water back at the spawn, through an unseen
-- sheet just under the surface.
local function catchFalls(folder, spawnAt)
	local sheet = box(folder, "WaterCatch", Vector3.new(-420, SURFACE_Y - 3, -600), Vector3.new(420, SURFACE_Y - 1, -1), C.under, nil, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	})
	local recent = {}
	sheet.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if player and not recent[player] then
			recent[player] = true
			character:PivotTo(spawnAt + Vector3.new(0, 3, 0))
			task.delay(1, function()
				recent[player] = nil
			end)
		end
	end)
end

function LobbyBuilder.build(map)
	local folder = Instance.new("Folder")
	folder.Name = "Lobby"
	folder.Parent = map
	local function part(name)
		local child = Instance.new("Folder")
		child.Name = name
		child.Parent = folder
		return child
	end

	buildWater(part("Water"))
	buildRidge(part("Ridge"))
	buildBoardwalks(part("Boardwalks"))
	local boards = buildLodge(part("Lodge"))
	local slots = buildSkins(part("Skins"))
	buildShop(part("Shop"))

	-- The party pads, in Config.Doors' order (Parties.luau knows them by it).
	local byStation = { party = {}, gate = {} }
	for _, spec in Config.Doors do
		table.insert(byStation[spec.station], spec)
	end
	local built = {}
	for _, door in buildPartyStation(part("PartyStation"), byStation.party) do
		built[door.spec] = door
	end
	for _, door in buildGate(part("Adventure"), byStation.gate) do
		built[door.spec] = door
	end
	local doors = {}
	for i, spec in Config.Doors do
		local door = built[spec]
		door.pad.Name = "DoorPad" .. i
		table.insert(doors, { mode = spec.mode, pad = door.pad, title = door.title, status = door.status })
	end

	local towers = part("Towers")
	for _, tower in TOWERS do
		buildTower(towers, tower.x, tower.z, tower.to)
		buildBridge(towers, tower.from + Vector3.new(0, LODGE.floor2, 0), tower.to + Vector3.new(0, LODGE.floor2, 0), 1.3)
	end
	buildSwamp(part("Swamp"))
	buildAmbience(part("Ambience"))

	-- Piles of snowballs to grab from, by the spawn and round the boardwalk.
	local snowPiles = {}
	if Config.Christmas then
		for _, spot in { { -0.5, -135 }, { -38, -93 }, { 28, -93 } } do
			table.insert(snowPiles, Christmas.snowballPile(folder, spot[1], spot[2]))
		end
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(8, 0.2, 8)
	spawn.CFrame = CFrame.lookAt(SPAWN + Vector3.new(0, 0.1, 0), SPAWN + Vector3.new(-3, 0.1, 60))
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.CastShadow = false
	spawn.Parent = folder
	catchFalls(folder, spawn.CFrame)

	buildMannequins(part("Mannequins"), slots)
	return { boards = boards, partyDoors = doors, snowPiles = snowPiles }
end

return LobbyBuilder
