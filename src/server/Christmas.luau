-- The Christmas lobby's decorations, built from parts (LobbyBuilder.luau uses
-- them while Config.Christmas is on): snow, decorated trees with a star on
-- top, presents, wreaths, and the piles of snowballs people grab from
-- (Snowballs.luau).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Parts = require(script.Parent.Parts)

local block, box = Parts.block, Parts.box

local TILE_TOP = Config.Room.SurfaceY + Config.Room.TileHeight

local C = {
	snow = Color3.fromRGB(232, 240, 255),
	pine = Color3.fromRGB(30, 90, 62),
	trunk = Color3.fromRGB(78, 54, 40),
	-- Neon shows far brighter than its colour, so the glowing bits are set dark.
	star = Color3.fromRGB(170, 130, 30),
	starLight = Color3.fromRGB(255, 220, 140),
	treeLight = Color3.fromRGB(255, 200, 150),
	berry = Color3.fromRGB(150, 16, 24),
	ribbon = Color3.fromRGB(250, 236, 200),
	bow = Color3.fromRGB(196, 24, 40),
}
-- Baubles and twinkle lights, dark for neon.
local BAUBLES = {
	Color3.fromRGB(150, 18, 28),
	Color3.fromRGB(160, 120, 20),
	Color3.fromRGB(30, 60, 160),
	Color3.fromRGB(160, 40, 110),
	Color3.fromRGB(40, 130, 120),
}
local WRAPPING = {
	Color3.fromRGB(214, 40, 56),
	Color3.fromRGB(46, 150, 92),
	Color3.fromRGB(240, 196, 60),
	Color3.fromRGB(255, 111, 177),
	Color3.fromRGB(99, 201, 255),
}
local DECOR = { CanCollide = false, CanQuery = false, CastShadow = false }
local NEON = { CanCollide = false, CanQuery = false, CastShadow = false, CanTouch = false }
local SNOW = Enum.Material.Snow

local Christmas = {}

-- A layer of snow filling the box between two corners.
function Christmas.snow(folder, min, max, solid)
	return box(folder, "Snow", min, max, C.snow, SNOW, if solid then nil else DECOR)
end

-- A slab of snow of size at cframe, for tops that aren't square to the world.
function Christmas.snowSlab(folder, size, cframe)
	return block(folder, "Snow", size, cframe, C.snow, SNOW, DECOR)
end

-- A ball of snow, for capping round things.
function Christmas.snowBall(folder, at, diameter)
	return block(folder, "Snow", Vector3.one * diameter, CFrame.new(at), C.snow, SNOW, {
		Shape = Enum.PartType.Ball,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	})
end

-- A soft hump of snow on the ground at (x, z), radius studs across its base.
function Christmas.mound(folder, x, z, radius, y)
	local r = radius / 0.87 -- the ball whose top third pokes out
	block(folder, "SnowMound", Vector3.one * r * 2, CFrame.new(x, (y or TILE_TOP) - r * 0.5, z), C.snow, SNOW, {
		Shape = Enum.PartType.Ball,
		CastShadow = false,
	})
end

-- An eight-sided cone of wedges: base radius r at (x, y, z), its point h
-- above. Each wedge's high edge is on the axis, its slope facing out.
local function cone(folder, x, y, z, r, h, color, material, props)
	local sides = 8
	local width = 2 * r * math.tan(math.pi / sides) + 0.04
	for i = 0, sides - 1 do
		local angle = i * 2 * math.pi / sides
		local cframe = CFrame.new(x, y, z) * CFrame.Angles(0, angle, 0) * CFrame.new(0, h / 2, -r / 2)
		local wedge = Instance.new("WedgePart")
		wedge.Name = "Branches"
		wedge.Anchored = true
		wedge.Size = Vector3.new(width, h, r)
		wedge.CFrame = cframe
		wedge.Color = color
		wedge.Material = material
		for key, value in props or {} do
			wedge[key] = value
		end
		wedge.Parent = folder
	end
end

-- A five-pointed star of neon bars, twice (crossed) so it reads from any side.
local function star(folder, at, size)
	for _, turn in { 0, math.pi / 2 } do
		for i = 0, 4 do
			local cframe = CFrame.new(at) * CFrame.Angles(0, turn, 0) * CFrame.Angles(0, 0, i * 2 * math.pi / 5) * CFrame.new(0, size * 0.32, 0)
			block(folder, "Star", Vector3.new(size * 0.22, size * 0.64, size * 0.12), cframe, C.star, Enum.Material.Neon, NEON)
		end
	end
	local core = block(folder, "Star", Vector3.one * size * 0.36, CFrame.new(at), C.star, Enum.Material.Neon, {
		Shape = Enum.PartType.Ball,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
		CanTouch = false,
	})
	local light = Instance.new("PointLight")
	light.Color = C.starLight
	light.Range = size * 6
	light.Brightness = 0.9
	light.Parent = core
end

-- A Christmas tree height studs tall standing at (x, base, z): three snowy
-- tiers hung with baubles and twinkle lights, and a star on top.
function Christmas.tree(parent, x, z, height, rng, base)
	local folder = Instance.new("Model")
	folder.Name = "ChristmasTree"
	folder.Parent = parent
	local y = base or TILE_TOP
	local h = height

	block(folder, "Trunk", Vector3.new(h * 0.18, h * 0.1, h * 0.1), CFrame.new(x, y + h * 0.09, z) * CFrame.Angles(0, 0, math.pi / 2), C.trunk, Enum.Material.Wood, {
		Shape = Enum.PartType.Cylinder,
	})

	local tiers = {
		{ y0 = 0.12, r = 0.36, h = 0.42 },
		{ y0 = 0.36, r = 0.28, h = 0.38 },
		{ y0 = 0.58, r = 0.2, h = 0.36 },
	}
	local snowFrom = 0.7 -- the top of each tier is snowy
	for _, tier in tiers do
		local ty, r, th = y + tier.y0 * h, tier.r * h, tier.h * h
		cone(folder, x, ty, z, r, th, C.pine, Enum.Material.LeafyGrass)
		-- The snow: the same cone's tip, a hair proud of it.
		local snowR = r * (1 - snowFrom) + 0.12
		cone(folder, x, ty + th * snowFrom, z, snowR, snowR * th / r, C.snow, SNOW, DECOR)

		-- Baubles and lights on the green, below the snow.
		for _ = 1, math.floor(r * 1.6) do
			local t = rng:NextNumber(0.08, snowFrom - 0.05)
			local angle = rng:NextNumber(0, math.pi * 2)
			local reach = r * (1 - t) * 1.04 + 0.12 -- out past the cone's corners
			local at = Vector3.new(x + math.cos(angle) * reach, ty + t * th, z + math.sin(angle) * reach)
			local small = rng:NextNumber() < 0.45
			local size = if small then 0.28 else 0.35 + h * 0.025
			local color = if small then C.treeLight:Lerp(Color3.new(), 0.45) else BAUBLES[rng:NextInteger(1, #BAUBLES)]
			block(folder, if small then "Twinkle" else "Bauble", Vector3.one * size, CFrame.new(at), color, Enum.Material.Neon, {
				Shape = Enum.PartType.Ball,
				CanCollide = false,
				CanQuery = false,
				CastShadow = false,
				CanTouch = false,
			})
		end
	end
	star(folder, Vector3.new(x, y + h * 0.97, z), math.max(1.2, h * 0.11))

	-- A soft glow from inside the branches.
	local glow = block(folder, "TreeGlow", Vector3.one, CFrame.new(x, y + h * 0.4, z), C.treeLight, nil, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	local light = Instance.new("PointLight")
	light.Color = C.treeLight
	light.Range = h * 0.9
	light.Brightness = 0.5
	light.Parent = glow
	return folder
end

-- A wrapped present sitting on base at (x, z): a box with a ribbon round it
-- both ways and a bow on top.
function Christmas.present(folder, x, z, size, color, turn, base)
	local cframe = CFrame.new(x, (base or TILE_TOP) + size.Y / 2, z) * CFrame.Angles(0, turn, 0)
	block(folder, "Present", size, cframe, color, Enum.Material.SmoothPlastic)
	block(folder, "Ribbon", Vector3.new(size.X + 0.04, size.Y + 0.04, 0.22), cframe, C.ribbon, nil, DECOR)
	block(folder, "Ribbon", Vector3.new(0.22, size.Y + 0.04, size.Z + 0.04), cframe, C.ribbon, nil, DECOR)
	for _, side in { -1, 1 } do
		block(folder, "Bow", Vector3.new(0.5, 0.32, 0.18), cframe * CFrame.new(side * 0.22, size.Y / 2 + 0.14, 0) * CFrame.Angles(0, 0, side * 0.6), C.bow, nil, DECOR)
	end
end

-- Presents piled round a tree's foot at (x, z), out to radius.
function Christmas.presents(folder, x, z, radius, count, rng, base)
	for i = 1, count do
		local angle = (i + rng:NextNumber(-0.3, 0.3)) * 2 * math.pi / count
		local reach = rng:NextNumber(radius * 0.55, radius)
		local size = Vector3.new(rng:NextNumber(1.2, 2.2), rng:NextNumber(0.9, 1.8), rng:NextNumber(1.2, 2.2))
		Christmas.present(folder, x + math.cos(angle) * reach, z + math.sin(angle) * reach, size, WRAPPING[(i - 1) % #WRAPPING + 1], rng:NextNumber(0, math.pi), base)
	end
end

-- A wreath hung flat on a door at center, facing normal: a ring of
-- leaves with red berries and a bow at the bottom.
function Christmas.wreath(folder, center, normal, radius)
	local look = CFrame.lookAt(center, center + normal)
	local leaves = 16
	for i = 0, leaves - 1 do
		local angle = i * 2 * math.pi / leaves
		local at = look * CFrame.new(math.cos(angle) * radius, math.sin(angle) * radius, 0)
		block(folder, "Wreath", Vector3.one * radius * 0.55, at, C.pine, Enum.Material.LeafyGrass, {
			Shape = Enum.PartType.Ball,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
		})
		if i % 3 == 0 then
			block(folder, "Berry", Vector3.one * 0.22, at * CFrame.new(0.1, 0.1, -radius * 0.25), C.berry, Enum.Material.Neon, NEON)
		end
	end
	for _, side in { -1, 1 } do
		block(folder, "Bow", Vector3.new(0.7, 0.45, 0.15), look * CFrame.new(side * 0.32, -radius, -radius * 0.3) * CFrame.Angles(0, 0, side * 0.5), C.bow, nil, DECOR)
	end
end

-- A heap of snowballs on a mound at (x, z), with the prompt that hands
-- them out (Snowballs.luau). Returns the prompt.
function Christmas.snowballPile(folder, x, z)
	Christmas.mound(folder, x, z, 2.8)
	local ball = 1.1
	local layers = {
		{ count = 7, reach = 1.5, y = 0.95 },
		{ count = 4, reach = 0.75, y = 1.75 },
		{ count = 1, reach = 0, y = 2.5 },
	}
	for _, layer in layers do
		for i = 1, layer.count do
			local angle = i * 2 * math.pi / layer.count
			block(folder, "Snowball", Vector3.one * ball, CFrame.new(x + math.cos(angle) * layer.reach, TILE_TOP + layer.y, z + math.sin(angle) * layer.reach), C.snow, SNOW, {
				Shape = Enum.PartType.Ball,
				CanCollide = false,
				CanQuery = false,
			})
		end
	end
	local holder = block(folder, "SnowballPile", Vector3.new(5, 4, 5), CFrame.new(x, TILE_TOP + 2, z), C.snow, nil, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GrabSnowballs"
	prompt.ActionText = "Grab snowballs"
	prompt.ObjectText = "Snow"
	prompt.KeyboardKeyCode = Enum.KeyCode.G -- E throws
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = holder
	return prompt
end

return Christmas
