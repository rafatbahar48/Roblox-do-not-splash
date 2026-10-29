-- Little pictures of the shop's items, drawn from frames so they need no
-- uploaded images: a blocky figure in a skin's colours, a simple shape per
-- accessory, and a symbol per boost. Each draws into a square well.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Candy = require(ReplicatedStorage.Shared.Candy)

local INK, WHITE = Candy.INK, Candy.WHITE
local create = Candy.create

-- The classic avatar colours, for the parts a skin leaves alone.
local BASE = {
	head = Color3.fromRGB(245, 205, 48),
	arms = Color3.fromRGB(245, 205, 48),
	torso = Color3.fromRGB(13, 105, 172),
	legs = Color3.fromRGB(164, 189, 71),
}

local ItemIcons = {}

-- A shape on a 48-unit grid, scaled to the well. radius is in grid units
-- too, or a UDim; outline is in pixels.
local function shape(parent, x, y, w, h, color, radius, outline, props)
	local frame = create("Frame", {
		Position = UDim2.fromScale(x / 48, y / 48),
		Size = UDim2.fromScale(w / 48, h / 48),
		BackgroundColor3 = color or WHITE,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = parent,
	})
	if radius then
		-- A UICorner's scale is a fraction of the shorter side.
		Candy.corner(if typeof(radius) == "UDim" then radius else UDim.new(radius / math.min(w, h), 0)).Parent = frame
	end
	if outline then
		Candy.stroke(outline).Parent = frame
	end
	for key, value in props or {} do
		frame[key] = value
	end
	return frame
end

-- A box that cuts off whatever is drawn into it at its edges.
local function clipBox(parent, x, y, w, h)
	return shape(parent, x, y, w, h, nil, nil, nil, { BackgroundTransparency = 1, ClipsDescendants = true })
end

local function skin(canvas, item)
	local function color(region)
		return if item[region] then item[region].color else BASE[region]
	end
	local fade = if item.id == "phantom" then 0.35 else 0
	local function part(x, y, w, h, region, radius)
		shape(canvas, x, y, w, h, color(region), radius, 1.5, { BackgroundTransparency = fade })
	end
	part(17, 3, 14, 13, "head", 3)
	part(8, 17, 6, 14, "arms")
	part(34, 17, 6, 14, "arms")
	part(14, 17, 20, 14, "torso")
	part(14, 31, 10, 14, "legs")
	part(24, 31, 10, 14, "legs")
end

local ACCESSORIES = {
	swim_cap = function(canvas, color)
		local clip = clipBox(canvas, 6, 6, 36, 26)
		create("Frame", {
			Position = UDim2.fromScale(0, 0.1),
			Size = UDim2.fromScale(1, 1.8),
			BackgroundColor3 = color,
			ZIndex = 4,
			Parent = clip,
		}, { Candy.corner(UDim.new(0.5, 0)), Candy.stroke(2.5) })
		shape(canvas, 5, 31, 38, 3, INK)
		shape(canvas, 23, 12, 2, 19, INK, nil, nil, { BackgroundTransparency = 0.5 })
	end,
	dive_goggles = function(canvas, color)
		shape(canvas, 3, 23, 44, 2.5, INK)
		for _, x in { 7, 26 } do
			shape(canvas, x, 16, 15, 16, color, UDim.new(0.5, 0), 2.5)
			shape(canvas, x + 3, 19, 4, 4, WHITE, UDim.new(0.5, 0))
		end
	end,
	float_ring = function(canvas, color)
		shape(canvas, 8, 8, 32, 32, color, UDim.new(0.5, 0), 2.5)
		for _, at in { { 21, 9 }, { 21, 33 }, { 9, 21 }, { 33, 21 } } do
			shape(canvas, at[1], at[2], 6, 6, WHITE, UDim.new(0.5, 0))
		end
		shape(canvas, 17.5, 17.5, 13, 13, Candy.ICE, UDim.new(0.5, 0), 2.5)
	end,
	-- A quarter of a big round shape: a curved front edge and a straight back.
	dorsal_fin = function(canvas, color)
		local clip = clipBox(canvas, 12, 7, 24, 30)
		create("Frame", {
			Size = UDim2.fromScale(2, 2),
			BackgroundColor3 = color,
			ZIndex = 4,
			Parent = clip,
		}, { Candy.corner(UDim.new(0.5, 0)), Candy.stroke(2.5) })
		shape(canvas, 34.5, 7, 2.5, 30, INK)
		shape(canvas, 5, 36, 38, 3, INK, UDim.new(0.5, 0))
	end,
	head_lamp = function(canvas, color)
		shape(canvas, 6, 27, 36, 7, Candy.MUTED, UDim.new(0.5, 0), 2.5)
		shape(canvas, 15, 14, 18, 18, color, UDim.new(0.5, 0), 2.5)
		shape(canvas, 19, 17, 5, 5, WHITE, UDim.new(0.5, 0))
		shape(canvas, 23, 3, 2.5, 6, INK, UDim.new(0.5, 0))
	end,
	drowned_halo = function(canvas, color)
		shape(canvas, 7, 19, 34, 14, nil, UDim.new(0.5, 0), 6, { BackgroundTransparency = 1 })
		local ring = shape(canvas, 7, 19, 34, 14, nil, UDim.new(0.5, 0), nil, { BackgroundTransparency = 1 })
		Candy.stroke(3, color).Parent = ring
		for _, at in { { 6, 20 }, { 21, 16 }, { 36, 20 }, { 14, 30 }, { 28, 30 } } do
			shape(canvas, at[1], at[2], 6, 6, color, UDim.new(0.5, 0), 2)
		end
	end,
}

local BOOSTS = {
	-- An arrow going up.
	updraft = function(canvas, color)
		shape(canvas, 19, 20, 10, 22, color, 2, 2.5)
		local clip = clipBox(canvas, 8, 4, 32, 20)
		create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.fromScale(0.7, 1.12),
			Rotation = 45,
			BackgroundColor3 = color,
			ZIndex = 4,
			Parent = clip,
		}, { Candy.corner(3), Candy.stroke(2.5) })
	end,
	-- "Shh".
	hush = function(canvas, color)
		shape(canvas, 6, 10, 36, 28, color, UDim.new(0.5, 0), 2.5)
		Candy.outlined({
			Position = UDim2.fromScale(0.18, 0.28),
			Size = UDim2.fromScale(0.64, 0.42),
			TextColor3 = WHITE,
			Text = "shh",
			ZIndex = 5,
			Parent = canvas,
		}, 2)
	end,
}

-- Draws item's picture into well (a square frame).
function ItemIcons.draw(well, item)
	local canvas = create("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.72, 0.72),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = well,
	})
	if item.kind == "skin" then
		skin(canvas, item)
	elseif item.kind == "accessory" and ACCESSORIES[item.id] then
		ACCESSORIES[item.id](canvas, item.swatch)
	elseif item.kind == "boost" and BOOSTS[item.id] then
		BOOSTS[item.id](canvas, item.swatch)
	else
		shape(canvas, 10, 10, 28, 28, item.swatch, UDim.new(0.5, 0), 2.5)
	end
end

return ItemIcons
