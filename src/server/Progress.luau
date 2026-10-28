-- Checkpoints, shells, escapes, difficulty, spawning and saving.
--
-- Player attributes the client reads:
--   Checkpoint   number of stages cleared (0 = start in the lobby)
--   Difficulty   "Easy", "Normal" or "Hard"
--   Pebbles      pebbles left this life
--   ShellsFound  comma-separated stage numbers whose shell was collected

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Stages = require(ReplicatedStorage.Shared.Stages)

local AUTOSAVE_INTERVAL = 120

local Progress = {}

local layout
local profiles = {} -- [Player] = profile
local pendingSaves = 0 -- saves still in flight, so BindToClose can wait for them

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

	return {
		checkpoint = math.clamp(math.floor(tonumber(data.checkpoint) or 0), 0, #Stages),
		shells = shells,
		wins = math.max(0, math.floor(tonumber(data.wins) or 0)),
		difficulty = if Config.Difficulties[data.difficulty] then data.difficulty else Config.DefaultDifficulty,
		escaped = false,
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
	pendingSaves += 1
	local ok, err = pcall(store.SetAsync, store, keyFor(player), {
		checkpoint = profile.checkpoint,
		shells = shells,
		wins = profile.wins,
		difficulty = profile.difficulty,
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

	player:SetAttribute("Checkpoint", profile.checkpoint)
	player:SetAttribute("Difficulty", profile.difficulty)
	player:SetAttribute("ShellsFound", table.concat(found, ","))

	local stats = player:FindFirstChild("leaderstats")
	if stats then
		stats.Stage.Value = math.min(profile.checkpoint + 1, #Stages)
		stats.Shells.Value = shellCount(profile)
		stats.Escapes.Value = profile.wins
	end
end

local function makeLeaderstats(player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	for _, name in { "Stage", "Shells", "Escapes" } do
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
	spawnPlayer(player)
end

local function onCheckpoint(room, hit)
	local player, profile = playerFromHit(hit)
	if not player or room.index <= profile.checkpoint then
		return
	end
	profile.checkpoint = room.index
	player:SetAttribute("Pebbles", Config.Pebbles.PerLife)
	sync(player, profile)
	local text = if room.index == #Stages then "Every stage cleared. Find the way out." else "Stage " .. room.index .. " cleared"
	Remotes.Notify:FireClient(player, "checkpoint", text)
end

local function onShell(room, hit)
	local player, profile = playerFromHit(hit)
	if not player or profile.shells[room.index] then
		return
	end
	profile.shells[room.index] = true
	sync(player, profile)
	Remotes.Notify:FireClient(player, "shell", ("Shell found (%d/%d)"):format(shellCount(profile), #Stages))
end

local function onExit(hit)
	local player, profile = playerFromHit(hit)
	if not player or profile.escaped or profile.checkpoint < #Stages then
		return
	end
	profile.escaped = true
	profile.wins += 1
	sync(player, profile)
	Remotes.Notify:FireClient(player, "win", ("You got out. Escapes: %d   Shells: %d/%d"):format(profile.wins, shellCount(profile), #Stages))
	task.spawn(save, player, profile)
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

	Remotes.SetDifficulty.OnServerEvent:Connect(function(player, name)
		local profile = profiles[player]
		if profile and type(name) == "string" and Config.Difficulties[name] then
			profile.difficulty = name
			sync(player, profile)
		end
	end)

	Remotes.Restart.OnServerEvent:Connect(function(player)
		local profile = profiles[player]
		if not profile then
			return
		end
		profile.checkpoint = 0
		profile.escaped = false
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
