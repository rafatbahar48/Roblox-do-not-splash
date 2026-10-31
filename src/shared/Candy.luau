-- The candy look shared by the menus and the HUD. The panels, buttons, coins
-- and badges are SpriteCook art (UiArt.luau, from the UI kit in
-- art/ui/kit/); the lettering is bubbly FredokaOne on top.
--
-- Every builder here takes the parent first and returns what you fill or
-- connect to. A raised thing's holder includes its lip: give the holder the
-- size and position, and put things in the returned body.

local SoundService = game:GetService("SoundService")

local Config = require(script.Parent.Config)
local UiArt = require(script.Parent.UiArt)

local Candy = {}

Candy.INK = Color3.fromRGB(43, 34, 87)
Candy.WHITE = Color3.fromRGB(255, 255, 255)
Candy.MUTED = Color3.fromRGB(74, 69, 128)
Candy.SKY = Color3.fromRGB(99, 201, 255)
Candy.MINT = Color3.fromRGB(111, 227, 180)
Candy.LEMON = Color3.fromRGB(255, 221, 74)
Candy.PINK = Color3.fromRGB(255, 111, 177)
Candy.LILAC = Color3.fromRGB(180, 160, 255)
Candy.ICE = Color3.fromRGB(234, 247, 255)
Candy.CLOUD = Color3.fromRGB(230, 235, 242) -- greyed-out buttons
Candy.DIM = Color3.fromRGB(215, 230, 242)
Candy.LIP = 5 -- how far the darker edge shows under a raised thing

-- Where the window art leaves room for things: below the ribbon, inside the
-- outline (see Candy.window).
Candy.WINDOW_TOP = 104
Candy.WINDOW_SIDE = 30
Candy.WINDOW_BOTTOM = 30

local INK, WHITE = Candy.INK, Candy.WHITE

-- Which kit button goes with which colour. Anything else is white.
local PILLS = {
	{ Candy.PINK, "button_pink" },
	{ Candy.MINT, "button_mint" },
	{ Candy.LEMON, "button_lemon" },
	{ Candy.SKY, "button_sky" },
	{ Candy.LILAC, "button_sky" },
	{ Candy.CLOUD, "button_grey" },
}

local function pillFor(color)
	for _, pill in PILLS do
		if pill[1] == color then
			return pill[2]
		end
	end
	return "button_white"
end
Candy.pillFor = pillFor

function Candy.create(className, props, children)
	local instance = Instance.new(className)
	for key, value in props do
		instance[key] = value
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	return instance
end
local create = Candy.create

-- A UICorner; radius in pixels, or a UDim.
function Candy.corner(radius)
	return create("UICorner", { CornerRadius = if typeof(radius) == "UDim" then radius else UDim.new(0, radius) })
end

function Candy.stroke(thickness, color)
	return create("UIStroke", {
		Color = color or INK,
		Thickness = thickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
end

-- An ImageLabel showing one part of the kit. Size it with props; height (in
-- pixels) shrinks a stretching part's corners to fit.
function Candy.art(name, props, height)
	local image = create("ImageLabel", { Name = name, BackgroundTransparency = 1 })
	UiArt.apply(image, name, UiArt.fitScale(name, height or 0))
	for key, value in props do
		image[key] = value
	end
	return image
end

-- A part's size in its atlas, in pixels.
function Candy.artSize(name)
	return UiArt.size(name)
end

-- Puts a different part on an image made by Candy.art or Candy.button.
function Candy.setArt(image, name, height)
	UiArt.apply(image, name, UiArt.fitScale(name, height or image.AbsoluteSize.Y))
end

-- Rounded ink lettering. Scales to fit unless given a TextSize.
function Candy.text(props)
	local label = create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		TextColor3 = INK,
		TextScaled = props.TextSize == nil,
		ZIndex = 3,
	})
	for key, value in props do
		label[key] = value
	end
	return label
end

-- Bubbly lettering with an ink outline, like the lobby's signs.
function Candy.outlined(props, thickness)
	local label = Candy.text(props)
	create("UIStroke", { Color = INK, Thickness = thickness or 3, LineJoinMode = Enum.LineJoinMode.Round, Parent = label })
	return label
end

-- Outlined lettering standing on an ink copy of itself, so it looks thick
-- and solid, like a title cut out of plastic. Returns the front label.
function Candy.title(parent, props, thickness, depth)
	local front = Candy.outlined(props, thickness)
	local back = Candy.outlined(props, thickness)
	back.Name = (props.Name or "Title") .. "Shadow"
	back.TextColor3 = INK
	back.ZIndex = front.ZIndex - 1
	back.Position = props.Position + UDim2.fromOffset(0, depth or 4)
	back.Parent = parent
	front.Parent = parent
	return front
end

local clickSound

-- The menus' click (Config.Sounds.Click), for this player only. Candy's
-- buttons and windows play it themselves; call it for other buttons.
function Candy.click()
	if Config.Sounds.Click == "" then
		return
	end
	if not clickSound then
		clickSound = create("Sound", {
			Name = "Click",
			SoundId = Config.Sounds.Click,
			Volume = 0.5,
			SoundGroup = SoundService:FindFirstChild("Effects"),
			Parent = SoundService,
		})
	end
	clickSound.TimePosition = 0
	clickSound:Play()
end

-- The height in pixels of a size, if it has one.
local function pixelHeight(size)
	return if size and size.Y.Scale == 0 then size.Y.Offset else 0
end

-- A raised panel: the kit's pale tile (or a coloured button, given a colour)
-- with an ink outline and a darker lip. Returns the body; its parent is the
-- holder.
function Candy.raised(parent, props)
	local lip = props.lip or Candy.LIP
	local holder = create("Frame", {
		Name = props.name or "Raised",
		BackgroundTransparency = 1,
		AnchorPoint = props.anchor or Vector2.zero,
		Position = props.position or UDim2.new(),
		Size = props.size,
		ZIndex = props.zIndex or 1,
		Parent = parent,
	})
	local name = if props.color and props.color ~= WHITE then pillFor(props.color) else "tile"
	Candy.art(name, { Name = "Art", Size = UDim2.fromScale(1, 1), ZIndex = holder.ZIndex, Parent = holder }, pixelHeight(props.size))
	return create("Frame", {
		Name = "Body",
		Size = UDim2.new(1, 0, 1, -lip),
		BackgroundTransparency = 1,
		ZIndex = holder.ZIndex,
		Parent = holder,
	})
end

-- A shiny, chunky button from the kit, with a label on it. Returns the
-- clickable face; set its colour with Candy.paint(face, color).
function Candy.button(parent, props)
	local holder = create("Frame", {
		Name = props.name or "Button",
		BackgroundTransparency = 1,
		AnchorPoint = props.anchor or Vector2.zero,
		Position = props.position or UDim2.new(),
		Size = props.size,
		LayoutOrder = props.order or 0,
		Parent = parent,
	})
	local face = create("ImageButton", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		ZIndex = 2,
		Parent = holder,
	}, {
		Candy.text({
			Name = "Label",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.46),
			Size = UDim2.new(1, -24, 0.5, 0),
			Text = props.text or "",
		}),
	})
	face:SetAttribute("Height", pixelHeight(props.size))
	face.Activated:Connect(Candy.click)
	-- Sink a little while held.
	face.MouseButton1Down:Connect(function()
		face.Position = UDim2.fromOffset(0, 2)
	end)
	face.MouseButton1Up:Connect(function()
		face.Position = UDim2.new()
	end)
	face.MouseLeave:Connect(function()
		face.Position = UDim2.new()
	end)
	Candy.paint(face, props.color or WHITE, props.labelColor)
	return face
end

-- Recolours a button: the kit's button in that colour. Flat buttons (greyed
-- out) are the grey one.
function Candy.paint(face, color, labelColor, flat)
	local name = if flat then "button_grey" else pillFor(color)
	local height = face:GetAttribute("Height") or 0
	UiArt.apply(face, name, UiArt.fitScale(name, if height > 0 then height else face.AbsoluteSize.Y))
	face.Label.TextColor3 = labelColor or (if flat then WHITE else INK)
end

-- A coin from the kit.
function Candy.coin(parent, size, position, anchor)
	return Candy.art("coin", {
		Name = "Coin",
		AnchorPoint = anchor or Vector2.zero,
		Position = position or UDim2.new(),
		Size = UDim2.fromOffset(size, size),
		ZIndex = 3,
		Parent = parent,
	})
end

-- A small round badge with lettering, for key hints and counts: white, or
-- the kit button of the given colour.
function Candy.badge(parent, text, size, position, anchor, color)
	local badge = Candy.art(if color then pillFor(color) else "button_white", {
		Name = "Badge",
		AnchorPoint = anchor or Vector2.zero,
		Position = position,
		Size = UDim2.fromOffset(size, size),
		ZIndex = 5,
		Parent = parent,
	}, size)
	Candy.text({
		Name = "Label",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.46),
		Size = UDim2.fromScale(0.62, 0.62),
		Text = text,
		ZIndex = 6,
		Parent = badge,
	})
	return badge
end

-- A menu window from the kit: the pale panel with a lilac ribbon across its
-- top left, where the title goes, and a pink close button on its top right.
-- Things go inside it, WINDOW_TOP below its top edge and WINDOW_SIDE in from
-- its sides. Returns the window, its title and its close button.
function Candy.window(parent, props)
	local window = Candy.art("window", {
		Name = props.name or "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = props.size,
		Active = true, -- clicks on the window don't reach what's behind it
		Parent = parent,
	})
	local title = Candy.outlined({
		Name = "Title",
		Position = UDim2.fromOffset(34, 18),
		Size = UDim2.fromOffset(186, 48),
		Rotation = -4,
		TextColor3 = WHITE,
		Text = props.title or "",
		ZIndex = 4,
		Parent = window,
	}, 3)
	local close = create("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -2, 0, 4),
		Size = UDim2.fromOffset(86, 86),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 5,
		Parent = window,
	})
	close.Activated:Connect(Candy.click)
	return window, title, close
end

-- Shrinks a window to fit small screens. designSize is the window's size at
-- scale 1, lip included.
function Candy.fit(window, designSize, margin)
	local scale = create("UIScale", { Parent = window })
	local camera = workspace.CurrentCamera
	local function fit()
		local viewport = camera.ViewportSize
		scale.Scale = math.min(1, (viewport.X - margin) / designSize.X, (viewport.Y - margin) / designSize.Y)
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	fit()
	return scale
end

return Candy
