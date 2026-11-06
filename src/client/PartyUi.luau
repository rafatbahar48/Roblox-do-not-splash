-- The party pop-up and the party banner. Stepping on a door's pad in the
-- lobby opens the pop-up (server/Parties.luau): party size, difficulty, how
-- many monsters and friends only, then Create. It creates the party itself
-- a little after your last change (Config.Party.AutoCreate). Hard stays shut
-- until you have escaped on Normal (Perks.canPlay). The practice door's
-- parties have no creature, so there the pop-up asks less. While you are in
-- a party, a banner says how full it is and when it leaves, with a button
-- to leave it.
--
-- Made of the SpriteCook UI kit's art (shared/Candy.luau). Everything here
-- only asks; the server decides. With a controller (Gamepad.luau) the pop-up
-- starts on Create party and B cancels; stepping off the pad leaves too.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Candy = require(ReplicatedStorage.Shared.Candy)
local Config = require(ReplicatedStorage.Shared.Config)
local Perks = require(ReplicatedStorage.Shared.Perks)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Gamepad = require(script.Parent.Gamepad)
local ScreenFit = require(script.Parent.ScreenFit)

local player = Players.LocalPlayer

local WHITE, MUTED = Candy.WHITE, Candy.MUTED
local MINT, LEMON, PINK = Candy.MINT, Candy.LEMON, Candy.PINK
local DIFFICULTIES = {
	{ name = "Easy", color = MINT },
	{ name = "Normal", color = LEMON },
	{ name = "Hard", color = PINK },
}
-- What each kind of door (Config.Doors) offers: the pop-up's title, and
-- a line saying what it is instead of the difficulties and monsters.
local MODES = {
	party = { title = "NEW PARTY" },
	practice = { title = "PRACTICE", line = "No creature. No coins or records." },
}
local WIDTH, HEIGHT = 640, 540
local TOP, SIDE = Candy.WINDOW_TOP, Candy.WINDOW_SIDE + 16 -- a window this tall has a wide frame
local PILL_WIDTH = 124

local create, text, paint = Candy.create, Candy.text, Candy.paint

local PartyUi = {}

local gui, popup, banner, bannerText
local refreshChoices -- redraws the pop-up's buttons from choice
local doorIndex -- the party door the pop-up is for
local doorMode = "party" -- and what kind it is
local choice = { size = Config.Party.MaxSize, difficulty = Config.DefaultDifficulty, monsters = 1, friendsOnly = false }
local askedFor -- a shut difficulty pressed, to say what opens it
local createAt -- os.clock() the pop-up creates the party itself, while it is open
local countdown -- says how long until then
local createParty -- creates the party with choice
local status -- the server's latest word on our party, or nil
local createButton -- where a controller starts
local cancel -- B

local function close()
	popup.Visible = false
	doorIndex = nil
	createAt = nil
	Gamepad.closed("party")
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
	Gamepad.keyHint(closeButton, nil, Enum.KeyCode.ButtonB, 36, UDim2.new(0, 8, 1, -8), Vector2.new(0, 1))

	local function row(y, caption)
		return text({ Position = UDim2.fromOffset(SIDE + 4, y + 10), Size = UDim2.fromOffset(150, 30), TextSize = 22, Text = caption, TextXAlignment = Enum.TextXAlignment.Left, Parent = popup })
	end

	-- A count with - and + either side of it, on the right of its row.
	local function stepper(y, field, max)
		local minus = pictureButton(popup, "minus", UDim2.fromOffset(50, 50), UDim2.fromOffset(WIDTH - SIDE - 176, y))
		local count = text({ Position = UDim2.fromOffset(WIDTH - SIDE - 118, y + 6), Size = UDim2.fromOffset(60, 38), Text = "", Parent = popup })
		local plus = pictureButton(popup, "plus", UDim2.fromOffset(50, 50), UDim2.fromOffset(WIDTH - SIDE - 50, y))
		minus.Activated:Connect(function()
			choice[field] = math.max(1, choice[field] - 1)
			refreshChoices()
		end)
		plus.Activated:Connect(function()
			choice[field] = math.min(max, choice[field] + 1)
			refreshChoices()
		end)
		return function(visible)
			count.Text = tostring(choice[field])
			count.Visible = visible
			minus.Visible = visible and choice[field] > 1
			plus.Visible = visible and choice[field] < max
			-- A controller on the one that just went keeps its place on the other.
			if GuiService.SelectedObject == minus and not minus.Visible then
				GuiService.SelectedObject = plus
			elseif GuiService.SelectedObject == plus and not plus.Visible then
				GuiService.SelectedObject = minus
			end
		end
	end

	-- A small line under a row.
	local function note(y)
		return text({
			Position = UDim2.fromOffset(SIDE + 4, y),
			Size = UDim2.new(1, -2 * SIDE - 8, 0, 20),
			Font = Enum.Font.GothamMedium,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = "",
			Parent = popup,
		})
	end

	-- Party size: - [n] +
	row(TOP, "Party size")
	local refreshSize = stepper(TOP, "size", Config.Party.MaxSize)

	-- Difficulty: a button for each, or at the practice door a line instead.
	local difficultyRow = row(TOP + 58, "Difficulty")
	local difficultyLine = note(TOP + 112)
	local modeLine = text({
		Position = UDim2.fromOffset(SIDE + 4, TOP + 66),
		Size = UDim2.new(1, -2 * SIDE - 8, 0, 34),
		TextSize = 22,
		TextColor3 = MUTED,
		Text = "",
		Parent = popup,
	})
	local pills = {}
	for slot, difficulty in DIFFICULTIES do
		local pill = Candy.button(popup, {
			size = UDim2.fromOffset(PILL_WIDTH, 52),
			position = UDim2.fromOffset(WIDTH - SIDE - (#DIFFICULTIES - slot + 1) * (PILL_WIDTH + 4) + 4, TOP + 56),
			text = difficulty.name,
		})
		pill.Activated:Connect(function()
			if Perks.canPlay(player, difficulty.name) then
				choice.difficulty = difficulty.name
				askedFor = nil
			else
				askedFor = difficulty.name
			end
			refreshChoices()
		end)
		local tag = Candy.badge(pill, "", 30, UDim2.new(1, 6, 0, -12), Vector2.new(1, 0), Candy.LEMON)
		tag.Label.Size = UDim2.fromScale(0.84, 0.66)
		pills[difficulty.name] = { face = pill, color = difficulty.color, tag = tag }
	end

	-- Monsters: more of them, more coins.
	local monstersRow = row(TOP + 142, "Monsters")
	local refreshMonsters = stepper(TOP + 142, "monsters", Config.Monsters.Max)
	local monstersLine = note(TOP + 196)

	-- Friends only: the kit's ON/OFF toggle.
	row(TOP + 226, "Friends only")
	local toggle = pictureButton(popup, "toggle_off", UDim2.fromOffset(112, 50), UDim2.fromOffset(WIDTH - SIDE - 112, TOP + 222))
	toggle.Activated:Connect(function()
		choice.friendsOnly = not choice.friendsOnly
		refreshChoices()
	end)

	countdown = text({
		Position = UDim2.fromOffset(SIDE, TOP + 282),
		Size = UDim2.new(1, -2 * SIDE, 0, 20),
		Font = Enum.Font.GothamMedium,
		TextSize = 16,
		Text = "",
		Parent = popup,
	})

	cancel = Candy.button(popup, {
		size = UDim2.fromOffset(160, 62),
		position = UDim2.new(0, SIDE, 1, -Candy.WINDOW_BOTTOM - 66),
		text = "Cancel",
	})
	cancel.Activated:Connect(function()
		Remotes.LeaveParty:FireServer()
		close()
	end)
	createButton = Candy.button(popup, {
		size = UDim2.new(1, -2 * SIDE - 172, 0, 62),
		position = UDim2.new(0, SIDE + 172, 1, -Candy.WINDOW_BOTTOM - 66),
		text = "Create party",
		color = LEMON,
	})
	createParty = function()
		if doorIndex then
			Remotes.CreateParty:FireServer(doorIndex, choice.size, choice.difficulty, choice.monsters, choice.friendsOnly)
		end
		close()
	end
	createButton.Activated:Connect(createParty)

	refreshChoices = function()
		local mode = MODES[doorMode] or MODES.party
		local party = mode.line == nil
		title.Text = mode.title
		refreshSize(true)
		difficultyRow.Visible = party
		difficultyLine.Visible = party
		monstersRow.Visible = party
		monstersLine.Visible = party
		refreshMonsters(party)
		modeLine.Visible = not party
		modeLine.Text = mode.line or ""
		for name, pill in pills do
			local left = Perks.escapesToOpen(player, name)
			pill.face.Parent.Visible = party
			if name == choice.difficulty then
				paint(pill.face, pill.color)
			elseif left > 0 then
				paint(pill.face, Candy.CLOUD, nil, true)
			else
				paint(pill.face, WHITE)
			end
			-- How far off a shut one is, and a first run's place to start.
			local needs = Config.Difficulties[name].needs
			local starting = name == Config.DefaultDifficulty and (player:GetAttribute("Escapes") or 0) == 0
			pill.tag.Visible = left > 0 or starting
			pill.tag.Size = UDim2.fromOffset(if left > 0 then 54 else 100, 30)
			if left > 0 then
				pill.tag.Label.Text = ("%d/%d"):format(needs.escapes - left, needs.escapes)
			else
				pill.tag.Label.Text = "Start here"
			end
		end
		if askedFor then
			local needs = Config.Difficulties[askedFor].needs
			difficultyLine.Text = ("Escape on %s %d times to open %s."):format(needs.on, needs.escapes, askedFor)
		else
			difficultyLine.Text = Config.Difficulties[choice.difficulty].blurb
		end
		local bonus = Config.Monsters.Coins[choice.monsters]
		monstersLine.Text = if bonus > 1 then ("Coins x%s on this run."):format(bonus) else "More monsters, more coins."
		Candy.setArt(toggle, if choice.friendsOnly then "toggle_on" else "toggle_off")
		if doorIndex then
			createAt = os.clock() + Config.Party.AutoCreate
		end
	end
	refreshChoices()
end

local function buildBanner()
	-- Shrinks with the HUD on small screens. On touch screens, where the HUD's
	-- buttons fill the top corners, it sits at the bottom, between the
	-- thumbstick and the jump button.
	local touch = UserInputService.TouchEnabled
	local body = Candy.raised(ScreenFit.frame(gui), {
		name = "PartyBanner",
		anchor = Vector2.new(0.5, if touch then 1 else 0),
		position = if touch then UDim2.new(0.5, 0, 1, -16) else UDim2.new(0.5, 0, 0, 132),
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
		askedFor = nil
		-- What you played last.
		choice.difficulty = player:GetAttribute("Difficulty") or Config.DefaultDifficulty
		-- Alone on the server: no one to wait for.
		choice.size = if #Players:GetPlayers() > 1 then Config.Party.MaxSize else 1
		refreshChoices()
		popup.Visible = true
		Gamepad.opened("party", createButton, function()
			Remotes.LeaveParty:FireServer()
			close()
		end)
	end)

	Remotes.PartyStatus.OnClientEvent:Connect(function(newStatus)
		status = if type(newStatus) == "table" then newStatus else nil
		banner.Visible = status ~= nil
	end)

	RunService.Heartbeat:Connect(function()
		if createAt then
			local left = math.max(0, math.ceil(createAt - os.clock()))
			countdown.Text = ("Others join by stepping on the pad. Starting by itself in %ds"):format(left)
			if left == 0 then
				createParty()
			end
		end
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
