-- Thrown pebbles. The server flies each one along an arc and raycasts ahead;
-- where it lands it makes a noise that draws the lurkers away from players.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Effects = require(script.Parent.Effects)
local Noise = require(script.Parent.Noise)

local SETTINGS = Config.Pebbles

local Pebbles = {}

local flying = {} -- { part, position, velocity, age }
local lastThrow = {} -- [Player] = time
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Include

local function isFinite(vector)
	return vector.X == vector.X and vector.Y == vector.Y and vector.Z == vector.Z and vector.Magnitude < math.huge
end

local function makePebble(position)
	local part = Instance.new("Part")
	part.Name = "Pebble"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(0.6, 0.6, 0.6)
	part.Color = Color3.fromRGB(110, 115, 118)
	part.Material = Enum.Material.Slate
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Position = position
	part.Parent = workspace:FindFirstChild("Effects") or workspace
	return part
end

local function throw(player, target)
	if typeof(target) ~= "Vector3" or not isFinite(target) then
		return
	end
	local count = player:GetAttribute("Pebbles") or 0
	local now = os.clock()
	if count <= 0 or (lastThrow[player] and now - lastThrow[player] < SETTINGS.Cooldown) then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end

	lastThrow[player] = now
	player:SetAttribute("Pebbles", count - 1)

	local origin = root.Position + Vector3.new(0, 1.5, 0)
	local offset = target - origin
	if offset.Magnitude < 1 then
		offset = root.CFrame.LookVector * 10
	elseif offset.Magnitude > SETTINGS.MaxRange then
		offset = offset.Unit * SETTINGS.MaxRange
	end

	-- Pick a flight time from the distance, then solve for the launch velocity.
	local flightTime = SETTINGS.MinFlightTime + (SETTINGS.MaxFlightTime - SETTINGS.MinFlightTime) * (offset.Magnitude / SETTINGS.MaxRange)
	local gravity = Vector3.new(0, -workspace.Gravity, 0)
	local velocity = offset / flightTime - gravity * flightTime / 2

	local start = origin + offset.Unit * 1.5
	table.insert(flying, { part = makePebble(start), position = start, velocity = velocity, age = 0 })
end

local function land(pebble, result)
	if result.Instance.Name == "Water" then
		Noise.emitAt(result.Position, Config.Noise.PebbleSplash)
		Effects.splash(result.Position, 3)
		pebble.part:Destroy()
	else
		Noise.emitAt(result.Position, Config.Noise.PebbleClatter)
		Effects.sound("Clatter", result.Position)
		pebble.part.Position = result.Position + result.Normal * 0.3
		task.delay(2, function()
			pebble.part:Destroy()
		end)
	end
end

local function step(dt)
	local gravity = Vector3.new(0, -workspace.Gravity, 0)
	for i = #flying, 1, -1 do
		local pebble = flying[i]
		pebble.age += dt
		local nextPosition = pebble.position + pebble.velocity * dt + gravity * (dt * dt / 2)
		local result = workspace:Raycast(pebble.position, nextPosition - pebble.position, raycastParams)
		if result then
			table.remove(flying, i)
			land(pebble, result)
		elseif pebble.age > SETTINGS.Lifetime then
			table.remove(flying, i)
			pebble.part:Destroy()
		else
			pebble.position = nextPosition
			pebble.velocity += gravity * dt
			pebble.part.Position = nextPosition
		end
	end
end

function Pebbles.init()
	-- Only the map stops pebbles, so they fly through players and lurkers.
	raycastParams.FilterDescendantsInstances = { workspace:WaitForChild("Map") }
	Remotes.ThrowPebble.OnServerEvent:Connect(throw)
	RunService.Heartbeat:Connect(step)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastThrow[player] = nil
	end)
end

return Pebbles
