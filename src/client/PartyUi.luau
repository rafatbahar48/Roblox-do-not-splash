-- The party pop-up and the party banner. Stepping on a party door's pad in
-- the lobby opens the pop-up (server/Parties.luau): party size, difficulty
-- and friends only, then Create. While you are in a party, a banner says how
-- full it is and when it leaves, with a button to leave it.
--
-- Everything here only asks; the server decides.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Candy = require(ReplicatedStorage.Shared.Candy)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local INK, WHITE, MUTED = Candy.INK, Candy.WHITE, Candy.MUTED
local SKY, MINT, LEMON, PINK = Candy.SKY, Candy.MINT, Candy.LEMON, Candy.PINK
local DIFFICULTIES = {
	{ name = "Easy", color = MINT },
	{ name = "Normal", color = LEMON },
	{ name = "Hard", color = PINK },
}

local create, text, outlined, paint = Candy.create, Candy.text, Candy.outlined, Candy.paint

local PartyUi = {}

local gui, popup, banner, bannerText
local refreshChoices -- redraws the pop-up's buttons from choice
local doorIndex -- the party door the pop-up is for
local choice = { size = Config.Party.MaxSize, difficulty = Config.DefaultDifficulty, friendsOnly = false }
local status -- the server's latest word on our party, or nil

local function chunkyButton(parent, size, position, labelText, radius)
	return Candy.button(parent, { size = size, position = position, text = labelText, radius = radius })
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
	Candy.fit(popup, Vector2.new(470, 430), 24)

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
