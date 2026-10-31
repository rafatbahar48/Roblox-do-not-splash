-- Checkpoints, shells, escapes, difficulty, coins, shop items, stats,
-- settings, spawning and saving.
--
-- Player attributes the client reads:
--   Checkpoint         number of stages cleared (0 = start in the lobby)
--   Difficulty         "Easy", "Normal" or "Hard"
--   Pebbles            pebbles left this life
--   ShellsFound        comma-separated stage numbers whose shell was collected
--   Coins             coins to spend in the shop
--   Owned              comma-separated ids of skins and accessories owned
--   EquippedSkin       id of the skin worn, if any
--   EquippedAccessory  id of the accessory worn, if any
--   Boost_<id>         how many of each boost the player carries
--   RunStartedAt       server time (workspace:GetServerTimeNow) the current
--                      run began, while one is being timed
--   Escapes            times escaped, all runs together
--   StatRuns           runs started (through stage 1's doors)
--   StatCaught         times it caught them
--   StatStages         stages cleared, all runs together
--   StatEarned         coins earned, all time
--   PlayTime           seconds played, as of PlayTimeAt (server time)
--   Best_<difficulty>  fastest escape on that difficulty, in seconds
--   Setting_<id>       their settings (Config.Settings)
--   SelfRevives        Self-Revives they have (bought for Robux), used first
--                      when it catches them
--   DownedUntil        server time they bleed out at, while caught and choosing
--                      to revive, bleed out or go back to the lobby (Config.Revive)
--   Practice           true on a practice run: no creature, and no coins,
--                      shells, stats or records
--   CaveArrival        server time their party last arrived in the cave
--                      (client/Cave.luau plays what happens next)
--   CommunityRewarded  true once they have had the reward for joining the
--                      game's community (Community.luau)
--
-- A run starts in the cave behind the lobby, where a party arrives
-- (Parties.luau), and is timed from walking out of its mouth to escaping.
-- It counts for the easiest difficulty played along the way, and the best
-- time on each difficulty is saved and sent to the record boards
-- (Leaderboards.luau). Practice runs aren't saved: leave halfway and you
-- start in the lobby next time.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Perks = require(ReplicatedStorage.Shared.Perks)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Stages = require(ReplicatedStorage.Shared.Stages)
local Cosmetics = require(script.Parent.Cosmetics)
local Leaderboards = require(script.Parent.Leaderboards)
local Noise = require(script.Parent.Noise)

local AUTOSAVE_INTERVAL = 120
local RESTART_COOLDOWN = 2
local SETTING_GAP = 0.1 -- seconds between changes to one of a player's settings

local Progress = {}

-- True in a party's own server (Parties.luau): everyone starts in the cave.
Progress.inPartyServer = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0

local layout
local profiles = {} -- [Player] = profile
local pendingSaves = 0 -- saves still in flight, so BindToClose can wait for them
local lastRestart = {} -- [Player] = time
local lastSetting = {} -- [Player] = { [setting id] = time }

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

-- A setting's value, cleaned up, or nil if it isn't one.
local function settingValue(setting, value)
	if setting.min then
		local number = tonumber(value)
		if not number or number ~= number then
			return nil
		end
		local stepped = setting.min + math.round((number - setting.min) / setting.step) * setting.step
		return math.clamp(stepped, setting.min, setting.max)
	end
	return if type(value) == "boolean" then value else nil
end

local function settingById(id)
	for _, setting in Config.Settings do
		if setting.id == id then
			return setting
		end
	end
	return nil
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
			-- Up to the most anyone can carry; Deep Pockets is checked after loading.
			boosts[item.id] = wholeNumber(type(data.boosts) == "table" and data.boosts[item.id], math.max(Config.Boosts.MaxCarried, Config.PassPerks.DeepPockets.maxBoosts))
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

	local settings = {}
	local savedSettings = if type(data.settings) == "table" then data.settings else {}
	for _, setting in Config.Settings do
		local value = settingValue(setting, savedSettings[setting.id])
		settings[setting.id] = if value == nil then setting.default else value
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
		coins = wholeNumber(data.coins or data.pearls), -- saves from before coins said pearls
		owned = owned,
		equipped = equipped,
		boosts = boosts,
		bestTimes = bestTimes, -- [difficulty name] = seconds
		selfRevives = wholeNumber(data.selfRevives),
		communityRewarded = data.communityRewarded == true,
		runs = wholeNumber(data.runs),
		caught = wholeNumber(data.caught),
		stages = wholeNumber(data.stages),
		earned = wholeNumber(data.earned),
		playTime = wholeNumber(data.playTime), -- seconds, up to joinedAt
		joinedAt = os.clock(),
		settings = settings, -- [setting id] = value
		run = nil, -- { startedAt = os.clock(), easiest = difficulty order } while timing
		inCave = false, -- on a run that started in the cave, so stage 1 restarts there
		practice = false,
		partyPractice = false, -- this party's own server is for practice
		canSave = loaded,
	}
end

local function playedSeconds(profile)
	return profile.playTime + (os.clock() - profile.joinedAt)
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
		-- Nothing from a practice run is kept: next time is a fresh start.
		checkpoint = if profile.practice then 0 else profile.checkpoint,
		shells = shells,
		wins = profile.wins,
		difficulty = profile.difficulty,
		escaped = profile.escaped and not profile.practice,
		coins = profile.coins,
		owned = owned,
		equipped = { skin = profile.equipped.skin, accessory = profile.equipped.accessory },
		boosts = profile.boosts,
		bestTimes = profile.bestTimes,
		selfRevives = profile.selfRevives,
		communityRewarded = profile.communityRewarded,
		runs = profile.runs,
		caught = profile.caught,
		stages = profile.stages,
		earned = profile.earned,
		playTime = math.floor(playedSeconds(profile)),
		settings = profile.settings,
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
	player:SetAttribute("Coins", profile.coins)
	player:SetAttribute("Owned", table.concat(owned, ","))
	player:SetAttribute("EquippedSkin", profile.equipped.skin)
	player:SetAttribute("EquippedAccessory", profile.equipped.accessory)
	for id, count in profile.boosts do
		player:SetAttribute("Boost_" .. id, count)
	end
	player:SetAttribute("SelfRevives", profile.selfRevives)
	player:SetAttribute("CommunityRewarded", if profile.communityRewarded then true else nil)
	player:SetAttribute("Practice", if profile.practice then true else nil)
	player:SetAttribute("Escapes", profile.wins)
	player:SetAttribute("StatRuns", profile.runs)
	player:SetAttribute("StatCaught", profile.caught)
	player:SetAttribute("StatStages", profile.stages)
	player:SetAttribute("StatEarned", profile.earned)
	player:SetAttribute("PlayTime", math.floor(playedSeconds(profile)))
	player:SetAttribute("PlayTimeAt", workspace:GetServerTimeNow())
	for name in Config.Difficulties do
		player:SetAttribute("Best_" .. name, profile.bestTimes[name])
	end
	for id, value in profile.settings do
		player:SetAttribute("Setting_" .. id, value)
	end

	local stats = player:FindFirstChild("leaderstats")
	if stats then
		stats.Stage.Value = math.min(profile.checkpoint + 1, #Stages)
		stats.Shells.Value = shellCount(profile)
		stats.Escapes.Value = profile.wins
		stats.Coins.Value = profile.coins
	end
end

local function makeLeaderstats(player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	for _, name in { "Stage", "Shells", "Escapes", "Coins" } do
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

-- Where in the cave the slot-th of count players stands as they arrive.
local function caveSpot(slot, count)
	return layout.cave.spawn * CFrame.new(((slot or 1) - ((count or 1) + 1) / 2) * 3, 0, 0)
end

-- Gives a player a new character at their checkpoint (the cave if their run
-- started there, else the lobby, if none), or at the given spot.
local function spawnPlayer(player, at)
	local profile = profiles[player]
	if not profile or not player.Parent then
		return
	end
	player:LoadCharacter()
	local character = player.Character
	if character and at then
		character:PivotTo(at)
	elseif character and profile.checkpoint > 0 then
		character:PivotTo(layout.rooms[profile.checkpoint].checkpointCFrame)
	elseif character and profile.inCave then
		character:PivotTo(caveSpot())
	end
end

-- Waits, after being caught, for the player to choose: revive or bleed out
-- (DeathChoice). Nobody choosing bleeds out once the time is up.
local function awaitChoice(player, profile, downed)
	local seconds = Config.Revive.ChoiceTime
	player:SetAttribute("DownedUntil", workspace:GetServerTimeNow() + seconds)
	downed.deadline = os.clock() + seconds
	while player.Parent and profile.downed == downed and not downed.choice and os.clock() < downed.deadline do
		task.wait(0.1)
	end
	player:SetAttribute("DownedUntil", nil)
end

-- Ends a player's run: back to stage 1, from the lobby.
local function leaveRun(player, profile)
	profile.checkpoint = 0
	profile.escaped = false
	profile.run = nil
	profile.downed = nil
	profile.inCave = false
	profile.practice = false
	player:SetAttribute("RunStartedAt", nil)
	sync(player, profile)
end

local function onCharacterAdded(player, character)
	player:SetAttribute("Pebbles", Perks.pebblesPerLife(player))
	local profile = profiles[player]
	if profile then
		-- A new body: whatever caught the last one is over with.
		profile.downed = nil
		task.spawn(Cosmetics.apply, player, character, profile.equipped)
	end
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	humanoid.Died:Connect(function()
		local current = profiles[player]
		local downed = current and current.downed
		if downed then
			awaitChoice(player, current, downed)
		else
			task.wait(Config.RespawnTime)
		end
		-- Skip if the player already got a new character (for example by restarting).
		if player.Character ~= character then
			return
		end
		if current and current.downed == downed then
			current.downed = nil
		end
		if downed and downed.choice == "revive" then
			spawnPlayer(player, downed.spot)
			Noise.hush(player, Config.Revive.SafeSeconds)
		else
			if downed and downed.choice == "lobby" and current then
				leaveRun(player, current)
			end
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
	-- A party sent here from another server's party door brings its
	-- difficulty, and whether it is practice.
	local joinData = player:GetJoinData().TeleportData
	if type(joinData) == "table" then
		if type(joinData.difficulty) == "string" and Config.Difficulties[joinData.difficulty] then
			profile.difficulty = joinData.difficulty
		end
		profile.partyPractice = joinData.practice == true
	end
	profiles[player] = profile
	sync(player, profile)
	Leaderboards.seed(player, profile.wins, profile.bestTimes)
	if Progress.inPartyServer then
		Progress.enterCave(player)
	else
		spawnPlayer(player)
	end
end

local function difficultyByOrder(order)
	for name, difficulty in Config.Difficulties do
		if difficulty.order == order then
			return name
		end
	end
	return Config.DefaultDifficulty
end

local function startRun(player, profile)
	if profile.checkpoint ~= 0 or profile.run then
		return
	end
	profile.run = { startedAt = os.clock(), easiest = Config.Difficulties[profile.difficulty].order }
	if not profile.practice then
		profile.runs += 1
	end
	player:SetAttribute("RunStartedAt", workspace:GetServerTimeNow())
	sync(player, profile)
end

local function onRunStart(hit)
	local player, profile = playerFromHit(hit)
	if player then
		startRun(player, profile)
	end
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
	if profile.practice then
		return ("\nTime %s, practice"):format(Format.time(seconds))
	end
	local difficulty = difficultyByOrder(run.easiest)
	local best = profile.bestTimes[difficulty]
	if best and seconds >= best then
		return ("\nTime %s on %s   (best %s)"):format(Format.time(seconds), difficulty, Format.time(best))
	end
	profile.bestTimes[difficulty] = seconds
	Leaderboards.recordTime(player, difficulty, seconds)
	return ("\nTime %s on %s   New best!"):format(Format.time(seconds), difficulty)
end

local function addCoins(player, profile, amount)
	profile.coins += amount
	sync(player, profile)
end

local function onCheckpoint(room, hit)
	local player, profile = playerFromHit(hit)
	if not player or room.index <= profile.checkpoint then
		return
	end
	profile.checkpoint = room.index
	if profile.practice then
		player:SetAttribute("Pebbles", Perks.pebblesPerLife(player))
		sync(player, profile)
		Remotes.Notify:FireClient(player, "checkpoint", ("Stage %d cleared (practice)"):format(room.index))
		return
	end
	profile.stages += 1
	local coins = Config.Coins.PerStage * Perks.coinMultiplier(player)
	profile.earned += coins
	player:SetAttribute("Pebbles", Perks.pebblesPerLife(player))
	addCoins(player, profile, coins)
	local text = if room.index == #Stages then "Every stage cleared. Find the way out." else "Stage " .. room.index .. " cleared"
	Remotes.Notify:FireClient(player, "checkpoint", ("%s   +%d coins"):format(text, coins))
end

local function onShell(room, hit)
	local player, profile = playerFromHit(hit)
	if not player or profile.shells[room.index] or profile.practice then
		return
	end
	profile.shells[room.index] = true
	local coins = Config.Coins.PerShell * Perks.coinMultiplier(player)
	profile.earned += coins
	addCoins(player, profile, coins)
	Remotes.Notify:FireClient(player, "shell", ("Shell found (%d/%d)   +%d coins"):format(shellCount(profile), #Stages, coins))
end

local function onExit(hit)
	local player, profile = playerFromHit(hit)
	if not player or profile.escaped or profile.checkpoint < #Stages then
		return
	end
	profile.escaped = true
	if profile.practice then
		Remotes.Notify:FireClient(player, "win", "Practice run done. Now do it for real: something will be listening." .. finishRun(player, profile))
		return
	end
	profile.wins += 1
	local timeLine = finishRun(player, profile)
	local coins = Config.Coins.PerEscape * Perks.coinMultiplier(player)
	profile.earned += coins
	addCoins(player, profile, coins)
	Leaderboards.recordEscape(player, profile.wins)
	Remotes.Notify:FireClient(
		player,
		"win",
		("You got out. Escapes: %d   Shells: %d/%d   +%d coins%s"):format(profile.wins, shellCount(profile), #Stages, coins, timeLine)
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

-- Sets a player's difficulty: the HUD buttons, the lobby doors and parties.
-- A run in progress counts for the easiest difficulty played along the way.
function Progress.setDifficulty(player, name)
	local profile = profiles[player]
	if not profile or type(name) ~= "string" or not Config.Difficulties[name] or profile.difficulty == name then
		return
	end
	profile.difficulty = name
	if profile.run then
		profile.run.easiest = math.min(profile.run.easiest, Config.Difficulties[name].order)
	end
	sync(player, profile)
end

-- Puts a player in the cave at the start of stage 1, on a new run: the
-- slot-th of a party of count arriving (Parties.luau), or arriving in their
-- party's own server. practice: no creature, and nothing earned or kept; nil
-- for what their party's server is for.
function Progress.enterCave(player, practice, slot, count)
	local profile = profiles[player]
	if not profile then
		return
	end
	if practice == nil then
		practice = profile.partyPractice
	end
	profile.checkpoint = 0
	profile.escaped = false
	profile.run = nil
	profile.inCave = true
	profile.practice = practice
	player:SetAttribute("RunStartedAt", nil)
	sync(player, profile)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		character:PivotTo(caveSpot(slot, count))
	else
		spawnPlayer(player, caveSpot(slot, count))
	end
	player:SetAttribute("CaveArrival", workspace:GetServerTimeNow())
	if practice then
		Remotes.Notify:FireClient(player, "party", "Practice run: nothing is out there tonight. No coins or records.")
	end
end

-- Counts a time the creature caught them (Lurker.luau), and holds their
-- respawn until they choose to revive (back at spot, the last dry ground
-- they stood on) or bleed out.
function Progress.recordCaught(player, spot)
	local profile = profiles[player]
	if profile then
		profile.caught += 1
		profile.downed = { spot = spot, choice = nil }
		sync(player, profile)
	end
end

-- Gets a caught player back up, free (a Self-Revive bought just now). False
-- if they aren't waiting to choose any more, or there is nowhere to put them.
function Progress.reviveBought(player)
	local profile = profiles[player]
	local downed = profile and profile.downed
	if not downed or downed.choice or not downed.spot then
		return false
	end
	downed.choice = "revive"
	return true
end

-- Gives what a Robux product gives (Purchases.luau, RobuxCatalog.luau):
-- coins; boosts, with any past what they can carry as coins instead;
-- Self-Revives, one of them used at once if it has them and they are
-- choosing; and items to keep (a bundle's exclusives). Saves straight away.
-- True once given.
function Progress.grant(player, gives)
	local profile = profiles[player]
	if not profile then
		return false
	end
	local coins = gives.coins or 0
	for id, count in gives.boosts or {} do
		local item = Catalog.byId[id]
		if item and item.kind == "boost" then
			local room = math.max(0, Perks.maxBoosts(player) - profile.boosts[id])
			local added = math.min(room, count)
			profile.boosts[id] += added
			coins += (count - added) * item.price
		end
	end
	for _, id in gives.items or {} do
		local item = Catalog.byId[id]
		if item and item.kind ~= "boost" then
			profile.owned[id] = true
		end
	end
	local revives = gives.selfRevives or 0
	if revives > 0 and Progress.reviveBought(player) then
		revives -= 1
	end
	profile.selfRevives += revives
	profile.coins += coins
	sync(player, profile)
	task.spawn(save, player, profile)
	return true
end

-- Pays the reward for joining the game's community, once ever (Community.luau
-- has checked they are in it). Saves straight away. True if it was paid now.
function Progress.rewardCommunity(player)
	local profile = profiles[player]
	if not profile or profile.communityRewarded then
		return false
	end
	profile.communityRewarded = true
	profile.coins += Config.Community.Reward
	sync(player, profile)
	task.spawn(save, player, profile)
	return true
end

-- For other systems and testing: gives (or with a negative amount, takes) coins.
function Progress.addCoins(player, amount)
	local profile = profiles[player]
	if profile and type(amount) == "number" then
		addCoins(player, profile, math.max(-profile.coins, math.floor(amount)))
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

	Remotes.SetDifficulty.OnServerEvent:Connect(Progress.setDifficulty)

	Remotes.SaveSetting.OnServerEvent:Connect(function(player, id, value)
		local profile = profiles[player]
		local now = os.clock()
		if not profile or type(id) ~= "string" then
			return
		end
		local setting = settingById(id)
		local clean = if setting then settingValue(setting, value) else nil
		local last = lastSetting[player] or {}
		if clean == nil or (last[id] and now - last[id] < SETTING_GAP) then
			return
		end
		last[id] = now
		lastSetting[player] = last
		profile.settings[id] = clean
		player:SetAttribute("Setting_" .. id, clean)
	end)

	Remotes.DeathChoice.OnServerEvent:Connect(function(player, choice)
		local profile = profiles[player]
		local downed = profile and profile.downed
		if not downed or downed.choice then
			return
		end
		if choice == "buying" then
			-- A Robux revive is being bought: more time, once.
			if downed.deadline and not downed.extended then
				downed.extended = true
				downed.deadline += Config.Revive.BuyTime
				player:SetAttribute("DownedUntil", (player:GetAttribute("DownedUntil") or workspace:GetServerTimeNow()) + Config.Revive.BuyTime)
			end
			return
		end
		if choice ~= "revive" and choice ~= "bleed" and choice ~= "lobby" then
			return
		end
		if choice == "revive" then
			-- Nowhere dry to put them back on: there is nothing to pay for.
			if not downed.spot then
				Remotes.Notify:FireClient(player, "downed", "Nowhere to get back up. Bleed out instead.")
				return
			end
			if profile.selfRevives > 0 then
				profile.selfRevives -= 1
				sync(player, profile)
			elseif profile.coins >= Config.Revive.Cost then
				addCoins(player, profile, -Config.Revive.Cost)
			else
				Remotes.Notify:FireClient(player, "downed", ("Not enough coins. Reviving costs %d."):format(Config.Revive.Cost))
				return
			end
		end
		downed.choice = choice
	end)

	Remotes.Restart.OnServerEvent:Connect(function(player)
		local profile = profiles[player]
		local now = os.clock()
		if not profile or (lastRestart[player] and now - lastRestart[player] < RESTART_COOLDOWN) then
			return
		end
		lastRestart[player] = now
		leaveRun(player, profile)
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
		lastSetting[player] = nil
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
