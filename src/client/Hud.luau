-- The on-screen HUD, made of the SpriteCook UI kit's art (shared/Candy.luau):
--
--   top left      which stage you are on
--   bottom left   coins (its + opens the shop); top left on touch screens,
--                 clear of the thumbstick
--   top middle    the run timer, and "IT HEARD YOU" while something hunts you
--   top right     the difficulty buttons
--   left          big Shop and Bag buttons (side by side on touch screens,
--                 above the thumbstick), or out in the forest the noise meter
--   right         the Christmas Bundle (LIMITED, with how long is left),
--                 2x Coins and Join (the game's community, until its reward
--                 is paid), and Stats, Settings and Invite (not out in the
--                 forest: in the lobby, the cave and the way out); on touch
--                 screens in two rows near the top, clear of the jump button
--   bottom right  pebble, Updraft and Hush buttons (only out in the forest);
--                 in the Christmas lobby, the snowball button. On touch
--                 screens they sit left of the jump button.
--
-- plus short notifications and the escape screen. On small screens it all
-- shrinks to fit (ScreenFit.luau).

local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Candy = require(ReplicatedStorage.Shared.Candy)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Stages = require(ReplicatedStorage.Shared.Stages)
local Zones = require(ReplicatedStorage.Shared.Zones)
local Boosts = require(script.Parent.Boosts)
local SettingsUi = require(script.Parent.SettingsUi)
local Sounds = require(script.Parent.Sounds)
local ChristmasBundle = require(script.Parent.ChristmasBundle)
local ScreenFit = require(script.Parent.ScreenFit)
local ShopUi = require(script.Parent.ShopUi)
local StatsUi = require(script.Parent.StatsUi)
local Throw = require(script.Parent.Throw)

local player = Players.LocalPlayer

local INK, WHITE, MUTED = Candy.INK, Candy.WHITE, Candy.MUTED
local RED = Color3.fromRGB(255, 60, 60)
local GREYED = Color3.fromRGB(150, 150, 165) -- tints an action button with none left
local DIFFICULTY_COLORS = { Easy = Candy.MINT, Normal = Candy.LEMON, Hard = Candy.PINK }
local SEGMENTS = 6 -- in the noise meter
local MARGIN = 16
local SIDE_BUTTON = 112 -- Shop and Bag, on the left
local GRID_BUTTON = 92 -- the buttons on the right
local GRID_GAP = 12
-- On touch screens (small, and pointed at with fingers) the buttons are drawn
-- smaller, and the coins, difficulty, timer and noise meter a little smaller.
local TOUCH_BUTTONS = 0.75
local TOUCH_BARS = 0.85

local Hud = {}

local create, text = Candy.create, Candy.text

local function textWidth(value, size, font)
	return TextService:GetTextSize(value, size, font or Enum.Font.FredokaOne, Vector2.new(2000, 100)).X
end

-- A picture button from the kit with its name across its bottom edge.
local function pictureButton(parent, art, name, size, props)
	local face = create("ImageButton", {
		Name = name,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Size = UDim2.fromOffset(size, size),
		Parent = parent,
	})
	Candy.setArt(face, art, size)
	for key, value in props or {} do
		face[key] = value
	end
	face.Activated:Connect(Candy.click)
	Candy.outlined({
		Name = "Caption",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, -size * 0.06),
		Size = UDim2.new(1, 6, 0, size * 0.22),
		TextColor3 = WHITE,
		Text = string.upper(name),
		ZIndex = 4,
		Parent = face,
	}, 2.5)
	face.MouseButton1Down:Connect(function()
		face.Size = UDim2.fromOffset(size * 0.94, size * 0.94)
	end)
	for _, signal in { face.MouseButton1Up, face.MouseLeave } do
		signal:Connect(function()
			face.Size = UDim2.fromOffset(size, size)
		end)
	end
	return face
end

-- Asks Roblox to show the invite-friends prompt.
local function inviteFriends()
	local ok, canInvite = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
	if ok and canInvite then
		pcall(SocialService.PromptGameInvite, SocialService, player)
	end
end

-- Asks Roblox to show the prompt to join the game's community, then asks
-- the server to check with Roblox and pay the reward (server/Community.luau).
local function joinCommunity()
	local ok, err = pcall(GroupService.PromptJoinAsync, GroupService, Config.Community.GroupId)
	if not ok then
		warn("[Hud] Could not show the community prompt:", err)
		return
	end
	Remotes.ClaimCommunity:FireServer()
end

function Hud.start()
	local gui = create("ScreenGui", {
		Name = "Hud",
		ResetOnSpawn = false,
		DisplayOrder = 2,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})

	-- Red wash behind everything while something is hunting you. On a screen
	-- of its own that ignores the safe area, so it reaches into a phone's
	-- notch strips too.
	local danger = create("Frame", {
		Name = "Danger",
		BackgroundColor3 = RED,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = create("ScreenGui", {
			Name = "Danger",
			ResetOnSpawn = false,
			DisplayOrder = 1,
			ScreenInsets = Enum.ScreenInsets.None,
			Parent = player:WaitForChild("PlayerGui"),
		}),
	})

	-- Everything else but the escape screen (which fits itself) shrinks on
	-- small screens.
	local fit, fitScale = ScreenFit.frame(gui)

	-- Bottom left: coins (top left on touch screens); top left: the stage ----

	local touch = UserInputService.TouchEnabled
	-- Shrinks a thing towards its anchor point on touch screens.
	local function shrinkOnTouch(object, scale)
		if touch then
			create("UIScale", { Scale = scale, Parent = object })
		end
	end

	local coinsPill = Candy.art("coin_counter", {
		Name = "Coins",
		AnchorPoint = Vector2.new(0, if touch then 0 else 1),
		Position = if touch then UDim2.fromOffset(MARGIN, 10) else UDim2.new(0, MARGIN, 1, -MARGIN),
		Size = UDim2.fromOffset(200, 64),
		Parent = fit,
	}, 64)
	shrinkOnTouch(coinsPill, TOUCH_BARS)
	local coinsLabel = text({
		Name = "Count",
		Position = UDim2.fromOffset(66, 6),
		Size = UDim2.new(1, -122, 1, -14),
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "0",
		Parent = coinsPill,
	})
	local moreCoins = create("TextButton", {
		Name = "More",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 56, 1, 0),
		BackgroundTransparency = 1,
		Text = "",
		Parent = coinsPill,
	})
	moreCoins.Activated:Connect(function()
		Candy.click()
		ShopUi.open("shop", "robux")
	end)

	local stagePill = Candy.art("button_white", {
		Name = "Stage",
		Position = UDim2.fromOffset(MARGIN, if touch then 72 else 12),
		Size = UDim2.fromOffset(0, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = fit,
	}, 40)
	create("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18), PaddingBottom = UDim.new(0, 4), Parent = stagePill })
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = stagePill,
	})
	local stageLabel = text({ LayoutOrder = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), TextSize = 17, Text = "", Parent = stagePill })
	text({ LayoutOrder = 2, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), TextSize = 17, TextColor3 = MUTED, Text = "·", Parent = stagePill })
	local stageName = text({ LayoutOrder = 3, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), TextSize = 17, TextColor3 = MUTED, Text = "", Parent = stagePill })

	-- Top middle: run timer and the warning ------------------------------------

	local timerPill = Candy.raised(fit, {
		name = "Timer",
		anchor = Vector2.new(0.5, 0),
		position = UDim2.new(0.5, 0, 0, 12),
		size = UDim2.fromOffset(160, 59),
	})
	shrinkOnTouch(timerPill.Parent, TOUCH_BARS)
	local runTimer = text({ Size = UDim2.fromScale(1, 1), Font = Enum.Font.RobotoMono, TextSize = 26, Text = "", Parent = timerPill })

	local warning = create("CanvasGroup", {
		Name = "Warning",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 80),
		Size = UDim2.fromOffset(250, 58),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Parent = fit,
	})
	local warningBody = Candy.raised(warning, { size = UDim2.fromScale(1, 1), color = Candy.PINK, lip = 6 })
	text({ Position = UDim2.fromScale(0.1, 0.22), Size = UDim2.fromScale(0.8, 0.56), Text = "IT HEARD YOU", Parent = warningBody })

	-- Top right: difficulty ------------------------------------------------------

	local difficultyBar = Candy.raised(fit, {
		name = "Difficulty",
		anchor = Vector2.new(1, 0),
		position = UDim2.new(1, -MARGIN, 0, 12),
		size = UDim2.fromOffset(3 * 88 + 16, 64),
	})
	shrinkOnTouch(difficultyBar.Parent, TOUCH_BARS)
	local difficultyButtons = {}
	for name, difficulty in Config.Difficulties do
		local face = Candy.button(difficultyBar, {
			name = name,
			position = UDim2.fromOffset(8 + (difficulty.order - 1) * 88, 6),
			size = UDim2.fromOffset(86, 46),
			text = name,
			color = DIFFICULTY_COLORS[name],
		})
		face.Activated:Connect(function()
			Remotes.SetDifficulty:FireServer(name)
		end)
		difficultyButtons[name] = face
	end

	-- Left: the noise meter ------------------------------------------------------

	local noisePanel = Candy.raised(fit, {
		name = "Noise",
		anchor = Vector2.new(0, 0.5),
		position = UDim2.new(0, MARGIN, 0.5, 0),
		size = UDim2.fromOffset(76, 176),
	})
	shrinkOnTouch(noisePanel.Parent, TOUCH_BARS)
	local segments = {}
	for i = 1, SEGMENTS do
		-- Segments loud enough to be grabbed at are pink.
		local threshold = i / SEGMENTS * Config.Noise.Max
		local art = if threshold > Config.Lurker.LungeNoise then "button_pink" elseif i > 2 then "button_lemon" else "button_mint"
		segments[i] = {
			art = art,
			shown = "button_white",
			image = Candy.art("button_white", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 12 + (SEGMENTS - i) * 21),
				Size = UDim2.fromOffset(42, 20),
				ZIndex = 2,
				Parent = noisePanel,
			}, 20),
		}
	end
	local noiseLabel = text({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.new(1, -12, 0, 16),
		TextSize = 13,
		Text = "NOISE",
		Parent = noisePanel,
	})

	-- Left: Shop and Bag, big ----------------------------------------------------
	-- On touch screens side by side under the stage, so a thumb on the
	-- thumbstick doesn't open them.

	local leftDock = create("Frame", {
		Name = "LeftDock",
		AnchorPoint = Vector2.new(0, if touch then 0 else 0.5),
		Position = if touch then UDim2.fromOffset(MARGIN, 124) else UDim2.new(0, MARGIN, 0.5, 0),
		Size = if touch
			then UDim2.fromOffset(SIDE_BUTTON * 2 + 14, SIDE_BUTTON)
			else UDim2.fromOffset(SIDE_BUTTON, SIDE_BUTTON * 2 + 14),
		BackgroundTransparency = 1,
		Parent = fit,
	}, {
		create("UIListLayout", {
			FillDirection = if touch then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 14),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	shrinkOnTouch(leftDock, TOUCH_BUTTONS)
	local shopButton = pictureButton(leftDock, "dock_shop", "Shop", SIDE_BUTTON, { LayoutOrder = 1 })
	shopButton.Activated:Connect(function()
		ShopUi.open("shop")
	end)
	if UserInputService.KeyboardEnabled then
		Candy.badge(shopButton, "B", 30, UDim2.fromOffset(-6, -6))
	end
	local bagButton = pictureButton(leftDock, "dock_bag", "Bag", SIDE_BUTTON, { LayoutOrder = 2 })
	bagButton.Activated:Connect(function()
		ShopUi.open("bag")
	end)

	-- Right: the Christmas Bundle, 2x Coins and Join, then Stats, Settings, Invite
	-- Two columns, or on touch screens two rows from near the top, so the grid
	-- stays clear of the jump button.

	local step = GRID_BUTTON + GRID_GAP
	local rightDock = create("Frame", {
		Name = "RightDock",
		AnchorPoint = Vector2.new(1, if touch then 0 else 0.5),
		Position = if touch then UDim2.new(1, -MARGIN, 0, 100) else UDim2.new(1, -MARGIN, 0.5, 0),
		Size = if touch
			then UDim2.fromOffset(step * 3 - GRID_GAP, step * 2 + 30)
			else UDim2.fromOffset(step * 2 - GRID_GAP, step * 3 + 30),
		BackgroundTransparency = 1,
		Parent = fit,
	})
	shrinkOnTouch(rightDock, TOUCH_BUTTONS)
	local function gridButton(art, name, open)
		local face = pictureButton(rightDock, art, name, GRID_BUTTON)
		face.Activated:Connect(open)
		return face
	end
	local menuButtons = {
		gridButton("dock_stats", "Stats", StatsUi.toggle),
		gridButton("dock_settings", "Settings", SettingsUi.toggle),
		gridButton("dock_invite", "Invite", inviteFriends),
	}
	local christmasButton = gridButton("button_christmas", "Christmas", ChristmasBundle.open)
	local doubleButton = gridButton("button_double_coins", "2x Coins", function()
		ShopUi.open("shop", "pass")
	end)
	-- The coins it pays, on a lemon tag across its corner.
	local joinButton = gridButton("dock_community", "Join", joinCommunity)
	local rewardTag = Candy.badge(joinButton, "+" .. Config.Community.Reward, 30, UDim2.new(1, 8, 0, -6), Vector2.new(1, 0), Candy.LEMON)
	rewardTag.Size = UDim2.fromOffset(58, 30)
	local function updateJoin()
		joinButton.Visible = Config.Community.GroupId ~= 0 and not player:GetAttribute("CommunityRewarded")
	end
	updateJoin()
	player:GetAttributeChangedSignal("CommunityRewarded"):Connect(updateJoin)
	-- LIMITED across its corner, and how long is left under it.
	local limited = Candy.art("ribbon_red", {
		Name = "Limited",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.62, 0, 0, 4),
		Size = UDim2.fromOffset(96, 38),
		Rotation = 14,
		ZIndex = 6,
		Parent = christmasButton,
	})
	Candy.outlined({ Position = UDim2.fromScale(0.16, 0.16), Size = UDim2.fromScale(0.68, 0.52), TextColor3 = WHITE, Text = "LIMITED", ZIndex = 7, Parent = limited }, 2)
	local timeLeft = Candy.art("button_white", {
		Name = "TimeLeft",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, -2),
		Size = UDim2.fromOffset(GRID_BUTTON, 26),
		ZIndex = 5,
		Parent = christmasButton,
	}, 26)
	local timeLeftText = text({ Position = UDim2.fromScale(0.08, 0.1), Size = UDim2.fromScale(0.84, 0.66), Text = "", ZIndex = 6, Parent = timeLeft })
	local function updateChristmas()
		local onSale = ChristmasBundle.onSale()
		christmasButton.Visible = onSale
		-- 2x Coins and Join follow the bundle, or take its place once it's
		-- gone; while it's on sale, what comes under it leaves room for the
		-- time left.
		local timeLeftRoom = if onSale then 30 else 0
		for i, face in { christmasButton, doubleButton, joinButton } do
			local slot = if onSale then i - 1 else i - 2
			face.Position = if touch
				then UDim2.fromOffset(slot * step, 0)
				else UDim2.fromOffset(0, slot * step + (if slot > 0 then timeLeftRoom else 0))
		end
		for i, face in menuButtons do
			face.Position = if touch
				then UDim2.fromOffset((i - 1) * step, step + timeLeftRoom)
				else UDim2.fromOffset(step, (i - 1) * step)
		end
		local left = ChristmasBundle.timeLeft()
		timeLeftText.Text = if left then ChristmasBundle.shortTime(left) else ""
	end
	updateChristmas()
	task.spawn(function()
		while true do
			task.wait(20)
			updateChristmas()
		end
	end)

	-- Bottom right: pebble and boost buttons -------------------------------------
	-- On touch screens left of the jump button (placeActions, below).

	local actions = create("Frame", {
		Name = "Actions",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -24),
		Size = UDim2.fromOffset(250, 250),
		BackgroundTransparency = 1,
		Parent = fit,
	})
	shrinkOnTouch(actions, TOUCH_BUTTONS)
	-- A round picture button with its key on the top left and how many you
	-- have on the top right. Returns the face and its count badge.
	local function actionButton(parent, art, name, key, size, position)
		local face = pictureButton(parent, art, name, size, { AnchorPoint = Vector2.new(1, 1), Position = position })
		if UserInputService.KeyboardEnabled then
			Candy.badge(face, key, 30, UDim2.fromOffset(-4, -4))
		end
		local count = Candy.badge(face, "", 30, UDim2.new(1, 4, 0, -4), Vector2.new(1, 0), Candy.LEMON)
		return face, count
	end
	local pebbleButton, pebbleCount = actionButton(actions, "action_pebble", "Pebble", "E", 112, UDim2.fromScale(1, 1))
	pebbleButton.Activated:Connect(Throw.fromButton)

	-- In the Christmas lobby, the snowball button sits where the pebble's is.
	local snowActions = create("Frame", {
		Name = "SnowActions",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -24),
		Size = UDim2.fromOffset(112, 112),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = fit,
	})
	shrinkOnTouch(snowActions, TOUCH_BUTTONS)
	local snowButton, snowCount = actionButton(snowActions, "action_snowball", "Snowball", "E", 112, UDim2.fromScale(1, 1))
	snowButton.Activated:Connect(Throw.fromButton)

	local boostButtons = {}
	for _, boost in {
		{ id = "updraft", art = "action_updraft", name = "Updraft", key = "Q", position = UDim2.new(1, -130, 1, -6) },
		{ id = "hush", art = "action_hush", name = "Hush", key = "F", position = UDim2.new(1, -12, 1, -130) },
	} do
		local face, count = actionButton(actions, boost.art, boost.name, boost.key, 88, boost.position)
		face.Activated:Connect(function()
			Boosts.use(boost.id)
		end)
		boostButtons[boost.id] = { face = face, count = count }
	end

	-- Roblox's jump button, while it's on screen (touch screens only).
	local function jumpButton()
		local touchGui = gui.Parent and gui.Parent:FindFirstChild("TouchGui")
		local frame = touchGui and touchGui.Enabled and touchGui:FindFirstChild("TouchControlFrame")
		local button = frame and frame.Visible and frame:FindFirstChild("JumpButton")
		return if button and button.Visible then button else nil
	end

	-- In the corner, or left of the jump button with their bottoms lined up.
	-- The jump button keeps its size on small screens, so this is measured
	-- on screen, then turned back into the fit frame's unshrunk pixels.
	local function placeActions()
		local right, bottom = 24, 24
		local jump = jumpButton()
		if jump then
			local scale = fitScale.Scale
			local corner = fit.AbsolutePosition + fit.AbsoluteSize
			right = (corner.X - jump.AbsolutePosition.X) / scale + GRID_GAP
			bottom = (corner.Y - jump.AbsolutePosition.Y - jump.AbsoluteSize.Y) / scale
		end
		local position = UDim2.new(1, -right, 1, -bottom)
		actions.Position = position
		snowActions.Position = position
	end

	-- Notifications --------------------------------------------------------------

	local toast = create("CanvasGroup", {
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.2),
		Size = UDim2.fromOffset(300, 58),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Parent = fit,
	})
	local toastBody = Candy.raised(toast, { size = UDim2.fromScale(1, 1), lip = 6 })
	local toastText = text({ Position = UDim2.fromOffset(18, 0), Size = UDim2.new(1, -36, 1, 0), TextSize = 20, Text = "", Parent = toastBody })

	-- Escape screen --------------------------------------------------------------

	local winPanel, _, winClose = Candy.window(gui, { name = "Escaped", size = UDim2.fromOffset(500, 360), title = "YOU GOT OUT" })
	winPanel.Visible = false
	Candy.fit(winPanel, Vector2.new(510, 370), 24)
	local winDetails = text({
		Position = UDim2.fromOffset(Candy.WINDOW_SIDE + 4, Candy.WINDOW_TOP),
		Size = UDim2.new(1, -2 * Candy.WINDOW_SIDE - 8, 0, 120),
		Font = Enum.Font.GothamBold,
		TextSize = 17,
		TextColor3 = MUTED,
		TextWrapped = true,
		Text = "",
		Parent = winPanel,
	})
	local playAgain = Candy.button(winPanel, {
		position = UDim2.new(0, Candy.WINDOW_SIDE, 1, -Candy.WINDOW_BOTTOM - 62),
		size = UDim2.new(0.5, -Candy.WINDOW_SIDE - 6, 0, 62),
		text = "Play again",
		color = Candy.MINT,
	})
	local close = Candy.button(winPanel, {
		position = UDim2.new(0.5, 6, 1, -Candy.WINDOW_BOTTOM - 62),
		size = UDim2.new(0.5, -Candy.WINDOW_SIDE - 6, 0, 62),
		text = "Close",
	})
	playAgain.Activated:Connect(function()
		winPanel.Visible = false
		Remotes.Restart:FireServer()
	end)
	for _, button in { close, winClose } do
		button.Activated:Connect(function()
			winPanel.Visible = false
		end)
	end

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

	local function updateSnowballs()
		local count = player:GetAttribute("Snowballs") or 0
		snowCount.Label.Text = tostring(count)
		snowButton.ImageColor3 = if count > 0 then WHITE else GREYED
	end

	local function updatePebbles()
		local count = player:GetAttribute("Pebbles") or 0
		pebbleCount.Label.Text = tostring(count)
		pebbleButton.ImageColor3 = if count > 0 then WHITE else GREYED
	end

	local function updateCoins()
		local coins = tostring(player:GetAttribute("Coins") or 0)
		coinsLabel.Text = coins
		coinsPill.Size = UDim2.fromOffset(math.max(180, 66 + textWidth(coins, 28) + 66), 64)
	end

	local function updateBoosts()
		for id, button in boostButtons do
			local count = player:GetAttribute("Boost_" .. id) or 0
			button.face.Visible = count > 0
			button.count.Label.Text = tostring(count)
		end
	end

	local function updateHushed()
		noiseLabel.Text = if player:GetAttribute("Hushed") then "HUSHED" else "NOISE"
	end

	local function updateDifficulty()
		local current = player:GetAttribute("Difficulty") or Config.DefaultDifficulty
		for name, face in difficultyButtons do
			local on = name == current
			face.ImageTransparency = if on then 0 else 1
			face.Label.TextColor3 = if on then INK else MUTED
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
		toast.Size = UDim2.fromOffset(textWidth(message, 20) + 56, 58)
		toast.GroupTransparency = 0
		task.delay(3, function()
			if id == toastId then
				TweenService:Create(toast, TweenInfo.new(0.6), { GroupTransparency = 1 }):Play()
			end
		end)
	end

	-- Chimes for good news.
	local NOTIFY_SOUNDS = { checkpoint = "Checkpoint", shell = "Shell", win = "Escape", bought = "Buy", reward = "Buy" }

	Remotes.Notify.OnClientEvent:Connect(function(kind, message)
		if NOTIFY_SOUNDS[kind] then
			Sounds.play(NOTIFY_SOUNDS[kind], if kind == "win" then 0.7 else 0.6)
		end
		if kind == "downed" then
			return -- for the death screen (DeathScene.luau)
		elseif kind == "win" then
			winDetails.Text = message
			winPanel.Visible = true
		else
			showToast(message)
		end
	end)

	player:GetAttributeChangedSignal("Checkpoint"):Connect(updateStage)
	player:GetAttributeChangedSignal("Pebbles"):Connect(updatePebbles)
	player:GetAttributeChangedSignal("Snowballs"):Connect(updateSnowballs)
	player:GetAttributeChangedSignal("Difficulty"):Connect(updateDifficulty)
	player:GetAttributeChangedSignal("Hunted"):Connect(updateHunted)
	player:GetAttributeChangedSignal("ShellsFound"):Connect(hideFoundShells)
	player:GetAttributeChangedSignal("Coins"):Connect(updateCoins)
	player:GetAttributeChangedSignal("Boost_updraft"):Connect(updateBoosts)
	player:GetAttributeChangedSignal("Boost_hush"):Connect(updateBoosts)
	player:GetAttributeChangedSignal("Hushed"):Connect(updateHushed)
	updateStage()
	updatePebbles()
	updateSnowballs()
	updateDifficulty()
	updateCoins()
	updateBoosts()
	updateHushed()
	updateHunted()
	task.spawn(function()
		workspace:WaitForChild("Map")
		hideFoundShells()
	end)

	local shown = 0
	RunService.RenderStepped:Connect(function(dt)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local zone = if root then Zones.at(root.Position) else "lobby"
		local inStages = zone == "forest"
		noisePanel.Parent.Visible = inStages
		actions.Visible = inStages
		leftDock.Visible = not inStages
		rightDock.Visible = not inStages
		snowActions.Visible = Config.Christmas and zone == "lobby"
		if actions.Visible or snowActions.Visible then
			placeActions()
		end

		local target = (player:GetAttribute("Noise") or 0) / Config.Noise.Max
		shown += (target - shown) * math.min(1, dt * 10)
		local lit = if shown > 0.02 then math.max(1, math.round(shown * SEGMENTS)) else 0
		local hushed = player:GetAttribute("Hushed")
		for i, segment in segments do
			local art = if i > lit then "button_white" elseif hushed then "button_sky" else segment.art
			if art ~= segment.shown then
				segment.shown = art
				Candy.setArt(segment.image, art, 20)
			end
		end

		local started = player:GetAttribute("RunStartedAt")
		timerPill.Parent.Visible = started ~= nil
		runTimer.Text = if started then Format.time(workspace:GetServerTimeNow() - started) else ""
	end)
end

return Hud
