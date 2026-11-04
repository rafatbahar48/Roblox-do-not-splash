-- The lobby on this screen: whenever you arrive there the camera turns to
-- face the lodge from behind you, and the first time it sweeps down to you
-- from high over the swamp; and its lanterns and fire flicker a little
-- (parts tagged LobbyLantern, server/LobbyBuilder.luau), each in its own
-- time, while you're there. Now and then, far off, something roars beyond
-- the ridge and something splashes out on the swamp, muffled and echoing
-- (in the Ambience group, with the crickets: the "Night sounds" setting).

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Zones = require(ReplicatedStorage.Shared.Zones)

local player = Players.LocalPlayer

local STEP = 0.08 -- seconds between changes
local RANGE = 140 -- studs from you; further ones are left alone
local LODGE = Vector3.new(4, Config.Room.SurfaceY + 12, -60) -- the middle of the lodge's front
local SWEEP = TweenInfo.new(3.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local ROAR_EVERY = { 50, 110 } -- seconds between the far-off roars
local SPLASH_EVERY = { 12, 30 } -- and splashes
local SPLASHES = { "DistantSplash", "DistantSplashDeep" }

local LobbyLife = {}

local lights = {} -- [light] = { base brightness, seed }
local swept = false
local sweep -- the sweep's tween while it plays

-- Gives the camera back to the player, following their character now (it may
-- have been swapped for a new one while the sweep played).
local function settle(camera)
	camera.CameraType = Enum.CameraType.Custom
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

local function arrive(character)
	local camera = workspace.CurrentCamera
	if sweep then
		-- A new character mid-sweep (a skin going on, or a checkpoint): stop it.
		sweep:Cancel()
		sweep = nil
		settle(camera)
	end
	local root = character:WaitForChild("HumanoidRootPart", 10)
	task.wait(0.3) -- after the camera has settled on the new character
	if not root or not root.Parent or player.Character ~= character or Zones.at(root.Position) ~= "lobby" then
		return
	end
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
		local tween = TweenService:Create(camera, SWEEP, { CFrame = behind })
		sweep = tween
		tween:Play()
		-- Cut short if you're sent off somewhere first (to your checkpoint).
		while tween.PlaybackState == Enum.PlaybackState.Playing do
			if not root.Parent or Zones.at(root.Position) ~= "lobby" then
				tween:Cancel()
			end
			task.wait(0.1)
		end
		if sweep ~= tween then
			return -- stopped for a new character, which has the camera now
		end
		sweep = nil
		settle(camera)
		if tween.PlaybackState ~= Enum.PlaybackState.Completed then
			return
		end
	end
	camera.CFrame = behind
end

local function lobbyRoot()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return if root and Zones.at(root.Position) == "lobby" then root else nil
end

-- Plays a Config.Sounds sound once from position, muffled and echoing as if
-- from a long way off: as loud as volume out to near studs, fading beyond.
local function playFar(name, position, volume, near, speed)
	local id = Config.Sounds[name]
	if not id or id == "" then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Parent = workspace.Terrain
	attachment.WorldPosition = position
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.PlaybackSpeed = speed
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = near
	sound.RollOffMaxDistance = 1000
	sound.SoundGroup = SoundService:FindFirstChild("Ambience")
	local muffle = Instance.new("EqualizerSoundEffect")
	muffle.HighGain = -18
	muffle.MidGain = -6
	muffle.LowGain = 2
	muffle.Parent = sound
	local echo = Instance.new("ReverbSoundEffect")
	echo.DecayTime = 3
	echo.DryLevel = -2
	echo.WetLevel = -4
	echo.Parent = sound
	sound.Parent = attachment
	sound:Play()
	Debris:AddItem(attachment, 16)
end

-- Something big roaring out past the ridge, where the stages are.
local function roar(root)
	local spot = Vector3.new(root.Position.X + math.random(-160, 160), Config.Room.SurfaceY + 10, math.random(70, 160))
	playFar("DistantRoar", spot, 1.6, 90, 0.75 + math.random() * 0.2)
end

-- One to three splashes somewhere out on the swamp, a little apart, as if
-- something were moving through the water.
local function splashes(root)
	local angle = math.random() * 2 * math.pi
	local spot = root.Position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * math.random(100, 200)
	spot = Vector3.new(math.clamp(spot.X, -400, 400), Config.Room.SurfaceY, math.clamp(spot.Z, -580, -25))
	local step = Vector3.new(math.cos(angle + math.pi / 2), 0, math.sin(angle + math.pi / 2)) * math.random(4, 10)
	for i = 1, math.random(1, 3) do
		if i > 1 then
			task.wait(0.5 + math.random() * 0.9)
		end
		playFar(SPLASHES[math.random(#SPLASHES)], spot + step * i, 1, 40, 0.85 + math.random() * 0.25)
	end
end

-- Calls play every so often (between every[1] and every[2] seconds, the
-- first after first) while you're in the lobby.
local function nowAndThen(every, first, play)
	task.spawn(function()
		task.wait(first)
		while true do
			local root = lobbyRoot()
			if root then
				play(root)
			end
			task.wait(math.random(every[1], every[2]))
		end
	end)
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
	nowAndThen(ROAR_EVERY, math.random(20, 35), roar)
	nowAndThen(SPLASH_EVERY, math.random(6, 12), splashes)
	task.spawn(function()
		while true do
			task.wait(STEP)
			local root = lobbyRoot()
			if root then
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
