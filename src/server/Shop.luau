-- Buying, wearing and using shop items. Prices, ownership and counts live in
-- the player's profile on the server (Progress.luau). The client only asks;
-- every request is checked here before anything changes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config)
local Perks = require(ReplicatedStorage.Shared.Perks)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Cosmetics = require(script.Parent.Cosmetics)
local Noise = require(script.Parent.Noise)
local Progress = require(script.Parent.Progress)

local REQUEST_COOLDOWN = 0.2 -- seconds between shop requests from one player

local Shop = {}

local lastRequest = {} -- [Player] = time
local boostReady = {} -- [Player] = { [boost id] = time it can next be used }

local function allowRequest(player)
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < REQUEST_COOLDOWN then
		return false
	end
	lastRequest[player] = now
	return true
end

-- kind is "bought" for a purchase (the client plays a till sound), else "shop".
local function tell(player, text, kind)
	Remotes.Notify:FireClient(player, kind or "shop", text)
end

local function isAlive(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0 and character:FindFirstChild("HumanoidRootPart") ~= nil
end

-- Buys one of an item: a skin or accessory to keep, or a boost to carry.
function Shop.buy(player, itemId)
	local profile = Progress.getProfile(player)
	local item = type(itemId) == "string" and Catalog.byId[itemId]
	if not profile or not item then
		return false
	end
	if item.kind == "boost" then
		if profile.boosts[item.id] >= Perks.maxBoosts(player) then
			tell(player, ("You can't carry more than %d."):format(Perks.maxBoosts(player)))
			return false
		end
	elseif profile.owned[item.id] then
		return false
	end
	if profile.coins < item.price then
		tell(player, ("Not enough coins. %s costs %d."):format(item.name, item.price))
		return false
	end

	profile.coins -= item.price
	if item.kind == "boost" then
		profile.boosts[item.id] += 1
	else
		profile.owned[item.id] = true
	end
	Progress.sync(player)
	tell(player, "Bought " .. item.name, "bought")
	return true
end

-- Wears an owned item in a slot, or takes the slot off when itemId is nil.
function Shop.equip(player, slot, itemId)
	local profile = Progress.getProfile(player)
	local kind = type(slot) == "string" and Catalog.slots[slot]
	if not profile or not kind then
		return false
	end
	if itemId ~= nil then
		local item = type(itemId) == "string" and Catalog.byId[itemId]
		if not item or item.kind ~= kind or not profile.owned[item.id] then
			return false
		end
	end

	profile.equipped[slot] = itemId
	Progress.sync(player)
	local character = player.Character
	if character then
		task.spawn(Cosmetics.apply, player, character, profile.equipped)
	end
	return true
end

-- Spends one boost. Hush is handled here; the client flies for Updraft.
function Shop.useBoost(player, boostId)
	local profile = Progress.getProfile(player)
	local item = type(boostId) == "string" and Catalog.byId[boostId]
	local settings = item and item.kind == "boost" and Config.Boosts[item.id]
	if not profile or not settings or profile.boosts[item.id] <= 0 or not isAlive(player) then
		return false
	end
	local ready = boostReady[player] or {}
	boostReady[player] = ready
	local now = os.clock()
	if now < (ready[item.id] or 0) then
		return false
	end
	ready[item.id] = now + settings.duration + settings.cooldown

	profile.boosts[item.id] -= 1
	Progress.sync(player)
	if item.id == "hush" then
		Noise.hush(player, settings.duration)
	end
	Remotes.BoostStarted:FireClient(player, item.id, settings.duration)
	return true
end

function Shop.init()
	Remotes.BuyItem.OnServerEvent:Connect(function(player, itemId)
		if allowRequest(player) then
			Shop.buy(player, itemId)
		end
	end)
	Remotes.EquipItem.OnServerEvent:Connect(function(player, slot, itemId)
		if allowRequest(player) then
			Shop.equip(player, slot, itemId)
		end
	end)
	Remotes.UseBoost.OnServerEvent:Connect(function(player, boostId)
		if allowRequest(player) then
			Shop.useBoost(player, boostId)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
		boostReady[player] = nil
	end)
end

return Shop
