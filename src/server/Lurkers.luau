-- Spawns the creature (one, for the whole forest) and steps it each frame.
-- Players being chased get the "Hunted" attribute for the HUD.

local Players = game:GetService("Players")

local Lurker = require(script.Parent.Lurker)

local Lurkers = {}

local lurkers = {}

function Lurkers.init(layout)
	local folder = Instance.new("Folder")
	folder.Name = "Lurkers"
	folder.Parent = workspace

	-- Where it can go: the water of every stage, end to end.
	local first, last = layout.rooms[1], layout.rooms[#layout.rooms]
	local area = {
		poolStart = first.poolStart,
		poolEnd = last.poolEnd,
		roamHalfWidth = first.roamHalfWidth,
		floorY = first.floorY,
		surfaceY = first.surfaceY,
		roomAt = layout.roomAt,
	}
	table.insert(lurkers, Lurker.new(area, folder, Random.new(104729)))
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
