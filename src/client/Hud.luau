-- The on-screen HUD, in the candy style of the Hud board in the Look Book:
--
--   top left      pearls, and which stage you are on
--   top middle    the run timer, and "IT HEARD YOU" while something hunts you
--   top right     the difficulty buttons
--   left          the noise meter (only in the stages)
--   bottom        the shop button
--   bottom right  pebble, Updraft and Hush buttons (only in the stages)
--
-- plus short notifications and the escape screen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Candy = require(ReplicatedStorage.Shared.Candy)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Stages = require(ReplicatedStorage.Shared.Stages)
local Boosts = require(script.Parent.Boosts)
local ItemIcons = require(script.Parent.ItemIcons)
local ShopUi = require(script.Parent.ShopUi)
local Throw = require(script.Parent.Throw)

local player = Players.LocalPlayer

local INK, WHITE, MUTED = Candy.INK, Candy.WHITE, Candy.MUTED
local RED = Color3.fromRGB(255, 60, 60)
local DIFFICULTY_COLORS = { Easy = Candy.MINT, Normal = Candy.LEMON, Hard = Candy.PINK }
local SEGMENTS = 6 -- in the noise meter
local MARGIN = 16

local Hud = {}

local create, text = Candy.create, Candy.text

local function textWidth(value, size, font)
	return TextService:GetTextSize(value, size, font or Enum.Font.FredokaOne, Vector2.new(2000, 100)).X
end

-- A round button with a picture, a name under it, a key hint and a count.
-- Returns the face and its count badge.
local function actionButton(parent, size, position, color, name, key, drawIcon)
	local face = Candy.button(parent, {
		name = name,
		anchor = Vector2.new(1, 1),
		position = position,
		size = UDim2.fromOffset(size, size + Candy.LIP),
		radius = size / 2,
		outline = 4,
		color = color,
	})
	face.Label.AnchorPoint = Vector2.new(0.5, 1)
	face.Label.Position = UDim2.new(0.5, 0, 1, -size * 0.14)
	face.Label.Size = UDim2.new(0.8, 0, 0, size * 0.15)
	face.Label.Text = string.upper(name)
	local well = create("Frame", {
		Name = "Picture",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(size * 0.5, size * 0.5),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = face,
	})
	drawIcon(well)
	-- The key on the top left, how many you have on the top right.
	if UserInputService.KeyboardEnabled then
		Candy.badge(face.Parent, key, 30, UDim2.fromOffset(-4, -4))
	end
	local count = Candy.badge(face.Parent, "", 30, UDim2.new(1, 4, 0, -4), Vector2.new(1, 0), Candy.LEMON)
	return face, count
end

function Hud.start()
	local gui = create("ScreenGui", {
		Name = "Hud",
		ResetOnSpawn = false,
		DisplayOrder = 2,
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

	-- Top left: pearls, and the stage under them --------------------------------

	local pearlsPill = Candy.raised(gui, { name = "Pearls", position = UDim2.fromOffset(MARGIN, 12), size = UDim2.fromOffset(150, 59), radius = 27 })
	Candy.pearl(pearlsPill, 40, UDim2.new(0, 7, 0.5, 0), Vector2.new(0, 0.5))
	local pearlsLabel = text({
		Name = "Count",
		Position = UDim2.fromOffset(56, 0),
		Size = UDim2.new(1, -66, 1, 0),
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "0",
		Parent = pearlsPill,
	})

	local stagePill = create("Frame", {
		Name = "Stage",
		Position = UDim2.fromOffset(MARGIN, 82),
		Size = UDim2.fromOffset(0, 38),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = WHITE,
		Parent = gui,
	}, {
		Candy.corner(UDim.new(0.5, 0)),
		Candy.stroke(3),
		create("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }),
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local stageLabel = text({ LayoutOrder = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), TextSize = 17, Text = "", Parent = stagePill })
	text({ LayoutOrder = 2, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), TextSize = 17, TextColor3 = MUTED, Text = "·", Parent = stagePill })
	local stageName = text({ LayoutOrder = 3, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), TextSize = 17, TextColor3 = MUTED, Text = "", Parent = stagePill })

	-- Top middle: run timer and the warning ------------------------------------

	local timerPill = Candy.raised(gui, {
		name = "Timer",
		anchor = Vector2.new(0.5, 0),
		position = UDim2.new(0.5, 0, 0, 12),
		size = UDim2.fromOffset(160, 59),
		radius = 27,
	})
	local runTimer = text({ Size = UDim2.fromScale(1, 1), Font = Enum.Font.RobotoMono, TextSize = 26, Text = "", Parent = timerPill })

	local warning = create("CanvasGroup", {
		Name = "Warning",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 80),
		Size = UDim2.fromOffset(250, 52),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Parent = gui,
	})
	local warningBody = Candy.raised(warning, { position = UDim2.fromOffset(4, 4), size = UDim2.new(1, -8, 1, -6), color = Candy.PINK, radius = 14, lip = 4, outline = 3 })
	text({ Position = UDim2.fromScale(0.08, 0.2), Size = UDim2.fromScale(0.84, 0.6), Text = "IT HEARD YOU", Parent = warningBody })

	-- Top right: difficulty ------------------------------------------------------

	local difficultyBar = Candy.raised(gui, {
		name = "Difficulty",
		anchor = Vector2.new(1, 0),
		position = UDim2.new(1, -MARGIN, 0, 12),
		size = UDim2.fromOffset(3 * 86 + 10, 57),
		radius = 26,
	})
	local difficultyButtons = {}
	for name, difficulty in Config.Difficulties do
		local btn = create("TextButton", {
			Name = name,
			Position = UDim2.fromOffset(5 + (difficulty.order - 1) * 86, 4),
			Size = UDim2.fromOffset(84, 44),
			BackgroundColor3 = DIFFICULTY_COLORS[name] or Candy.MINT,
			AutoButtonColor = false,
			Font = Enum.Font.FredokaOne,
			TextSize = 18,
			TextColor3 = INK,
			Text = name,
			Parent = difficultyBar,
		}, { Candy.corner(UDim.new(0.5, 0)), Candy.stroke(3) })
		btn.Activated:Connect(function()
			Remotes.SetDifficulty:FireServer(name)
		end)
		difficultyButtons[name] = btn
	end

	-- Left: the noise meter ------------------------------------------------------

	local noisePanel = Candy.raised(gui, {
		name = "Noise",
		anchor = Vector2.new(0, 0.5),
		position = UDim2.new(0, MARGIN, 0.5, 0),
		size = UDim2.fromOffset(72, 169),
		radius = 20,
	})
	local segments = {}
	for i = 1, SEGMENTS do
		-- Segments loud enough to be grabbed at are pink.
		local threshold = i / SEGMENTS * Config.Noise.Max
		local color = if threshold > Config.Lurker.LungeNoise then Candy.PINK elseif i > 2 then Candy.LEMON else Candy.MINT
		segments[i] = {
			color = color,
			frame = create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 14 + (SEGMENTS - i) * 19),
				Size = UDim2.fromOffset(34, 14),
				BackgroundColor3 = Candy.DIM,
				Parent = noisePanel,
			}, { Candy.corner(4) }),
		}
	end
	local noiseLabel = text({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, -8, 0, 16),
		TextSize = 13,
		Text = "NOISE",
		Parent = noisePanel,
	})

	-- Bottom: the shop button ----------------------------------------------------

	local dock = create("Frame", {
		Name = "Dock",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(120, 124),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.8,
		Parent = gui,
	}, { Candy.corner(28) })
	local shopButton = Candy.button(dock, {
		name = "Shop",
		anchor = Vector2.new(0.5, 0),
		position = UDim2.new(0.5, 0, 0, 12),
		size = UDim2.fromOffset(92, 101),
		radius = 20,
		outline = 4,
		text = "SHOP",
		color = Candy.LEMON,
	})
	shopButton.Label.AnchorPoint = Vector2.new(0.5, 1)
	shopButton.Label.Position = UDim2.new(0.5, 0, 1, -10)
	shopButton.Label.Size = UDim2.new(1, -16, 0, 17)
	-- A little shop stall: a striped awning with a scalloped edge over a
	-- counter with a pearl on it.
	local stall = create("Frame", {
		Name = "Stall",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(48, 46),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = shopButton,
	})
	create("Frame", {
		Name = "Counter",
		Position = UDim2.fromOffset(5, 18),
		Size = UDim2.fromOffset(38, 26),
		BackgroundColor3 = WHITE,
		ZIndex = 3,
		Parent = stall,
	}, { Candy.corner(4), Candy.stroke(3) })
	local awning = create("Frame", {
		Name = "Awning",
		Size = UDim2.fromOffset(48, 14),
		BackgroundColor3 = WHITE,
		ClipsDescendants = true,
		ZIndex = 4,
		Parent = stall,
	}, { Candy.stroke(3) })
	for i = 0, 3 do
		create("Frame", {
			Position = UDim2.fromOffset(i * 12, 0),
			Size = UDim2.fromOffset(12, 14),
			BackgroundColor3 = if i % 2 == 0 then Candy.PINK else WHITE,
			BorderSizePixel = 0,
			ZIndex = 4,
			Parent = awning,
		})
		create("Frame", {
			Position = UDim2.fromOffset(i * 12, 8),
			Size = UDim2.fromOffset(12, 12),
			BackgroundColor3 = if i % 2 == 0 then Candy.PINK else WHITE,
			ZIndex = 3,
			Parent = stall,
		}, { Candy.corner(UDim.new(0.5, 0)), Candy.stroke(2.5) })
	end
	Candy.pearl(stall, 14, UDim2.fromOffset(17, 26)).ZIndex = 5
	if UserInputService.KeyboardEnabled then
		Candy.badge(shopButton.Parent, "B", 30, UDim2.fromOffset(-6, -6))
	end
	shopButton.Activated:Connect(function()
		ShopUi.toggle()
	end)

	-- Bottom right: pebble and boost buttons -------------------------------------

	-- Lifted clear of the jump button on touch screens.
	local actionsLift = if UserInputService.TouchEnabled then 150 else 0
	local actions = create("Frame", {
		Name = "Actions",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -24 - actionsLift),
		Size = UDim2.fromOffset(250, 250),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local pebbleButton, pebbleCount = actionButton(actions, 112, UDim2.fromScale(1, 1), Candy.LEMON, "Pebble", "E", function(well)
		local stone = create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.55),
			Size = UDim2.fromScale(0.8, 0.6),
			BackgroundColor3 = Color3.fromRGB(176, 178, 196),
			ZIndex = 4,
			Parent = well,
		}, { Candy.corner(UDim.new(0.5, 0)), Candy.stroke(3) })
		create("Frame", {
			Position = UDim2.fromScale(0.2, 0.18),
			Size = UDim2.fromScale(0.3, 0.25),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.3,
			ZIndex = 5,
			Parent = stone,
		}, { Candy.corner(UDim.new(0.5, 0)) })
	end)
	pebbleButton.Activated:Connect(Throw.fromButton)

	local boostButtons = {}
	for _, boost in {
		{ id = "updraft", name = "Updraft", key = "Q", color = Candy.MINT, position = UDim2.new(1, -130, 1, -6) },
		{ id = "hush", name = "Hush", key = "F", color = Candy.PINK, position = UDim2.new(1, -12, 1, -130) },
	} do
		local face, count = actionButton(actions, 88, boost.position, boost.color, boost.name, boost.key, function(well)
			ItemIcons.draw(well, { kind = "boost", id = boost.id, swatch = WHITE })
		end)
		face.Activated:Connect(function()
			Boosts.use(boost.id)
		end)
		boostButtons[boost.id] = { face = face, count = count }
	end

	-- Notifications --------------------------------------------------------------

	local toast = create("CanvasGroup", {
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.2),
		Size = UDim2.fromOffset(300, 54),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Parent = gui,
	})
	local toastBody = Candy.raised(toast, { position = UDim2.fromOffset(4, 4), size = UDim2.new(1, -8, 1, -6), radius = 22, lip = 4, outline = 3 })
	local toastText = text({ Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -32, 1, 0), TextSize = 20, Text = "", Parent = toastBody })

	-- Escape screen --------------------------------------------------------------

	local winBody = Candy.raised(gui, {
		name = "Escaped",
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5),
		size = UDim2.fromOffset(420, 290),
		radius = 28,
		lip = 8,
		outline = 5,
	})
	local winPanel = winBody.Parent
	winPanel.Visible = false
	Candy.fit(winPanel, Vector2.new(430, 300), 24)
	local winHeader = create("Frame", {
		Size = UDim2.new(1, 0, 0, 78),
		BackgroundColor3 = Candy.SKY,
		Parent = winBody,
	}, { Candy.corner(28) })
	create("Frame", { Position = UDim2.new(0, 0, 1, -28), Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = Candy.SKY, BorderSizePixel = 0, Parent = winHeader })
	create("Frame", { Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = INK, BorderSizePixel = 0, Parent = winHeader })
	Candy.title(winHeader, {
		Position = UDim2.fromOffset(20, 12),
		Size = UDim2.new(1, -40, 0, 50),
		TextColor3 = Candy.LEMON,
		Text = "YOU MADE IT OUT",
	}, 3, 4)
	local winDetails = text({
		Position = UDim2.fromOffset(24, 96),
		Size = UDim2.new(1, -48, 0, 92),
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = MUTED,
		TextWrapped = true,
		Text = "",
		Parent = winBody,
	})
	local playAgain = Candy.button(winBody, {
		position = UDim2.new(0, 24, 1, -82),
		size = UDim2.new(0.5, -30, 0, 60),
		radius = 28,
		text = "Play again",
		color = Candy.MINT,
	})
	local close = Candy.button(winBody, {
		position = UDim2.new(0.5, 6, 1, -82),
		size = UDim2.new(0.5, -30, 0, 60),
		radius = 28,
		text = "Close",
		color = WHITE,
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
			stageLabel.Text = "The way out"
			stageName.Text = "Walk into the light"
		else
			local index = checkpoint + 1
			stageLabel.Text = ("Stage %d of %d"):format(index, #Stages)
			stageName.Text = Stages[index].name
		end
	end

	local function updatePebbles()
		local count = player:GetAttribute("Pebbles") or 0
		pebbleCount.Label.Text = tostring(count)
		Candy.paint(pebbleButton, if count > 0 then Candy.LEMON else Candy.CLOUD, if count > 0 then INK else MUTED, count == 0)
	end

	local function updatePearls()
		local pearls = tostring(player:GetAttribute("Pearls") or 0)
		pearlsLabel.Text = pearls
		pearlsPill.Parent.Size = UDim2.fromOffset(math.max(110, 56 + textWidth(pearls, 26) + 22), 59)
	end

	local function updateBoosts()
		for id, button in boostButtons do
			local count = player:GetAttribute("Boost_" .. id) or 0
			button.face.Parent.Visible = count > 0
			button.count.Label.Text = tostring(count)
		end
	end

	local function updateHushed()
		noiseLabel.Text = if player:GetAttribute("Hushed") then "HUSHED" else "NOISE"
	end

	local function updateDifficulty()
		local current = player:GetAttribute("Difficulty") or Config.DefaultDifficulty
		for name, btn in difficultyButtons do
			local on = name == current
			btn.BackgroundTransparency = if on then 0 else 1
			btn.UIStroke.Enabled = on
			btn.TextColor3 = if on then INK else MUTED
		end
	end

	local function updateHunted()
		local hunted = player:GetAttribute("Hunted") == true
		local info = TweenInfo.new(if hunted then 0.2 else 0.8)
		TweenService:Create(warning, info, { GroupTransparency = if hunted then 0 else 1 }):Play()
		-- Light enough that you can still see it coming.
		TweenService:Create(danger, info, { BackgroundTransparency = if hunted then 0.9 else 1 }):Play()
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
		toastText.Text = message
		toast.Size = UDim2.fromOffset(textWidth(message, 20) + 48, 54)
		toast.GroupTransparency = 0
		task.delay(3, function()
			if id == toastId then
				TweenService:Create(toast, TweenInfo.new(0.6), { GroupTransparency = 1 }):Play()
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
	player:GetAttributeChangedSignal("Pearls"):Connect(updatePearls)
	player:GetAttributeChangedSignal("Boost_updraft"):Connect(updateBoosts)
	player:GetAttributeChangedSignal("Boost_hush"):Connect(updateBoosts)
	player:GetAttributeChangedSignal("Hushed"):Connect(updateHushed)
	updateStage()
	updatePebbles()
	updateDifficulty()
	updatePearls()
	updateBoosts()
	updateHushed()
	updateHunted()
	task.spawn(function()
		workspace:WaitForChild("Map")
		hideFoundShells()
	end)

	-- The lobby and the way out start where Mood.luau says they do.
	local exitZ = 0
	for _, stage in Stages do
		exitZ += stage.length
	end

	local shown = 0
	RunService.RenderStepped:Connect(function(dt)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local inStages = root ~= nil and root.Position.Z >= 0 and root.Position.Z < exitZ
		noisePanel.Parent.Visible = inStages
		actions.Visible = inStages

		local target = (player:GetAttribute("Noise") or 0) / Config.Noise.Max
		shown += (target - shown) * math.min(1, dt * 10)
		local lit = if shown > 0.02 then math.max(1, math.round(shown * SEGMENTS)) else 0
		local hushed = player:GetAttribute("Hushed")
		for i, segment in segments do
			segment.frame.BackgroundColor3 = if i > lit then Candy.DIM elseif hushed then Candy.LILAC else segment.color
		end

		local started = player:GetAttribute("RunStartedAt")
		timerPill.Parent.Visible = started ~= nil
		runTimer.Text = if started then Format.time(workspace:GetServerTimeNow() - started) else ""
	end)
end

return Hud
