-- Your record: six numbers the server keeps for you (player attributes, see
-- server/Progress.luau), each on one of the UI kit's picture tiles, in the
-- kit's window. Opened from the HUD's dock.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Candy = require(ReplicatedStorage.Shared.Candy)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Stages = require(ReplicatedStorage.Shared.Stages)
local Windows = require(script.Parent.Windows)

local player = Players.LocalPlayer

local INK, MUTED = Candy.INK, Candy.MUTED
local WIDTH, HEIGHT = 680, 520
local ROW = 108
local TILE = 92

local StatsUi = {}

local gui, playTimeLabel
local values = {} -- [stat id] = value label

local function count(attribute)
	return tostring(player:GetAttribute(attribute) or 0)
end

local function fastest()
	local best, on = nil, nil
	for name in Config.Difficulties do
		local seconds = player:GetAttribute("Best_" .. name)
		if seconds and (not best or seconds < best) then
			best, on = seconds, name
		end
	end
	return if best then ("%s  ·  %s"):format(Format.time(best), on) else "Not yet"
end

local function shells()
	local found = 0
	for _ in string.gmatch(player:GetAttribute("ShellsFound") or "", "%d+") do
		found += 1
	end
	return ("%d of %d"):format(found, #Stages)
end

local STATS = {
	{ id = "escapes", art = "stat_trophy", name = "Escapes", value = function()
		return count("Escapes")
	end, watch = { "Escapes" } },
	{ id = "fastest", art = "stat_stopwatch", name = "Fastest escape", value = fastest, watch = { "Best_Easy", "Best_Normal", "Best_Hard" } },
	{ id = "stages", art = "stat_footprints", name = "Stages cleared", value = function()
		return count("StatStages")
	end, watch = { "StatStages" } },
	{ id = "caught", art = "stat_skull", name = "Times caught", value = function()
		return count("StatCaught")
	end, watch = { "StatCaught" } },
	{ id = "shells", art = "stat_shell", name = "Shells found", value = shells, watch = { "ShellsFound" } },
	{ id = "runs", art = "stat_wave", name = "Runs started", value = function()
		return count("StatRuns")
	end, watch = { "StatRuns" } },
}

local function playTime()
	local seconds = (player:GetAttribute("PlayTime") or 0) + workspace:GetServerTimeNow() - (player:GetAttribute("PlayTimeAt") or workspace:GetServerTimeNow())
	local minutes = math.floor(seconds / 60)
	return if minutes >= 60 then ("%dh %02dm"):format(minutes // 60, minutes % 60) else ("%dm"):format(minutes)
end

local function render()
	if not gui then
		return
	end
	for _, stat in STATS do
		values[stat.id].Text = stat.value()
	end
	playTimeLabel.Text = "Time played: " .. playTime()
end

local function build()
	gui = Candy.create("ScreenGui", {
		Name = "Stats",
		ResetOnSpawn = false,
		DisplayOrder = 5,
		Enabled = false,
		ScreenInsets = Enum.ScreenInsets.None, -- the whole screen, notch strips too
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	local backdrop = Candy.create("TextButton", {
		Name = "Backdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.5,
		AutoButtonColor = false,
		Text = "",
		Parent = gui,
	})
	backdrop.Activated:Connect(StatsUi.close)

	local window, _, close = Candy.window(gui, { size = UDim2.fromOffset(WIDTH, HEIGHT), title = "YOUR RECORD" })
	close.Activated:Connect(StatsUi.close)
	Candy.fit(window, Vector2.new(WIDTH + 10, HEIGHT + 10), 24)

	local columnWidth = (WIDTH - 2 * Candy.WINDOW_SIDE) / 2
	for i, stat in STATS do
		local column, row = (i - 1) % 2, (i - 1) // 2
		local cell = Candy.create("Frame", {
			Name = stat.id,
			Position = UDim2.fromOffset(Candy.WINDOW_SIDE + column * columnWidth, Candy.WINDOW_TOP + row * ROW),
			Size = UDim2.fromOffset(columnWidth, ROW),
			BackgroundTransparency = 1,
			Parent = window,
		})
		Candy.art(stat.art, {
			Name = "Picture",
			Position = UDim2.fromOffset(0, (ROW - TILE) / 2),
			Size = UDim2.fromOffset(TILE * 1.04, TILE),
			ZIndex = 2,
			Parent = cell,
		})
		Candy.text({
			Name = "StatName",
			Position = UDim2.fromOffset(TILE + 16, 22),
			Size = UDim2.new(1, -TILE - 24, 0, 22),
			TextSize = 18,
			TextColor3 = MUTED,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = stat.name,
			Parent = cell,
		})
		values[stat.id] = Candy.text({
			Name = "Value",
			Position = UDim2.fromOffset(TILE + 16, 46),
			Size = UDim2.new(1, -TILE - 24, 0, 38),
			TextSize = 32,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = "",
			Parent = cell,
		})
	end

	playTimeLabel = Candy.text({
		Name = "PlayTime",
		Position = UDim2.new(0, Candy.WINDOW_SIDE, 1, -Candy.WINDOW_BOTTOM - 30),
		Size = UDim2.new(1, -2 * Candy.WINDOW_SIDE, 0, 22),
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = MUTED,
		Text = "",
		Parent = window,
	})

	gui.Parent = player:WaitForChild("PlayerGui")
end

local closeOthers = Windows.add(function()
	StatsUi.close()
end)

function StatsUi.close()
	if gui then
		gui.Enabled = false
	end
end

function StatsUi.toggle()
	if not gui then
		build()
	end
	if gui.Enabled then
		StatsUi.close()
		return
	end
	closeOthers()
	gui.Enabled = true
	render()
	-- Keep the time played ticking while it is open.
	task.spawn(function()
		while gui.Enabled do
			task.wait(1)
			render()
		end
	end)
end

function StatsUi.start()
	for _, stat in STATS do
		for _, attribute in stat.watch do
			player:GetAttributeChangedSignal(attribute):Connect(render)
		end
	end
end

return StatsUi
