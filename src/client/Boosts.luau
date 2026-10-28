-- Boost input and the Updraft flight. Q (or L1) uses an Updraft, F (or Y) a
-- Hush; on touch screens a button shows while you carry any. The server
-- checks and spends the boost (server/Shop.luau) and answers with
-- BoostStarted. Only then does Updraft lift you; Hush happens on the server.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local BOOSTS = {
	{ id = "updraft", action = "UseUpdraft", title = "Fly", keys = { Enum.KeyCode.Q, Enum.KeyCode.ButtonL1 } },
	{ id = "hush", action = "UseHush", title = "Hush", keys = { Enum.KeyCode.F, Enum.KeyCode.ButtonY } },
}

local Boosts = {}

local bound = {} -- [boost id] = true while its action is bound
local flying = false

-- Lifts the character a few studs and lets it glide where it is walking.
local function fly(duration)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if flying or not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	flying = true
	local settings = Config.Boosts.updraft

	local attachment = Instance.new("Attachment")
	attachment.Name = "Updraft"
	attachment.Parent = root

	local lift = Instance.new("LinearVelocity")
	lift.Attachment0 = attachment
	lift.MaxForce = 100000
	lift.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lift.RelativeTo = Enum.ActuatorRelativeTo.World
	lift.Parent = root

	local wind = Instance.new("ParticleEmitter")
	wind.Color = ColorSequence.new(Color3.fromRGB(190, 235, 255))
	wind.LightEmission = 0.6
	wind.Lifetime = NumberRange.new(0.4, 0.7)
	wind.Rate = 40
	wind.Speed = NumberRange.new(2, 4)
	wind.SpreadAngle = Vector2.new(180, 180)
	wind.Size = NumberSequence.new(0.3, 0)
	wind.Transparency = NumberSequence.new(0.3, 1)
	wind.Parent = attachment

	local targetY = root.Position.Y + settings.height
	local connection = RunService.Heartbeat:Connect(function()
		local move = humanoid.MoveDirection * settings.glideSpeed
		local climb = math.clamp((targetY - root.Position.Y) * 6, -8, 30)
		lift.VectorVelocity = Vector3.new(move.X, climb, move.Z)
	end)

	task.delay(duration, function()
		connection:Disconnect()
		lift:Destroy()
		wind.Enabled = false
		task.delay(0.8, function()
			attachment:Destroy()
		end)
		flying = false
	end)
end

local function onAction(actionName, inputState)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	for _, boost in BOOSTS do
		if boost.action == actionName and (player:GetAttribute("Boost_" .. boost.id) or 0) > 0 then
			Remotes.UseBoost:FireServer(boost.id)
		end
	end
	return Enum.ContextActionResult.Sink
end

-- Binds a boost's keys and touch button while the player carries any.
local function refresh(boost)
	local count = player:GetAttribute("Boost_" .. boost.id) or 0
	if count > 0 then
		if not bound[boost.id] then
			ContextActionService:BindAction(boost.action, onAction, true, table.unpack(boost.keys))
			bound[boost.id] = true
		end
		ContextActionService:SetTitle(boost.action, ("%s %d"):format(boost.title, count))
	elseif bound[boost.id] then
		ContextActionService:UnbindAction(boost.action)
		bound[boost.id] = nil
	end
end

function Boosts.start()
	for _, boost in BOOSTS do
		player:GetAttributeChangedSignal("Boost_" .. boost.id):Connect(function()
			refresh(boost)
		end)
		refresh(boost)
	end

	Remotes.BoostStarted.OnClientEvent:Connect(function(id, duration)
		if id == "updraft" and type(duration) == "number" then
			fly(duration)
		end
	end)
end

return Boosts
