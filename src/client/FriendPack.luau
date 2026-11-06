-- The Rare Pack's window (Config.FriendPack): you in its skin, turning, what
-- comes in it, and how to get it, with a button to invite friends. It pops up
-- once a visit, back in the lobby, for anyone who has played a run and hasn't
-- got it; the HUD's Invite button and the skin's shop card open it too. It
-- says so when you have won it (server/Progress.luau), with a button to wear
-- the skin. Everyone who clears all the stages on a run with the party wins
-- it, whatever the others do.
--
-- Made of the SpriteCook UI kit's art (shared/Candy.luau); the code only
-- places it and writes the words and numbers.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")

local Candy = require(ReplicatedStorage.Shared.Candy)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Stages = require(ReplicatedStorage.Shared.Stages)
local Zones = require(ReplicatedStorage.Shared.Zones)
local Gamepad = require(script.Parent.Gamepad)
local ShopPreview = require(script.Parent.ShopPreview)
local Windows = require(script.Parent.Windows)

local player = Players.LocalPlayer

local PACK = Config.FriendPack
local SKIN = Catalog.byId[PACK.Skin]
local WIDTH, HEIGHT = 760, 470
local TOP, SIDE = Candy.WINDOW_TOP, Candy.WINDOW_SIDE + 16
local PICTURE = 240
local OFFER_WAIT = 8 -- seconds after arriving before it can pop up
local WON_WAIT = 2 -- seconds after the escape screen
local CHECK_INTERVAL = 1

local FriendPack = {}

local window, title, detail, actionButton, viewport
local pose -- turns the copy of you in the viewport
local openedAt = 0
local won = false -- showing that you have won it
local closeOthers

local function owned()
	return table.find(string.split(player:GetAttribute("Owned") or "", ","), PACK.Skin) ~= nil
end

function FriendPack.invite()
	local ok, canInvite = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
	if ok and canInvite then
		pcall(SocialService.PromptGameInvite, SocialService, player)
	end
end

local function close()
	if window then
		window.Visible = false
		Gamepad.closed("pack")
	end
end

local function build()
	local gui = Candy.create("ScreenGui", {
		Name = "FriendPack",
		ResetOnSpawn = false,
		DisplayOrder = 8,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local closeButton
	window, title, closeButton = Candy.window(gui, { name = "Pack", size = UDim2.fromOffset(WIDTH, HEIGHT), title = "RARE PACK" })
	window.Visible = false
	Candy.fit(window, Vector2.new(WIDTH + 10, HEIGHT + 10), 24)
	closeOthers = Windows.add(close)
	closeButton.Activated:Connect(close)
	Gamepad.keyHint(closeButton, nil, Enum.KeyCode.ButtonB, 36, UDim2.new(0, 8, 1, -8), Vector2.new(0, 1))

	-- Left: you in the skin.
	local picture = Candy.raised(window, {
		name = "Picture",
		position = UDim2.fromOffset(SIDE, TOP - 6),
		size = UDim2.fromOffset(PICTURE, HEIGHT - TOP - Candy.WINDOW_BOTTOM - 6),
		lip = 6,
		zIndex = 2,
	})
	viewport = Candy.create("ViewportFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(190, 190, 190),
		LightColor = Color3.fromRGB(255, 255, 255),
		ZIndex = 3,
		Parent = picture,
	})

	-- Right: what it is, and how to get it.
	local x = SIDE + PICTURE + 20
	local right = WIDTH - x - SIDE
	Candy.text({
		Position = UDim2.fromOffset(x, TOP - 6),
		Size = UDim2.fromOffset(right, 38),
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = SKIN.name,
		Parent = window,
	})
	Candy.text({
		Position = UDim2.fromOffset(x, TOP + 34),
		Size = UDim2.fromOffset(right, 24),
		Font = Enum.Font.GothamMedium,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = ("%s skin, %d coins and a Self-Revive"):format(SKIN.rarity, PACK.Gives.coins),
		Parent = window,
	})
	detail = Candy.text({
		Position = UDim2.fromOffset(x, TOP + 72),
		Size = UDim2.fromOffset(right, 120),
		Font = Enum.Font.GothamMedium,
		TextSize = 19,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "",
		Parent = window,
	})
	actionButton = Candy.button(window, {
		size = UDim2.fromOffset(right, 62),
		position = UDim2.new(0, x, 1, -Candy.WINDOW_BOTTOM - 66),
		text = "",
		color = Candy.LEMON,
	})
	actionButton.Activated:Connect(function()
		if won then
			Remotes.EquipItem:FireServer("skin", PACK.Skin)
			close()
		else
			FriendPack.invite()
		end
	end)

	RunService.RenderStepped:Connect(function()
		if window.Visible and pose then
			pose(os.clock() - openedAt)
		end
	end)
end

local function show()
	if not window then
		build()
	end
	title.Text = if won then "YOU WON IT" else "RARE PACK"
	detail.Text = if won
		then ("You cleared all %d stages with your friends. It's yours to keep."):format(#Stages)
		else ("Make a party with %d friends. Whoever clears all %d stages gets the pack, even if the others don't make it."):format(PACK.Friends, #Stages)
	actionButton.Label.Text = if won then "Wear it" else "Invite friends"
	closeOthers()
	window.Visible = true
	viewport:ClearAllChildren()
	pose = ShopPreview.avatar(viewport, { skin = SKIN })
	openedAt = os.clock()
	Gamepad.opened("pack", actionButton, close)
end

-- The HUD's Invite button: the pack until you have it, then Roblox's invite.
function FriendPack.openOrInvite()
	if owned() then
		FriendPack.invite()
	else
		won = false
		show()
	end
end

-- A skin's shop card.
function FriendPack.open()
	won = false
	show()
end

function FriendPack.start()
	Remotes.PackWon.OnClientEvent:Connect(function()
		task.wait(WON_WAIT)
		won = true
		show()
	end)
	task.spawn(function()
		task.wait(OFFER_WAIT)
		while true do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local inLobby = root ~= nil and Zones.at(root.Position) == "lobby"
			local played = (player:GetAttribute("StatRuns") or 0) > 0
			if inLobby and played and not player:GetAttribute("DailyDue") then
				if not owned() then
					FriendPack.open()
				end
				return
			end
			task.wait(CHECK_INTERVAL)
		end
	end)
end

return FriendPack
