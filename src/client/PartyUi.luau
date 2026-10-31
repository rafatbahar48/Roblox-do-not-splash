-- The party pop-up and the party banner. Stepping on a door's pad in the
-- lobby opens the pop-up (server/Parties.luau): party size, friends only,
-- and at the middle doors Normal or Hard, then Create. The Easy door's
-- parties are always Easy, and the practice door's have no creature. While
-- you are in a party, a banner says how full it is and when it leaves, with
-- a button to leave it.
--
-- Made of the SpriteCook UI kit's art (shared/Candy.luau). Everything here
-- only asks; the server decides.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Candy = require(ReplicatedStorage.Shared.Candy)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local WHITE, MUTED = Candy.WHITE, Candy.MUTED
local MINT, LEMON, PINK = Candy.MINT, Candy.LEMON, Candy.PINK
local DIFFICULTIES = {
	{ name = "Easy", color = MINT },
	{ name = "Normal", color = LEMON },
	{ name = "Hard", color = PINK },
}
-- What each kind of door (Config.Doors) offers: the pop-up's title, and the
-- difficulties to pick from, or a line saying what it is instead.
local MODES = {
	easy = { title = "EASY PARTY", difficulties = { "Easy" } },
	party = { title = "NEW PARTY", difficulties = { "Normal", "Hard" } },
	practice = { title = "PRACTICE", line = "No creature. No coins or records." },
}
local WIDTH, HEIGHT = 520, 470
local TOP, SIDE = Candy.WINDOW_TOP, Candy.WINDOW_SIDE

local create, text, paint = Candy.create, Candy.text, Candy.paint

local PartyUi = {}

local gui, popup, banner, bannerText
local refreshChoices -- redraws the pop-up's buttons from choice
local doorIndex -- the party door the pop-up is for
local doorMode = "party" -- and what kind it is
local choice = { size = Config.Party.MaxSize, difficulty = Config.DefaultDifficulty, friendsOnly = false }
local status -- the server's latest word on our party, or nil

local function close()
	popup.Visible = false
	doorIndex = nil
end

-- A button that is just a picture from the kit.
local function pictureButton(parent, art, size, position)
	local button = create("ImageButton", {
		Name = art,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Position = position,
		Size = size,
		ZIndex = 3,
		Parent = parent,
	})
	Candy.setArt(button, art)
	button.Activated:Connect(Candy.click)
	return button
end

local function buildPopup()
	local window, title, closeButton = Candy.window(gui, { name = "PartySetup", size = UDim2.fromOffset(WIDTH, HEIGHT), title = "NEW PARTY" })
	popup = window
	popup.Visible = false
	Candy.fit(popup, Vector2.new(WIDTH + 10, HEIGHT + 10), 24)
	closeButton.Activated:Connect(function()
		Remotes.LeaveParty:FireServer()
		close()
	end)

	local function row(y, caption)
		return text({ Position = UDim2.fromOffset(SIDE + 4, y + 10), Size = UDim2.fromOffset(150, 30), TextSize = 22, Text = caption, TextXAlignment = Enum.TextXAlignment.Left, Parent = popup })
	end

	-- Party size: - [n] +
	row(TOP, "Party size")
	local minus = pictureButton(popup, "minus", UDim2.fromOffset(50, 50), UDim2.fromOffset(282, TOP))
	local count = text({ Position = UDim2.fromOffset(340, TOP + 6), Size = UDim2.fromOffset(60, 38), Text = "", Parent = popup })
	local plus = pictureButton(popup, "plus", UDim2.fromOffset(50, 50), UDim2.fromOffset(408, TOP))
	minus.Activated:Connect(function()
		choice.size = math.max(1, choice.size - 1)
		refreshChoices()
	end)
	plus.Activated:Connect(function()
		choice.size = math.min(Config.Party.MaxSize, choice.size + 1)
		refreshChoices()
	end)

	-- Difficulty: a button for each this door offers, or a line instead.
	local difficultyRow = row(TOP + 68, "Difficulty")
	local modeLine = text({
		Position = UDim2.fromOffset(SIDE + 4, TOP + 76),
		Size = UDim2.new(1, -2 * SIDE - 8, 0, 34),
		TextSize = 22,
		TextColor3 = MUTED,
		Text = "",
		Parent = popup,
	})
	local pills = {}
	for _, difficulty in DIFFICULTIES do
		local pill = Candy.button(popup, {
			size = UDim2.fromOffset(150, 52),
			position = UDim2.fromOffset(176, TOP + 64),
			text = difficulty.name,
		})
		pill.Activated:Connect(function()
			choice.difficulty = difficulty.name
			refreshChoices()
		end)
		pills[difficulty.name] = { face = pill, color = difficulty.color }
	end

	-- Friends only: the kit's ON/OFF toggle.
	row(TOP + 136, "Friends only")
	local toggle = pictureButton(popup, "toggle_off", UDim2.fromOffset(112, 50), UDim2.fromOffset(WIDTH - SIDE - 112, TOP + 132))
	toggle.Activated:Connect(function()
		choice.friendsOnly = not choice.friendsOnly
		refreshChoices()
	end)

	text({
		Position = UDim2.fromOffset(SIDE, TOP + 196),
		Size = UDim2.new(1, -2 * SIDE, 0, 20),
		Font = Enum.Font.GothamMedium,
		TextSize = 16,
		TextColor3 = MUTED,
		Text = "Others join by stepping on the pad.",
		Parent = popup,
	})

	local cancel = Candy.button(popup, {
		size = UDim2.fromOffset(160, 62),
		position = UDim2.new(0, SIDE, 1, -Candy.WINDOW_BOTTOM - 66),
		text = "Cancel",
	})
	cancel.Activated:Connect(function()
		Remotes.LeaveParty:FireServer()
		close()
	end)
	local createButton = Candy.button(popup, {
		size = UDim2.new(1, -2 * SIDE - 172, 0, 62),
		position = UDim2.new(0, SIDE + 172, 1, -Candy.WINDOW_BOTTOM - 66),
		text = "Create party",
		color = LEMON,
	})
	createButton.Activated:Connect(function()
		if doorIndex then
			Remotes.CreateParty:FireServer(doorIndex, choice.size, choice.difficulty, choice.friendsOnly)
		end
		close()
	end)

	refreshChoices = function()
		local mode = MODES[doorMode] or MODES.party
		title.Text = mode.title
		count.Text = tostring(choice.size)
		minus.Visible = choice.size > 1
		plus.Visible = choice.size < Config.Party.MaxSize
		local offered = mode.difficulties or {}
		difficultyRow.Visible = #offered > 0
		modeLine.Visible = mode.line ~= nil
		modeLine.Text = mode.line or ""
		for name, pill in pills do
			local slot = table.find(offered, name)
			pill.face.Parent.Visible = slot ~= nil
			if slot then
				pill.face.Parent.Position = UDim2.fromOffset(176 + (slot - 1) * 154, TOP + 64)
			end
			if name == choice.difficulty then
				paint(pill.face, pill.color)
			else
				paint(pill.face, WHITE, MUTED)
			end
		end
		Candy.setArt(toggle, if choice.friendsOnly then "toggle_on" else "toggle_off")
	end
	refreshChoices()
end

local function buildBanner()
	local body = Candy.raised(gui, {
		name = "PartyBanner",
		anchor = Vector2.new(0.5, 0),
		position = UDim2.new(0.5, 0, 0, 132),
		size = UDim2.fromOffset(440, 70),
		lip = 6,
	})
	banner = body.Parent
	banner.Visible = false
	bannerText = text({ Position = UDim2.fromOffset(22, 14), Size = UDim2.new(1, -150, 0, 36), TextXAlignment = Enum.TextXAlignment.Left, Text = "", Parent = body })
	local leave = Candy.button(body, { size = UDim2.fromOffset(110, 52), position = UDim2.new(1, -122, 0, 6), text = "Leave", color = PINK })
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

	Remotes.PartySetup.OnClientEvent:Connect(function(index, mode)
		if type(index) ~= "number" then
			close()
			return
		end
		doorIndex = index
		doorMode = if MODES[mode] then mode else "party"
		-- What you played last, if this door offers it.
		local offered = MODES[doorMode].difficulties or {}
		local last = player:GetAttribute("Difficulty")
		choice.difficulty = if table.find(offered, last) then last else offered[1]
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
		if status.practice then
			bannerText.Text = ("PRACTICE %d/%d  ·  %ds"):format(status.count, status.size, seconds)
		else
			bannerText.Text = ("PARTY %d/%d  ·  %s  ·  %ds"):format(status.count, status.size, status.difficulty or "", seconds)
		end
	end)
end

return PartyUi
