-- The game's Roblox community (Config.Community): being in it pays a coin
-- reward, once per player. The HUD's Join button shows Roblox's join prompt
-- and then asks here (ClaimCommunity); players who joined on the website get
-- it when they next play. Membership is always checked with Roblox, never
-- taken from the client, and Progress.rewardCommunity pays only once.

local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Progress = require(script.Parent.Progress)

local CLAIM_GAP = 5 -- seconds between a player's ClaimCommunity requests
local LOAD_WAIT = 60 -- seconds to wait for a joining player's save to load

local Community = {}

local lastClaim = {} -- [Player] = os.clock()

-- Whether they are in the community now. Asks Roblox each time, since
-- Player:IsInGroup keeps its first answer for the whole server and would
-- miss someone joining mid-game.
local function isMember(player)
	local ok, groups = pcall(GroupService.GetGroupsAsync, GroupService, player.UserId)
	if not ok then
		warn("[Community] Could not check", player.Name, groups)
		return false
	end
	for _, group in groups do
		if group.Id == Config.Community.GroupId then
			return true
		end
	end
	return false
end

local function check(player)
	if not Progress.getProfile(player) or player:GetAttribute("CommunityRewarded") then
		return
	end
	if isMember(player) and player.Parent and Progress.rewardCommunity(player) then
		Remotes.Notify:FireClient(player, "reward", ("Thanks for joining the community!   +%d coins"):format(Config.Community.Reward))
	end
end

-- On joining the game: anyone already in the community (joined on the
-- website) gets the reward once their save has loaded.
local function onPlayerAdded(player)
	local deadline = os.clock() + LOAD_WAIT
	while player.Parent and not Progress.getProfile(player) and os.clock() < deadline do
		task.wait(1)
	end
	check(player)
end

function Community.init()
	if Config.Community.GroupId == 0 then
		return
	end
	Remotes.ClaimCommunity.OnServerEvent:Connect(function(player)
		local now = os.clock()
		if lastClaim[player] and now - lastClaim[player] < CLAIM_GAP then
			return
		end
		lastClaim[player] = now
		check(player)
	end)
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastClaim[player] = nil
	end)
end

return Community
