-- Throwing pebbles: E, the gamepad's right trigger, or the HUD's pebble
-- button (Hud.luau). Aims at the mouse, or at the centre of the screen on
-- touch, gamepad and the button. In the Christmas lobby the same keys (and
-- the HUD's snowball button) throw snowballs instead (server/Snowballs.luau).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Zones = require(ReplicatedStorage.Shared.Zones)

local player = Players.LocalPlayer

local Throw = {}

local lastThrow = 0

local function aimPoint(atMouse, range)
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
	return ray.Origin + ray.Direction * range
end

local function inChristmasLobby()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return Config.Christmas and root ~= nil and Zones.at(root.Position) == "lobby"
end

local function throw(atMouse)
	local now = os.clock()
	if inChristmasLobby() then
		-- Snowballs only: a pebble here would only puzzle people.
		if (player:GetAttribute("Snowballs") or 0) > 0 and now - lastThrow >= Config.Snowballs.Cooldown then
			lastThrow = now
			Remotes.ThrowSnowball:FireServer(aimPoint(atMouse, Config.Snowballs.MaxRange))
		end
	elseif (player:GetAttribute("Pebbles") or 0) > 0 and now - lastThrow >= Config.Pebbles.Cooldown then
		lastThrow = now
		Remotes.ThrowPebble:FireServer(aimPoint(atMouse, Config.Pebbles.MaxRange))
	end
end

local function onThrow(_, inputState, inputObject)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	throw(inputObject.UserInputType == Enum.UserInputType.Keyboard)
	return Enum.ContextActionResult.Sink
end

-- For the HUD's pebble and snowball buttons.
function Throw.fromButton()
	throw(false)
end

function Throw.start()
	ContextActionService:BindAction("ThrowPebble", onThrow, false, Enum.KeyCode.E, Enum.KeyCode.ButtonR2)
end

return Throw
