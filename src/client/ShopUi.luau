-- The shop window and the bag. The shop sells skins, accessories and boosts
-- for coins on three tabs, and coin packs, Self-Revives and bundles
-- (Robux tab) and Game Passes (Passes tab) for Robux, from
-- shared/RobuxCatalog.luau; the bag shows only what you own, to wear or take
-- off. It shows what the server says (player attributes, see
-- server/Progress.luau) and sends requests; the server decides what actually
-- happens (server/Shop.luau, server/Purchases.luau).
--
-- Made of the SpriteCook UI kit's art (shared/Candy.luau): the kit's window
-- with its title on the ribbon, the coin counter, chunky tabs, and a big card
-- per item: the thing itself in 3D (ShopPreview.luau) on a stage in its
-- rarity's colour, with a spinning sunburst, twinkling sparkles and a glint
-- now and then, then its rarity, name, a line about it and one button.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Candy = require(ReplicatedStorage.Shared.Candy)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config)
local Perks = require(ReplicatedStorage.Shared.Perks)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RobuxCatalog = require(ReplicatedStorage.Shared.RobuxCatalog)
local ItemIcons = require(script.Parent.ItemIcons)
local ShopPreview = require(script.Parent.ShopPreview)
local Windows = require(script.Parent.Windows)

local player = Players.LocalPlayer

local INK, WHITE, MUTED = Candy.INK, Candy.WHITE, Candy.MUTED
local OWNED = Color3.fromRGB(31, 122, 90) -- "Owned" and "Wearing"

local WIDTH, HEIGHT = 920, 620
local CARD = Vector2.new(268, 352)
local STAGE_HEIGHT = 196 -- the stage the thing turns on, at the top of a card
-- Where the sparkles twinkle on a card: x, y, size.
local SPARKLES = { { 238, 52, 26 }, { 30, 168, 20 }, { 226, 176, 16 } }
local GLINT_EVERY = 2.6 -- seconds between a card's glints
-- What each rarity looks like: its colour (a kit button) on the cards.
local RARITIES = {
	Common = { color = Candy.MINT },
	Rare = { color = Candy.SKY },
	Epic = { color = Candy.PINK },
	Legendary = { color = Candy.LEMON },
}
local TOP = Candy.WINDOW_TOP

-- robux: a tab of things bought with Robux, which the bag leaves out.
local TABS = {
	{ kind = "skin", title = "Skins", color = Candy.PINK, width = 116 },
	{ kind = "accessory", title = "Accessories", color = Candy.MINT, width = 180 },
	{ kind = "boost", title = "Boosts", color = Candy.LEMON, width = 128 },
	{ kind = "robux", title = "Robux", color = Candy.SKY, width = 124, robux = true },
	{ kind = "pass", title = "Passes", color = Candy.PINK, width = 128, robux = true },
}

local MODES = {
	shop = { title = "SHOP", footer = "Earn coins by clearing stages, finding shells and escaping" },
	bag = { title = "YOUR BAG", footer = "Everything you own. Wear one skin and one accessory at a time." },
}

local ShopUi = {}

local gui, window, titleLabel, footer, emptyLabel
local coinsLabel
local tabButtons = {} -- [kind] = button face
local cards = {} -- [item id] = { holder, status, button, price, priceText, badge, show }
local robuxCards = {} -- [offer id] = { holder, status, button, offer, kind, show }
local robuxPrices = {} -- [offer id] = its price in Robux, once known
local currentKind = "skin"
local mode = "shop"

local create, text = Candy.create, Candy.text

local function ownedSet()
	local owned = {}
	for id in string.gmatch(player:GetAttribute("Owned") or "", "[^,]+") do
		owned[id] = true
	end
	return owned
end

local function boostCount(item)
	return player:GetAttribute("Boost_" .. item.id) or 0
end

-- Whether an item belongs in the bag: owned, or a boost you carry.
local function inBag(item, owned)
	if item.kind == "boost" then
		return boostCount(item) > 0
	end
	return owned[item.id] == true
end

local function onCardPressed(item)
	if item.kind == "boost" and mode == "bag" then
		-- More of it, from the shop.
		mode = "shop"
		ShopUi.render()
		return
	end
	if item.kind == "boost" or not ownedSet()[item.id] then
		Remotes.BuyItem:FireServer(item.id)
		return
	end
	local slot = item.kind
	local wearing = player:GetAttribute(if slot == "skin" then "EquippedSkin" else "EquippedAccessory")
	Remotes.EquipItem:FireServer(slot, if wearing == item.id then nil else item.id)
end

-- A card's one button, with "Buy", a coin and the price in a row in its
-- middle for when it is for sale. Returns the button, the row and the price.
local function buyButton(body, item)
	local button = Candy.button(body, {
		position = UDim2.new(0, 12, 1, -60),
		size = UDim2.new(1, -24, 0, 50),
	})
	button.Activated:Connect(function()
		onCardPressed(item)
	end)
	local price = create("Frame", {
		Name = "Price",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.46),
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = button,
	}, {
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 7),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	text({ LayoutOrder = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), TextSize = 18, Text = "Buy", Parent = price })
	Candy.coin(price, 24).LayoutOrder = 2
	local priceText = text({ LayoutOrder = 3, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), TextSize = 18, Text = "", Parent = price })
	return button, price, priceText
end

-- A "WEARING" tag sitting on a card's top edge.
local function wearingBadge(body)
	local badge = Candy.art("button_mint", {
		Name = "Wearing",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0, 2),
		Size = UDim2.fromOffset(104, 30),
		Visible = false,
		ZIndex = 8,
		Parent = body,
	}, 30)
	text({ Position = UDim2.fromScale(0.12, 0.16), Size = UDim2.fromScale(0.76, 0.56), Text = "WEARING", ZIndex = 9, Parent = badge })
	return badge
end

-- The top of a card: a stage in the rarity's colour, a sunburst spinning
-- behind, the thing itself in 3D (or its picture, or the little drawn
-- figure, until there is 3D to show), sparkles, a glint and the rarity tag.
-- preview says what to show: { look = ... } for your avatar wearing it, or
-- { art = ... } for one of the shop's 3D models (and its picture meanwhile).
local function makeShow(body, rarityName, preview, figureItem)
	local rarity = RARITIES[rarityName] or RARITIES.Common
	Candy.art(Candy.pillFor(rarity.color), {
		Name = "Stage",
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(CARD.X - 20, STAGE_HEIGHT),
		ZIndex = 2,
		Parent = body,
	}, STAGE_HEIGHT)
	-- The sunburst, kept inside the stage.
	local glow = create("CanvasGroup", {
		Name = "Glow",
		Position = UDim2.fromOffset(16, 14),
		Size = UDim2.fromOffset(CARD.X - 32, STAGE_HEIGHT - 16),
		BackgroundTransparency = 1,
		GroupTransparency = 0.15,
		ZIndex = 3,
		Parent = body,
	}, { Candy.corner(26) })
	local sunburst = Candy.art("sunburst", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(340, 340),
		ImageColor3 = WHITE,
		ZIndex = 3,
		Parent = glow,
	})
	local viewport = create("ViewportFrame", {
		Name = "Show",
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.fromOffset(CARD.X - 20, STAGE_HEIGHT + 2),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(190, 190, 205),
		LightColor = Color3.fromRGB(255, 250, 240),
		LightDirection = Vector3.new(-0.6, -1, 0.8),
		ZIndex = 4,
		Parent = body,
	})
	-- Shown until there is 3D: its picture, or the little drawn figure.
	local stand = create("Frame", {
		Name = "Stand",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 10 + STAGE_HEIGHT / 2),
		Size = UDim2.fromOffset(140, 140),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 4,
		Parent = body,
	})
	if preview.art then
		local picture = Candy.art(preview.art, { Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = stand })
		local size = Candy.artSize(preview.art)
		create("UIAspectRatioConstraint", { AspectRatio = size.X / size.Y, Parent = picture })
	elseif figureItem then
		ItemIcons.draw(stand, figureItem)
	end

	local sparkles = {}
	for i, spot in SPARKLES do
		sparkles[i] = Candy.art("sparkle", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(spot[1], spot[2]),
			Size = UDim2.fromOffset(spot[3], spot[3] * 1.06),
			ZIndex = 6,
			Parent = body,
		})
	end
	-- A big sparkle that flashes over the thing now and then: its shine.
	local glint = Candy.art("sparkle", {
		Name = "Glint",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(CARD.X * 0.66, 60),
		Size = UDim2.fromOffset(0, 0),
		ZIndex = 6,
		Parent = body,
	})

	local tag = Candy.art("button_white", {
		Name = "Rarity",
		Position = UDim2.fromOffset(18, 16),
		Size = UDim2.fromOffset(118, 30),
		ZIndex = 7,
		Parent = body,
	}, 30)
	text({ Position = UDim2.fromScale(0.1, 0.16), Size = UDim2.fromScale(0.8, 0.56), Text = string.upper(rarityName or "Common"), ZIndex = 8, Parent = tag })

	return {
		preview = preview,
		viewport = viewport,
		stand = stand,
		sunburst = sunburst,
		sparkles = sparkles,
		glint = glint,
		phase = math.random() * 10, -- so the cards don't all move together
	}
end

-- A card's name, status (on the right) and a line about it, under the stage.
-- Returns the status label.
local function describe(body, name, blurb)
	text({
		Name = "ItemName",
		Position = UDim2.fromOffset(14, STAGE_HEIGHT + 18),
		Size = UDim2.new(1, -112, 0, 28),
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = name,
		Parent = body,
	})
	text({
		Name = "Blurb",
		Position = UDim2.fromOffset(14, STAGE_HEIGHT + 50),
		Size = UDim2.new(1, -28, 0, 32), -- two lines
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = MUTED,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = blurb,
		Parent = body,
	})
	return text({
		Name = "Status",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, STAGE_HEIGHT + 24),
		Size = UDim2.fromOffset(96, 18),
		Font = Enum.Font.GothamBlack,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
		Parent = body,
	})
end

-- What a catalog item shows: you in it (skins and accessories), or its 3D
-- model (boosts).
local function previewOf(item)
	if item.kind == "skin" then
		return { look = { skin = item } }
	elseif item.kind == "accessory" then
		return { look = { accessory = item.id, focus = item.focus } }
	end
	return { art = "action_" .. item.id }
end

local function makeCard(item, order, parent)
	local body = Candy.raised(parent, { name = item.id, size = UDim2.fromOffset(CARD.X, CARD.Y), lip = 8 })
	local holder = body.Parent
	holder.LayoutOrder = order
	local show = makeShow(body, item.rarity, previewOf(item), item)
	local status = describe(body, item.name, item.blurb)
	local button, price, priceText = buyButton(body, item)
	cards[item.id] = {
		holder = holder,
		status = status,
		button = button,
		price = price,
		priceText = priceText,
		badge = wearingBadge(body),
		show = show,
	}
end

-- Makes (or makes again) what a card shows: you, if your character has
-- changed since; a model, once it is there.
local function prepareShow(show)
	local preview = show.preview
	if preview.look then
		if show.madeFor == player.Character then
			return
		end
		show.madeFor = player.Character
		show.pose = ShopPreview.avatar(show.viewport, preview.look)
	elseif not show.pose and ShopPreview.hasModel(preview.art) then
		show.pose = ShopPreview.model(show.viewport, preview.art, preview.tilt, preview.rock)
	end
	show.stand.Visible = show.pose == nil
end

-- Every card's show, wherever it is.
local function eachShow(fn)
	for _, card in cards do
		fn(card.show, card.holder)
	end
	for _, card in robuxCards do
		fn(card.show, card.holder)
	end
end

-- Moves everything on the cards on show: the 3D (or the picture bobbing),
-- the sunburst, the sparkles and the glint.
local clock = 0
local function animate(dt)
	if not (gui and gui.Enabled) then
		return
	end
	clock += dt
	eachShow(function(show, holder)
		if not holder.Visible then
			return
		end
		local t = clock + show.phase
		if show.pose then
			show.pose(t)
		else
			show.stand.Position = UDim2.new(0.5, 0, 0, 10 + STAGE_HEIGHT / 2 + math.sin(t * 2) * 5)
			show.stand.Rotation = math.sin(t * 1.3) * 4
		end
		show.sunburst.Rotation = t * 14
		for i, sparkle in show.sparkles do
			local twinkle = 0.5 + 0.5 * math.sin(t * 3.2 + i * 2.1)
			sparkle.ImageTransparency = 1 - twinkle
			sparkle.Rotation = twinkle * 20
		end
		-- The glint: grows, turns and fades over half a second, now and then.
		local since = t % GLINT_EVERY
		local flash = math.clamp(since / 0.5, 0, 1)
		local size = if since < 0.5 then math.sin(flash * math.pi) * 46 else 0
		show.glint.Size = UDim2.fromOffset(size, size * 1.06)
		show.glint.Rotation = flash * 90
	end)
end

-- The id an offer has on the dashboard (Config.Products or Config.Passes), or 0.
local function robuxId(kind, offer)
	return (if kind == "pass" then Config.Passes else Config.Products)[offer.id] or 0
end

-- Whether an offer shows: once it is set up, or always in Studio, to see it.
local function onSale(kind, offer)
	return robuxId(kind, offer) ~= 0 or RunService:IsStudio()
end

local function buyOffer(kind, offer)
	if kind == "pass" and Perks.owns(player, offer.id) then
		return
	end
	local id = robuxId(kind, offer)
	if id == 0 then
		footer.Text = ("Set Config.%s.%s first (README: Robux)"):format(if kind == "pass" then "Passes" else "Products", offer.id)
		return
	end
	if kind == "pass" then
		MarketplaceService:PromptGamePassPurchase(player, id)
	else
		MarketplaceService:PromptProductPurchase(player, id)
	end
end

-- A card for something sold for Robux: its 3D model, what it is, and a
-- button with its price.
local function makeRobuxCard(kind, offer, order, parent)
	local body = Candy.raised(parent, { name = offer.id, size = UDim2.fromOffset(CARD.X, CARD.Y), lip = 8 })
	local holder = body.Parent
	holder.LayoutOrder = order
	local show = makeShow(body, offer.rarity, { art = offer.art, tilt = offer.tilt, rock = offer.rock })
	local status = describe(body, offer.name, offer.blurb)
	local button = Candy.button(body, {
		position = UDim2.new(0, 12, 1, -60),
		size = UDim2.new(1, -24, 0, 50),
		color = Candy.LEMON,
	})
	button.Activated:Connect(function()
		buyOffer(kind, offer)
	end)
	robuxCards[offer.id] = { holder = holder, status = status, button = button, offer = offer, kind = kind, show = show }
end

-- Prices come from the dashboard, a little after the shop opens.
local function fetchPrices()
	for _, list in { { "product", RobuxCatalog.products }, { "pass", RobuxCatalog.passes } } do
		local kind = list[1]
		for _, offer in list[2] do
			local id = robuxId(kind, offer)
			if id ~= 0 then
				task.spawn(function()
					local infoType = if kind == "pass" then Enum.InfoType.GamePass else Enum.InfoType.Product
					local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, infoType)
					if ok and info and info.PriceInRobux then
						robuxPrices[offer.id] = info.PriceInRobux
						ShopUi.render()
					end
				end)
			end
		end
	end
end

function ShopUi.render()
	if not gui then
		return
	end
	local coins = player:GetAttribute("Coins") or 0
	local owned = ownedSet()
	local worn = {
		skin = player:GetAttribute("EquippedSkin"),
		accessory = player:GetAttribute("EquippedAccessory"),
	}
	coinsLabel.Text = tostring(coins)
	titleLabel.Text = MODES[mode].title
	footer.Text = MODES[mode].footer
		.. (if mode == "bag" then ("  ·  Self-Revives: %d"):format(player:GetAttribute("SelfRevives") or 0) else "")
		.. (if UserInputService.KeyboardEnabled and mode == "shop" then "  ·  Press B to close" else "")

	for _, tab in TABS do
		tabButtons[tab.kind].Parent.Visible = mode == "shop" or not tab.robux
		if tab.kind == currentKind then
			Candy.paint(tabButtons[tab.kind], tab.color)
		else
			Candy.paint(tabButtons[tab.kind], WHITE, MUTED)
		end
	end

	local anyShown = false
	for _, item in Catalog.items do
		local card = cards[item.id]
		local shown = item.kind == currentKind and (mode == "shop" or inBag(item, owned))
		card.holder.Visible = shown
		anyShown = anyShown or shown
		-- What the button says and does. A greyed button still sends its
		-- request, so the server can say why not.
		local label, color, flat, showPrice = "", Candy.LEMON, false, false
		local statusText, statusColor, wearing = "", MUTED, false
		local function needMore()
			label, color, flat = ("Need %d more"):format(item.price - coins), Candy.CLOUD, true
		end
		if item.kind == "boost" then
			local count = boostCount(item)
			statusText = ("You have %d of %d"):format(count, Perks.maxBoosts(player))
			if mode == "bag" then
				label, color = "Get more", Candy.SKY
			elseif count >= Perks.maxBoosts(player) then
				label, color, flat = "Full", Candy.CLOUD, true
			elseif coins >= item.price then
				showPrice = true
			else
				needMore()
			end
		elseif owned[item.id] then
			wearing = worn[item.kind] == item.id
			statusText, statusColor = if wearing then "Wearing" else "Owned", OWNED
			label, color = if wearing then "Take off" else "Wear", if wearing then WHITE else Candy.MINT
		elseif coins >= item.price then
			showPrice = true
		else
			needMore()
		end
		card.status.Text = statusText
		card.status.TextColor3 = statusColor
		card.badge.Visible = wearing
		Candy.paint(card.button, color, if flat then WHITE else INK, flat)
		card.button.Label.Text = if showPrice then "" else label
		card.price.Visible = showPrice
		card.priceText.Text = tostring(item.price)
	end

	for _, card in robuxCards do
		local offer, kind = card.offer, card.kind
		local tabKind = if kind == "pass" then "pass" else "robux"
		local shown = mode == "shop" and currentKind == tabKind and onSale(kind, offer)
		card.holder.Visible = shown
		anyShown = anyShown or shown
		local passOwned = kind == "pass" and Perks.owns(player, offer.id)
		local price = robuxPrices[offer.id]
		if passOwned then
			card.status.Text, card.status.TextColor3 = "Owned", OWNED
			Candy.paint(card.button, WHITE, MUTED, true)
			card.button.Label.Text = "Owned"
		else
			if offer.gives and offer.gives.selfRevives and not offer.gives.coins then
				card.status.Text = ("You have %d"):format(player:GetAttribute("SelfRevives") or 0)
			else
				card.status.Text = if kind == "pass" then "Forever" else ""
			end
			card.status.TextColor3 = MUTED
			Candy.paint(card.button, Candy.LEMON)
			card.button.Label.Text = if price then ("R$ %d"):format(price) else "Robux"
		end
	end
	emptyLabel.Text = if mode == "bag" then "Nothing here yet. Find something in the shop." else "Nothing for sale here yet."
	emptyLabel.Visible = not anyShown

	-- The 3D for the cards on show, made the first time they show.
	if gui.Enabled then
		eachShow(function(show, holder)
			if holder.Visible then
				prepareShow(show)
			end
		end)
	end
end

local function build()
	gui = create("ScreenGui", {
		Name = "Shop",
		ResetOnSpawn = false,
		DisplayOrder = 5,
		Enabled = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	-- Dim the world behind; clicking it closes the window.
	local backdrop = create("TextButton", {
		Name = "Backdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.5,
		AutoButtonColor = false,
		Text = "",
		Parent = gui,
	})
	backdrop.Activated:Connect(ShopUi.close)

	local close
	window, titleLabel, close = Candy.window(gui, { name = "Window", size = UDim2.fromOffset(WIDTH, HEIGHT) })
	close.Activated:Connect(ShopUi.close)
	Candy.fit(window, Vector2.new(WIDTH + 10, HEIGHT + 10), 24)

	-- Coins, between the ribbon and the close button. Its + opens the shop.
	local pill = Candy.art("coin_counter", {
		Name = "Coins",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -110, 0, 22),
		Size = UDim2.fromOffset(210, 60),
		ZIndex = 3,
		Parent = window,
	}, 60)
	coinsLabel = text({
		Name = "Count",
		Position = UDim2.fromOffset(62, 5),
		Size = UDim2.new(1, -116, 1, -14),
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "0",
		ZIndex = 4,
		Parent = pill,
	})
	local more = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 54, 1, 0),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 5,
		Parent = pill,
	})
	more.Activated:Connect(function()
		mode = "shop"
		ShopUi.render()
	end)

	local tabBar = create("Frame", {
		Name = "Tabs",
		Position = UDim2.fromOffset(Candy.WINDOW_SIDE, TOP),
		Size = UDim2.new(1, -2 * Candy.WINDOW_SIDE, 0, 56),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = window,
	}, {
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for order, tab in TABS do
		local face = Candy.button(tabBar, { name = tab.kind, order = order, size = UDim2.fromOffset(tab.width, 56), text = tab.title })
		face.Activated:Connect(function()
			currentKind = tab.kind
			ShopUi.render()
		end)
		tabButtons[tab.kind] = face
	end

	local list = create("ScrollingFrame", {
		Name = "Items",
		Position = UDim2.fromOffset(Candy.WINDOW_SIDE - 2, TOP + 66),
		Size = UDim2.new(1, -2 * Candy.WINDOW_SIDE + 8, 1, -(TOP + 66) - Candy.WINDOW_BOTTOM - 30),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = INK,
		Parent = window,
	}, {
		-- Room above the first row for the WEARING tags.
		create("UIPadding", { PaddingTop = UDim.new(0, 16), PaddingLeft = UDim.new(0, 4) }),
		create("UIGridLayout", {
			Name = "Grid",
			CellSize = UDim2.fromOffset(CARD.X, CARD.Y),
			CellPadding = UDim2.fromOffset(16, 18),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for order, item in Catalog.items do
		makeCard(item, order, list)
	end
	for order, offer in RobuxCatalog.products do
		makeRobuxCard("product", offer, 100 + order, list)
	end
	for order, offer in RobuxCatalog.passes do
		makeRobuxCard("pass", offer, 200 + order, list)
	end
	fetchPrices()

	emptyLabel = text({
		Name = "Empty",
		Position = UDim2.fromOffset(Candy.WINDOW_SIDE, TOP + 110),
		Size = UDim2.new(1, -2 * Candy.WINDOW_SIDE, 0, 30),
		TextSize = 22,
		TextColor3 = MUTED,
		Text = "Nothing here yet. Find something in the shop.",
		Visible = false,
		Parent = window,
	})

	footer = text({
		Name = "Footer",
		Position = UDim2.new(0, Candy.WINDOW_SIDE, 1, -Candy.WINDOW_BOTTOM - 24),
		Size = UDim2.new(1, -2 * Candy.WINDOW_SIDE, 0, 20),
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = MUTED,
		Text = "",
		Parent = window,
	})

	gui.Parent = player:WaitForChild("PlayerGui")
end

local closeOthers = Windows.add(function()
	ShopUi.close()
end)

-- Opens the shop ("shop") or your bag ("bag"), on a tab if given ("robux"
-- for the coin packs). Pressing the same one again closes it.
function ShopUi.open(newMode, kind)
	if not gui then
		build()
	end
	if gui.Enabled and mode == newMode and not kind then
		ShopUi.close()
		return
	end
	closeOthers()
	mode = newMode
	if kind then
		currentKind = kind
	elseif newMode == "bag" and (currentKind == "robux" or currentKind == "pass") then
		currentKind = "skin"
	end
	gui.Enabled = true
	ShopUi.render()
end

function ShopUi.close()
	if gui then
		gui.Enabled = false
	end
end

function ShopUi.toggle()
	ShopUi.open("shop")
end

function ShopUi.start()
	RunService.RenderStepped:Connect(animate)
	player.CharacterAppearanceLoaded:Connect(function()
		if gui and gui.Enabled then
			ShopUi.render()
		end
	end)
	-- The 3D models are added to the place in Studio; show them as they come.
	task.spawn(function()
		local folder = ReplicatedStorage:WaitForChild("ShopModels", math.huge)
		folder.ChildAdded:Connect(function()
			if gui and gui.Enabled then
				ShopUi.render()
			end
		end)
	end)

	local watched = { "Coins", "Owned", "EquippedSkin", "EquippedAccessory", "SelfRevives" }
	for name in Config.Passes do
		table.insert(watched, "Pass_" .. name)
	end
	for _, item in Catalog.items do
		if item.kind == "boost" then
			table.insert(watched, "Boost_" .. item.id)
		end
	end
	for _, name in watched do
		player:GetAttributeChangedSignal(name):Connect(ShopUi.render)
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.B then
			ShopUi.toggle()
		end
	end)

	-- The shop's cottage in the lobby (LobbyBuilder.luau) and the cave's stall open it too.
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "OpenShop" and not (gui and gui.Enabled and mode == "shop") then
			ShopUi.open("shop")
		end
	end)
end

return ShopUi
