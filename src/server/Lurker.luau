-- One creature living under the water of one room. It drifts around until it
-- hears something, then swims to the loudest thing it can hear. Players in the
-- water within reach are dragged under; so are loud players on nearby tiles.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Effects = require(script.Parent.Effects)
local Noise = require(script.Parent.Noise)

local SETTINGS = Config.Lurker
local DARK = Color3.fromRGB(12, 16, 18)
local EYE_IDLE = Color3.fromRGB(90, 24, 24)
local EYE_ALERT = Color3.fromRGB(255, 40, 40)

local Lurker = {}
Lurker.__index = Lurker

local function flatDistance(a, b)
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

local function speedMultiplier(player)
	local difficulty = Config.Difficulties[player:GetAttribute("Difficulty")] or Config.Difficulties[Config.DefaultDifficulty]
	return difficulty.lurkerSpeedMultiplier
end

local function addPart(model, name, size, offset, color, material, shape)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = offset
	part.Color = color
	part.Material = material
	if shape then
		part.Shape = shape
	end
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = model
	return part
end

-- Built facing -Z around the origin; PivotTo moves it into place.
local function buildModel(parent)
	local model = Instance.new("Model")
	model.Name = "Lurker"

	local body = addPart(model, "Body", Vector3.new(2.6, 1.4, 7), CFrame.new(), DARK, Enum.Material.SmoothPlastic)
	addPart(model, "Head", Vector3.new(2.2, 1.6, 2.4), CFrame.new(0, 0.3, -4.4), DARK, Enum.Material.SmoothPlastic)
	addPart(model, "Tail", Vector3.new(1.2, 0.6, 4), CFrame.new(0, 0, 5.4), DARK, Enum.Material.SmoothPlastic)
	local eyes = {
		addPart(model, "LeftEye", Vector3.new(0.45, 0.45, 0.45), CFrame.new(-0.55, 1.2, -5.1), EYE_IDLE, Enum.Material.Neon, Enum.PartType.Ball),
		addPart(model, "RightEye", Vector3.new(0.45, 0.45, 0.45), CFrame.new(0.55, 1.2, -5.1), EYE_IDLE, Enum.Material.Neon, Enum.PartType.Ball),
	}
	local glow = Instance.new("PointLight")
	glow.Color = EYE_ALERT
	glow.Range = 8
	glow.Brightness = 0
	glow.Parent = eyes[1]

	model.PrimaryPart = body
	model.Parent = parent
	return model, eyes, glow
end

local function movePivot(model, from, to, duration)
	local start = os.clock()
	while true do
		local alpha = math.min(1, (os.clock() - start) / duration)
		model:PivotTo(from:Lerp(to, alpha))
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
	self.model, self.eyes, self.glow = buildModel(parent)
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
	self.model:PivotTo(CFrame.lookAt(self.position, self.position + self.heading))
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
	for _, eye in self.eyes do
		eye.Color = if alert then EYE_ALERT else EYE_IDLE
	end
	self.glow.Brightness = if alert then 3 else 0
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
	self.model:PivotTo(CFrame.lookAt(self.position, self.position + self.heading))
end

function Lurker:lunge(player, state)
	self.busy = true
	local root, humanoid = state.root, state.humanoid
	task.spawn(function()
		local rest = self.model:GetPivot()
		local strike = CFrame.lookAt(root.Position, root.Position + self.heading)
		Effects.splash(Vector3.new(root.Position.X, self.room.surfaceY, root.Position.Z), 6)
		Effects.sound("Lunge", root.Position)
		movePivot(self.model, rest, strike, 0.18)
		if humanoid.Parent and humanoid.Health > 0 then
			humanoid.Health = 0
		end
		Noise.clear(player)
		movePivot(self.model, strike, rest, 0.6)
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
