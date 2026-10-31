-- Snowball fights in the Christmas lobby (Config.Christmas, Config.Snowballs).
-- A pile's prompt (G) fills your hands; E, R2 or the HUD's snowball button
-- throws one (client/Throw.luau). The server flies each along an arc and
-- raycasts ahead: whoever it hits gets snow in the face (client/Snow.luau),
-- and everyone near sees a puff and hears it. It never moves anyone, so a
-- snowball can't knock someone off a party pad. Only in the lobby: walk out
-- of it (into the cave) and you drop what you carry.
--
-- Player attribute: Snowballs, how many you carry.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Effects = require(script.Parent.Effects)

local SETTINGS = Config.Snowballs
local SNOW = Color3.fromRGB(240, 246, 255)
local CHECK_INTERVAL = 0.5

local Snowballs = {}

local folder
local flying = {} -- { part, position, velocity, age, thrower, params }
local lastThrow = {} -- [Player] = time

local function isFinite(vector)
	return vector.X == vector.X and vector.Y == vector.Y and vector.Z == vector.Z and vector.Magnitude < math.huge
end

-- The player's root, if they are alive and in the lobby.
local function rootInLobby(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and humanoid and humanoid.Health > 0 and root.Position.Z < 0 then
		return root
	end
	return nil
end

local function makeBall(position)
	local part = Instance.new("Part")
	part.Name = "Snowball"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * 0.9
	part.Color = SNOW
	part.Material = Enum.Material.Snow
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Position = position
	part.Parent = folder
	return part
end

-- A white burst where it breaks, for everyone.
local function puff(position)
	local part = makeBall(position)
	part.Name = "SnowPuff"
	part.Transparency = 0.15
	TweenService:Create(part, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * 3.2,
		Transparency = 1,
	}):Play()
	Debris:AddItem(part, 0.4)
end

local function grab(player, pile)
	if not rootInLobby(player) then
		return
	end
	local count = player:GetAttribute("Snowballs") or 0
	if count >= SETTINGS.Max then
		return
	end
	player:SetAttribute("Snowballs", math.min(SETTINGS.Max, count + SETTINGS.PerGrab))
	Effects.sound("SnowGrab", pile.Position, 0.6)
end

local function throw(player, target)
	if typeof(target) ~= "Vector3" or not isFinite(target) then
		return
	end
	local count = player:GetAttribute("Snowballs") or 0
	local now = os.clock()
	if count <= 0 or (lastThrow[player] and now - lastThrow[player] < SETTINGS.Cooldown) then
		return
	end
	local root = rootInLobby(player)
	if not root then
		return
	end
	lastThrow[player] = now
	player:SetAttribute("Snowballs", count - 1)

	local origin = root.Position + Vector3.new(0, 1.5, 0)
	local offset = target - origin
	if offset.Magnitude < 1 then
		offset = root.CFrame.LookVector * 10
	elseif offset.Magnitude > SETTINGS.MaxRange then
		offset = offset.Unit * SETTINGS.MaxRange
	end
	-- A flight time from the distance, then the launch velocity that lands it there.
	local flightTime = SETTINGS.MinFlightTime + (SETTINGS.MaxFlightTime - SETTINGS.MinFlightTime) * (offset.Magnitude / SETTINGS.MaxRange)
	local gravity = Vector3.new(0, -workspace.Gravity, 0)
	local velocity = offset / flightTime - gravity * flightTime / 2

	-- It flies through the thrower and other snowballs, and hits everything else.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character, folder }
	local start = origin + offset.Unit * 1.5
	table.insert(flying, { part = makeBall(start), position = start, velocity = velocity, age = 0, thrower = player, params = params })
	Effects.sound("SnowballThrow", origin, 0.5)
end

local function land(ball, result)
	ball.part:Destroy()
	puff(result.Position)
	local character = result.Instance:FindFirstAncestorOfClass("Model")
	local victim = character and Players:GetPlayerFromCharacter(character)
	if victim and victim ~= ball.thrower then
		Effects.sound("SnowballHit", result.Position, 0.9)
		Remotes.SnowballHit:FireClient(victim)
		Remotes.Notify:FireClient(victim, "snowball", ball.thrower.DisplayName .. " got you!")
		if ball.thrower.Parent then
			Remotes.Notify:FireClient(ball.thrower, "snowball", "Got " .. victim.DisplayName .. "!")
		end
	else
		Effects.sound("SnowballLand", result.Position, 0.6)
	end
end

local function step(dt)
	local gravity = Vector3.new(0, -workspace.Gravity, 0)
	for i = #flying, 1, -1 do
		local ball = flying[i]
		ball.age += dt
		local nextPosition = ball.position + ball.velocity * dt + gravity * (dt * dt / 2)
		local result = workspace:Raycast(ball.position, nextPosition - ball.position, ball.params)
		if result then
			table.remove(flying, i)
			land(ball, result)
		elseif ball.age > SETTINGS.Lifetime then
			table.remove(flying, i)
			ball.part:Destroy()
		else
			ball.position = nextPosition
			ball.velocity += gravity * dt
			ball.part.Position = nextPosition
		end
	end
end

function Snowballs.init(layout)
	if not Config.Christmas then
		return
	end
	folder = Instance.new("Folder")
	folder.Name = "Snowballs"
	folder.Parent = workspace

	for _, prompt in layout.snowPiles do
		prompt.Triggered:Connect(function(player)
			grab(player, prompt.Parent)
		end)
	end
	Remotes.ThrowSnowball.OnServerEvent:Connect(throw)
	RunService.Heartbeat:Connect(step)
	Players.PlayerRemoving:Connect(function(player)
		lastThrow[player] = nil
	end)

	-- Out of the lobby (or dead), your hands are empty.
	task.spawn(function()
		while true do
			task.wait(CHECK_INTERVAL)
			for _, player in Players:GetPlayers() do
				if (player:GetAttribute("Snowballs") or 0) > 0 and not rootInLobby(player) then
					player:SetAttribute("Snowballs", 0)
				end
			end
		end
	end)
end

return Snowballs
