-- Creaky tiles, sinking tiles, drifting rafts and flickering lights.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Effects = require(script.Parent.Effects)
local Noise = require(script.Parent.Noise)

local Hazards = {}

local rafts = {}

local function playerFromHit(hit)
	local character = hit:FindFirstAncestorOfClass("Model")
	local player = character and Players:GetPlayerFromCharacter(character)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if player and humanoid and humanoid.Health > 0 then
		return player
	end
	return nil
end

local function setupCreaky(tile)
	local lastCreak = {} -- [Player] = time
	local baseColor = tile.Color
	tile.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		if not player then
			return
		end
		local now = os.clock()
		if lastCreak[player] and now - lastCreak[player] < 1 then
			return
		end
		lastCreak[player] = now
		Noise.add(player, Config.Noise.CreakyTile, "creak")
		Effects.sound("Creak", tile.Position)
		tile.Color = baseColor:Lerp(Color3.new(0, 0, 0), 0.15)
		task.delay(0.25, function()
			tile.Color = baseColor
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastCreak[player] = nil
	end)
end

local function setupSinking(tile)
	local rest = tile.CFrame
	local busy = false
	local shake = Random.new()
	tile.Touched:Connect(function(hit)
		if busy or not playerFromHit(hit) then
			return
		end
		busy = true

		local shakeUntil = os.clock() + tile:GetAttribute("SinkDelay")
		while os.clock() < shakeUntil do
			tile.CFrame = rest * CFrame.new(shake:NextNumber(-0.08, 0.08), 0, shake:NextNumber(-0.08, 0.08))
			task.wait(0.05)
		end
		tile.CFrame = rest

		local down = TweenService:Create(tile, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			CFrame = rest - Vector3.new(0, Config.SinkingTile.Drop, 0),
		})
		down:Play()
		down.Completed:Wait()
		tile.CanCollide = false
		task.wait(Config.SinkingTile.ResetTime)

		local up = TweenService:Create(tile, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = rest })
		up:Play()
		up.Completed:Wait()
		tile.CanCollide = true
		busy = false
	end)
end

local function setupFlicker(lights)
	local rng = Random.new()
	task.spawn(function()
		while true do
			task.wait(rng:NextNumber(3, 8))
			for _ = 1, rng:NextInteger(2, 5) do
				for _, panel in lights do
					panel.Material = Enum.Material.SmoothPlastic
					panel.PointLight.Enabled = false
				end
				task.wait(rng:NextNumber(0.05, 0.3))
				for _, panel in lights do
					panel.Material = Enum.Material.Neon
					panel.PointLight.Enabled = true
				end
				task.wait(rng:NextNumber(0.05, 0.2))
			end
		end
	end)
end

local function stepRafts()
	local now = os.clock()
	for _, raft in rafts do
		local offset = math.sin(now * math.pi * 2 / raft.period + raft.phase) * raft.range
		raft.align.Position = Vector3.new(raft.baseX + offset, raft.y, raft.z)
	end
end

function Hazards.init(layout)
	for _, room in layout.rooms do
		for _, tile in room.tiles do
			local kind = tile:GetAttribute("TileKind")
			if kind == "creaky" then
				setupCreaky(tile)
			elseif kind == "sinking" then
				setupSinking(tile)
			elseif kind == "raft" then
				-- The server simulates rafts so everyone sees them in the same place.
				tile:SetNetworkOwner(nil)
				table.insert(rafts, {
					align = tile.AlignPosition,
					baseX = tile:GetAttribute("BaseX"),
					range = tile:GetAttribute("Range"),
					period = tile:GetAttribute("Period"),
					phase = tile:GetAttribute("Phase"),
					y = tile.Position.Y,
					z = tile.Position.Z,
				})
			end
		end
		if room.stage.flicker then
			setupFlicker(room.lights)
		end
	end
	RunService.Heartbeat:Connect(stepRafts)
end

return Hazards
