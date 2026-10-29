-- The three doors into stage 1. Stepping on a door's pad picks its difficulty
-- (the same as the HUD buttons), and its screen says how many people are in
-- the water on that difficulty right now.

local Players = game:GetService("Players")

local Progress = require(script.Parent.Progress)

local REFRESH_INTERVAL = 1

local LobbyDoors = {}

local function playerFromHit(hit)
	local character = hit:FindFirstAncestorOfClass("Model")
	local player = character and Players:GetPlayerFromCharacter(character)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if player and humanoid and humanoid.Health > 0 then
		return player
	end
	return nil
end

-- How many players are on a run on that difficulty.
local function inTheWater(difficulty)
	local count = 0
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("RunStartedAt") and player:GetAttribute("Difficulty") == difficulty then
			count += 1
		end
	end
	return count
end

function LobbyDoors.init(layout)
	for _, door in layout.doors do
		door.pad.Touched:Connect(function(hit)
			local player = playerFromHit(hit)
			if player then
				Progress.setDifficulty(player, door.difficulty)
			end
		end)
	end

	task.spawn(function()
		while true do
			for _, door in layout.doors do
				local count = inTheWater(door.difficulty)
				door.status.Text = if count == 0 then "Nobody in the water" elseif count == 1 then "1 swimmer inside" else count .. " swimmers inside"
			end
			task.wait(REFRESH_INTERVAL)
		end
	end)
end

return LobbyDoors
