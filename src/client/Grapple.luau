-- The grapple, on your screen: which hook (server/Forest.luau's
-- grappleHook) is in reach, lit up so you can see it through the fog, and
-- the swing over to its platform once the server says yes. Boosts.luau
-- asks; the server spends the grapple and runs the rope (server/Grapple.luau).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer

local GLOW = Color3.fromRGB(200, 255, 160)
local HANG = 2.5 -- how far under the ring you pass, halfway over
local CHECK_INTERVAL = 0.1

local Grapple = {}

local swinging = false
local highlight -- round the hook in reach, if any

-- The hook you would swing to now: of those in reach, not over the
-- platform you're already on, the one meant to be swung to from where you
-- stand (the nearest From), so a nearer ring behind you or off to the side
-- doesn't take you the wrong way. Nil if there's none.
function Grapple.target()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or swinging then
		return nil
	end
	local best, bestStart
	for _, hook in CollectionService:GetTagged("GrappleHook") do
		local landAt, from = hook:GetAttribute("LandAt"), hook:GetAttribute("From")
		if typeof(landAt) == "Vector3" and typeof(from) == "Vector3" then
			local distance = (hook.Position - root.Position).Magnitude
			local across = Vector2.new(landAt.X - root.Position.X, landAt.Z - root.Position.Z).Magnitude
			local start = Vector2.new(from.X - root.Position.X, from.Z - root.Position.Z).Magnitude
			if distance <= Config.Grapple.Range and across > 5 and (not best or start < bestStart) then
				best, bestStart = hook, start
			end
		end
	end
	return best
end

-- Swings you over to the hook's platform: up under the ring and down onto
-- the middle of the platform, over duration seconds.
function Grapple.swing(hook, duration)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local landAt = hook:GetAttribute("LandAt")
	if swinging or not root or not humanoid or humanoid.Health <= 0 or typeof(landAt) ~= "Vector3" then
		return
	end
	swinging = true

	-- A curve from where you are to where you land that passes just under
	-- the ring halfway.
	local start = root.Position
	local land = landAt + Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0)
	local under = hook.Position - Vector3.new(0, HANG, 0)
	local control = under * 2 - (start + land) / 2
	local facing = Vector3.new(land.X - start.X, 0, land.Z - start.Z).Unit
	humanoid.AutoRotate = false
	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)

	local began = os.clock()
	local connection
	connection = RunService.Heartbeat:Connect(function()
		local t = math.min(1, (os.clock() - began) / duration)
		local s = t * t * (3 - 2 * t) -- eases in and out
		local position = start * (1 - s) ^ 2 + control * (2 * (1 - s) * s) + land * (s * s)
		local velocity = ((control - start) * (1 - s) + (land - control) * s) * (2 * 6 * t * (1 - t) / duration)
		root.CFrame = CFrame.lookAt(position, position + facing)
		root.AssemblyLinearVelocity = velocity
		if t >= 1 or humanoid.Health <= 0 then
			connection:Disconnect()
			root.AssemblyLinearVelocity = Vector3.new(0, -2, 0)
			humanoid.AutoRotate = true
			swinging = false
		end
	end)
end

function Grapple.start()
	highlight = Instance.new("Highlight")
	highlight.Name = "GrappleHook"
	highlight.FillTransparency = 1
	highlight.OutlineColor = GLOW
	highlight.OutlineTransparency = 0.15
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Enabled = false
	highlight.Parent = workspace -- only on this screen

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < CHECK_INTERVAL then
			return
		end
		elapsed = 0
		local hook = Grapple.target()
		local model = hook and hook.Parent
		highlight.Adornee = model
		highlight.Enabled = model ~= nil
	end)
end

return Grapple
