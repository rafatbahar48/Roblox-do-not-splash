-- The candy look shared by the menus, the HUD and the lobby's record boards:
-- panels with a thick ink outline sitting on a darker lip, glossy chunky
-- buttons and bubbly lettering, in the Splash Park colours (art/ui/).
--
-- Every builder here takes the parent first and returns what you fill or
-- connect to. A raised thing's holder includes its lip: give the holder the
-- size and position, and put things in the returned body.

local Candy = {}

Candy.INK = Color3.fromRGB(43, 34, 87)
Candy.WHITE = Color3.fromRGB(255, 255, 255)
Candy.MUTED = Color3.fromRGB(74, 69, 128)
Candy.SKY = Color3.fromRGB(99, 201, 255)
Candy.MINT = Color3.fromRGB(111, 227, 180)
Candy.LEMON = Color3.fromRGB(255, 221, 74)
Candy.PINK = Color3.fromRGB(255, 111, 177)
Candy.LILAC = Color3.fromRGB(180, 160, 255)
Candy.ICE = Color3.fromRGB(234, 247, 255) -- icon wells
Candy.CLOUD = Color3.fromRGB(230, 235, 242) -- greyed-out buttons
Candy.DIM = Color3.fromRGB(215, 230, 242) -- unlit meter segments
Candy.LIP = 5 -- how far the darker edge shows under a raised thing

local INK, WHITE = Candy.INK, Candy.WHITE

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

-- A raised panel: a body with an ink outline on a darker lip. Returns the
-- body; its parent is the holder.
function Candy.raised(parent, props)
	local radius = props.radius or 20
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
	create("Frame", {
		Name = "Lip",
		Position = UDim2.fromOffset(0, lip),
		Size = UDim2.new(1, 0, 1, -lip),
		BackgroundColor3 = props.lipColor or INK,
		Visible = lip > 0,
		Parent = holder,
	}, { Candy.corner(radius) })
	return create("Frame", {
		Name = "Body",
		Size = UDim2.new(1, 0, 1, -lip),
		BackgroundColor3 = props.color or WHITE,
		Parent = holder,
	}, { Candy.corner(radius), Candy.stroke(props.outline or 4) })
end

-- A shiny, chunky button: a glossy face with a highlight across the top and
-- an ink outline, on a darker lip. Returns the clickable face; set its
-- colour with Candy.paint(face, color).
function Candy.button(parent, props)
	local radius = props.radius or 16
	local lip = Candy.LIP
	local holder = create("Frame", {
		Name = props.name or "Button",
		BackgroundTransparency = 1,
		AnchorPoint = props.anchor or Vector2.zero,
		Position = props.position or UDim2.new(),
		Size = props.size,
		LayoutOrder = props.order or 0,
		Parent = parent,
	})
	create("Frame", {
		Name = "Lip",
		Position = UDim2.fromOffset(0, lip),
		Size = UDim2.new(1, 0, 1, -lip),
		BackgroundColor3 = INK,
		Parent = holder,
	}, { Candy.corner(radius) })
	local face = create("TextButton", {
		Name = "Face",
		Size = UDim2.new(1, 0, 1, -lip),
		BackgroundColor3 = WHITE,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 2,
		Parent = holder,
	}, {
		Candy.corner(radius),
		Candy.stroke(props.outline or 3),
		create("UIGradient", { Name = "Gloss", Rotation = 90 }),
		create("Frame", {
			Name = "Shine",
			Position = UDim2.new(0, 6, 0, 3),
			Size = UDim2.new(1, -12, 0.34, 0),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.55,
			ZIndex = 2,
		}, { Candy.corner(radius) }),
		Candy.text({
			Name = "Label",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.52),
			Size = UDim2.new(1, -16, 0.62, 0),
			Text = props.text or "",
		}),
	})
	-- Sink into the lip while held.
	face.MouseButton1Down:Connect(function()
		face.Position = UDim2.fromOffset(0, lip - 2)
	end)
	face.MouseButton1Up:Connect(function()
		face.Position = UDim2.new()
	end)
	face.MouseLeave:Connect(function()
		face.Position = UDim2.new()
	end)
	if props.color then
		Candy.paint(face, props.color, props.labelColor)
	end
	return face
end

-- Recolours a button. Flat buttons (greyed out) have no gloss and no lip.
function Candy.paint(face, color, labelColor, flat)
	local light = if flat then color else color:Lerp(WHITE, 0.4)
	face.Gloss.Color = ColorSequence.new(light, color)
	face.Shine.Visible = not flat
	face.Label.TextColor3 = labelColor or INK
	face.Parent.Lip.BackgroundColor3 = color:Lerp(INK, 0.55)
	face.Parent.Lip.Visible = not flat
end

-- A pearl: a pale ball with an ink edge and a shine.
function Candy.pearl(parent, size, position, anchor)
	local pearl = create("Frame", {
		Name = "Pearl",
		AnchorPoint = anchor or Vector2.zero,
		Position = position or UDim2.new(),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = WHITE,
		ZIndex = 3,
		Parent = parent,
	}, {
		Candy.corner(UDim.new(0.5, 0)),
		Candy.stroke(math.max(2, size / 14)),
		create("UIGradient", { Rotation = 45, Color = ColorSequence.new(WHITE, Color3.fromRGB(196, 232, 255)) }),
	})
	create("Frame", {
		Name = "Shine",
		Position = UDim2.fromScale(0.22, 0.18),
		Size = UDim2.fromScale(0.3, 0.3),
		BackgroundColor3 = WHITE,
		ZIndex = 4,
		Parent = pearl,
	}, { Candy.corner(UDim.new(0.5, 0)) })
	return pearl
end

-- A small round ink badge with white lettering, for key hints and counts.
function Candy.badge(parent, text, size, position, anchor, color)
	local badge = create("Frame", {
		Name = "Badge",
		AnchorPoint = anchor or Vector2.zero,
		Position = position,
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color or INK,
		ZIndex = 5,
		Parent = parent,
	}, { Candy.corner(UDim.new(0.5, 0)), Candy.stroke(2) })
	Candy.text({
		Name = "Label",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.7, 0.7),
		TextColor3 = if color then INK else WHITE,
		Text = text,
		ZIndex = 6,
		Parent = badge,
	})
	return badge
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
