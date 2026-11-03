-- The look shared by the menus and the HUD: lantern-lit wood, like the
-- lobby's outpost. The panels, buttons, coins and badges are SpriteCook art
-- (UiArt.luau, from the UI kits in art/ui/); the lettering is Merriweather,
-- like the lobby's signs, in dark ink on parchment and in old white with a
-- dark edge on wood. (It was a candy look once, hence the name.)
--
-- Every builder here takes the parent first and returns what you fill or
-- connect to. A raised thing's holder includes its lip: give the holder the
-- size and position, and put things in the returned body.

local GuiService = game:GetService("GuiService")
local SoundService = game:GetService("SoundService")

local Config = require(script.Parent.Config)
local UiArt = require(script.Parent.UiArt)

local Candy = {}

-- The colours keep their old candy names; the buttons in those colours are
-- the kit's woods (see PILLS).
Candy.INK = Color3.fromRGB(38, 24, 14) -- dark brown: lettering on parchment, and every edge
Candy.WHITE = Color3.fromRGB(244, 234, 212) -- old white: lettering on wood
Candy.MUTED = Color3.fromRGB(112, 86, 60)
Candy.SKY = Color3.fromRGB(110, 170, 178) -- swamp teal
Candy.MINT = Color3.fromRGB(138, 182, 98) -- moss
Candy.LEMON = Color3.fromRGB(242, 178, 74) -- lantern amber
Candy.PINK = Color3.fromRGB(206, 96, 68) -- rust
Candy.LILAC = Color3.fromRGB(168, 148, 190)
Candy.ICE = Color3.fromRGB(236, 224, 196) -- parchment
Candy.CLOUD = Color3.fromRGB(128, 124, 118) -- greyed-out buttons
Candy.DIM = Color3.fromRGB(196, 182, 156)
Candy.LIP = 5 -- how far the darker edge shows under a raised thing
Candy.FONT = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold)

-- Where the window art leaves room for things: below its hanging plaque,
-- inside its wooden frame (see Candy.window).
Candy.WINDOW_TOP = 100
Candy.WINDOW_SIDE = 46
Candy.WINDOW_BOTTOM = 44

-- On a TV (a console's), seen from across the room, windows and the HUD
-- grow with the screen, up to TV_SCALE times their size on a 1080p screen,
-- and keep TV_SAFE of the screen clear on each side, since some TVs cut the
-- edges of the picture off.
Candy.TV_SCALE = 1.5
Candy.TV_SAFE = 0.05

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

-- The darker woods, where lettering is old white with a dark edge; on the
-- others (amber, bone) it is dark ink.
local DARK_PILLS = { button_mint = true, button_pink = true, button_sky = true, button_grey = true }

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
	image:SetAttribute("Art", name)
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
	image:SetAttribute("Art", name)
end

-- Ink lettering. Scales to fit unless given a TextSize.
function Candy.text(props, children)
	local label = create("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = Candy.FONT,
		TextColor3 = INK,
		TextScaled = props.TextSize == nil,
		ZIndex = 3,
	}, children)
	for key, value in props do
		label[key] = value
	end
	return label
end

-- Lettering with an ink edge, like the lobby's signs.
function Candy.outlined(props, thickness)
	local label = Candy.text(props)
	create("UIStroke", { Color = INK, Thickness = thickness or 3, LineJoinMode = Enum.LineJoinMode.Round, Parent = label })
	return label
end

-- Outlined lettering standing on an ink copy of itself, so it looks thick
-- and solid, like a title cut into a board. Returns the front label.
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

-- Keeps lettering readable on dark wood: whatever is put on the body (but
-- not on a button there, which looks after its own, nor on a light piece of
-- the kit there, like a tag) ink turns old white and muted ink pale tan, now
-- and whenever it is set again.
local function lightenOnWood(body)
	local function watch(label)
		if not label:IsA("TextLabel") and not label:IsA("TextBox") then
			return
		end
		local button = label:FindFirstAncestorWhichIsA("GuiButton")
		if button and button:IsDescendantOf(body) then
			return
		end
		local art = label.Parent and label.Parent:GetAttribute("Art")
		if art and art ~= "tile" and not DARK_PILLS[art] then
			return
		end
		local function fix()
			if label.TextColor3 == INK then
				label.TextColor3 = WHITE
			elseif label.TextColor3 == Candy.MUTED then
				label.TextColor3 = Candy.DIM
			end
		end
		fix()
		label:GetPropertyChangedSignal("TextColor3"):Connect(fix)
	end
	body.DescendantAdded:Connect(watch)
end

-- A raised panel: the kit's dark wooden tile (or a wooden button, given a
-- colour). Lettering on it reads light where the wood is dark. Returns the
-- body; its parent is the holder.
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
	local body = create("Frame", {
		Name = "Body",
		Size = UDim2.new(1, 0, 1, -lip),
		BackgroundTransparency = 1,
		ZIndex = holder.ZIndex,
		Parent = holder,
	})
	if name == "tile" or DARK_PILLS[name] then
		lightenOnWood(body)
	end
	return body
end

-- A chunky wooden button from the kit, with a label on it. Returns the
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
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -36, 0.5, 0), -- clear of the rounded ends
			Text = props.text or "",
		}, {
			create("UIStroke", { Name = "Edge", Color = INK, Thickness = 1.5, LineJoinMode = Enum.LineJoinMode.Round }),
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

-- The lettering colour that reads on the kit's button of this colour: old
-- white on the darker woods, ink on the others.
function Candy.letteringOn(color)
	return if DARK_PILLS[pillFor(color)] then WHITE else INK
end

-- Recolours a button: the kit's button in that colour. Flat buttons (greyed
-- out) are the grey one. On the darker woods, ink lettering (or none asked
-- for) turns old white with a dark edge, so it can be read.
function Candy.paint(face, color, labelColor, flat)
	local name = if flat then "button_grey" else pillFor(color)
	local height = face:GetAttribute("Height") or 0
	UiArt.apply(face, name, UiArt.fitScale(name, if height > 0 then height else face.AbsoluteSize.Y))
	face:SetAttribute("Art", name)
	local label = face.Label
	if DARK_PILLS[name] and (labelColor == nil or labelColor == INK) then
		label.TextColor3 = WHITE
	else
		label.TextColor3 = labelColor or INK
	end
	local edge = label:FindFirstChild("Edge")
	if edge then
		edge.Enabled = label.TextColor3 == WHITE
	end
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

-- Whether this screen is a TV.
function Candy.onTv()
	return GuiService:IsTenFootInterface() or GuiService.ViewportDisplaySize == Enum.DisplaySize.Large
end

-- How big things can get on a TV of this height, in pixels.
function Candy.tvScale(height)
	return Candy.TV_SCALE * height / 1080
end

-- A menu window from the kit: parchment in a frame of old planks and iron,
-- with a plaque hanging at its top left, where the title goes, and an iron
-- close button on its top right.
-- Things go inside it, WINDOW_TOP below its top edge and WINDOW_SIDE in from
-- its sides. A controller's selection stays inside it. Returns the window,
-- its title and its close button.
function Candy.window(parent, props)
	local window = Candy.art("window", {
		Name = props.name or "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = props.size,
		Active = true, -- clicks on the window don't reach what's behind it
		SelectionGroup = true,
		SelectionBehaviorUp = Enum.SelectionBehavior.Stop,
		SelectionBehaviorDown = Enum.SelectionBehavior.Stop,
		SelectionBehaviorLeft = Enum.SelectionBehavior.Stop,
		SelectionBehaviorRight = Enum.SelectionBehavior.Stop,
		Parent = parent,
	})
	local title = Candy.outlined({
		Name = "Title",
		Position = UDim2.fromOffset(26, 42),
		Size = UDim2.fromOffset(166, 40),
		Rotation = -2,
		TextColor3 = WHITE,
		Text = props.title or "",
		ZIndex = 4,
		Parent = window,
	}, 3)
	local close = create("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -2, 0, 38),
		Size = UDim2.fromOffset(78, 78),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 5,
		Parent = window,
	})
	close.Activated:Connect(Candy.click)
	return window, title, close
end

-- Shrinks a window to fit small screens, and grows it on a TV, inside its
-- safe area. designSize is the window's size at scale 1, lip included.
function Candy.fit(window, designSize, margin)
	local scale = create("UIScale", { Parent = window })
	local camera = workspace.CurrentCamera
	local function fit()
		local viewport = camera.ViewportSize
		local biggest = 1
		if Candy.onTv() then
			biggest = Candy.tvScale(viewport.Y)
			viewport *= 1 - 2 * Candy.TV_SAFE
		end
		scale.Scale = math.min(biggest, (viewport.X - margin) / designSize.X, (viewport.Y - margin) / designSize.Y)
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	fit()
	return scale
end

return Candy
