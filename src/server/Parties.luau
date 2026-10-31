-- The doors on the lobby's building (Config.Doors). Nobody walks through
-- them. Step on a free door's pad and a pop-up asks how big a party and
-- whether it is for friends only, and at the middle three, Normal or Hard
-- (client/PartyUi.luau): the door on the left makes Easy parties, the one
-- on the right practice runs, with no creature. Others join by stepping on
-- the pad; stepping off leaves, and the party ends if the one who made it
-- (the host) leaves. When the countdown runs out, or a few seconds after the
-- party fills, everyone in it goes off together: in the published game to a
-- private server of their own, with the difficulty and practice sent along
-- (Progress.luau reads them, and starts everyone in the cave); in Studio,
-- which can't teleport, straight into the cave behind the doors here.
--
-- In a party's own server the party is already together, so the doors
-- don't make parties: their pads take you back into the cave.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Progress = require(script.Parent.Progress)

local PARTY = Config.Party
local TICK = 0.25
local REQUEST_GAP = 0.3 -- seconds between a player's requests

local Parties = {}

-- Which difficulties a party door's host picks from, by its mode. A
-- practice run has no difficulty.
local CHOICES = {
	easy = { "Easy" },
	party = { "Normal", "Hard" },
	practice = {},
}

local doors -- layout.partyDoors, each with its party's state added
local lastRequest = {} -- [player] = os.clock() of their last request
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

local function launch(door)
	local members = door.members
	local difficulty = door.difficulty
	local practice = door.mode == "practice"
	for _, member in members do
		door.ignored[member] = true
		if difficulty then
			Progress.setDifficulty(member, difficulty)
		end
		Remotes.PartyStatus:FireClient(member, nil)
	end
	clear(door)

	if not RunService:IsStudio() then
		local ok, problem = pcall(function()
			local options = Instance.new("TeleportOptions")
			options.ReservedServerAccessCode = TeleportService:ReserveServer(game.PlaceId)
			options:SetTeleportData({ difficulty = difficulty, practice = practice })
			TeleportService:TeleportAsync(game.PlaceId, members, options)
		end)
		if ok then
			return
		end
		warn("[Parties] Could not send the party to its own server, starting it here:", problem)
	end

	-- Studio, or the teleport failed: into the cave together.
	for i, member in members do
		if member.Parent then
			Progress.enterCave(member, practice, i, #members)
		end
	end
end

local function updateScreen(door, now)
	if inPartyServer then
		door.status.Text = "Step on the pad to go back in"
	elseif door.owner then
		local seconds = math.max(0, math.ceil(door.leavesAt - now))
		local kind = if door.mode == "party" then "  ·  " .. door.difficulty else ""
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
	if inPartyServer then
		return
	end

	Remotes.CreateParty.OnServerEvent:Connect(function(player, index, size, difficulty, friendsOnly)
		if not allowed(player) then
			return
		end
		if type(index) ~= "number" or type(size) ~= "number" or size ~= size or type(friendsOnly) ~= "boolean" then
			return
		end
		local door = doors[index]
		if not door or door.setup ~= player or not onPad(door, player) then
			return
		end
		-- The door decides what can be picked: Easy at the Easy door, nothing
		-- for practice.
		local choices = CHOICES[door.mode]
		if #choices == 0 then
			difficulty = nil
		elseif #choices == 1 then
			difficulty = choices[1]
		elseif type(difficulty) ~= "string" or not table.find(choices, difficulty) then
			return
		end
		size = math.clamp(math.floor(size), 1, PARTY.MaxSize)
		door.setup = nil
		door.setupUntil = nil
		door.owner = player
		door.members = { player }
		door.size = size
		door.difficulty = difficulty
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
