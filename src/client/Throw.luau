-- Throwing pebbles: E, the gamepad's right trigger, or the HUD's pebble
-- button (Hud.luau). Aims at the mouse, or at the centre of the screen on
-- touch, gamepad and the button.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local Throw = {}

local lastThrow = 0

local function aimPoint(atMouse)
	local camera = workspace.CurrentCamera
	local screenPoint = if atMouse then UserInputService:GetMouseLocation() else camera.ViewportSize / 2

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

local function throw(atMouse)
	local now = os.clock()
	if (player:GetAttribute("Pebbles") or 0) > 0 and now - lastThrow >= Config.Pebbles.Cooldown then
		lastThrow = now
		Remotes.ThrowPebble:FireServer(aimPoint(atMouse))
	end
end

local function onThrow(_, inputState, inputObject)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	throw(inputObject.UserInputType == Enum.UserInputType.Keyboard)
	return Enum.ContextActionResult.Sink
end

-- For the HUD's pebble button.
function Throw.fromButton()
	throw(false)
end

function Throw.start()
	ContextActionService:BindAction("ThrowPebble", onThrow, false, Enum.KeyCode.E, Enum.KeyCode.ButtonR2)
end

return Throw
