-- The lobby on this screen: whenever you arrive there the camera turns to
-- face the lodge from behind you, and the first time it sweeps down to you
-- from high over the swamp; and its lanterns and fire flicker a little
-- (parts tagged LobbyLantern, server/LobbyBuilder.luau), each in its own
-- time, while you're there.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Zones = require(ReplicatedStorage.Shared.Zones)

local player = Players.LocalPlayer

local STEP = 0.08 -- seconds between changes
local RANGE = 140 -- studs from you; further ones are left alone
local LODGE = Vector3.new(4, Config.Room.SurfaceY + 12, -60) -- the middle of the lodge's front
local SWEEP = TweenInfo.new(3.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

local LobbyLife = {}

local lights = {} -- [light] = { base brightness, seed }
local swept = false

local function arrive(character)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	task.wait(0.3) -- after the camera has settled on the new character
	if not root or not root.Parent or Zones.at(root.Position) ~= "lobby" then
		return
	end
	local camera = workspace.CurrentCamera
	local flat = (LODGE - root.Position) * Vector3.new(1, 0, 1)
	if flat.Magnitude < 1 then
		return
	end
	local ahead = flat.Unit
	local behind = CFrame.lookAt(root.Position - ahead * 12 + Vector3.new(0, 4.5, 0), root.Position + ahead * 40 + Vector3.new(0, 9, 0))
	if not swept then
		swept = true
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CFrame.lookAt(root.Position - ahead * 26 + Vector3.new(0, 30, 0), LODGE)
		local sweep = TweenService:Create(camera, SWEEP, { CFrame = behind })
		sweep:Play()
		sweep.Completed:Wait()
		camera.CameraType = Enum.CameraType.Custom
	end
	camera.CFrame = behind
end

local function add(part)
	local light = part:FindFirstChildWhichIsA("Light")
	if light and not lights[light] then
		lights[light] = { base = light.Brightness, seed = math.random() * 100 }
	end
end

function LobbyLife.start()
	player.CharacterAdded:Connect(arrive)
	if player.Character then
		task.spawn(arrive, player.Character)
	end
	CollectionService:GetInstanceAddedSignal("LobbyLantern"):Connect(add)
	for _, part in CollectionService:GetTagged("LobbyLantern") do
		add(part)
	end
	task.spawn(function()
		while true do
			task.wait(STEP)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root and Zones.at(root.Position) == "lobby" then
				local t = os.clock()
				for light, info in lights do
					if not light.Parent then
						lights[light] = nil
					elseif (light.Parent.Position - root.Position).Magnitude < RANGE then
						-- Mostly steady, now and then dipping as the flame gutters.
						local wobble = math.noise(t * 2.3, info.seed) * 0.5 + math.noise(t * 7.1, info.seed + 31) * 0.25
						light.Brightness = info.base * (0.92 + math.clamp(wobble, -0.35, 0.2))
					end
				end
			end
		end
	end)
end

return LobbyLife
