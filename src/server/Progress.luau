-- Checkpoints, shells, escapes, difficulty, pearls, shop items, spawning and
-- saving.
--
-- Player attributes the client reads:
--   Checkpoint         number of stages cleared (0 = start in the lobby)
--   Difficulty         "Easy", "Normal" or "Hard"
--   Pebbles            pebbles left this life
--   ShellsFound        comma-separated stage numbers whose shell was collected
--   Pearls             pearls to spend in the shop
--   Owned              comma-separated ids of skins and accessories owned
--   EquippedSkin       id of the skin worn, if any
--   EquippedAccessory  id of the accessory worn, if any
--   Boost_<id>         how many of each boost the player carries
--   RunStartedAt       server time (workspace:GetServerTimeNow) the current
--                      run began, while one is being timed
--
-- A run is timed from walking through stage 1's door to escaping. It counts
-- for the easiest difficulty played along the way, and the best time on each
-- difficulty is saved and sent to the record boards (Leaderboards.luau).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Stages = require(ReplicatedStorage.Shared.Stages)
local Cosmetics = require(script.Parent.Cosmetics)
local Leaderboards = require(script.Parent.Leaderboards)

local AUTOSAVE_INTERVAL = 120
local RESTART_COOLDOWN = 2

local Progress = {}

local layout
local profiles = {} -- [Player] = profile
local pendingSaves = 0 -- saves still in flight, so BindToClose can wait for them
local lastRestart = {} -- [Player] = time

local store
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[Progress] Saving is off:", result)
	end
end

local function keyFor(player)
	return "player_" .. player.UserId
end

-- A saved count, cleaned up: a whole number from 0 to max.
local function wholeNumber(value, max)
	local number = tonumber(value)
	if not number or number ~= number then
		return 0
	end
	return math.clamp(math.floor(number), 0, max or math.huge)
end

local function load(player)
	local data, loaded = nil, store ~= nil
	if store then
		local ok, result = pcall(store.GetAsync, store, keyFor(player))
		if ok then
			data = result
		else
			-- Don't save over data we couldn't read.
			loaded = false
			warn("[Progress] Could not load", player.Name, result)
		end
	end
	if type(data) ~= "table" then
		data = {}
	end

	local shells = {}
	if type(data.shells) == "table" then
		for _, index in data.shells do
			if type(index) == "number" and Stages[index] then
				shells[index] = true
			end
		end
	end

	local owned = {}
	if type(data.owned) == "table" then
		for _, id in data.owned do
			local item = type(id) == "string" and Catalog.byId[id]
			if item and item.kind ~= "boost" then
				owned[id] = true
			end
		end
	end

	local equipped = {}
	if type(data.equipped) == "table" then
		for slot, kind in Catalog.slots do
			local id = data.equipped[slot]
			local item = type(id) == "string" and Catalog.byId[id]
			if item and item.kind == kind and owned[id] then
				equipped[slot] = id
			end
		end
	end

	local boosts = {}
	for _, item in Catalog.items do
		if item.kind == "boost" then
			boosts[item.id] = wholeNumber(type(data.boosts) == "table" and data.boosts[item.id], Config.Boosts.MaxCarried)
		end
	end

	local bestTimes = {}
	if type(data.bestTimes) == "table" then
		for name in Config.Difficulties do
			local seconds = tonumber(data.bestTimes[name])
			if seconds and seconds == seconds and seconds > 0 then
				bestTimes[name] = seconds
			end
		end
	end

	-- A run that already escaped starts over, so the exit can't pay twice.
	local checkpoint = math.clamp(math.floor(tonumber(data.checkpoint) or 0), 0, #Stages)
	if data.escaped == true then
		checkpoint = 0
	end

	return {
		checkpoint = checkpoint,
		shells = shells,
		wins = wholeNumber(data.wins),
		difficulty = if Config.Difficulties[data.difficulty] then data.difficulty else Config.DefaultDifficulty,
		escaped = false,
		pearls = wholeNumber(data.pearls),
		owned = owned,
		equipped = equipped,
		boosts = boosts,
		bestTimes = bestTimes, -- [difficulty name] = seconds
		run = nil, -- { startedAt = os.clock(), easiest = difficulty order } while timing
		canSave = loaded,
	}
end

local function save(player, profile)
	if not store or not profile.canSave then
		return
	end
	local shells = {}
	for index in profile.shells do
		table.insert(shells, index)
	end
	local owned = {}
	for id in profile.owned do
		table.insert(owned, id)
	end
	pendingSaves += 1
	local ok, err = pcall(store.SetAsync, store, keyFor(player), {
		checkpoint = profile.checkpoint,
		shells = shells,
		wins = profile.wins,
		difficulty = profile.difficulty,
		escaped = profile.escaped,
		pearls = profile.pearls,
		owned = owned,
		equipped = { skin = profile.equipped.skin, accessory = profile.equipped.accessory },
		boosts = profile.boosts,
		bestTimes = profile.bestTimes,
	}, { player.UserId })
	pendingSaves -= 1
	if not ok then
		warn("[Progress] Could not save", player.Name, err)
	end
end

local function shellCount(profile)
	local count = 0
	for _ in profile.shells do
		count += 1
	end
	return count
end

local function sync(player, profile)
	local found = {}
	for index in profile.shells do
		table.insert(found, index)
	end
	table.sort(found)
	local owned = {}
	for id in profile.owned do
		table.insert(owned, id)
	end
	table.sort(owned)

	player:SetAttribute("Checkpoint", profile.checkpoint)
	player:SetAttribute("Difficulty", profile.difficulty)
	player:SetAttribute("ShellsFound", table.concat(found, ","))
	player:SetAttribute("Pearls", profile.pearls)
	player:SetAttribute("Owned", table.concat(owned, ","))
	player:SetAttribute("EquippedSkin", profile.equipped.skin)
	player:SetAttribute("EquippedAccessory", profile.equipped.accessory)
	for id, count in profile.boosts do
		player:SetAttribute("Boost_" .. id, count)
	end

	local stats = player:FindFirstChild("leaderstats")
	if stats then
		stats.Stage.Value = math.min(profile.checkpoint + 1, #Stages)
		stats.Shells.Value = shellCount(profile)
		stats.Escapes.Value = profile.wins
		stats.Pearls.Value = profile.pearls
	end
end

local function makeLeaderstats(player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	for _, name in { "Stage", "Shells", "Escapes", "Pearls" } do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = stats
	end
	stats.Parent = player
end

local function playerFromHit(hit)
	local character = hit:FindFirstAncestorOfClass("Model")
	local player = character and Players:GetPlayerFromCharacter(character)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if player and humanoid and humanoid.Health > 0 and profiles[player] then
		return player, profiles[player]
	end
	return nil, nil
end

local function spawnPlayer(player)
	local profile = profiles[player]
	if not profile or not player.Parent then
		return
	end
	player:LoadCharacter()
	local character = player.Character
	if character and profile.checkpoint > 0 then
		character:PivotTo(layout.rooms[profile.checkpoint].checkpointCFrame)
	end
end

local function onCharacterAdded(player, character)
	player:SetAttribute("Pebbles", Config.Pebbles.PerLife)
	local profile = profiles[player]
	if profile then
		task.spawn(Cosmetics.apply, player, character, profile.equipped)
	end
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	humanoid.Died:Connect(function()
		task.wait(Config.RespawnTime)
		-- Skip if the player already got a new character (for example by restarting).
		if player.Character == character then
			spawnPlayer(player)
		end
	end)
end

local function onPlayerAdded(player)
	makeLeaderstats(player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)

	local profile = load(player)
	if not player.Parent then
		return
	end
	profiles[player] = profile
	sync(player, profile)
	Leaderboards.seed(player, profile.wins, profile.bestTimes)
	spawnPlayer(player)
end

local function difficultyByOrder(order)
	for name, difficulty in Config.Difficulties do
		if difficulty.order == order then
			return name
		end
	end
	return Config.DefaultDifficulty
end

local function onRunStart(hit)
	local player, profile = playerFromHit(hit)
	if not player or profile.checkpoint ~= 0 or profile.run then
		return
	end
	profile.run = { startedAt = os.clock(), easiest = Config.Difficulties[profile.difficulty].order }
	player:SetAttribute("RunStartedAt", workspace:GetServerTimeNow())
end

-- Stops the run clock at the exit. Returns a line for the escape screen.
local function finishRun(player, profile)
	local run = profile.run
	if not run then
		return ""
	end
	profile.run = nil
	player:SetAttribute("RunStartedAt", nil)

	local seconds = math.floor((os.clock() - run.startedAt) * 10) / 10
	local difficulty = difficultyByOrder(run.easiest)
	local best = profile.bestTimes[difficulty]
	if best and seconds >= best then
		return ("\nTime %s on %s   (best %s)"):format(Format.time(seconds), difficulty, Format.time(best))
	end
	profile.bestTimes[difficulty] = seconds
	Leaderboards.recordTime(player, difficulty, seconds)
	return ("\nTime %s on %s   New best!"):format(Format.time(seconds), difficulty)
end

local function addPearls(player, profile, amount)
	profile.pearls += amount
	sync(player, profile)
end

local function onCheckpoint(room, hit)
	local player, profile = playerFromHit(hit)
	if not player or room.index <= profile.checkpoint then
		return
	end
	profile.checkpoint = room.index
	player:SetAttribute("Pebbles", Config.Pebbles.PerLife)
	addPearls(player, profile, Config.Pearls.PerStage)
	local text = if room.index == #Stages then "Every stage cleared. Find the way out." else "Stage " .. room.index .. " cleared"
	Remotes.Notify:FireClient(player, "checkpoint", ("%s   +%d pearls"):format(text, Config.Pearls.PerStage))
end

local function onShell(room, hit)
	local player, profile = playerFromHit(hit)
	if not player or profile.shells[room.index] then
		return
	end
	profile.shells[room.index] = true
	addPearls(player, profile, Config.Pearls.PerShell)
	Remotes.Notify:FireClient(player, "shell", ("Shell found (%d/%d)   +%d pearls"):format(shellCount(profile), #Stages, Config.Pearls.PerShell))
end

local function onExit(hit)
	local player, profile = playerFromHit(hit)
	if not player or profile.escaped or profile.checkpoint < #Stages then
		return
	end
	profile.escaped = true
	profile.wins += 1
	local timeLine = finishRun(player, profile)
	addPearls(player, profile, Config.Pearls.PerEscape)
	Leaderboards.recordEscape(player, profile.wins)
	Remotes.Notify:FireClient(
		player,
		"win",
		("You got out. Escapes: %d   Shells: %d/%d   +%d pearls%s"):format(profile.wins, shellCount(profile), #Stages, Config.Pearls.PerEscape, timeLine)
	)
	task.spawn(save, player, profile)
end

-- The profile of a player who has finished loading, or nil.
function Progress.getProfile(player)
	return profiles[player]
end

-- Pushes a player's profile out to their attributes and leaderstats.
function Progress.sync(player)
	local profile = profiles[player]
	if profile then
		sync(player, profile)
	end
end

-- For other systems and testing: gives (or with a negative amount, takes) pearls.
function Progress.addPearls(player, amount)
	local profile = profiles[player]
	if profile and type(amount) == "number" then
		addPearls(player, profile, math.max(-profile.pearls, math.floor(amount)))
	end
end

function Progress.init(newLayout)
	layout = newLayout
	-- Characters are spawned by spawnPlayer so they can start at their checkpoint.
	Players.CharacterAutoLoads = false

	for _, room in layout.rooms do
		room.checkpointPad.Touched:Connect(function(hit)
			onCheckpoint(room, hit)
		end)
		if room.shell then
			room.shell.Touched:Connect(function(hit)
				onShell(room, hit)
			end)
		end
	end
	layout.exitDoor.Touched:Connect(onExit)
	layout.runStart.Touched:Connect(onRunStart)

	Remotes.SetDifficulty.OnServerEvent:Connect(function(player, name)
		local profile = profiles[player]
		if profile and type(name) == "string" and Config.Difficulties[name] then
			profile.difficulty = name
			if profile.run then
				profile.run.easiest = math.min(profile.run.easiest, Config.Difficulties[name].order)
			end
			sync(player, profile)
		end
	end)

	Remotes.Restart.OnServerEvent:Connect(function(player)
		local profile = profiles[player]
		local now = os.clock()
		if not profile or (lastRestart[player] and now - lastRestart[player] < RESTART_COOLDOWN) then
			return
		end
		lastRestart[player] = now
		profile.checkpoint = 0
		profile.escaped = false
		profile.run = nil
		player:SetAttribute("RunStartedAt", nil)
		sync(player, profile)
		spawnPlayer(player)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		profiles[player] = nil
		lastRestart[player] = nil
		if profile then
			save(player, profile)
		end
	end)

	game:BindToClose(function()
		for player, profile in profiles do
			task.spawn(save, player, profile)
		end
		-- Also waits for saves PlayerRemoving already started. Their profiles are
		-- gone from the table, and the server would otherwise close mid-save.
		while pendingSaves > 0 do
			task.wait()
		end
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player, profile in profiles do
				task.spawn(save, player, profile)
			end
		end
	end)
end

return Progress
