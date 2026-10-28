-- One creature living under the water of one room. It drifts around until it
-- hears something, then swims to the loudest thing it can hear. Players in the
-- water within reach are dragged under; so are loud players on nearby tiles.
--
-- The server only moves an invisible anchor part. Each client builds the body
-- and animates it (client/LurkerVisuals.luau) from the anchor and these
-- attributes:
--   Room      index of the room it lives in
--   Alert     true while it is chasing something
--   Lunging   true while it strikes

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Effects = require(script.Parent.Effects)
local Noise = require(script.Parent.Noise)

local SETTINGS = Config.Lurker

local Lurker = {}
Lurker.__index = Lurker

local function flatDistance(a, b)
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

local function speedMultiplier(player)
	local difficulty = Config.Difficulties[player:GetAttribute("Difficulty")] or Config.Difficulties[Config.DefaultDifficulty]
	return difficulty.lurkerSpeedMultiplier
end

local function buildAnchor(parent, room)
	local anchor = Instance.new("Part")
	anchor.Name = "Lurker"
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	anchor:SetAttribute("Room", room.index)
	anchor:SetAttribute("Alert", false)
	anchor:SetAttribute("Lunging", false)
	anchor.Parent = parent
	return anchor
end

local function moveAnchor(anchor, from, to, duration)
	local start = os.clock()
	while true do
		local alpha = math.min(1, (os.clock() - start) / duration)
		anchor.CFrame = from:Lerp(to, alpha)
		if alpha >= 1 then
			return
		end
		RunService.Heartbeat:Wait()
	end
end

function Lurker.new(room, parent, rng)
	local self = setmetatable({}, Lurker)
	self.room = room
	self.rng = rng
	self.anchor = buildAnchor(parent, room)
	self.position = Vector3.new(0, room.surfaceY - SETTINGS.Depth, 0)
	self.position = self:randomPoint()
	self.heading = Vector3.new(0, 0, -1)
	self.busy = false
	self.alert = false
	self.huntingPlayer = nil
	self.wanderGoal = nil
	self.wanderUntil = 0
	self.searchSpot = nil
	self.searchUntil = 0
	self.anchor.CFrame = CFrame.lookAt(self.position, self.position + self.heading)
	return self
end

function Lurker:randomPoint()
	local room = self.room
	local margin = SETTINGS.Margin
	return Vector3.new(
		self.rng:NextNumber(-room.halfWidth + margin, room.halfWidth - margin),
		self.position.Y,
		self.rng:NextNumber(room.poolStart + margin, room.poolEnd - margin)
	)
end

function Lurker:setAlert(alert)
	if alert == self.alert then
		return
	end
	self.alert = alert
	self.anchor:SetAttribute("Alert", alert)
end

function Lurker:moveToward(goal, speed, dt)
	local room = self.room
	local margin = SETTINGS.Margin
	local target = Vector3.new(
		math.clamp(goal.X, -room.halfWidth + margin, room.halfWidth - margin),
		self.position.Y,
		math.clamp(goal.Z, room.poolStart + margin, room.poolEnd - margin)
	)
	local offset = target - self.position
	local distance = offset.Magnitude
	if distance > 0.05 then
		local direction = offset / distance
		self.position += direction * math.min(distance, speed * dt)
		local heading = self.heading:Lerp(direction, math.min(1, dt * 6))
		self.heading = if heading.Magnitude > 0.01 then heading.Unit else direction
	end
	self.anchor.CFrame = CFrame.lookAt(self.position, self.position + self.heading)
end

function Lurker:lunge(player, state)
	self.busy = true
	local root, humanoid = state.root, state.humanoid
	task.spawn(function()
		local rest = self.anchor.CFrame
		local target = root.Position
		local strike = CFrame.lookAt(target, target + self.heading)
		if player.Parent then
			Remotes.Caught:FireClient(player, target)
		end
		self.anchor:SetAttribute("Lunging", true)
		Effects.splash(Vector3.new(target.X, self.room.surfaceY, target.Z), 6)
		Effects.sound("Lunge", target)
		moveAnchor(self.anchor, rest, strike, 0.22)
		if humanoid.Parent and humanoid.Health > 0 then
			humanoid.Health = 0
		end
		Noise.clear(player)
		-- Hang there for a moment before sinking back.
		task.wait(0.35)
		self.anchor:SetAttribute("Lunging", false)
		moveAnchor(self.anchor, strike, rest, 0.8)
		self.busy = false
	end)
end

-- Finds the loudest thing it can hear in its room, after distance.
function Lurker:listen()
	local best, bestScore = nil, SETTINGS.HearingThreshold
	for player, state in Noise.states() do
		if state.room == self.room and state.root then
			local score = state.noise - flatDistance(self.position, state.root.Position) * SETTINGS.DistanceFalloff
			if player == self.huntingPlayer then
				score += SETTINGS.Stickiness
			end
			if score > bestScore then
				best, bestScore = { player = player, state = state }, score
			end
		end
	end
	for _, source in Noise.pointSources() do
		if source.room == self.room then
			local score = source.loudness - flatDistance(self.position, source.position) * SETTINGS.DistanceFalloff
			if score > bestScore then
				best, bestScore = { source = source }, score
			end
		end
	end
	return best
end

function Lurker:step(dt, now)
	if self.busy then
		return
	end

	local heard = self:listen()
	self.huntingPlayer = nil

	if heard and heard.player then
		local state = heard.state
		local distance = flatDistance(self.position, state.root.Position)
		self.huntingPlayer = heard.player
		self:setAlert(true)
		if (state.inWater and distance <= SETTINGS.GrabRange) or (not state.inWater and distance <= SETTINGS.LungeRange and state.noise >= SETTINGS.LungeNoise) then
			self:lunge(heard.player, state)
			return
		end
		self:moveToward(state.root.Position, SETTINGS.HuntSpeed * speedMultiplier(heard.player), dt)
	elseif heard and heard.source then
		local source = heard.source
		self:setAlert(true)
		if flatDistance(self.position, source.position) < 2 then
			-- Found the spot. Nothing here, so circle it for a bit.
			source.loudness = 0
			self.searchSpot = source.position
			self.searchUntil = now + SETTINGS.SearchTime
			self.wanderGoal = nil
		end
		self:moveToward(source.position, SETTINGS.HuntSpeed, dt)
	else
		self:setAlert(false)
		local searching = now < self.searchUntil
		if not self.wanderGoal or now > self.wanderUntil or flatDistance(self.position, self.wanderGoal) < 1 then
			if searching then
				self.wanderGoal = self.searchSpot + Vector3.new(self.rng:NextNumber(-4, 4), 0, self.rng:NextNumber(-4, 4))
			else
				self.wanderGoal = self:randomPoint()
			end
			self.wanderUntil = now + 10
		end
		self:moveToward(self.wanderGoal, SETTINGS.IdleSpeed, dt)
	end
end

return Lurker
