-- The creature in the lobby aquarium. It swims slow loops around its tank;
-- when someone stands close to the glass it darts over, eyes burning, and
-- stares at them for a moment. It can't get out.
--
-- It is drawn by client/LurkerVisuals.luau like the others: this only moves
-- an anchor in workspace.Lurkers and sets its Alert attribute. It has no
-- Room attribute, so no stage lights react to it.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LOOP_SPEED = 0.35 -- how fast its loop goes round (radians per second)
local SWIM_SPEED = 7
local DART_SPEED = 14
local STARE_RANGE = 7 -- studs in front of the glass that count as close
local STARE_TIME = 3.5 -- seconds from noticing you to swimming off again
local STARE_COOLDOWN = 8
local LOOK_INTERVAL = 0.3

local LobbyTank = {}

function LobbyTank.init(layout)
	local tank = layout.tank
	local folder = workspace:FindFirstChild("Lurkers")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Lurkers"
		folder.Parent = workspace
	end

	local anchor = Instance.new("Part")
	anchor.Name = "TankLurker"
	anchor.Size = Vector3.one
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor:SetAttribute("Alert", false)
	anchor:SetAttribute("Lunging", false)

	-- Where its head may go: inside the tank, clear of the walls.
	local low = tank.min + Vector3.new(2.5, 2, 2.5)
	local high = tank.max - Vector3.new(1.5, 2.5, 2.5)
	local center = (low + high) / 2
	local half = (high - low) / 2

	local phase = 0
	local position = center
	local heading = Vector3.zAxis
	local staring = false
	local stareSpot
	local stareUntil, nextStare, nextLook = 0, 0, 0

	local function loopPoint(t)
		return center + Vector3.new(half.X * 0.7 * math.sin(t * 2), half.Y * 0.6 * math.sin(t * 0.7), half.Z * 0.9 * math.sin(t))
	end

	-- Someone standing right in front of the window, if anyone is.
	local function findViewer()
		for _, player in Players:GetPlayers() do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root then
				local p = root.Position
				if p.X > tank.glassX and p.X < tank.glassX + STARE_RANGE and p.Z > tank.windowZ0 and p.Z < tank.windowZ1 and p.Y < tank.max.Y + 4 then
					return p
				end
			end
		end
		return nil
	end

	anchor.CFrame = CFrame.lookAt(position, position + heading)
	anchor.Parent = folder

	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		local goal, speed
		if staring then
			goal, speed = stareSpot, DART_SPEED
			if now > stareUntil then
				staring = false
				nextStare = now + STARE_COOLDOWN
				anchor:SetAttribute("Alert", false)
			end
		else
			phase += dt * LOOP_SPEED
			goal, speed = loopPoint(phase), SWIM_SPEED
			if now >= nextStare and now >= nextLook then
				nextLook = now + LOOK_INTERVAL
				local viewer = findViewer()
				if viewer then
					staring = true
					stareUntil = now + STARE_TIME
					stareSpot = Vector3.new(high.X, math.clamp(viewer.Y, low.Y, high.Y), math.clamp(viewer.Z, low.Z, high.Z))
					anchor:SetAttribute("Alert", true)
				end
			end
		end

		local offset = goal - position
		local distance = offset.Magnitude
		if distance > 0.05 then
			local direction = offset / distance
			position += direction * math.min(distance, speed * dt)
			local turned = heading:Lerp(Vector3.new(direction.X, direction.Y * 0.3, direction.Z), math.min(1, dt * 4))
			if turned.Magnitude > 0.01 then
				heading = turned.Unit
			end
		end
		-- Once it reaches the glass it turns to look straight out at you.
		if staring and distance < 1 then
			local turned = heading:Lerp(Vector3.xAxis, math.min(1, dt * 6))
			if turned.Magnitude > 0.01 then
				heading = turned.Unit
			end
		end
		anchor.CFrame = CFrame.lookAt(position, position + heading)
	end)
end

return LobbyTank
