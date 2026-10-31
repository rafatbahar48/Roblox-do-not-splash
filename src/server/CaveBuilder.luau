-- The cave behind the lobby's building, where a party arrives (Parties.luau):
-- the start of stage 1, from the building's back wall to Config.Cave.Length.
-- Wet rock all round, gloomy but never too dark to see: torches, lanterns by
-- the doors you came through and glowing crystals. A supply stall where the
-- shop opens, room to walk about, and a wide mouth onto the forest, where
-- the run timer starts.
--
-- The rock is terrain: a block carved out with overlapping balls, so the
-- walls and roof come out rounded and uneven. The floor is a part, flat at
-- the islands' height. client/Cave.luau does its sounds, the torches'
-- flicker and what happens when you arrive.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Parts = require(script.Parent.Parts)

local block, box = Parts.block, Parts.box

local ROOM = Config.Room
local CAVE = Config.Cave
local SURFACE_Y = ROOM.SurfaceY
local TILE_TOP = SURFACE_Y + ROOM.TileHeight
local BASE_Y = SURFACE_Y - ROOM.PoolDepth - 1
local LENGTH, HALF, HEIGHT = CAVE.Length, CAVE.HalfWidth, CAVE.Height
local OUTER = HALF + 16 -- how far out either side the rock goes
local MOUTH = 15 -- the mouth's radius: wide enough for a party side by side

local C = {
	rock = Color3.fromRGB(88, 82, 96),
	floor = Color3.fromRGB(66, 61, 70),
	wood = Color3.fromRGB(104, 74, 52),
	darkWood = Color3.fromRGB(64, 46, 36),
	iron = Color3.fromRGB(34, 32, 40),
	-- Neon shows far brighter than its colour, so the glowing bits are set dark.
	flame = Color3.fromRGB(160, 90, 30),
	fire = Color3.fromRGB(255, 160, 86),
	amber = Color3.fromRGB(125, 98, 45),
	warm = Color3.fromRGB(255, 214, 150),
	crystal = Color3.fromRGB(30, 110, 120),
	crystalLight = Color3.fromRGB(90, 220, 230),
	puddle = Color3.fromRGB(96, 116, 150),
	stripeA = Color3.fromRGB(150, 70, 104),
	stripeB = Color3.fromRGB(196, 176, 150),
	lemon = Color3.fromRGB(255, 221, 74),
	mint = Color3.fromRGB(111, 227, 180),
	pink = Color3.fromRGB(255, 111, 177),
	ink = Color3.fromRGB(43, 34, 87),
}
local DECOR = { CanCollide = false, CanQuery = false, CastShadow = false }
local NEON = { CanCollide = false, CanQuery = false, CastShadow = false, CanTouch = false }
local FIRE_TEXTURE = "rbxasset://textures/particles/fire_main.dds" -- ships with Roblox

local CaveBuilder = {}

local function light(parent, color, range, brightness, shadows)
	local result = Instance.new("PointLight")
	result.Color = color
	result.Range = range
	result.Brightness = brightness
	result.Shadows = shadows == true
	result.Parent = parent
	return result
end

-- The chamber: balls of air, each touching the roof at its top. Rows from
-- the back wall to the mouth, wider in the middle. Returns them as
-- { center, radius } for working out where the roof is.
local function chamberBalls(z0, rng)
	local balls = {}
	local rows = {
		{ z = 7, xs = { -8, 0, 8 }, r = 13 }, -- inside the building's back, which is 44 wide
		{ z = 16, xs = { -12, 0, 12 }, r = 13.5 },
		{ z = 25, xs = { -12, 0, 12 }, r = 13.5 },
		{ z = 33, xs = { -8, 8 }, r = 13 },
	}
	for _, row in rows do
		for _, x in row.xs do
			local r = row.r + rng:NextNumber(-0.6, 0.6)
			local top = TILE_TOP + HEIGHT - rng:NextNumber(0, 3)
			table.insert(balls, { center = Vector3.new(x + rng:NextNumber(-1, 1), top - r, z0 + row.z + rng:NextNumber(-1, 1)), radius = r })
		end
	end
	-- The mouth, wide and a little lower.
	table.insert(balls, { center = Vector3.new(0, TILE_TOP + 1, z0 + LENGTH + 3), radius = MOUTH })
	table.insert(balls, { center = Vector3.new(0, TILE_TOP + 2, z0 + LENGTH - 4), radius = MOUTH })
	return balls
end

-- How high the roof is over (x, z), or nil if that is inside the rock.
local function roofAt(balls, x, z)
	local best
	for _, ball in balls do
		local dx, dz = x - ball.center.X, z - ball.center.Z
		local inside = ball.radius * ball.radius - dx * dx - dz * dz
		if inside > 0 then
			local y = ball.center.Y + math.sqrt(inside)
			best = if best then math.max(best, y) else y
		end
	end
	return best
end

local function carve(z0, rng)
	local terrain = workspace.Terrain
	terrain:SetMaterialColor(Enum.Material.Rock, C.rock)
	local top = TILE_TOP + HEIGHT + 9
	-- Terrain bulges a stud or two past what is filled, and the building's
	-- front wall is thin: starting the rock right behind it, it showed
	-- through the bricks in the lobby.
	local back, front = z0 + 3, z0 + LENGTH + 2
	terrain:FillBlock(CFrame.new(0, (BASE_Y - 4 + top) / 2, (back + front) / 2), Vector3.new(OUTER * 2, top - BASE_Y + 4, front - back), Enum.Material.Rock)

	-- Lumps along the top and round the front, so from the forest it is a
	-- rocky hill and not a box. They stay low and well back from the
	-- building, or they would show over it (or through it) in the lobby.
	for x = -OUTER + 4, OUTER - 4, 8 do
		for _, z in { 18, 28, 37 } do
			terrain:FillBall(Vector3.new(x + rng:NextNumber(-2, 2), top - rng:NextNumber(2, 4), z0 + z + rng:NextNumber(-2, 2)), rng:NextNumber(4, 7), Enum.Material.Rock)
		end
	end
	for _, side in { -1, 1 } do
		for x = MOUTH + 6, OUTER, 7 do
			terrain:FillBall(Vector3.new(side * x, TILE_TOP + rng:NextNumber(2, 14), front - 1), rng:NextNumber(5, 8), Enum.Material.Rock)
		end
	end
	for x = -MOUTH, MOUTH, 7 do
		terrain:FillBall(Vector3.new(x, TILE_TOP + MOUTH + 7 + rng:NextNumber(0, 3), front - 1), rng:NextNumber(5, 7), Enum.Material.Rock)
	end

	local balls = chamberBalls(z0, rng)
	for _, ball in balls do
		terrain:FillBall(ball.center, ball.radius, Enum.Material.Air)
	end
	-- Rock again under the floor, where the balls went too deep.
	terrain:FillBlock(CFrame.new(0, (BASE_Y - 4 + TILE_TOP - 1) / 2, (back + front) / 2), Vector3.new(OUTER * 2, TILE_TOP - 1 - BASE_Y + 4, front - back), Enum.Material.Rock)
	return balls
end

-- A rock tooth hanging from the roof at (x, z): a few shrinking blocks.
local function stalactite(folder, balls, x, z, rng)
	local roof = roofAt(balls, x, z)
	if not roof or roof < TILE_TOP + 9 then
		return nil
	end
	local y = roof + 1.5 -- its root sunk into the rock
	local width = rng:NextNumber(1.2, 2.2)
	local tip
	for i = 1, 3 do
		local length = rng:NextNumber(1.2, 2.2) * (if i == 1 then 1.6 else 1)
		local size = width * (1.15 - i * 0.28)
		local cframe = CFrame.new(x, y - length / 2, z) * CFrame.Angles(rng:NextNumber(-0.08, 0.08), rng:NextNumber(0, math.pi), rng:NextNumber(-0.08, 0.08))
		tip = block(folder, "Stalactite", Vector3.new(size, length, size), cframe, C.rock, Enum.Material.Rock, DECOR)
		y -= length * 0.8
	end
	return tip
end

-- A drop of water falling every so often from a tip, onto a puddle.
local function drip(folder, tip, rng)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(Color3.fromRGB(200, 225, 255))
	emitter.LightEmission = 0.4
	emitter.Size = NumberSequence.new(0.12)
	emitter.Lifetime = NumberRange.new(0.5)
	emitter.Rate = rng:NextNumber(0.4, 0.9)
	emitter.Speed = NumberRange.new(0)
	emitter.Acceleration = Vector3.new(0, -70, 0)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.Parent = tip
	local x, z = tip.Position.X, tip.Position.Z
	block(folder, "Puddle", Vector3.new(0.06, rng:NextNumber(2.5, 4), rng:NextNumber(2.5, 4)), CFrame.new(x, TILE_TOP + 0.03, z) * CFrame.Angles(0, 0, math.pi / 2), C.puddle, Enum.Material.Glass, {
		Shape = Enum.PartType.Cylinder,
		Transparency = 0.45,
		Reflectance = 0.45,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	})
end

-- A torch on an iron stand at (x, z): a bowl of fire that lights the rock
-- round it. The flame part is named so client/Cave.luau can flicker it.
local function torch(folder, x, z)
	block(folder, "TorchFoot", Vector3.new(1.4, 0.4, 1.4), CFrame.new(x, TILE_TOP + 0.2, z), C.iron, Enum.Material.Metal)
	block(folder, "TorchStand", Vector3.new(0.35, 6, 0.35), CFrame.new(x, TILE_TOP + 3.2, z), C.iron, Enum.Material.Metal)
	block(folder, "TorchBowl", Vector3.new(0.6, 1.4, 1.4), CFrame.new(x, TILE_TOP + 6.4, z) * CFrame.Angles(0, 0, math.pi / 2), C.iron, Enum.Material.Metal, {
		Shape = Enum.PartType.Cylinder,
		CanQuery = false,
	})
	local flame = block(folder, "Flame", Vector3.one * 0.9, CFrame.new(x, TILE_TOP + 7, z), C.flame, Enum.Material.Neon, {
		Shape = Enum.PartType.Ball,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
		CanTouch = false,
	})
	local fire = Instance.new("ParticleEmitter")
	fire.Texture = FIRE_TEXTURE
	fire.Color = ColorSequence.new(Color3.fromRGB(255, 190, 90), Color3.fromRGB(255, 90, 40))
	fire.LightEmission = 1
	fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.3), NumberSequenceKeypoint.new(1, 0.2) })
	fire.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	fire.Lifetime = NumberRange.new(0.35, 0.6)
	fire.Rate = 28
	fire.Speed = NumberRange.new(2, 3.5)
	fire.SpreadAngle = Vector2.new(12, 12)
	fire.Parent = flame
	light(flame, C.fire, 26, 1.3, true)
end

-- A lantern on the building's back wall by the doors, at (x, z) facing +Z.
local function wallLantern(folder, x, z)
	local at = Vector3.new(x, TILE_TOP + 8, z)
	block(folder, "LanternBracket", Vector3.new(0.3, 0.3, 1.2), CFrame.new(at + Vector3.new(0, 0.6, 0.6)), C.iron, Enum.Material.Metal, DECOR)
	block(folder, "LanternCap", Vector3.new(0.9, 0.25, 0.9), CFrame.new(at + Vector3.new(0, 0.5, 1.2)), C.iron, Enum.Material.Metal, DECOR)
	local glass = block(folder, "Lantern", Vector3.new(0.7, 1, 0.7), CFrame.new(at + Vector3.new(0, -0.15, 1.2)), C.amber, Enum.Material.Neon, NEON)
	light(glass, C.warm, 18, 0.8)
end

-- A cluster of glowing crystals growing out of the floor at (x, z), leaning
-- away from the wall on the side given.
local function crystals(folder, x, z, side, rng)
	for i = 1, rng:NextInteger(4, 6) do
		local height = rng:NextNumber(1.6, 4.2) * (if i == 1 then 1.3 else 1)
		local width = rng:NextNumber(0.5, 1)
		local at = Vector3.new(x + rng:NextNumber(-1.4, 1.4), TILE_TOP, z + rng:NextNumber(-1.6, 1.6))
		local lean = CFrame.Angles(rng:NextNumber(-0.35, 0.35), 0, side * rng:NextNumber(0.1, 0.5)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
		block(folder, "Crystal", Vector3.new(width, height, width), CFrame.new(at) * lean * CFrame.new(0, height / 2 - 0.3, 0), C.crystal, Enum.Material.Neon, NEON)
	end
	local glow = block(folder, "CrystalGlow", Vector3.one, CFrame.new(x, TILE_TOP + 2.5, z), C.crystal, nil, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	light(glow, C.crystalLight, 16, 0.9)
end

-- A rough boulder sitting on the floor at (x, z).
local function boulder(folder, x, z, size, rng)
	block(folder, "Boulder", Vector3.new(size * rng:NextNumber(1, 1.5), size, size * rng:NextNumber(0.9, 1.3)), CFrame.new(x, TILE_TOP + size * 0.3, z) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, math.pi), rng:NextNumber(-0.3, 0.3)), C.rock, Enum.Material.Rock)
end

local function crate(folder, cframe, size)
	block(folder, "Crate", Vector3.one * size, cframe, C.wood, Enum.Material.WoodPlanks)
	for _, axis in { CFrame.new(), CFrame.Angles(0, math.pi / 2, 0) } do
		block(folder, "CrateBand", Vector3.new(size + 0.06, 0.25, size + 0.06), cframe * axis * CFrame.new(0, size * 0.3, 0), C.darkWood, Enum.Material.Wood, DECOR)
	end
end

-- The supply stall against a side wall, centred on (x, z), its counter
-- facing along X (facing is 1 or -1). The shop's prompt is on its own part,
-- named OpenShop as in the lobby (client/ShopUi.luau opens on it).
local function stall(folder, x, z, facing)
	local out = Vector3.new(facing, 0, 0)
	-- A point dx in front of the counter's middle (behind it, if negative),
	-- y up from the floor and dz along it.
	local function at(dx, y, dz)
		return Vector3.new(x + dx * facing, TILE_TOP + y, z + dz)
	end
	local look = CFrame.lookAt(Vector3.zero, out)

	-- The counter, with a darker top.
	block(folder, "Counter", Vector3.new(8, 3.2, 2.6), CFrame.new(at(0, 1.6, 0)) * look, C.wood, Enum.Material.WoodPlanks)
	block(folder, "CounterTop", Vector3.new(8.6, 0.3, 3.2), CFrame.new(at(0, 3.35, 0)) * look, C.darkWood, Enum.Material.Wood)

	-- Posts and a striped canvas roof, sloping down to the front.
	for _, dz in { -4.2, 4.2 } do
		block(folder, "StallPost", Vector3.new(0.45, 7.4, 0.45), CFrame.new(at(-1.8, 3.7, dz)), C.darkWood, Enum.Material.Wood)
		block(folder, "StallPost", Vector3.new(0.45, 6.4, 0.45), CFrame.new(at(1.8, 3.2, dz)), C.darkWood, Enum.Material.Wood)
	end
	local roof = CFrame.new(at(0, 6.9, 0)) * look * CFrame.Angles(math.rad(-14), 0, 0)
	for i = -4, 3 do
		block(folder, "Canvas", Vector3.new(1.15, 0.15, 4.8), roof * CFrame.new(i * 1.15 + 0.575, 0, 0), if i % 2 == 0 then C.stripeA else C.stripeB, Enum.Material.Fabric, { CastShadow = true })
	end

	-- The sign along the roof's front edge.
	local sign = block(folder, "StallSign", Vector3.new(7.6, 1.5, 0.25), CFrame.new(at(2.5, 6.2, 0)) * look, C.darkWood, Enum.Material.Wood, DECOR)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.4
	gui.Parent = sign
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = C.lemon
	text.Text = "SUPPLIES"
	text.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = C.ink
	stroke.Thickness = 4
	stroke.Parent = text

	-- A lantern under the roof, and jars of what's for sale on the counter.
	local lantern = block(folder, "Lantern", Vector3.new(0.7, 1, 0.7), CFrame.new(at(0.4, 5.6, 0)), C.amber, Enum.Material.Neon, NEON)
	light(lantern, C.warm, 20, 1.1, true)
	for i, color in { C.mint, C.pink, C.lemon } do
		local jar = at(0.4, 3.95, (i - 2) * 2.2)
		block(folder, "Jar", Vector3.new(0.9, 1, 1), CFrame.new(jar) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(220, 235, 245), Enum.Material.Glass, {
			Shape = Enum.PartType.Cylinder,
			Transparency = 0.5,
			CanQuery = false,
		})
		block(folder, "JarGlow", Vector3.new(0.6, 0.7, 0.7), CFrame.new(jar - Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.pi / 2), color:Lerp(Color3.new(), 0.45), Enum.Material.Neon, {
			Shape = Enum.PartType.Cylinder,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
		})
	end

	-- Stock: crates stacked behind the counter, more at its ends.
	crate(folder, CFrame.new(at(-2.6, 1, -2.4)) * CFrame.Angles(0, 0.2, 0), 2)
	crate(folder, CFrame.new(at(-2.7, 2.8, -2.2)) * CFrame.Angles(0, -0.3, 0), 1.6)
	crate(folder, CFrame.new(at(-2.6, 1, 2.7)) * CFrame.Angles(0, 0.5, 0), 2)
	crate(folder, CFrame.new(at(0.4, 0.9, -5.7)) * CFrame.Angles(0, 0.7, 0), 1.8)
	for _, spot in { { 0.2, 5.8 }, { 2.1, 5.6 } } do
		block(folder, "Barrel", Vector3.new(2.6, 1.8, 1.8), CFrame.new(at(spot[1], 1.3, spot[2])) * CFrame.Angles(0, 0, math.pi / 2), C.darkWood, Enum.Material.Wood, {
			Shape = Enum.PartType.Cylinder,
		})
	end

	local counter = block(folder, "SupplyShop", Vector3.new(4, 6, 9), CFrame.new(at(-0.6, 3, 0)), C.lemon, nil, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OpenShop"
	prompt.ActionText = "Open shop"
	prompt.ObjectText = "Supplies"
	prompt.KeyboardKeyCode = Enum.KeyCode.G -- E throws a pebble
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter
end

-- Builds the cave in folder, its back against the wall at z0. Returns where
-- a party arrives (spawn, facing the mouth), the run timer's trigger across
-- the mouth (runStart), and where it ends (zEnd) and how wide it is
-- (halfWidth, rock included).
function CaveBuilder.build(parent, z0)
	local folder = Instance.new("Folder")
	folder.Name = "Cave"
	folder.Parent = parent
	local rng = Random.new(7477)

	local balls = carve(z0, rng)
	box(folder, "CaveFloor", Vector3.new(-HALF - 3, BASE_Y, z0), Vector3.new(HALF + 3, TILE_TOP, z0 + LENGTH), C.floor, Enum.Material.Slate)

	-- Light: lanterns by the doors you come in by, torches down both sides,
	-- crystals in the corners.
	for _, x in { -18.5, -6.5, 6.5, 18.5 } do
		wallLantern(folder, x, z0 + 0.5)
	end
	-- { x, z, how far boulders keep off }
	local taken = { { 19, 21, 8 } } -- the stall
	for _, spot in { { -17, 12 }, { 17, 9 }, { -18, 29 }, { 16, 33 } } do
		torch(folder, spot[1], z0 + spot[2])
		table.insert(taken, { spot[1], spot[2], 3 })
	end
	for _, spot in { { -20.5, 21, -1 }, { -14, 36.5, -1 }, { 20.5, 4.5, 1 } } do
		crystals(folder, spot[1], z0 + spot[2], spot[3], rng)
		table.insert(taken, { spot[1], spot[2], 4 })
	end

	stall(folder, 19, z0 + 21, -1)

	-- Rock teeth from the roof, some dripping onto puddles.
	local drips = 0
	for _ = 1, 30 do
		local x, z = rng:NextNumber(-HALF + 3, HALF - 3), z0 + rng:NextNumber(3, LENGTH - 2)
		local tip = stalactite(folder, balls, x, z, rng)
		if tip and drips < 6 and math.abs(x) < HALF - 7 then
			drips += 1
			drip(folder, tip, rng)
		end
	end
	for _ = 1, 10 do
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local z = rng:NextNumber(4, LENGTH - 3)
		local x = side * rng:NextNumber(HALF - 6, HALF - 2)
		local clear = true
		for _, spot in taken do
			if math.abs(x - spot[1]) < spot[3] and math.abs(z - spot[2]) < spot[3] then
				clear = false
			end
		end
		if clear then
			boulder(folder, x, z0 + z, rng:NextNumber(1.5, 3.2), rng)
		end
	end

	-- Walking out of the mouth starts the run timer (Progress.luau).
	local runStart = block(folder, "RunStart", Vector3.new(MOUTH * 2 + 10, ROOM.DoorHeight, 2), CFrame.new(0, TILE_TOP + ROOM.DoorHeight / 2, z0 + LENGTH + 1), C.lemon, nil, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})

	local spawnAt = Vector3.new(0, TILE_TOP + 3, z0 + 7)
	return {
		spawn = CFrame.lookAt(spawnAt, spawnAt + Vector3.zAxis),
		runStart = runStart,
		zEnd = z0 + LENGTH,
		halfWidth = OUTER,
	}
end

return CaveBuilder
