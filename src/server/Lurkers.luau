-- Spawns the lurkers for every room and steps them each frame.
-- Players being chased get the "Hunted" attribute for the HUD.

local Players = game:GetService("Players")

local Lurker = require(script.Parent.Lurker)

local Lurkers = {}

local lurkers = {}

function Lurkers.init(layout)
	local folder = Instance.new("Folder")
	folder.Name = "Lurkers"
	folder.Parent = workspace

	for _, room in layout.rooms do
		local rng = Random.new(room.index * 104729)
		for _ = 1, room.stage.lurkers or 1 do
			table.insert(lurkers, Lurker.new(room, folder, rng))
		end
	end
end

function Lurkers.step(dt)
	local now = os.clock()
	local hunted = {}
	for _, lurker in lurkers do
		lurker:step(dt, now)
		if lurker.huntingPlayer then
			hunted[lurker.huntingPlayer] = true
		end
	end
	for _, player in Players:GetPlayers() do
		local isHunted = hunted[player] == true
		if player:GetAttribute("Hunted") ~= isHunted then
			player:SetAttribute("Hunted", isHunted)
		end
	end
end

return Lurkers
