-- The record boards in the lobby: most escapes, and the fastest escape on
-- each difficulty. Records are kept in OrderedDataStores (best times in
-- tenths of a second) and the boards refresh every minute. Where those can't
-- be reached, as in an unpublished place in Studio, a board shows the
-- players in this server instead and says so.
--
-- Progress.luau reports escapes and new best times; this only writes them.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Candy = require(ReplicatedStorage.Shared.Candy)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local REFRESH_INTERVAL = 60
local ROWS = 10

local BOARDS = {
	-- The difficulty colours match the doors (LobbyBuilder.luau).
	{ id = "Escapes", title = "MOST ESCAPES", ascending = false, color = Candy.SKY },
	{ id = "Easy", title = "FASTEST · EASY", ascending = true, color = Candy.MINT },
	{ id = "Normal", title = "FASTEST · NORMAL", ascending = true, color = Candy.LEMON },
	{ id = "Hard", title = "FASTEST · HARD", ascending = true, color = Candy.PINK },
}

local WHITE, INK, LEMON = Candy.WHITE, Candy.INK, Candy.LEMON
local MUTED = Color3.fromRGB(170, 176, 225) -- on the dark board
local STRIPE = Color3.fromRGB(58, 48, 112) -- every other row
-- Gold, silver and bronze for the top three.
local MEDALS = { LEMON, Color3.fromRGB(222, 228, 242), Color3.fromRGB(255, 170, 110) }

local Leaderboards = {}

local byId = {}
local names = {} -- [user id] = name, so each name is looked up once
local here = {} -- [user id] = { name, Escapes, Easy, ... } for this server's players
local refreshQueued = false

for _, board in BOARDS do
	byId[board.id] = board
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore(Config.DataStoreName .. "_" .. board.id)
	end)
	board.store = if ok then store else nil
end

local function keyFor(userId)
	return "player_" .. userId
end

local function nameOf(userId)
	if names[userId] then
		return names[userId]
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	names[userId] = if ok and name then name else "Unknown"
	return names[userId]
end

local function shown(board, value)
	return if board.id == "Escapes" then tostring(value) else Format.time(value / 10)
end

local function label(parent, props)
	props.Parent = parent
	return Candy.text(props)
end

-- A board: a glossy header in the board's colour with its title in bubbly
-- lettering, ten rows with medals for the top three, and a footer.
local function buildBoard(board, part)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Left -- the side facing into the lobby
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0
	-- 450 x 375 pixels on a 9 x 7.5 stud board.

	local header = Candy.create("Frame", {
		Name = "Header",
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.new(1, -24, 0, 62),
		BackgroundColor3 = board.color,
		Parent = gui,
	}, {
		Candy.corner(18),
		Candy.stroke(3),
		Candy.create("UIGradient", { Rotation = 90, Color = ColorSequence.new(board.color:Lerp(WHITE, 0.4), board.color) }),
		Candy.create("Frame", {
			Name = "Shine",
			Position = UDim2.fromOffset(10, 4),
			Size = UDim2.new(1, -20, 0.3, 0),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.55,
		}, { Candy.corner(12) }),
	})
	Candy.title(header, {
		Name = "Title",
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.new(1, -32, 0, 42),
		TextColor3 = WHITE,
		Text = board.title,
	}, 3, 3)

	board.rows = {}
	for i = 1, ROWS do
		local row = Candy.create("Frame", {
			Name = "Row" .. i,
			Position = UDim2.fromOffset(12, 86 + (i - 1) * 25),
			Size = UDim2.new(1, -24, 0, 23),
			BackgroundColor3 = STRIPE,
			BackgroundTransparency = if i % 2 == 1 then 0 else 1,
			Parent = gui,
		}, { Candy.corner(UDim.new(0.5, 0)) })
		local medal = MEDALS[i]
		local rank = Candy.create("Frame", {
			Name = "Rank",
			Position = UDim2.fromOffset(4, 1),
			Size = UDim2.fromOffset(32, 21),
			BackgroundColor3 = medal or STRIPE,
			BackgroundTransparency = if medal then 0 else 1,
			Parent = row,
		}, { Candy.corner(UDim.new(0.5, 0)), if medal then Candy.stroke(2) else nil })
		label(rank, { Position = UDim2.fromScale(0.15, 0.12), Size = UDim2.fromScale(0.7, 0.76), TextColor3 = if medal then INK else MUTED, Text = tostring(i) })
		board.rows[i] = {
			rank = rank,
			name = label(row, { Position = UDim2.fromOffset(46, 2), Size = UDim2.new(0.66, -46, 1, -4), Font = Enum.Font.GothamBold, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left }),
			value = label(row, { Position = UDim2.new(0.66, 0, 0, 2), Size = UDim2.new(0.34, -10, 1, -4), TextColor3 = LEMON, TextXAlignment = Enum.TextXAlignment.Right }),
		}
	end

	board.footer = label(gui, {
		Position = UDim2.new(0, 12, 1, -36),
		Size = UDim2.new(1, -24, 0, 18),
		Font = Enum.Font.GothamBold,
		TextColor3 = MUTED,
	})
	gui.Parent = part
end

-- The board's top entries from its OrderedDataStore, or nil if that failed.
local function fetchAllTime(board)
	if not board.store then
		return nil
	end
	local ok, page = pcall(function()
		return board.store:GetSortedAsync(board.ascending, ROWS):GetCurrentPage()
	end)
	if not ok then
		return nil
	end
	local entries = {}
	for _, item in page do
		local userId = tonumber(string.match(item.key, "^player_(%-?%d+)$"))
		if userId then
			table.insert(entries, { name = nameOf(userId), value = item.value })
		end
	end
	return entries
end

local function fetchHere(board)
	local entries = {}
	for _, record in here do
		if record[board.id] then
			table.insert(entries, { name = record.name, value = record[board.id] })
		end
	end
	table.sort(entries, function(a, b)
		return if board.ascending then a.value < b.value else a.value > b.value
	end)
	return entries
end

local function draw(board, entries, allTime)
	for i, row in board.rows do
		local entry = entries[i]
		row.name.Text = if entry then entry.name elseif i == 1 then "No records yet. Be the first!" else ""
		row.value.Text = if entry then shown(board, entry.value) else ""
		row.rank.Visible = entry ~= nil
	end
	board.footer.Text = if allTime then "All time  ·  updates every minute" else "This server only  ·  publish the game for all-time records"
end

-- hereOnly redraws just the boards showing this server, without reading the
-- stores again; all-time boards wait for the next minute (read limits).
local function refresh(hereOnly)
	for _, board in BOARDS do
		if board.rows and not (hereOnly and board.allTime) then
			local entries = if hereOnly then nil else fetchAllTime(board)
			board.allTime = entries ~= nil
			draw(board, entries or fetchHere(board), board.allTime)
		end
	end
end

local function refreshSoon()
	if refreshQueued then
		return
	end
	refreshQueued = true
	task.delay(2, function()
		refreshQueued = false
		refresh(true)
	end)
end

local function write(id, player, value)
	local board = byId[id]
	if not board.store or player.UserId <= 0 then
		return
	end
	task.spawn(function()
		local ok, err = pcall(board.store.SetAsync, board.store, keyFor(player.UserId), value)
		if not ok then
			warn("[Leaderboards] Could not save", id, err)
		end
	end)
end

local function recordHere(player)
	local record = here[player.UserId]
	if not record then
		record = { name = player.Name }
		here[player.UserId] = record
	end
	return record
end

-- A joining player's saved records, for the "this server" boards.
function Leaderboards.seed(player, escapes, bestTimes)
	local record = recordHere(player)
	if escapes > 0 then
		record.Escapes = escapes
	end
	for difficulty, seconds in bestTimes do
		record[difficulty] = math.floor(seconds * 10 + 0.5)
	end
	refreshSoon()
end

function Leaderboards.recordEscape(player, escapes)
	recordHere(player).Escapes = escapes
	write("Escapes", player, escapes)
	refreshSoon()
end

-- Called only when seconds beats the player's saved best on that difficulty.
function Leaderboards.recordTime(player, difficulty, seconds)
	if not byId[difficulty] then
		return
	end
	local tenths = math.floor(seconds * 10 + 0.5)
	recordHere(player)[difficulty] = tenths
	write(difficulty, player, tenths)
	refreshSoon()
end

function Leaderboards.init(layout)
	for _, board in BOARDS do
		local part = layout.boards[board.id]
		if part then
			buildBoard(board, part)
		end
	end
	refresh()
	task.spawn(function()
		while true do
			task.wait(REFRESH_INTERVAL)
			refresh()
		end
	end)
end

return Leaderboards
