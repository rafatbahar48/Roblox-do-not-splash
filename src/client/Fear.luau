-- Fear effects on this client: a dark vignette that closes in and beats like
-- a heart while something hunts you, lanterns that falter in any stage where
-- something is hunting, and a camera shake when it strikes nearby.
-- Being caught is DeathScene.luau; these effects stand aside while it plays.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local DeathScene = require(script.Parent.DeathScene)

local player = Players.LocalPlayer

local VIGNETTE_CALM = 0.55 -- edge transparency when nothing is hunting you
local VIGNETTE_HUNTED = 0.08
local BLACK = Color3.new(0, 0, 0)
local BLOOD = Color3.fromRGB(70, 0, 0)
local SHAKE_RANGE = 40
local FALTER_INTERVAL = 0.07

local Fear = {}

local edges = {}
local baseFov
local fovTouched = false
local huntLevel = 0
local beatClock = 0
local shake = 0
local anchors = {} -- [anchor part] = true
local roomLights = {} -- [room index] = { { light, base } }
local faltering = {} -- [room index] = true
local nextFalter = 0

local function makeEdge(gui, rotation, position, size)
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = BLACK
	frame.BackgroundTransparency = VIGNETTE_CALM
	frame.BorderSizePixel = 0
	frame.Position = position
	frame.Size = size
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = rotation
	gradient.Transparency = NumberSequence.new(0, 1)
	gradient.Parent = frame
	frame.Parent = gui
	table.insert(edges, frame)
end

local function lightsFor(index)
	local cached = roomLights[index]
	if cached then
		return cached
	end
	local map = workspace:FindFirstChild("Map")
	local room = map and map:FindFirstChild(string.format("Stage%02d", index))
	if not room then
		return {}
	end
	local list = {}
	for _, panel in room:GetChildren() do
		local light = panel:FindFirstChildOfClass("PointLight")
		if light then
			table.insert(list, { light = light, base = light.Brightness })
		end
	end
	roomLights[index] = list
	return list
end

-- Lanterns in stages with a hunting creature stutter; others go back to normal.
local function falterLights()
	local hunting = {}
	for anchor in anchors do
		if anchor:GetAttribute("Alert") then
			local room = anchor:GetAttribute("Room")
			if room then
				hunting[room] = true
			end
		end
	end
	for room in hunting do
		faltering[room] = true
		for _, entry in lightsFor(room) do
			local level = if math.random() < 0.25 then 0.1 + math.random() * 0.3 else 0.75 + math.random() * 0.25
			entry.light.Brightness = entry.base * level
		end
	end
	for room in faltering do
		if not hunting[room] then
			faltering[room] = nil
			for _, entry in lightsFor(room) do
				entry.light.Brightness = entry.base
			end
		end
	end
end

local function watchAnchor(anchor)
	if anchors[anchor] or not anchor:IsA("BasePart") then
		return
	end
	anchors[anchor] = true
	anchor:GetAttributeChangedSignal("Lunging"):Connect(function()
		if not anchor:GetAttribute("Lunging") or DeathScene.playing() then
			return
		end
		local distance = (anchor.Position - workspace.CurrentCamera.CFrame.Position).Magnitude
		if distance < SHAKE_RANGE then
			shake = math.max(shake, 0.01 + 0.03 * (1 - distance / SHAKE_RANGE))
		end
	end)
end

local function step(dt)
	local dying = DeathScene.playing()
	local hunted = player:GetAttribute("Hunted") == true and not dying
	huntLevel += ((if hunted then 1 else 0) - huntLevel) * math.min(1, dt * 3)

	-- A heartbeat: two quick pulses, faster the louder you are.
	local noise = player:GetAttribute("Noise") or 0
	local interval = 0.85 - math.clamp(noise / 100, 0, 1) * 0.35
	beatClock = (beatClock + dt) % interval
	local pulse = huntLevel * (math.exp(-(beatClock ^ 2) / 0.003) + 0.6 * math.exp(-((beatClock - 0.2) ^ 2) / 0.003))

	local transparency = math.clamp(VIGNETTE_CALM + (VIGNETTE_HUNTED - VIGNETTE_CALM) * huntLevel - pulse * 0.12, 0, 1)
	local color = BLACK:Lerp(BLOOD, math.clamp(huntLevel * 0.6 + pulse * 0.4, 0, 1))
	for _, frame in edges do
		frame.BackgroundTransparency = transparency
		frame.BackgroundColor3 = color
	end

	if dying then
		fovTouched = false -- the death scene owns the camera now
	else
		local camera = workspace.CurrentCamera
		if huntLevel > 0.001 then
			camera.FieldOfView = baseFov - 5 * huntLevel - pulse * 1.5
			fovTouched = true
		elseif fovTouched then
			camera.FieldOfView = baseFov
			fovTouched = false
		end
	end

	local now = os.clock()
	if now >= nextFalter then
		nextFalter = now + FALTER_INTERVAL
		falterLights()
	end
end

function Fear.start()
	baseFov = workspace.CurrentCamera.FieldOfView

	local gui = Instance.new("ScreenGui")
	gui.Name = "Fear"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1
	makeEdge(gui, 0, UDim2.fromScale(0, 0), UDim2.fromScale(0.22, 1))
	makeEdge(gui, 180, UDim2.fromScale(0.78, 0), UDim2.fromScale(0.22, 1))
	makeEdge(gui, 90, UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.25))
	makeEdge(gui, 270, UDim2.fromScale(0, 0.75), UDim2.fromScale(1, 0.25))
	gui.Parent = player:WaitForChild("PlayerGui")

	task.spawn(function()
		local folder = workspace:WaitForChild("Lurkers")
		folder.ChildAdded:Connect(watchAnchor)
		folder.ChildRemoved:Connect(function(anchor)
			anchors[anchor] = nil
		end)
		for _, anchor in folder:GetChildren() do
			watchAnchor(anchor)
		end
	end)

	RunService.RenderStepped:Connect(step)
	RunService:BindToRenderStep("FearShake", Enum.RenderPriority.Camera.Value + 1, function(dt)
		if shake <= 0 or DeathScene.playing() then
			shake = 0
			return
		end
		local camera = workspace.CurrentCamera
		camera.CFrame *= CFrame.Angles((math.random() - 0.5) * 2 * shake, (math.random() - 0.5) * 2 * shake, 0)
		shake = math.max(0, shake - dt * 0.08)
	end)
end

return Fear
