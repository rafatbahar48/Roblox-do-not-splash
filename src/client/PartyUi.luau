-- The party pop-up and the party banner. Stepping on a party door's pad in
-- the lobby opens the pop-up (server/Parties.luau): party size, difficulty
-- and friends only, then Create. While you are in a party, a banner says how
-- full it is and when it leaves, with a button to leave it.
--
-- Everything here only asks; the server decides.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local INK = Color3.fromRGB(43, 34, 87)
local WHITE = Color3.fromRGB(255, 255, 255)
local MUTED = Color3.fromRGB(74, 69, 128)
local SKY = Color3.fromRGB(99, 201, 255)
local MINT = Color3.fromRGB(111, 227, 180)
local LEMON = Color3.fromRGB(255, 221, 74)
local PINK = Color3.fromRGB(255, 111, 177)
local DIFFICULTIES = {
	{ name = "Easy", color = MINT },
	{ name = "Normal", color = LEMON },
	{ name = "Hard", color = PINK },
}
local LIP = 5 -- how far the darker edge shows under a chunky button

local PartyUi = {}

local gui, popup, banner, bannerText
local refreshChoices -- redraws the pop-up's buttons from choice
local doorIndex -- the party door the pop-up is for
local choice = { size = Config.Party.MaxSize, difficulty = Config.DefaultDifficulty, friendsOnly = false }
local status -- the server's latest word on our party, or nil

local function create(className, props, children)
	local instance = Instance.new(className)
	for key, value in props do
		instance[key] = value
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	return instance
end

local function text(props)
	local label = create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		TextColor3 = INK,
		TextScaled = true,
		ZIndex = 3,
	})
	for key, value in props do
		label[key] = value
	end
	return label
end

-- Bubbly lettering with an ink outline, like the lobby's signs.
local function outlined(props, thickness)
	local label = text(props)
	create("UIStroke", { Color = INK, Thickness = thickness or 3, LineJoinMode = Enum.LineJoinMode.Round, Parent = label })
	return label
end

-- A shiny, chunky button: a glossy face with a highlight across the top and
-- an ink outline, on a darker lip. Returns the clickable face; set its colour
-- with paint(face, color).
local function chunkyButton(parent, size, position, labelText, radius)
	local holder = create("Frame", { BackgroundTransparency = 1, Size = size, Position = position or UDim2.new(), Parent = parent })
	create("Frame", {
		Name = "Lip",
		Position = UDim2.fromOffset(0, LIP),
		Size = UDim2.new(1, 0, 1, -LIP),
		BackgroundColor3 = INK,
		Parent = holder,
	}, { create("UICorner", { CornerRadius = UDim.new(0, radius) }) })
	local face = create("TextButton", {
		Name = "Face",
		Size = UDim2.new(1, 0, 1, -LIP),
		BackgroundColor3 = WHITE,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 2,
		Parent = holder,
	}, {
		create("UICorner", { CornerRadius = UDim.new(0, radius) }),
		create("UIStroke", { Color = INK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		create("UIGradient", { Name = "Gloss", Rotation = 90 }),
		create("Frame", {
			Name = "Shine",
			Position = UDim2.new(0, 6, 0, 3),
			Size = UDim2.new(1, -12, 0.34, 0),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.55,
			ZIndex = 2,
		}, { create("UICorner", { CornerRadius = UDim.new(0, radius) }) }),
		text({ Name = "Label", Size = UDim2.new(1, -16, 0.62, 0), Position = UDim2.fromScale(0.5, 0.52), AnchorPoint = Vector2.new(0.5, 0.5), Text = labelText }),
	})
	-- Sink into the lip while held.
	face.MouseButton1Down:Connect(function()
		face.Position = UDim2.fromOffset(0, LIP - 2)
	end)
	face.MouseButton1Up:Connect(function()
		face.Position = UDim2.new()
	end)
	face.MouseLeave:Connect(function()
		face.Position = UDim2.new()
	end)
	return face
end

local function paint(face, color, labelColor)
	local light = color:Lerp(WHITE, 0.4)
	face.Gloss.Color = ColorSequence.new(light, color)
	face.Label.TextColor3 = labelColor or INK
	face.Parent.Lip.BackgroundColor3 = color:Lerp(INK, 0.55)
end

local function close()
	popup.Visible = false
	doorIndex = nil
end

local function buildPopup()
	popup = create("Frame", {
		Name = "PartySetup",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, 400),
		BackgroundColor3 = WHITE,
		Visible = false,
		Parent = gui,
	}, {
		create("UICorner", { CornerRadius = UDim.new(0, 28) }),
		create("UIStroke", { Color = INK, Thickness = 5 }),
	})
	-- Shrink to fit small screens.
	local scale = create("UIScale", { Parent = popup })
	local function fit()
		local viewport = workspace.CurrentCamera.ViewportSize
		scale.Scale = math.min(1, (viewport.Y - 40) / 430, (viewport.X - 24) / 470)
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	fit()

	local header = create("Frame", {
		Size = UDim2.new(1, 0, 0, 78),
		BackgroundColor3 = SKY,
		Parent = popup,
	}, { create("UICorner", { CornerRadius = UDim.new(0, 26) }) })
	-- Square off the header's bottom corners.
	create("Frame", { Position = UDim2.new(0, 0, 1, -26), Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = SKY, BorderSizePixel = 0, Parent = header })
	create("Frame", { Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = INK, BorderSizePixel = 0, Parent = header })
	outlined({ Position = UDim2.fromOffset(24, 12), Size = UDim2.new(1, -110, 0, 54), Text = "NEW PARTY", TextColor3 = LEMON, TextXAlignment = Enum.TextXAlignment.Left, Parent = header }, 4)
	local closeButton = chunkyButton(header, UDim2.fromOffset(52, 56), UDim2.new(1, -70, 0, 10), "X", 26)
	paint(closeButton, PINK)
	closeButton.Activated:Connect(function()
		Remotes.LeaveParty:FireServer()
		close()
	end)

	local function row(y, title)
		text({ Position = UDim2.fromOffset(28, y + 10), Size = UDim2.fromOffset(120, 30), Text = title, TextXAlignment = Enum.TextXAlignment.Left, Parent = popup })
	end

	-- Party size: - [n] +
	row(98, "Party size")
	local minus = chunkyButton(popup, UDim2.fromOffset(52, 54), UDim2.fromOffset(250, 96), "-", 16)
	local count = text({ Position = UDim2.fromOffset(306, 104), Size = UDim2.fromOffset(60, 40), Text = "", Parent = popup })
	local plus = chunkyButton(popup, UDim2.fromOffset(52, 54), UDim2.fromOffset(370, 96), "+", 16)
	paint(minus, SKY)
	paint(plus, SKY)
	minus.Activated:Connect(function()
		choice.size = math.max(1, choice.size - 1)
		refreshChoices()
	end)
	plus.Activated:Connect(function()
		choice.size = math.min(Config.Party.MaxSize, choice.size + 1)
		refreshChoices()
	end)

	-- Difficulty: three pills.
	row(166, "Difficulty")
	local pills = {}
	for i, difficulty in DIFFICULTIES do
		local pill = chunkyButton(popup, UDim2.fromOffset(92, 50), UDim2.fromOffset(156 + (i - 1) * 98, 164), difficulty.name, 25)
		pill.Activated:Connect(function()
			choice.difficulty = difficulty.name
			refreshChoices()
		end)
		pills[difficulty.name] = { face = pill, color = difficulty.color }
	end

	-- Friends only: an on/off pill.
	row(232, "Friends only")
	local toggle = chunkyButton(popup, UDim2.fromOffset(92, 50), UDim2.fromOffset(332, 230), "", 25)
	toggle.Activated:Connect(function()
		choice.friendsOnly = not choice.friendsOnly
		refreshChoices()
	end)

	text({
		Position = UDim2.fromOffset(28, 292),
		Size = UDim2.new(1, -56, 0, 20),
		Font = Enum.Font.GothamMedium,
		TextColor3 = MUTED,
		Text = "Others join by stepping on the pad.",
		Parent = popup,
	})

	local cancel = chunkyButton(popup, UDim2.fromOffset(150, 58), UDim2.fromOffset(28, 324), "Cancel", 29)
	paint(cancel, WHITE)
	cancel.Activated:Connect(function()
		Remotes.LeaveParty:FireServer()
		close()
	end)
	local createButton = chunkyButton(popup, UDim2.new(1, -214, 0, 58), UDim2.fromOffset(186, 324), "Create party", 29)
	paint(createButton, LEMON)
	createButton.Activated:Connect(function()
		if doorIndex then
			Remotes.CreateParty:FireServer(doorIndex, choice.size, choice.difficulty, choice.friendsOnly)
		end
		close()
	end)

	refreshChoices = function()
		count.Text = tostring(choice.size)
		minus.Parent.Visible = choice.size > 1
		plus.Parent.Visible = choice.size < Config.Party.MaxSize
		for name, pill in pills do
			if name == choice.difficulty then
				paint(pill.face, pill.color)
			else
				paint(pill.face, WHITE, MUTED)
			end
		end
		toggle.Label.Text = if choice.friendsOnly then "On" else "Off"
		paint(toggle, if choice.friendsOnly then MINT else WHITE, if choice.friendsOnly then INK else MUTED)
	end
	refreshChoices()
end

local function buildBanner()
	banner = create("Frame", {
		Name = "PartyBanner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 132),
		Size = UDim2.fromOffset(420, 64),
		BackgroundColor3 = WHITE,
		Visible = false,
		Parent = gui,
	}, {
		create("UICorner", { CornerRadius = UDim.new(0, 32) }),
		create("UIStroke", { Color = INK, Thickness = 4 }),
	})
	bannerText = text({ Position = UDim2.fromOffset(22, 14), Size = UDim2.new(1, -150, 0, 36), TextXAlignment = Enum.TextXAlignment.Left, Text = "", Parent = banner })
	local leave = chunkyButton(banner, UDim2.fromOffset(104, 50), UDim2.new(1, -116, 0, 4), "Leave", 25)
	paint(leave, PINK)
	leave.Activated:Connect(function()
		Remotes.LeaveParty:FireServer()
	end)
end

function PartyUi.start()
	gui = create("ScreenGui", {
		Name = "Party",
		ResetOnSpawn = false,
		DisplayOrder = 6,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	buildPopup()
	buildBanner()

	Remotes.PartySetup.OnClientEvent:Connect(function(index)
		if type(index) ~= "number" then
			close()
			return
		end
		doorIndex = index
		choice.difficulty = player:GetAttribute("Difficulty") or Config.DefaultDifficulty
		refreshChoices()
		popup.Visible = true
	end)

	Remotes.PartyStatus.OnClientEvent:Connect(function(newStatus)
		status = if type(newStatus) == "table" then newStatus else nil
		banner.Visible = status ~= nil
	end)

	RunService.Heartbeat:Connect(function()
		if not status then
			return
		end
		local seconds = math.max(0, math.ceil(status.leavesAt - workspace:GetServerTimeNow()))
		bannerText.Text = ("PARTY %d/%d  ·  %s  ·  %ds"):format(status.count, status.size, status.difficulty, seconds)
	end)
end

return PartyUi
