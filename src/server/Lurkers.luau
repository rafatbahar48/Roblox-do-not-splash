-- Spawns the creatures (one for the whole forest, or as many as the party
-- chose, Config.Monsters) and steps them each frame. Workspace's Monsters
-- attribute says how many are out there. Players being chased get the
-- "Hunted" attribute for the HUD.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Lurker = require(script.Parent.Lurker)

local Lurkers = {}

local lurkers = {}
local area
local folder

-- Makes it this many creatures, adding or taking away.
function Lurkers.setCount(count)
	count = math.clamp(math.floor(count), 1, Config.Monsters.Max)
	while #lurkers < count do
		table.insert(lurkers, Lurker.new(area, folder, Random.new(104729 + #lurkers), #lurkers + 1))
	end
	while #lurkers > count do
		table.remove(lurkers).anchor:Destroy()
	end
	workspace:SetAttribute("Monsters", count)
end

function Lurkers.init(layout)
	folder = Instance.new("Folder")
	folder.Name = "Lurkers"
	folder.Parent = workspace

	-- Where it can go: the water of every stage, end to end, as wide as the
	-- widest (a swamp stage's).
	local first, last = layout.rooms[1], layout.rooms[#layout.rooms]
	local roamHalfWidth = 0
	for _, room in layout.rooms do
		roamHalfWidth = math.max(roamHalfWidth, room.roamHalfWidth)
	end
	area = {
		poolStart = first.poolStart,
		poolEnd = last.poolEnd,
		roamHalfWidth = roamHalfWidth,
		floorY = first.floorY,
		surfaceY = first.surfaceY,
		roomAt = layout.roomAt,
	}
	Lurkers.setCount(1)
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
