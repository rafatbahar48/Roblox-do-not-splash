-- What a player's Game Passes change (Config.Passes, Config.PassPerks). The
-- server marks the passes each player owns as Pass_<id> attributes
-- (server/Purchases.luau); the server and the client both read them here.

local Config = require(script.Parent.Config)

local Perks = {}

function Perks.owns(player, passId)
	return player:GetAttribute("Pass_" .. passId) == true
end

-- How many times over coins from stages, shells and escapes count.
function Perks.coinMultiplier(player)
	return if Perks.owns(player, "DoubleCoins") then Config.PassPerks.DoubleCoins.multiplier else 1
end

function Perks.pebblesPerLife(player)
	return if Perks.owns(player, "DeepPockets") then Config.PassPerks.DeepPockets.pebbles else Config.Pebbles.PerLife
end

-- How many of each boost a player may carry.
function Perks.maxBoosts(player)
	return if Perks.owns(player, "DeepPockets") then Config.PassPerks.DeepPockets.maxBoosts else Config.Boosts.MaxCarried
end

return Perks
