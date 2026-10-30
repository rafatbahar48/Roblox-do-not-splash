-- The creature: one for the whole forest. While nobody is in the water it
-- keeps watch from out in the fog, far enough away to be barely visible,
-- standing still and moving round only to stay that far from the nearest
-- player. The moment someone is in the water (and it can hear them) it is
-- out in the fog ahead of them, where their camera points
-- (client/CameraReport.luau), and runs straight at them so they see it
-- coming, round them, closing in, and grabs them. When it grabs you it turns
-- you round to face it (client/DeathScene.luau shows the rest). A pebble's
-- splash draws it off to look; then it goes back to watching.
--
-- The server only moves an invisible anchor part at its feet, on the bottom
-- of the water. Each client builds the body and animates it
-- (client/LurkerVisuals.luau) from the anchor and these attributes:
--   Room      index of the stage it is in
--   Alert     true while it is going after something
--   Running   true while it runs
--   Lunging   true while it grabs
--   Warp      goes up by one each time it is moved somewhere new in one go,
--             so clients put its body there instead of sliding it over

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Effects = require(script.Parent.Effects)
local Noise = require(script.Parent.Noise)
local Progress = require(script.Parent.Progress)

local SETTINGS = Config.Lurker
local TRAIL_HALF = Config.Room.Width / 2 -- where the stepping stones are

local Lurker = {}
Lurker.__index = Lurker

local function flatDistance(a, b)
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

local function flat(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

local function speedMultiplier(player)
	local difficulty = Config.Difficulties[player:GetAttribute("Difficulty")] or Config.Difficulties[Config.DefaultDifficulty]
	return difficulty.lurkerSpeedMultiplier
end

local function buildAnchor(parent)
	local anchor = Instance.new("Part")
	anchor.Name = "Lurker"
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	anchor:SetAttribute("Room", 0)
	anchor:SetAttribute("Alert", false)
	anchor:SetAttribute("Running", false)
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

-- area is where it can go: { poolStart, poolEnd, roamHalfWidth, floorY,
-- surfaceY } across all the stages, and roomAt(position) for which stage a
-- point is in (MapBuilder.luau's layout).
function Lurker.new(area, parent, rng)
	local self = setmetatable({}, Lurker)
	self.area = area
	self.rng = rng
	self.anchor = buildAnchor(parent)
	self.position = self:clampToArea(Vector3.new(-area.roamHalfWidth, 0, area.poolStart + 60))
	self.heading = Vector3.new(0, 0, -1)
	self.busy = false
	self.alert = false
	self.running = false
	self.huntingPlayer = nil
	self.circling = nil -- { angle, radius, direction, since, striking, player } while it circles someone
	self.goal = nil -- where it is heading to keep watch from
	self.anchor.CFrame = CFrame.lookAt(self.position, self.position + self.heading)
	return self
end

function Lurker:clampToArea(point)
	local area = self.area
	local margin = SETTINGS.Margin
	return Vector3.new(
		math.clamp(point.X, -area.roamHalfWidth + margin, area.roamHalfWidth - margin),
		area.floorY,
		math.clamp(point.Z, area.poolStart + margin, area.poolEnd - margin)
	)
end

-- The nearest living player in the forest, and how far, or nil.
function Lurker:nearestPlayer()
	local best, bestDistance
	for _, state in Noise.states() do
		if state.room and state.root then
			local distance = flatDistance(self.position, state.root.Position)
			if not best or distance < bestDistance then
				best, bestDistance = state, distance
			end
		end
	end
	return best, bestDistance
end

-- A spot in the fog, in the middle of its watching distance from target,
-- round from where it already is and preferably off the trail.
function Lurker:watchPoint(target)
	local range = SETTINGS.WatchDistance
	local offset = flat(self.position - target)
	local bearing = if offset.Magnitude > 0.1 then math.atan2(offset.Z, offset.X) else self.rng:NextNumber(0, math.pi * 2)
	local point
	for _ = 1, 8 do
		local angle = bearing + self.rng:NextNumber(-0.7, 0.7)
		point = self:clampToArea(target + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (range[1] + range[2]) / 2)
		if math.abs(point.X) > TRAIL_HALF + 4 and flatDistance(point, target) >= range[1] then
			return point
		end
	end
	return point
end

function Lurker:setFlag(name, field, value)
	if self[field] == value then
		return
	end
	self[field] = value
	self.anchor:SetAttribute(name, value)
end

function Lurker:face(direction, dt)
	direction = flat(direction)
	if direction.Magnitude < 0.01 then
		return
	end
	local heading = self.heading:Lerp(direction.Unit, math.min(1, dt * 4))
	self.heading = if heading.Magnitude > 0.01 then heading.Unit else direction.Unit
end

function Lurker:moveToward(goal, speed, dt)
	local target = self:clampToArea(goal)
	local offset = target - self.position
	local distance = offset.Magnitude
	if distance > 0.05 then
		local direction = offset / distance
		self.position += direction * math.min(distance, speed * dt)
		self:face(direction, dt)
	end
	self.anchor.CFrame = CFrame.lookAt(self.position, self.position + self.heading)
	return distance
end

function Lurker:lunge(player, state)
	self.busy = true
	self.circling = nil
	self:setFlag("Running", "running", false)
	local root, humanoid = state.root, state.humanoid
	task.spawn(function()
		local rest = self.anchor.CFrame
		local target = root.Position
		local toward = flat(target - rest.Position)
		toward = if toward.Magnitude > 0.1 then toward.Unit else self.heading
		-- One long stride to just in front of them, reaching down.
		local feet = self:clampToArea(Vector3.new(target.X, 0, target.Z) - toward * 3)
		local strike = CFrame.lookAt(feet, feet + toward)
		if player.Parent then
			local cause, loudness = Noise.causeOf(player)
			Remotes.Caught:FireClient(player, target, cause, loudness, self.anchor)
			Progress.recordCaught(player, Noise.lastDry(player))
		end
		-- It has them: they can't move, and they turn round to face it. The
		-- body stays whole, held where it is, for everyone watching.
		if humanoid.Parent then
			humanoid.BreakJointsOnDeath = false
			root.Anchored = true
			root.CFrame = CFrame.lookAt(root.Position, Vector3.new(feet.X, root.Position.Y, feet.Z))
		end
		self.anchor:SetAttribute("Lunging", true)
		Effects.splash(Vector3.new(target.X, self.area.surfaceY, target.Z), 6)
		Effects.sound("Lunge", target, 1)
		moveAnchor(self.anchor, rest, strike, 0.3)
		self.position, self.heading = feet, toward
		Noise.clear(player)
		-- Long enough for the close-up on its face (client/DeathScene.luau).
		task.wait(1.4)
		if humanoid.Parent and humanoid.Health > 0 then
			humanoid.Health = 0
		end
		task.wait(0.6)
		self.anchor:SetAttribute("Lunging", false)
		self.goal = nil
		self.busy = false
	end)
end

-- Puts it out in the fog ahead of the player, where their camera points
-- (or where they face), so they see it coming. Only from out of sight: if
-- it is already close, it just comes.
function Lurker:appearAhead(state)
	local target = state.root.Position
	if flatDistance(self.position, target) < SETTINGS.WatchDistance[1] - 10 then
		return
	end
	local look = state.look or flat(state.root.CFrame.LookVector)
	look = if look.Magnitude > 0.01 then look.Unit else Vector3.zAxis
	self.position = self:clampToArea(target + look * SETTINGS.AppearDistance)
	local toward = flat(target - self.position)
	self.heading = if toward.Magnitude > 0.01 then toward.Unit else -look
	self.anchor.CFrame = CFrame.lookAt(self.position, self.position + self.heading)
	self.anchor:SetAttribute("Warp", (self.anchor:GetAttribute("Warp") or 0) + 1)
end

-- Runs round the player through the trees, closing in, then comes straight
-- at them. Returns true once it is coming straight in.
function Lurker:circle(state, distance, speed, dt, now)
	local target = state.root.Position
	local c = self.circling
	if not c then
		local offset = flat(self.position - target)
		c = {
			angle = math.atan2(offset.Z, offset.X),
			radius = math.max(distance, SETTINGS.CircleMinRadius),
			direction = if self.rng:NextNumber() < 0.5 then -1 else 1,
			since = now,
		}
		self.circling = c
	end
	local circled = now - c.since
	if not c.striking and ((c.radius <= SETTINGS.CircleMinRadius + 0.5 and circled >= SETTINGS.MinCircleTime) or circled > SETTINGS.MaxCircleTime) then
		c.striking = true
	end
	if c.striking then
		self:moveToward(target, speed * 1.15, dt)
		return true
	end
	c.radius = math.max(SETTINGS.CircleMinRadius, c.radius - SETTINGS.CloseIn * dt)
	c.angle += c.direction * speed * 0.85 / c.radius * dt
	self:moveToward(target + Vector3.new(math.cos(c.angle), 0, math.sin(c.angle)) * c.radius, speed, dt)
	return false
end

-- What it is going after: the loudest player it can hear who is in the
-- water (or the one it is already after, while it can still hear them), or
-- a pebble's splash. Players out of the water don't draw it in.
function Lurker:listen()
	local best, bestScore = nil, SETTINGS.HearingThreshold
	for player, state in Noise.states() do
		local hunted = player == self.huntingPlayer
		if state.room and state.root and (state.inWater or hunted) then
			local score = state.noise - flatDistance(self.position, state.root.Position) * SETTINGS.DistanceFalloff
			if hunted then
				score += SETTINGS.Stickiness
			end
			if score > bestScore then
				best, bestScore = { player = player, state = state }, score
			end
		end
	end
	for _, source in Noise.pointSources() do
		local score = source.loudness - flatDistance(self.position, source.position) * SETTINGS.DistanceFalloff
		if score > bestScore then
			best, bestScore = { source = source }, score
		end
	end
	return best
end

-- Out in the fog, watching the nearest player: stands still while it is
-- the right distance away, and moves round to stay there when they move.
function Lurker:keepWatch(dt)
	local nearest, distance = self:nearestPlayer()
	if not nearest then
		self.goal = nil
		self.anchor.CFrame = CFrame.lookAt(self.position, self.position + self.heading)
		return
	end
	local range = SETTINGS.WatchDistance
	local target = nearest.root.Position
	if self.goal then
		-- Re-plan if they have moved off since it picked the spot.
		local fromGoal = flatDistance(self.goal, target)
		if fromGoal < range[1] or fromGoal > range[2] then
			self.goal = nil
		else
			-- Hurrying when they have got well away, so it never falls behind.
			local speed = if distance > range[2] + 20 then SETTINGS.HuntSpeed else SETTINGS.StalkSpeed
			if self:moveToward(self.goal, speed, dt) < 1 then
				self.goal = nil
			end
			return
		end
	end
	if distance < range[1] or distance > range[2] then
		self.goal = self:watchPoint(target)
		return
	end
	self:face(target - self.position, dt * 0.5)
	self.anchor.CFrame = CFrame.lookAt(self.position, self.position + self.heading)
end

function Lurker:step(dt, now)
	if self.busy then
		return
	end

	local previous = self.huntingPlayer
	local heard = self:listen()
	self.huntingPlayer = nil

	if heard and heard.player then
		local state = heard.state
		if heard.player ~= previous then
			self:appearAhead(state)
		end
		local distance = flatDistance(self.position, state.root.Position)
		if self.circling and self.circling.player ~= heard.player then
			self.circling = nil
		end
		self.huntingPlayer = heard.player
		self.goal = nil
		self:setFlag("Alert", "alert", true)
		self:setFlag("Running", "running", true)
		local speed = SETTINGS.HuntSpeed * speedMultiplier(heard.player)
		local closing = true -- coming straight at them, so it can grab
		if self.circling or distance <= SETTINGS.CircleRadius then
			closing = self:circle(state, distance, speed, dt, now)
			self.circling.player = heard.player
		else
			self:moveToward(state.root.Position, speed, dt)
		end
		if closing and ((state.inWater and distance <= SETTINGS.GrabRange) or (not state.inWater and distance <= SETTINGS.LungeRange and state.noise >= SETTINGS.LungeNoise)) then
			self:lunge(heard.player, state)
			return
		end
	elseif heard and heard.source then
		-- A pebble: over to the splash to look, then back to watching.
		local source = heard.source
		self.circling = nil
		self.goal = nil
		self:setFlag("Alert", "alert", true)
		self:setFlag("Running", "running", false)
		if self:moveToward(source.position, SETTINGS.StalkSpeed * 1.5, dt) < 2 then
			source.loudness = 0
		end
	else
		self.circling = nil
		self:setFlag("Alert", "alert", false)
		self:setFlag("Running", "running", false)
		self:keepWatch(dt)
	end

	-- Which stage it is in, for the lanterns that falter near it (client/Fear.luau).
	local room = self.area.roomAt(self.position)
	local index = if room then room.index else 0
	if index ~= self.roomIndex then
		self.roomIndex = index
		self.anchor:SetAttribute("Room", index)
	end
end

return Lurker
