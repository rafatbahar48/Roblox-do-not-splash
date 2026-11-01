-- Boost input and the Updraft flight. Q (or L1) uses an Updraft, F (or Y) a
-- Hush, G (or X) a grapple, to the hook in reach (Grapple.luau); so do the
-- HUD's boost buttons (Hud.luau), which show while you carry any (the
-- grapple's also while a hook is in reach: with none, it buys one for coins
-- and swings). The server checks and spends the boost (server/Shop.luau) and
-- answers with BoostStarted. Only then does Updraft lift you or the grapple
-- swing you; Hush happens on the server.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Grapple = require(script.Parent.Grapple)

local player = Players.LocalPlayer

local BOOSTS = {
	{ id = "updraft", action = "UseUpdraft", keys = { Enum.KeyCode.Q, Enum.KeyCode.ButtonL1 } },
	{ id = "hush", action = "UseHush", keys = { Enum.KeyCode.F, Enum.KeyCode.ButtonY } },
	{ id = "grapple", action = "UseGrapple", keys = { Enum.KeyCode.G, Enum.KeyCode.ButtonX } },
}
local BUY_WAIT = 3 -- seconds to wait for a grapple bought on the spot to arrive
local SHOP_GAP = 0.25 -- the shop takes one request from you every 0.2 seconds (server/Shop.luau)

local Boosts = {}

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

local buying = false

-- Asks the server to use one of boost id, if you carry any. A grapple needs
-- a hook in reach; with none left, it buys one first.
function Boosts.use(id)
	local carried = player:GetAttribute("Boost_" .. id) or 0
	if id ~= "grapple" then
		if carried > 0 then
			Remotes.UseBoost:FireServer(id)
		end
		return
	end
	local hook = Grapple.target()
	if not hook then
		return
	end
	if carried > 0 then
		Remotes.UseBoost:FireServer(id, hook)
	elseif not buying then
		buying = true
		Remotes.BuyItem:FireServer(id)
		task.spawn(function()
			local waited = task.wait(SHOP_GAP)
			while waited < BUY_WAIT and (player:GetAttribute("Boost_grapple") or 0) == 0 do
				waited += task.wait(0.1)
			end
			buying = false
			local now = Grapple.target()
			if now and (player:GetAttribute("Boost_grapple") or 0) > 0 then
				Remotes.UseBoost:FireServer(id, now)
			end
		end)
	end
end

local function onAction(actionName, inputState)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	for _, boost in BOOSTS do
		if boost.action == actionName then
			Boosts.use(boost.id)
		end
	end
	return Enum.ContextActionResult.Sink
end

function Boosts.start()
	for _, boost in BOOSTS do
		ContextActionService:BindAction(boost.action, onAction, false, table.unpack(boost.keys))
	end

	Grapple.start()
	Remotes.BoostStarted.OnClientEvent:Connect(function(id, duration, hook)
		if type(duration) ~= "number" then
			return
		end
		if id == "updraft" then
			fly(duration)
		elseif id == "grapple" and typeof(hook) == "Instance" then
			Grapple.swing(hook, duration)
		end
	end)
end

return Boosts
