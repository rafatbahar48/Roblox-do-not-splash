-- Throwing pebbles: E, the gamepad's right trigger, or the on-screen Throw
-- button. Aims at the mouse, or at the centre of the screen on touch and gamepad.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local Throw = {}

local lastThrow = 0

local function aimPoint(inputObject)
	local camera = workspace.CurrentCamera
	local screenPoint
	if inputObject.UserInputType == Enum.UserInputType.Keyboard then
		screenPoint = UserInputService:GetMouseLocation()
	else
		screenPoint = camera.ViewportSize / 2
	end

	local ray = camera:ViewportPointToRay(screenPoint.X, screenPoint.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	local result = workspace:Raycast(ray.Origin, ray.Direction * 300, params)
	if result then
		return result.Position
	end
	return ray.Origin + ray.Direction * Config.Pebbles.MaxRange
end

local function onThrow(_, inputState, inputObject)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	local now = os.clock()
	if (player:GetAttribute("Pebbles") or 0) > 0 and now - lastThrow >= Config.Pebbles.Cooldown then
		lastThrow = now
		Remotes.ThrowPebble:FireServer(aimPoint(inputObject))
	end
	return Enum.ContextActionResult.Sink
end

function Throw.start()
	ContextActionService:BindAction("ThrowPebble", onThrow, true, Enum.KeyCode.E, Enum.KeyCode.ButtonR2)
	ContextActionService:SetTitle("ThrowPebble", "Throw")
end

return Throw
