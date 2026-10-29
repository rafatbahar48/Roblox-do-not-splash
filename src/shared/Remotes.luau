-- The server creates the RemoteEvents; clients wait for them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	"SetDifficulty", -- client -> server: difficulty name
	"ThrowPebble", -- client -> server: Vector3 aim point
	"Restart", -- client -> server: go back to stage 1
	"Notify", -- server -> client: kind, text
	"BuyItem", -- client -> server: item id
	"EquipItem", -- client -> server: slot ("skin" or "accessory"), item id or nil to take it off
	"UseBoost", -- client -> server: boost id
	"BoostStarted", -- server -> client: boost id, duration
	"Caught", -- server -> client: where it struck, what it heard ("splash", ...), how loud you were
	"PartySetup", -- server -> client: party door number to set up a party on, or nil to close the pop-up
	"CreateParty", -- client -> server: party door number, size, difficulty name, friends only
	"LeaveParty", -- client -> server: leave your party, or cancel setting one up
	"PartyStatus", -- server -> client: { count, size, difficulty, leavesAt, owner } for your party, or nil
}

local folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
	end
	for _, name in NAMES do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

local Remotes = {}
for _, name in NAMES do
	Remotes[name] = folder:WaitForChild(name)
end

return Remotes
