-- The Christmas Bundle's window (shared/RobuxCatalog.luau's bundles): its
-- picture, how long it's on sale for, what's in it, and its Robux button.
-- Opened by the HUD's Christmas button (Hud.luau) and by the shop's
-- exclusive items (ShopUi.luau). Roblox takes the payment and
-- server/Purchases.luau hands out what it gives.
--
-- Made of the SpriteCook UI kit's art (shared/Candy.luau); the code only
-- places it and writes the words and numbers.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Candy = require(ReplicatedStorage.Shared.Candy)
local Config = require(ReplicatedStorage.Shared.Config)
local RobuxCatalog = require(ReplicatedStorage.Shared.RobuxCatalog)
local Windows = require(script.Parent.Windows)

local player = Players.LocalPlayer

local BUNDLE = RobuxCatalog.productById.ChristmasBundle
local WIDTH, HEIGHT = 820, 520
local TOP, SIDE, BOTTOM = Candy.WINDOW_TOP, Candy.WINDOW_SIDE, Candy.WINDOW_BOTTOM
local LEFT = 300 -- the picture's panel
local ROW = 70
local TAG_COLORS = { FOREVER = Candy.MINT }

local create, text = Candy.create, Candy.text

local ChristmasBundle = {}

local window, countdown, buyButton, footer
local openWindow -- closes the other menu windows
local price -- in Robux, once Roblox says

local function productId()
	return Config.Products[BUNDLE.id] or 0
end

-- Seconds until it stops being sold, or nil once it has.
function ChristmasBundle.timeLeft()
	local left = BUNDLE.endsAt - DateTime.now().UnixTimestamp
	return if left > 0 then left else nil
end

-- Whether it is for sale: Christmas is on, it hasn't ended, and it is set up
-- on the dashboard (always, in Studio, to see it).
function ChristmasBundle.onSale()
	return Config.Christmas and ChristmasBundle.timeLeft() ~= nil and (productId() ~= 0 or RunService:IsStudio())
end

-- "61D 4H" (or "5H 12M" on the last day), for the HUD.
function ChristmasBundle.shortTime(seconds)
	local days, hours = seconds // 86400, seconds % 86400 // 3600
	if days > 0 then
		return ("%dD %dH"):format(days, hours)
	end
	return ("%dH %dM"):format(hours, seconds % 3600 // 60)
end

local function longTime(seconds)
	return ("ENDS IN %dD %02dH %02dM"):format(seconds // 86400, seconds % 86400 // 3600, seconds % 3600 // 60)
end

-- A tag on the right of a row: the kit's pill in a colour, with words on it.
local function tag(parent, words)
	local color = TAG_COLORS[words] or Candy.SKY
	local pill = Candy.art(Candy.pillFor(color), {
		Name = "Tag",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, -2),
		Size = UDim2.fromOffset(112, 40),
		ZIndex = 4,
		Parent = parent,
	}, 40)
	text({ Position = UDim2.fromScale(0.1, 0.14), Size = UDim2.fromScale(0.8, 0.58), Text = words, ZIndex = 5, Parent = pill })
end

local function build()
	local gui = create("ScreenGui", {
		Name = "ChristmasBundle",
		ResetOnSpawn = false,
		DisplayOrder = 7,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local made, _, closeButton = Candy.window(gui, { name = "Bundle", size = UDim2.fromOffset(WIDTH, HEIGHT), title = "CHRISTMAS" })
	window = made
	window.Visible = false
	Candy.fit(window, Vector2.new(WIDTH + 10, HEIGHT + 10), 24)
	local function close()
		window.Visible = false
	end
	openWindow = Windows.add(close)
	closeButton.Activated:Connect(close)

	-- Left: the picture, LIMITED, and how long is left.
	local panel = Candy.raised(window, {
		name = "Picture",
		position = UDim2.fromOffset(SIDE, TOP - 8),
		size = UDim2.fromOffset(LEFT, HEIGHT - TOP - BOTTOM + 8),
		lip = 8,
		zIndex = 2,
	})
	Candy.art("christmas_bundle", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 22),
		Size = UDim2.fromOffset(270, 243),
		ZIndex = 3,
		Parent = panel,
	})
	local ribbon = Candy.art("ribbon_red", {
		Position = UDim2.fromOffset(-18, -12),
		Size = UDim2.fromOffset(150, 59),
		Rotation = -10,
		ZIndex = 6,
		Parent = panel,
	})
	Candy.outlined({ Position = UDim2.fromScale(0.16, 0.18), Size = UDim2.fromScale(0.68, 0.5), TextColor3 = Candy.WHITE, Text = "LIMITED", ZIndex = 7, Parent = ribbon }, 2.5)
	Candy.outlined({
		Position = UDim2.new(0, 10, 1, -96),
		Size = UDim2.new(1, -20, 0, 32),
		TextColor3 = Candy.LEMON,
		Text = "HOLIDAY SEASON ONLY",
		ZIndex = 4,
		Parent = panel,
	}, 3)
	countdown = text({
		Position = UDim2.new(0, 10, 1, -56),
		Size = UDim2.new(1, -20, 0, 30),
		TextColor3 = Candy.MUTED,
		Text = "",
		ZIndex = 4,
		Parent = panel,
	})

	-- Right: what's in it.
	local x = SIDE + LEFT + 18
	for i, perk in BUNDLE.perks do
		local row = Candy.raised(window, {
			name = "Perk" .. i,
			position = UDim2.fromOffset(x, TOP - 8 + (i - 1) * (ROW + 8)),
			size = UDim2.fromOffset(WIDTH - x - SIDE, ROW),
			lip = 5,
			zIndex = 2,
		})
		local art = Candy.artSize(perk.art)
		local scale = math.min(54 / art.X, 54 / art.Y)
		Candy.art(perk.art, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(40, ROW / 2 - 3),
			Size = UDim2.fromOffset(art.X * scale, art.Y * scale),
			ZIndex = 3,
			Parent = row,
		})
		text({ Position = UDim2.fromOffset(76, 8), Size = UDim2.new(1, -206, 0, 28), TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left, Text = perk.name, ZIndex = 3, Parent = row })
		text({
			Position = UDim2.fromOffset(76, 36),
			Size = UDim2.new(1, -206, 0, 20),
			Font = Enum.Font.GothamMedium,
			TextSize = 14,
			TextColor3 = Candy.MUTED,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = perk.blurb,
			ZIndex = 3,
			Parent = row,
		})
		tag(row, perk.tag)
	end

	-- The Robux button, and a line under it.
	buyButton = Candy.button(window, {
		position = UDim2.new(0, x, 1, -BOTTOM - 74),
		size = UDim2.new(1, -x - SIDE, 0, 64),
		text = "Robux",
		color = Candy.MINT,
	})
	buyButton.Activated:Connect(function()
		local id = productId()
		if id == 0 then
			footer.Text = "Set Config.Products.ChristmasBundle first (README: Robux)"
			return
		end
		MarketplaceService:PromptProductPurchase(player, id)
	end)
	footer = text({
		Position = UDim2.new(0, x, 1, -BOTTOM - 4),
		Size = UDim2.new(1, -x - SIDE, 0, 18),
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		TextColor3 = Candy.MUTED,
		Text = "The skin and hat are yours to keep.",
		Parent = window,
	})

	RunService.Heartbeat:Connect(function()
		if not window.Visible then
			return
		end
		local left = ChristmasBundle.timeLeft()
		countdown.Text = if left then longTime(left) else "ON SALE NO MORE"
		buyButton.Label.Text = if price then ("R$ %d"):format(price) else "Robux"
	end)
end

function ChristmasBundle.open()
	if not window then
		build()
	end
	if window.Visible then
		window.Visible = false
		return
	end
	openWindow()
	window.Visible = true
	if not price and productId() ~= 0 then
		task.spawn(function()
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, productId(), Enum.InfoType.Product)
			if ok and info then
				price = info.PriceInRobux
			end
		end)
	end
end

return ChristmasBundle
