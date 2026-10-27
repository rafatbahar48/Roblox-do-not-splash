-- Tracks how much noise each player is making, and short-lived noises at
-- points in the world (pebbles). The lurkers listen to both.
--
-- Each player's noise is published as the "Noise" attribute for the HUD.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Effects = require(script.Parent.Effects)

local SETTINGS = Config.Noise

local Noise = {}

local layout
local states = {} -- [Player] = { noise, inWater, lastVelocityY, room, root, humanoid, reported }
local pointSources = {} -- { position, loudness, room }

local function noiseMultiplier(player)
	local difficulty = Config.Difficulties[player:GetAttribute("Difficulty")] or Config.Difficulties[Config.DefaultDifficulty]
	return difficulty.noiseMultiplier
end

function Noise.init(newLayout)
	layout = newLayout

	local function track(player)
		states[player] = { noise = 0, inWater = false, lastVelocityY = 0, reported = -1 }
	end
	for _, player in Players:GetPlayers() do
		track(player)
	end
	Players.PlayerAdded:Connect(track)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
end

function Noise.states()
	return states
end

function Noise.pointSources()
	return pointSources
end

-- Adds noise to a player, scaled by their difficulty.
function Noise.add(player, amount)
	local state = states[player]
	if state then
		state.noise = math.min(SETTINGS.Max, state.noise + amount * noiseMultiplier(player))
	end
end

function Noise.clear(player)
	local state = states[player]
	if state then
		state.noise = 0
	end
end

-- A noise at a point, such as a pebble landing.
function Noise.emitAt(position, loudness)
	local room = layout.roomAt(position)
	if room then
		table.insert(pointSources, { position = position, loudness = loudness, room = room })
	end
end

local function setWalkSpeed(humanoid, speed)
	if humanoid.WalkSpeed ~= speed then
		humanoid.WalkSpeed = speed
	end
end

function Noise.step(dt)
	for player, state in states do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")

		if not root or not humanoid or humanoid.Health <= 0 then
			state.noise = 0
			state.inWater = false
			state.room = nil
			state.root = nil
			state.humanoid = nil
		else
			local position = root.Position
			local room = layout.roomAt(position)
			local inWater = room ~= nil and layout.inPool(room, position) and position.Y < room.surfaceY + 1.5

			if inWater and not state.inWater then
				Noise.add(player, SETTINGS.Splash)
				Effects.splash(Vector3.new(position.X, room.surfaceY, position.Z), 8)
			end
			setWalkSpeed(humanoid, if inWater then Config.Wading.WalkSpeed else Config.WalkSpeed)

			if inWater then
				Noise.add(player, SETTINGS.WadingPerSecond * dt)
			else
				-- A hard landing: falling fast last frame, stopped this frame.
				local velocityY = root.AssemblyLinearVelocity.Y
				if state.lastVelocityY < -SETTINGS.HardLandingSpeed and velocityY > -5 then
					local extra = (-state.lastVelocityY - SETTINGS.HardLandingSpeed) * SETTINGS.HardLandingPerStud
					Noise.add(player, math.min(extra, SETTINGS.HardLandingMax))
				end
			end

			state.lastVelocityY = root.AssemblyLinearVelocity.Y
			state.inWater = inWater
			state.room = room
			state.root = root
			state.humanoid = humanoid
			state.noise = math.max(0, state.noise - SETTINGS.DecayPerSecond * dt)
		end

		local rounded = math.floor(state.noise + 0.5)
		if rounded ~= state.reported then
			state.reported = rounded
			player:SetAttribute("Noise", rounded)
		end
	end

	for i = #pointSources, 1, -1 do
		local source = pointSources[i]
		source.loudness -= SETTINGS.PointDecayPerSecond * dt
		if source.loudness <= 0 then
			table.remove(pointSources, i)
		end
	end
end

return Noise
