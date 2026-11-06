-- The reward for coming back on a new day (Config.Daily): a window a few
-- seconds after you arrive in the lobby, with the week's rewards and today's
-- lit, and Claim. The server says when one is due (the DailyDue attribute,
-- server/Progress.luau) and gives it; closing the window claims it too.
--
-- Made of the SpriteCook UI kit's art (shared/Candy.luau); the code only
-- places it and writes the words and numbers.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Candy = require(ReplicatedStorage.Shared.Candy)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Zones = require(ReplicatedStorage.Shared.Zones)
local Gamepad = require(script.Parent.Gamepad)
local Windows = require(script.Parent.Windows)

local player = Players.LocalPlayer

local WIDTH, HEIGHT = 800, 430
local TOP, SIDE = Candy.WINDOW_TOP, Candy.WINDOW_SIDE + 16
local TILE_GAP = 6
local TILE_HEIGHT = 134
local ICON = 52
local ARRIVAL_WAIT = 5 -- seconds in the lobby first, for the camera's sweep (LobbyLife.luau)
local CHECK_INTERVAL = 1

local REWARDS = Config.Daily.Rewards

local WelcomeBack = {}

local window, heading, claimButton
local tiles = {} -- [day of the week] = { holder, day label }
local closeOthers

-- A reward's icon and what it says under it.
local function describe(gives)
	local words = {}
	if gives.coins then
		table.insert(words, tostring(gives.coins))
	end
	if gives.boosts then
		table.insert(words, "Updraft and Hush")
	end
	if gives.selfRevives then
		table.insert(words, "Self-Revive")
	end
	local art = if gives.coins then nil elseif gives.boosts then "action_updraft" else "robux_self_revive"
	return art, table.concat(words, " + ")
end

local function tile(day, gives, width)
	local x = SIDE + (day - 1) * (width + TILE_GAP)
	local today = false
	local holder = Candy.create("Frame", {
		Name = "Day" .. day,
		Position = UDim2.fromOffset(x, TOP + 44),
		Size = UDim2.fromOffset(width, TILE_HEIGHT),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = window,
	})
	local function draw(lit)
		if today == lit and holder:FindFirstChild("Tile") then
			return
		end
		today = lit
		local old = holder:FindFirstChild("Tile")
		if old then
			old:Destroy()
		end
		local body = Candy.raised(holder, {
			name = "Tile",
			size = UDim2.fromScale(1, 1),
			color = if lit then Candy.LEMON else nil,
			lip = 5,
			zIndex = 2,
		})
		-- Old white with a dark edge on today's lit wood.
		local function write(props)
			if lit then
				props.TextColor3 = Candy.WHITE
				return Candy.outlined(props, 1.5)
			end
			return Candy.text(props)
		end
		write({ Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 20), TextSize = 16, Text = "Day " .. day, ZIndex = 3, Parent = body })
		local art, words = describe(gives)
		local iconAt = UDim2.new(0.5, 0, 0, 58)
		if art then
			Candy.art(art, { AnchorPoint = Vector2.new(0.5, 0.5), Position = iconAt, Size = UDim2.fromOffset(ICON, ICON), ZIndex = 3, Parent = body })
		else
			Candy.coin(body, ICON - 8, iconAt, Vector2.new(0.5, 0.5))
		end
		write({
			Position = UDim2.new(0, 4, 1, -46),
			Size = UDim2.new(1, -8, 0, 40),
			Font = Enum.Font.GothamMedium,
			TextSize = 14,
			TextWrapped = true,
			Text = words,
			ZIndex = 3,
			Parent = body,
		})
	end
	draw(false)
	tiles[day] = draw
end

local function close()
	window.Visible = false
	Gamepad.closed("welcome")
end

local function claim()
	Remotes.ClaimDaily:FireServer()
	close()
end

local function build()
	local gui = Candy.create("ScreenGui", {
		Name = "WelcomeBack",
		ResetOnSpawn = false,
		DisplayOrder = 7,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local closeButton
	window, _, closeButton = Candy.window(gui, { name = "Welcome", size = UDim2.fromOffset(WIDTH, HEIGHT), title = "WELCOME BACK" })
	window.Visible = false
	Candy.fit(window, Vector2.new(WIDTH + 10, HEIGHT + 10), 24)
	closeOthers = Windows.add(close)
	closeButton.Activated:Connect(claim)
	Gamepad.keyHint(closeButton, nil, Enum.KeyCode.ButtonB, 36, UDim2.new(0, 8, 1, -8), Vector2.new(0, 1))

	heading = Candy.text({
		Position = UDim2.fromOffset(SIDE, TOP - 4),
		Size = UDim2.new(1, -2 * SIDE, 0, 36),
		TextSize = 24,
		Text = "",
		Parent = window,
	})
	local width = (WIDTH - 2 * SIDE - (#REWARDS - 1) * TILE_GAP) / #REWARDS
	for day, gives in REWARDS do
		tile(day, gives, width)
	end
	claimButton = Candy.button(window, {
		anchor = Vector2.new(0.5, 0),
		size = UDim2.fromOffset(240, 62),
		position = UDim2.new(0.5, 0, 1, -Candy.WINDOW_BOTTOM - 66),
		text = "Claim",
		color = Candy.LEMON,
	})
	claimButton.Activated:Connect(claim)
end

local function show(due)
	local today = (due - 1) % #REWARDS + 1
	heading.Text = if due > 1 then ("%d days in a row. Today's reward:"):format(due) else "Your reward for coming back:"
	for day, draw in tiles do
		draw(day == today)
	end
	closeOthers()
	window.Position = UDim2.fromScale(0.5, 0.58)
	window.Visible = true
	Gamepad.opened("welcome", claimButton, claim)
	TweenService:Create(window, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
end

function WelcomeBack.start()
	build()
	task.spawn(function()
		task.wait(ARRIVAL_WAIT)
		while true do
			local due = player:GetAttribute("DailyDue")
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if due and root and Zones.at(root.Position) == "lobby" then
				show(due)
				return
			end
			task.wait(CHECK_INTERVAL)
		end
	end)
end

return WelcomeBack
