-- The on-screen HUD: stage name, noise meter, pebbles, difficulty buttons,
-- the "it heard you" warning, short notifications and the escape screen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Stages = require(ReplicatedStorage.Shared.Stages)

local player = Players.LocalPlayer

local WHITE = Color3.fromRGB(240, 246, 248)
local RED = Color3.fromRGB(255, 60, 60)
local PANEL = Color3.fromRGB(14, 22, 26)

local Hud = {}

local function create(className, props, children)
	local instance = Instance.new(className)
	for key, value in props do
		instance[key] = value
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	return instance
end

local function text(props)
	local label = create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = WHITE,
		TextStrokeTransparency = 0.6,
		TextSize = 16,
	})
	for key, value in props do
		label[key] = value
	end
	return label
end

local function corner(radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function button(props)
	local btn = create("TextButton", {
		AutoButtonColor = true,
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.25,
		Font = Enum.Font.GothamBold,
		TextColor3 = WHITE,
		TextSize = 14,
	}, { corner(6) })
	for key, value in props do
		btn[key] = value
	end
	return btn
end

function Hud.start()
	local gui = create("ScreenGui", {
		Name = "Hud",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})

	-- Red wash behind everything while something is hunting you.
	local danger = create("Frame", {
		Name = "Danger",
		BackgroundColor3 = RED,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, -60),
		Size = UDim2.new(1, 0, 1, 60),
		Parent = gui,
	})
	local warning = text({
		Name = "Warning",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(500, 50),
		Font = Enum.Font.GothamBlack,
		TextSize = 34,
		TextColor3 = RED,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Text = "IT HEARD YOU",
		Parent = gui,
	})

	-- Stage name
	local stageLabel = text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(400, 24),
		TextSize = 20,
		Parent = gui,
	})
	local stageName = text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 32),
		Size = UDim2.fromOffset(400, 18),
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		TextTransparency = 0.2,
		Parent = gui,
	})

	-- Noise meter
	local meter = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(260, 10),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Parent = gui,
	}, { corner(5) })
	local fill = create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Parent = meter,
	}, { corner(5) })
	create("Frame", {
		Name = "LungeMark",
		Position = UDim2.fromScale(Config.Lurker.LungeNoise / Config.Noise.Max, 0),
		Size = UDim2.new(0, 2, 1, 0),
		BackgroundColor3 = RED,
		BorderSizePixel = 0,
		Parent = meter,
	})
	text({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -4),
		Size = UDim2.new(1, 0, 0, 16),
		TextSize = 12,
		Text = "NOISE",
		Parent = meter,
	})
	local pebbleLabel = text({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -22),
		Size = UDim2.new(2, 0, 0, 18),
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		Parent = meter,
	})

	-- Difficulty buttons
	local difficultyBar = create("Frame", {
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(240, 30),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local difficultyButtons = {}
	for name, difficulty in Config.Difficulties do
		local btn = button({
			Name = name,
			LayoutOrder = difficulty.order,
			Size = UDim2.fromOffset(74, 28),
			Text = name,
			Parent = difficultyBar,
		})
		btn.Activated:Connect(function()
			Remotes.SetDifficulty:FireServer(name)
		end)
		difficultyButtons[name] = btn
	end

	-- Notifications
	local toast = text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.16),
		Size = UDim2.fromOffset(500, 30),
		TextSize = 22,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Parent = gui,
	})

	-- Escape screen
	local winPanel = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(340, 190),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = gui,
	}, { corner(10) })
	text({
		Position = UDim2.fromOffset(0, 18),
		Size = UDim2.new(1, 0, 0, 34),
		Font = Enum.Font.GothamBlack,
		TextSize = 28,
		Text = "YOU MADE IT OUT",
		Parent = winPanel,
	})
	local winDetails = text({
		Position = UDim2.fromOffset(16, 60),
		Size = UDim2.new(1, -32, 0, 50),
		Font = Enum.Font.GothamMedium,
		TextSize = 15,
		TextWrapped = true,
		Parent = winPanel,
	})
	local playAgain = button({
		Position = UDim2.new(0, 20, 1, -56),
		Size = UDim2.new(0.5, -26, 0, 38),
		BackgroundColor3 = Color3.fromRGB(60, 150, 120),
		BackgroundTransparency = 0,
		Text = "Play again",
		Parent = winPanel,
	})
	local close = button({
		Position = UDim2.new(0.5, 6, 1, -56),
		Size = UDim2.new(0.5, -26, 0, 38),
		Text = "Close",
		Parent = winPanel,
	})
	playAgain.Activated:Connect(function()
		winPanel.Visible = false
		Remotes.Restart:FireServer()
	end)
	close.Activated:Connect(function()
		winPanel.Visible = false
	end)

	gui.Parent = player:WaitForChild("PlayerGui")

	-- Updating ----------------------------------------------------------------

	local function updateStage()
		local checkpoint = player:GetAttribute("Checkpoint") or 0
		if checkpoint >= #Stages then
			stageLabel.Text = "THE WAY OUT"
			stageName.Text = "Walk into the light"
		else
			local index = checkpoint + 1
			stageLabel.Text = ("STAGE %d / %d"):format(index, #Stages)
			stageName.Text = Stages[index].name
		end
	end

	local function updatePebbles()
		local count = player:GetAttribute("Pebbles") or 0
		local hint = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then "tap Throw" else "E to throw"
		pebbleLabel.Text = ("Pebbles: %d   ·   %s"):format(count, hint)
	end

	local function updateDifficulty()
		local current = player:GetAttribute("Difficulty") or Config.DefaultDifficulty
		for name, btn in difficultyButtons do
			btn.BackgroundColor3 = if name == current then Color3.fromRGB(60, 150, 120) else PANEL
		end
	end

	local function updateHunted()
		local hunted = player:GetAttribute("Hunted") == true
		local info = TweenInfo.new(if hunted then 0.2 else 0.8)
		TweenService:Create(warning, info, {
			TextTransparency = if hunted then 0 else 1,
			TextStrokeTransparency = if hunted then 0.5 else 1,
		}):Play()
		TweenService:Create(danger, info, { BackgroundTransparency = if hunted then 0.82 else 1 }):Play()
	end

	-- Hide shells this player has already collected (only on their screen).
	local function hideFoundShells()
		local found = {}
		for index in string.gmatch(player:GetAttribute("ShellsFound") or "", "%d+") do
			found[tonumber(index)] = true
		end
		local map = workspace:FindFirstChild("Map")
		if not map then
			return
		end
		for _, part in map:GetDescendants() do
			local stage = part:GetAttribute("ShellStage")
			if stage then
				local isFound = found[stage] == true
				part.LocalTransparencyModifier = if isFound then 1 else 0
				local glow = part:FindFirstChildOfClass("PointLight")
				if glow then
					glow.Enabled = not isFound
				end
			end
		end
	end

	local toastId = 0
	local function showToast(message)
		toastId += 1
		local id = toastId
		toast.Text = message
		toast.TextTransparency = 0
		toast.TextStrokeTransparency = 0.6
		task.delay(3, function()
			if id == toastId then
				TweenService:Create(toast, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			end
		end)
	end

	Remotes.Notify.OnClientEvent:Connect(function(kind, message)
		if kind == "win" then
			winDetails.Text = message
			winPanel.Visible = true
		else
			showToast(message)
		end
	end)

	player:GetAttributeChangedSignal("Checkpoint"):Connect(updateStage)
	player:GetAttributeChangedSignal("Pebbles"):Connect(updatePebbles)
	player:GetAttributeChangedSignal("Difficulty"):Connect(updateDifficulty)
	player:GetAttributeChangedSignal("Hunted"):Connect(updateHunted)
	player:GetAttributeChangedSignal("ShellsFound"):Connect(hideFoundShells)
	updateStage()
	updatePebbles()
	updateDifficulty()
	task.spawn(function()
		workspace:WaitForChild("Map")
		hideFoundShells()
	end)

	local shown = 0
	RunService.RenderStepped:Connect(function(dt)
		local target = (player:GetAttribute("Noise") or 0) / Config.Noise.Max
		shown += (target - shown) * math.min(1, dt * 10)
		fill.Size = UDim2.fromScale(shown, 1)
		fill.BackgroundColor3 = WHITE:Lerp(RED, shown)
	end)
end

return Hud
