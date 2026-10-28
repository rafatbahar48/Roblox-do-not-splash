-- Tracks how much noise each player is making, and short-lived noises at
-- points in the world (pebbles). The lurkers listen to both.
--
-- Each player's noise is published as the "Noise" attribute for the HUD, and
-- "Hushed" is true while a Hush boost keeps them silent.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Effects = require(script.Parent.Effects)

local SETTINGS = Config.Noise
local CAUSE_MEMORY = 3 -- seconds a loud noise stays "what gave you away"

local Noise = {}

local layout
local states = {} -- [Player] = { noise, inWater, lastVelocityY, room, root, humanoid, reported, hushedUntil, hushed, cause, causeAmount, causeAt }
local pointSources = {} -- { position, loudness, room }

local function noiseMultiplier(player)
	local difficulty = Config.Difficulties[player:GetAttribute("Difficulty")] or Config.Difficulties[Config.DefaultDifficulty]
	return difficulty.noiseMultiplier
end

function Noise.init(newLayout)
	layout = newLayout

	local function track(player)
		states[player] = {
			noise = 0,
			inWater = false,
			lastVelocityY = 0,
			reported = -1,
			hushedUntil = 0,
			hushed = false,
			cause = nil,
			causeAmount = 0,
			causeAt = -math.huge,
		}
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

-- Adds noise to a player, scaled by their difficulty. Nothing while hushed.
-- cause ("splash", "wading", "landing" or "creak") is remembered so a caught
-- player can be told what gave them away: the loudest noise of the last few
-- seconds, or after a quiet spell, whatever came next.
function Noise.add(player, amount, cause)
	local state = states[player]
	if state and os.clock() >= state.hushedUntil then
		local added = amount * noiseMultiplier(player)
		state.noise = math.min(SETTINGS.Max, state.noise + added)
		local now = os.clock()
		if cause and (now - state.causeAt > CAUSE_MEMORY or added >= state.causeAmount) then
			state.cause, state.causeAmount, state.causeAt = cause, added, now
		end
	end
end

-- What most recently gave a player away, and how loud they are right now.
function Noise.causeOf(player)
	local state = states[player]
	if not state then
		return nil, 0
	end
	return state.cause, math.floor(state.noise + 0.5)
end

function Noise.clear(player)
	local state = states[player]
	if state then
		state.noise = 0
	end
end

-- Silences a player completely for a while (the Hush boost).
function Noise.hush(player, duration)
	local state = states[player]
	if state then
		state.noise = 0
		state.hushedUntil = math.max(state.hushedUntil, os.clock() + duration)
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
				Noise.add(player, SETTINGS.Splash, "splash")
				Effects.splash(Vector3.new(position.X, room.surfaceY, position.Z), 8)
			end
			setWalkSpeed(humanoid, if inWater then Config.Wading.WalkSpeed else Config.WalkSpeed)

			if inWater then
				Noise.add(player, SETTINGS.WadingPerSecond * dt, "wading")
			else
				-- A hard landing: falling fast last frame, stopped this frame.
				local velocityY = root.AssemblyLinearVelocity.Y
				if state.lastVelocityY < -SETTINGS.HardLandingSpeed and velocityY > -5 then
					local extra = (-state.lastVelocityY - SETTINGS.HardLandingSpeed) * SETTINGS.HardLandingPerStud
					Noise.add(player, math.min(extra, SETTINGS.HardLandingMax), "landing")
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
		local hushed = os.clock() < state.hushedUntil
		if hushed ~= state.hushed then
			state.hushed = hushed
			player:SetAttribute("Hushed", hushed)
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
