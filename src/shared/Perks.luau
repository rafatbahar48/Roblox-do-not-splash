-- What a player's Game Passes change (Config.Passes, Config.PassPerks), and
-- what else decides their coins and the difficulties open to them. The
-- server marks the passes each player owns as Pass_<id> attributes
-- (server/Purchases.luau) and their escapes on each difficulty as
-- Escapes_<difficulty> (server/Progress.luau); the server and the client both
-- read them here.

local Config = require(script.Parent.Config)

local Perks = {}

function Perks.owns(player, passId)
	return player:GetAttribute("Pass_" .. passId) == true
end

-- What coins from a stage, shell or escape come to: more with the pass, and
-- with more monsters out there (the Monsters attribute on Workspace,
-- server/Lurkers.luau).
function Perks.coins(player, amount)
	local pass = if Perks.owns(player, "DoubleCoins") then Config.PassPerks.DoubleCoins.multiplier else 1
	return math.floor(amount * pass * Config.Monsters.Coins[workspace:GetAttribute("Monsters") or 1])
end

-- How many more escapes on what a difficulty needs, or 0 once it is open.
function Perks.escapesToOpen(player, name)
	local needs = Config.Difficulties[name].needs
	return if needs then math.max(0, needs.escapes - (player:GetAttribute("Escapes_" .. needs.on) or 0)) else 0
end

function Perks.canPlay(player, name)
	return Perks.escapesToOpen(player, name) == 0
end

function Perks.pebblesPerLife(player)
	return if Perks.owns(player, "DeepPockets") then Config.PassPerks.DeepPockets.pebbles else Config.Pebbles.PerLife
end

-- How many of each boost a player may carry.
function Perks.maxBoosts(player)
	return if Perks.owns(player, "DeepPockets") then Config.PassPerks.DeepPockets.maxBoosts else Config.Boosts.MaxCarried
end

return Perks
