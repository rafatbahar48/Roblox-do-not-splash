-- The doors on the lobby's building (Config.Doors). Nobody walks through
-- them. Step on a free door's pad and a pop-up asks how big a party, the
-- difficulty, how many monsters and whether it is for friends only
-- (client/PartyUi.luau); the practice door makes practice runs, with no
-- creature. Others join by stepping on
-- the pad; stepping off leaves, and the party ends if the one who made it
-- (the host) leaves. When the countdown runs out, or a few seconds after the
-- party fills, everyone in it goes off together: in the published game to a
-- private server of their own, with the difficulty, monsters and practice sent along
-- (Progress.luau reads them, and starts everyone in the cave); in Studio,
-- which can't teleport, straight into the cave behind the doors here.
--
-- In a party's own server the party is already together, so the doors
-- don't make parties: their pads take you back into the cave.
--
-- The HUD's Play button skips all that: a run of your own, on the difficulty
-- you have set. If nobody else on the server is past the lobby it starts
-- here, at once, with the forest and its one creature to yourself; if
-- somebody is, you go off as a party of one.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Zones = require(ReplicatedStorage.Shared.Zones)
local Perks = require(ReplicatedStorage.Shared.Perks)
local Analytics = require(script.Parent.Analytics)
local Lurkers = require(script.Parent.Lurkers)
local Progress = require(script.Parent.Progress)

local PARTY = Config.Party
local TICK = 0.25
local REQUEST_GAP = 0.3 -- seconds between a player's requests
local PLAY_GAP = 10 -- seconds between presses of Play, while a teleport is on its way

local Parties = {}

local doors -- layout.partyDoors, each with its party's state added
local lastRequest = {} -- [player] = os.clock() of their last request
local lastPlay = {} -- [player] = os.clock() they last pressed Play
local friends = {} -- [owner] = { [player] = true or false }, so each pair is asked once

local inPartyServer = Progress.inPartyServer

local function allowed(player)
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < REQUEST_GAP then
		return false
	end
	lastRequest[player] = now
	return true
end

local function onPad(door, player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return false
	end
	local offset = door.pad.CFrame:PointToObjectSpace(root.Position)
	local half = door.pad.Size / 2
	return math.abs(offset.X) <= half.X and math.abs(offset.Y) <= half.Y and math.abs(offset.Z) <= half.Z
end

-- The door a player is setting up a party on or is in a party at, if any.
local function doorOf(player)
	for _, door in doors do
		if door.setup == player or table.find(door.members, player) then
			return door
		end
	end
	return nil
end

local function isFriend(owner, player)
	friends[owner] = friends[owner] or {}
	if friends[owner][player] == nil then
		local ok, result = pcall(owner.IsFriendsWith, owner, player.UserId)
		friends[owner][player] = ok and result
	end
	return friends[owner][player]
end

local function clear(door)
	door.setup = nil
	door.setupUntil = nil
	door.owner = nil
	door.members = {}
	door.size = nil
	door.difficulty = nil
	door.monsters = nil
	door.friendsOnly = nil
	door.leavesAt = nil
end

local function sendStatus(door)
	for _, member in door.members do
		Remotes.PartyStatus:FireClient(member, {
			count = #door.members,
			size = door.size,
			difficulty = door.difficulty,
			practice = door.mode == "practice",
			leavesAt = door.leavesAt,
			owner = member == door.owner,
		})
	end
end

-- Closes the pop-up and leaves the door free. The player is ignored until
-- they step off the pad, or the pop-up would open again straight away.
local function closeSetup(door)
	local player = door.setup
	door.setup = nil
	door.setupUntil = nil
	if player and player.Parent then
		door.ignored[player] = true
		Remotes.PartySetup:FireClient(player, nil)
	end
end

local function removeMember(door, player)
	local index = table.find(door.members, player)
	if not index then
		return
	end
	table.remove(door.members, index)
	if player.Parent then
		door.ignored[player] = true
		Remotes.PartyStatus:FireClient(player, nil)
	end
	if player ~= door.owner then
		sendStatus(door)
		return
	end
	-- The party goes with the one who made it.
	for _, member in door.members do
		door.ignored[member] = true
		Remotes.PartyStatus:FireClient(member, nil)
		Remotes.Notify:FireClient(member, "party", "The party was called off")
	end
	clear(door)
end

-- Sends players off on a run: to a server of their own, or, with here, into
-- the cave on this one. run says what kind: difficulty, monsters, practice
-- and friendRun (the Rare Pack, Config.FriendPack), all sent along.
local function sendOff(members, run, here)
	if not run.practice then
		for _, member in members do
			Analytics.reached(member, "Set off")
		end
	end

	if not here and not RunService:IsStudio() then
		local ok, problem = pcall(function()
			local options = Instance.new("TeleportOptions")
			options.ReservedServerAccessCode = TeleportService:ReserveServer(game.PlaceId)
			options:SetTeleportData(run)
			TeleportService:TeleportAsync(game.PlaceId, members, options)
		end)
		if ok then
			return
		end
		warn("[Parties] Could not send the party to its own server, starting it here:", problem)
	end

	-- Staying here, in Studio, or the teleport failed: into the cave together.
	Lurkers.setCount(run.monsters)
	for i, member in members do
		if member.Parent then
			Progress.setFriendRun(member, run.friendRun)
			Progress.enterCave(member, run.practice, i, #members)
		end
	end
end

-- How many of a party are friends of its host.
local function hostsFriends(door)
	local count = 0
	for _, member in door.members do
		if member ~= door.owner and isFriend(door.owner, member) then
			count += 1
		end
	end
	return count
end

local function launch(door)
	local members = door.members
	local practice = door.mode == "practice"
	local run = {
		difficulty = door.difficulty,
		monsters = door.monsters,
		practice = practice,
		friendRun = not practice and hostsFriends(door) >= Config.FriendPack.Friends,
	}
	for _, member in members do
		door.ignored[member] = true
		if run.difficulty then
			Progress.setDifficulty(member, run.difficulty)
		end
		Remotes.PartyStatus:FireClient(member, nil)
	end
	clear(door)
	sendOff(members, run)
end

-- Whether nobody on this server is past the lobby.
local function forestFree()
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and Zones.at(root.Position) ~= "lobby" then
			return false
		end
	end
	return true
end

local function quickPlay(player)
	local now = os.clock()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local profile = Progress.getProfile(player)
	if not allowed(player) or (lastPlay[player] and now - lastPlay[player] < PLAY_GAP) then
		return
	end
	if not profile or not root or not humanoid or humanoid.Health <= 0 or Zones.at(root.Position) ~= "lobby" or doorOf(player) then
		return
	end
	lastPlay[player] = now
	if inPartyServer then
		Progress.enterCave(player)
	else
		sendOff({ player }, { difficulty = profile.difficulty, monsters = 1, practice = false }, forestFree())
	end
end

local function updateScreen(door, now)
	if inPartyServer then
		door.status.Text = "Step on the pad to go back in"
	elseif door.owner then
		local seconds = math.max(0, math.ceil(door.leavesAt - now))
		local kind = if door.mode == "party" then "  ·  " .. door.difficulty else ""
		if door.monsters > 1 then
			kind ..= ("  ·  %d monsters"):format(door.monsters)
		end
		door.status.Text = ("%d/%d%s  ·  leaving in %ds"):format(#door.members, door.size, kind, seconds)
	elseif door.setup then
		door.status.Text = door.setup.DisplayName .. " is setting up a party"
	else
		door.status.Text = "Step on the pad to start a party"
	end
end

local function step()
	local now = workspace:GetServerTimeNow()
	for index, door in doors do
		for player in door.ignored do
			if not player.Parent or not onPad(door, player) then
				door.ignored[player] = nil
			end
		end

		if inPartyServer then
			-- Back from the lobby: straight into the cave again.
			for _, player in Players:GetPlayers() do
				if onPad(door, player) and not door.ignored[player] then
					door.ignored[player] = true
					Progress.enterCave(player)
				end
			end
		elseif door.setup then
			local player = door.setup
			if not player.Parent or not onPad(door, player) or os.clock() > door.setupUntil then
				closeSetup(door)
			end
		elseif door.owner then
			for i = #door.members, 1, -1 do
				local member = door.members[i]
				if not member.Parent or not onPad(door, member) then
					removeMember(door, member)
					if not door.owner then
						break
					end
				end
			end
			if door.owner then
				local joined = false
				for _, player in Players:GetPlayers() do
					if #door.members >= door.size then
						break
					end
					if onPad(door, player) and not door.ignored[player] and not doorOf(player) and (not door.friendsOnly or isFriend(door.owner, player)) then
						table.insert(door.members, player)
						joined = true
					end
				end
				if joined then
					if #door.members >= door.size then
						door.leavesAt = math.min(door.leavesAt, now + PARTY.FullCountdown)
					end
					sendStatus(door)
				end
				if now >= door.leavesAt then
					launch(door)
				end
			end
		else
			-- A free door: the first person on its pad gets to set up a party.
			for _, player in Players:GetPlayers() do
				if onPad(door, player) and not door.ignored[player] and not doorOf(player) then
					door.setup = player
					door.setupUntil = os.clock() + PARTY.SetupTimeout
					Remotes.PartySetup:FireClient(player, index, door.mode)
					break
				end
			end
		end
		updateScreen(door, now)
	end
end

function Parties.init(layout)
	doors = layout.partyDoors
	for _, door in doors do
		door.ignored = {}
		clear(door)
	end

	task.spawn(function()
		while true do
			step()
			task.wait(TICK)
		end
	end)
	Remotes.QuickPlay.OnServerEvent:Connect(quickPlay)
	Players.PlayerRemoving:Connect(function(player)
		lastPlay[player] = nil
	end)
	if inPartyServer then
		-- As many monsters as the party chose.
		local function arrived(player)
			local data = player:GetJoinData().TeleportData
			if type(data) == "table" and type(data.monsters) == "number" and data.monsters == data.monsters then
				Lurkers.setCount(data.monsters)
			end
		end
		Players.PlayerAdded:Connect(arrived)
		for _, player in Players:GetPlayers() do
			arrived(player)
		end
		return
	end

	Remotes.CreateParty.OnServerEvent:Connect(function(player, index, size, difficulty, monsters, friendsOnly)
		if not allowed(player) then
			return
		end
		if type(index) ~= "number" or type(size) ~= "number" or size ~= size or type(friendsOnly) ~= "boolean" then
			return
		end
		if type(monsters) ~= "number" or monsters ~= monsters then
			return
		end
		local door = doors[index]
		if not door or door.setup ~= player or not onPad(door, player) then
			return
		end
		-- Practice has no difficulty and nothing out there; otherwise it has
		-- to be one the host has opened.
		if door.mode == "practice" then
			difficulty = nil
			monsters = 1
		elseif type(difficulty) ~= "string" or not Config.Difficulties[difficulty] or not Perks.canPlay(player, difficulty) then
			return
		end
		size = math.clamp(math.floor(size), 1, PARTY.MaxSize)
		door.setup = nil
		door.setupUntil = nil
		door.owner = player
		door.members = { player }
		door.size = size
		door.difficulty = difficulty
		door.monsters = math.clamp(math.floor(monsters), 1, Config.Monsters.Max)
		door.friendsOnly = friendsOnly
		door.leavesAt = workspace:GetServerTimeNow() + (if size == 1 then PARTY.FullCountdown else PARTY.Countdown)
		sendStatus(door)
	end)

	Remotes.LeaveParty.OnServerEvent:Connect(function(player)
		if not allowed(player) then
			return
		end
		local door = doorOf(player)
		if door and door.setup == player then
			closeSetup(door)
		elseif door then
			removeMember(door, player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
		friends[player] = nil
		for _, cache in friends do
			cache[player] = nil
		end
	end)
end

return Parties
