-- The shop window: skins, accessories and boosts on three tabs. It shows what
-- the server says (player attributes, see server/Progress.luau) and sends
-- requests; the server decides what actually happens (server/Shop.luau).
--
-- It follows the Shop board in the Look Book: a white window under a sky-blue
-- awning, chunky tabs, and a card per item with its picture, what it is and
-- one button.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Candy = require(ReplicatedStorage.Shared.Candy)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ItemIcons = require(script.Parent.ItemIcons)

local player = Players.LocalPlayer

local INK, WHITE, MUTED = Candy.INK, Candy.WHITE, Candy.MUTED
local OWNED = Color3.fromRGB(31, 122, 90) -- "Owned" and "Wearing"
local WORN_CARD = Color3.fromRGB(237, 255, 247)

local WIDTH, HEIGHT, HEADER = 880, 584, 96
local WINDOW_LIP = 10
local CARD = Vector2.new(264, 171) -- lip included

local TABS = {
	{ kind = "skin", title = "Skins", color = Candy.PINK, width = 128 },
	{ kind = "accessory", title = "Accessories", color = Candy.MINT, width = 184 },
	{ kind = "boost", title = "Boosts", color = Candy.LEMON, width = 136 },
}

local ShopUi = {}

local gui
local pearlsLabel
local tabButtons = {} -- [kind] = button face
local cards = {} -- [item id] = { holder, body, status, button, price, priceText, badge }
local currentKind = "skin"

local create, text = Candy.create, Candy.text

local function ownedSet()
	local owned = {}
	for id in string.gmatch(player:GetAttribute("Owned") or "", "[^,]+") do
		owned[id] = true
	end
	return owned
end

local function onCardPressed(item)
	if item.kind == "boost" or not ownedSet()[item.id] then
		Remotes.BuyItem:FireServer(item.id)
		return
	end
	local slot = item.kind
	local wearing = player:GetAttribute(if slot == "skin" then "EquippedSkin" else "EquippedAccessory")
	Remotes.EquipItem:FireServer(slot, if wearing == item.id then nil else item.id)
end

local function makeCard(item, order, parent)
	local body = Candy.raised(parent, { name = item.id, size = UDim2.fromOffset(CARD.X, CARD.Y), radius = 22 })
	local holder = body.Parent
	holder.LayoutOrder = order

	local well = create("Frame", {
		Name = "Well",
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(76, 76),
		BackgroundColor3 = Candy.ICE,
		ZIndex = 2,
		Parent = body,
	}, { Candy.corner(UDim.new(0.5, 0)), Candy.stroke(3) })
	ItemIcons.draw(well, item)

	text({
		Name = "ItemName",
		Position = UDim2.fromOffset(100, 12),
		Size = UDim2.new(1, -110, 0, 24),
		TextSize = 19,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = item.name,
		Parent = body,
	})
	local status = text({
		Name = "Status",
		Position = UDim2.fromOffset(100, 37),
		Size = UDim2.new(1, -110, 0, 16),
		Font = Enum.Font.GothamBlack,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Parent = body,
	})
	text({
		Name = "Blurb",
		Position = UDim2.fromOffset(100, 55),
		Size = UDim2.new(1, -110, 0, 50), -- three lines
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = MUTED,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = item.blurb,
		Parent = body,
	})

	local button = Candy.button(body, {
		position = UDim2.new(0, 12, 1, -56),
		size = UDim2.new(1, -24, 0, 45),
		radius = 20,
	})
	button.Activated:Connect(function()
		onCardPressed(item)
	end)
	-- "Buy", a pearl and the price, in a row in the middle of the button.
	local price = create("Frame", {
		Name = "Price",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
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
	Candy.pearl(price, 22).LayoutOrder = 2
	local priceText = text({ LayoutOrder = 3, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), TextSize = 18, Text = "", Parent = price })

	-- A "WEARING" tag sitting on the card's top edge.
	local badge = create("Frame", {
		Name = "Wearing",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0, 0),
		Size = UDim2.fromOffset(96, 24),
		BackgroundColor3 = Candy.MINT,
		Visible = false,
		ZIndex = 5,
		Parent = body,
	}, { Candy.corner(UDim.new(0.5, 0)), Candy.stroke(3) })
	text({ Position = UDim2.fromScale(0.1, 0.15), Size = UDim2.fromScale(0.8, 0.7), Text = "WEARING", ZIndex = 6, Parent = badge })

	cards[item.id] = { holder = holder, body = body, status = status, button = button, price = price, priceText = priceText, badge = badge }
end

local function render()
	if not gui then
		return
	end
	local pearls = player:GetAttribute("Pearls") or 0
	local owned = ownedSet()
	local worn = {
		skin = player:GetAttribute("EquippedSkin"),
		accessory = player:GetAttribute("EquippedAccessory"),
	}
	pearlsLabel.Text = tostring(pearls)

	for _, tab in TABS do
		if tab.kind == currentKind then
			Candy.paint(tabButtons[tab.kind], tab.color)
		else
			Candy.paint(tabButtons[tab.kind], WHITE, MUTED)
		end
	end

	for _, item in Catalog.items do
		local card = cards[item.id]
		card.holder.Visible = item.kind == currentKind
		-- What the button says and does. A greyed button still sends its
		-- request, so the server can say why not.
		local label, color, flat, showPrice = "", Candy.LEMON, false, false
		local statusText, statusColor, wearing = "", MUTED, false
		local function needMore()
			label, color, flat = ("Need %d more"):format(item.price - pearls), Candy.CLOUD, true
		end
		if item.kind == "boost" then
			local count = player:GetAttribute("Boost_" .. item.id) or 0
			statusText = ("You have %d of %d"):format(count, Config.Boosts.MaxCarried)
			if count >= Config.Boosts.MaxCarried then
				label, color, flat = "Full", Candy.CLOUD, true
			elseif pearls >= item.price then
				showPrice = true
			else
				needMore()
			end
		elseif owned[item.id] then
			wearing = worn[item.kind] == item.id
			statusText, statusColor = if wearing then "Wearing" else "Owned", OWNED
			label, color = if wearing then "Take off" else "Wear", if wearing then WHITE else Candy.MINT
		elseif pearls >= item.price then
			showPrice = true
		else
			needMore()
		end
		card.status.Text = statusText
		card.status.TextColor3 = statusColor
		card.body.BackgroundColor3 = if wearing then WORN_CARD else WHITE
		card.badge.Visible = wearing
		Candy.paint(card.button, color, if flat then MUTED else INK, flat)
		card.button.Label.Text = if showPrice then "" else label
		card.price.Visible = showPrice
		card.priceText.Text = tostring(item.price)
	end
end

-- The sky-blue header with the pearls, the title and the close button, and
-- a scalloped awning edge along its bottom.
local function buildHeader(window)
	local header = create("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, HEADER),
		BackgroundColor3 = Candy.SKY,
		Parent = window,
	}, { Candy.corner(32) })
	-- Square off its bottom corners.
	create("Frame", { Position = UDim2.new(0, 0, 1, -32), Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = Candy.SKY, BorderSizePixel = 0, Parent = header })

	-- Scallops: white circles along the edge, their lower halves covered.
	local size = 29
	for x = 0, WIDTH, size do
		create("Frame", {
			Name = "Scallop",
			Position = UDim2.fromOffset(x, HEADER - size / 2),
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = WHITE,
			ZIndex = 2,
			Parent = window,
		}, { Candy.corner(UDim.new(0.5, 0)), Candy.stroke(3.5) })
	end
	create("Frame", {
		Name = "AwningCover",
		Position = UDim2.fromOffset(0, HEADER),
		Size = UDim2.new(1, 0, 0, size / 2 + 4),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = window,
	})

	local pill = Candy.raised(header, { name = "Pearls", position = UDim2.fromOffset(24, 16), size = UDim2.fromOffset(170, 54), radius = 25, lip = 4 })
	pill.ZIndex = 4
	Candy.pearl(pill, 36, UDim2.new(0, 7, 0.5, 0), Vector2.new(0, 0.5))
	pearlsLabel = text({
		Name = "Count",
		Position = UDim2.fromOffset(50, 0),
		Size = UDim2.new(0, 64, 1, 0),
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "0",
		Parent = pill,
	})
	text({
		Position = UDim2.new(1, -60, 0, 0),
		Size = UDim2.new(0, 50, 1, 0),
		Font = Enum.Font.GothamBlack,
		TextSize = 14,
		TextColor3 = MUTED,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "pearls",
		Parent = pill,
	})

	Candy.title(header, {
		Name = "Title",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(240, 58),
		TextColor3 = Candy.LEMON,
		Text = "SHOP",
	}, 3, 4)

	local close = Candy.button(header, {
		name = "Close",
		position = UDim2.new(1, -24, 0, 14),
		anchor = Vector2.new(1, 0),
		size = UDim2.fromOffset(54, 59),
		radius = 27,
		text = "X",
		color = Candy.PINK,
	})
	close.Activated:Connect(ShopUi.toggle)
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
	-- Dim the world behind; clicking it closes the shop.
	local backdrop = create("TextButton", {
		Name = "Backdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.5,
		AutoButtonColor = false,
		Text = "",
		Parent = gui,
	})
	backdrop.Activated:Connect(ShopUi.toggle)

	local window = Candy.raised(gui, {
		name = "Window",
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5),
		size = UDim2.fromOffset(WIDTH, HEIGHT + WINDOW_LIP),
		radius = 32,
		lip = WINDOW_LIP,
		outline = 5,
	})
	window.Active = true -- clicks on the window don't reach the backdrop
	window.ClipsDescendants = true
	Candy.fit(window.Parent, Vector2.new(WIDTH + 10, HEIGHT + WINDOW_LIP + 10), 24)

	buildHeader(window)

	local tabBar = create("Frame", {
		Name = "Tabs",
		Position = UDim2.fromOffset(28, HEADER + 16),
		Size = UDim2.new(1, -56, 0, 57),
		BackgroundTransparency = 1,
		ZIndex = 4, -- over the awning's edge
		Parent = window,
	}, {
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 14),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for order, tab in TABS do
		local face = Candy.button(tabBar, { name = tab.kind, order = order, size = UDim2.fromOffset(tab.width, 57), radius = 26, text = tab.title, outline = 4 })
		face.Label.Size = UDim2.new(1, -28, 0.5, 0)
		face.Activated:Connect(function()
			currentKind = tab.kind
			render()
		end)
		tabButtons[tab.kind] = face
	end

	local list = create("ScrollingFrame", {
		Name = "Items",
		Position = UDim2.fromOffset(28, HEADER + 76),
		Size = UDim2.new(1, -50, 1, -(HEADER + 76) - 40),
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
		create("UIPadding", { PaddingTop = UDim.new(0, 14), PaddingLeft = UDim.new(0, 2) }),
		create("UIGridLayout", {
			CellSize = UDim2.fromOffset(CARD.X, CARD.Y),
			CellPadding = UDim2.fromOffset(16, 16),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for order, item in Catalog.items do
		makeCard(item, order, list)
	end

	local closeHint = if UserInputService.KeyboardEnabled then "  ·  Press B to close" else ""
	text({
		Name = "Footer",
		Position = UDim2.new(0, 28, 1, -34),
		Size = UDim2.new(1, -56, 0, 20),
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = MUTED,
		Text = "Earn pearls by clearing stages, finding shells and escaping" .. closeHint,
		Parent = window,
	})

	gui.Parent = player:WaitForChild("PlayerGui")
end

function ShopUi.toggle()
	if not gui then
		build()
	end
	gui.Enabled = not gui.Enabled
	if gui.Enabled then
		render()
	end
end

function ShopUi.start()
	local watched = { "Pearls", "Owned", "EquippedSkin", "EquippedAccessory" }
	for _, item in Catalog.items do
		if item.kind == "boost" then
			table.insert(watched, "Boost_" .. item.id)
		end
	end
	for _, name in watched do
		player:GetAttributeChangedSignal(name):Connect(render)
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.B then
			ShopUi.toggle()
		end
	end)

	-- The shop hut in the lobby (LobbyBuilder.luau) opens it too.
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "OpenShop" and not (gui and gui.Enabled) then
			ShopUi.toggle()
		end
	end)
end

return ShopUi
