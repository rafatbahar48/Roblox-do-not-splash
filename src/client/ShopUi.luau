-- The shop window and the bag. The shop sells skins, accessories and boosts
-- on three tabs; the bag shows only what you own, to wear or take off. It
-- shows what the server says (player attributes, see server/Progress.luau)
-- and sends requests; the server decides what actually happens
-- (server/Shop.luau).
--
-- Made of the SpriteCook UI kit's art (shared/Candy.luau): the kit's window
-- with its title on the ribbon, the pearl counter, chunky tabs, and a tile
-- per item with its picture in a round well and one button.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Candy = require(ReplicatedStorage.Shared.Candy)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ItemIcons = require(script.Parent.ItemIcons)
local Windows = require(script.Parent.Windows)

local player = Players.LocalPlayer

local INK, WHITE, MUTED = Candy.INK, Candy.WHITE, Candy.MUTED
local OWNED = Color3.fromRGB(31, 122, 90) -- "Owned" and "Wearing"

local WIDTH, HEIGHT = 920, 620
local CARD = Vector2.new(268, 176)
local TOP = Candy.WINDOW_TOP

local TABS = {
	{ kind = "skin", title = "Skins", color = Candy.PINK, width = 140 },
	{ kind = "accessory", title = "Accessories", color = Candy.MINT, width = 196 },
	{ kind = "boost", title = "Boosts", color = Candy.LEMON, width = 148 },
}

local MODES = {
	shop = { title = "SHOP", footer = "Earn pearls by clearing stages, finding shells and escaping" },
	bag = { title = "YOUR BAG", footer = "Everything you own. Wear one skin and one accessory at a time." },
}

local ShopUi = {}

local gui, window, titleLabel, footer, emptyLabel
local pearlsLabel
local tabButtons = {} -- [kind] = button face
local cards = {} -- [item id] = { holder, status, button, price, priceText, badge }
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

local function makeCard(item, order, parent)
	local body = Candy.raised(parent, { name = item.id, size = UDim2.fromOffset(CARD.X, CARD.Y), lip = 8 })
	local holder = body.Parent
	holder.LayoutOrder = order

	local well = Candy.art("well", {
		Name = "Well",
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(80, 80),
		ZIndex = 2,
		Parent = body,
	})
	if item.kind == "boost" then
		-- The boost's own button from the HUD.
		Candy.art("action_" .. item.id, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.8, 0.8),
			ZIndex = 3,
			Parent = well,
		})
	else
		ItemIcons.draw(well, item)
	end

	text({
		Name = "ItemName",
		Position = UDim2.fromOffset(102, 14),
		Size = UDim2.new(1, -114, 0, 24),
		TextSize = 19,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = item.name,
		Parent = body,
	})
	local status = text({
		Name = "Status",
		Position = UDim2.fromOffset(102, 39),
		Size = UDim2.new(1, -114, 0, 16),
		Font = Enum.Font.GothamBlack,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Parent = body,
	})
	text({
		Name = "Blurb",
		Position = UDim2.fromOffset(102, 57),
		Size = UDim2.new(1, -114, 0, 50), -- three lines
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
		position = UDim2.new(0, 12, 1, -60),
		size = UDim2.new(1, -24, 0, 50),
	})
	button.Activated:Connect(function()
		onCardPressed(item)
	end)
	-- "Buy", a pearl and the price, in a row in the middle of the button.
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
	Candy.pearl(price, 24).LayoutOrder = 2
	local priceText = text({ LayoutOrder = 3, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), TextSize = 18, Text = "", Parent = price })

	-- A "WEARING" tag sitting on the card's top edge.
	local badge = Candy.art("button_mint", {
		Name = "Wearing",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0, 2),
		Size = UDim2.fromOffset(104, 30),
		Visible = false,
		ZIndex = 5,
		Parent = body,
	}, 30)
	text({ Position = UDim2.fromScale(0.12, 0.16), Size = UDim2.fromScale(0.76, 0.56), Text = "WEARING", ZIndex = 6, Parent = badge })

	cards[item.id] = { holder = holder, status = status, button = button, price = price, priceText = priceText, badge = badge }
end

function ShopUi.render()
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
	titleLabel.Text = MODES[mode].title
	footer.Text = MODES[mode].footer .. (if UserInputService.KeyboardEnabled and mode == "shop" then "  ·  Press B to close" else "")

	for _, tab in TABS do
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
			label, color, flat = ("Need %d more"):format(item.price - pearls), Candy.CLOUD, true
		end
		if item.kind == "boost" then
			local count = boostCount(item)
			statusText = ("You have %d of %d"):format(count, Config.Boosts.MaxCarried)
			if mode == "bag" then
				label, color = "Get more", Candy.SKY
			elseif count >= Config.Boosts.MaxCarried then
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
		card.badge.Visible = wearing
		Candy.paint(card.button, color, if flat then WHITE else INK, flat)
		card.button.Label.Text = if showPrice then "" else label
		card.price.Visible = showPrice
		card.priceText.Text = tostring(item.price)
	end
	emptyLabel.Visible = not anyShown
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

	-- Pearls, between the ribbon and the close button. Its + opens the shop.
	local pill = Candy.art("pearl_counter", {
		Name = "Pearls",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -110, 0, 22),
		Size = UDim2.fromOffset(210, 60),
		ZIndex = 3,
		Parent = window,
	}, 60)
	pearlsLabel = text({
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
			CellSize = UDim2.fromOffset(CARD.X, CARD.Y),
			CellPadding = UDim2.fromOffset(16, 18),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for order, item in Catalog.items do
		makeCard(item, order, list)
	end

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

-- Opens the shop ("shop") or your bag ("bag"). Pressing the same one again
-- closes it.
function ShopUi.open(newMode)
	if not gui then
		build()
	end
	if gui.Enabled and mode == newMode then
		ShopUi.close()
		return
	end
	closeOthers()
	mode = newMode
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
	local watched = { "Pearls", "Owned", "EquippedSkin", "EquippedAccessory" }
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

	-- The shop hut in the lobby (LobbyBuilder.luau) opens it too.
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "OpenShop" and not (gui and gui.Enabled and mode == "shop") then
			ShopUi.open("shop")
		end
	end)
end

return ShopUi
