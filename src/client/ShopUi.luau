-- The shop window: skins, accessories and boosts on three tabs. It shows what
-- the server says (player attributes, see server/Progress.luau) and sends
-- requests; the server decides what actually happens (server/Shop.luau).

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local WHITE = Color3.fromRGB(240, 246, 248)
local MUTED = Color3.fromRGB(150, 166, 172)
local PANEL = Color3.fromRGB(14, 22, 26)
local CARD = Color3.fromRGB(24, 34, 40)
local GREEN = Color3.fromRGB(60, 150, 120)
local GREY = Color3.fromRGB(58, 66, 70)
local WEARING = Color3.fromRGB(120, 230, 170)

local TABS = {
	{ kind = "skin", title = "Skins" },
	{ kind = "accessory", title = "Accessories" },
	{ kind = "boost", title = "Boosts" },
}

local ShopUi = {}

local gui
local pearlsLabel
local tabButtons = {} -- [kind] = TextButton
local cards = {} -- [item id] = { frame, status, button, stroke }
local currentKind = "skin"

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

local function corner(radius)
	return create("UICorner", { CornerRadius = radius })
end

local function label(props)
	local result = create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = WHITE,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	for key, value in props do
		result[key] = value
	end
	return result
end

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
	local frame = create("Frame", {
		Name = item.id,
		BackgroundColor3 = CARD,
		LayoutOrder = order,
		Parent = parent,
	}, {
		corner(UDim.new(0, 8)),
		create("UIPadding", {
			PaddingTop = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 10),
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
		}),
	})
	local stroke = create("UIStroke", { Color = WEARING, Thickness = 2, Enabled = false, Parent = frame })
	create("Frame", {
		Size = UDim2.fromOffset(32, 32),
		BackgroundColor3 = item.swatch,
		Parent = frame,
	}, { corner(UDim.new(0.5, 0)) })
	label({
		Position = UDim2.fromOffset(42, 0),
		Size = UDim2.new(1, -42, 0, 18),
		Text = item.name,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = frame,
	})
	local status = label({
		Position = UDim2.fromOffset(42, 18),
		Size = UDim2.new(1, -42, 0, 14),
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextColor3 = MUTED,
		Parent = frame,
	})
	label({
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 1, -80),
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextColor3 = MUTED,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = item.blurb,
		Parent = frame,
	})
	local button = create("TextButton", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = GREEN,
		Font = Enum.Font.GothamBold,
		TextColor3 = WHITE,
		TextSize = 14,
		Parent = frame,
	}, { corner(UDim.new(0, 6)) })
	button.Activated:Connect(function()
		onCardPressed(item)
	end)
	cards[item.id] = { frame = frame, status = status, button = button, stroke = stroke }
end

-- A greyed button still sends its request, so the server can say why not.
local function setButton(button, text, color)
	button.Text = text
	button.BackgroundColor3 = color
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
	pearlsLabel.Text = ("%d pearls"):format(pearls)

	for kind, tabButton in tabButtons do
		tabButton.BackgroundColor3 = if kind == currentKind then GREEN else CARD
	end

	for _, item in Catalog.items do
		local card = cards[item.id]
		card.frame.Visible = item.kind == currentKind
		card.stroke.Enabled = false
		if item.kind == "boost" then
			local count = player:GetAttribute("Boost_" .. item.id) or 0
			local full = count >= Config.Boosts.MaxCarried
			card.status.Text = ("You have %d"):format(count)
			setButton(card.button, if full then "Full" else ("Buy for %d"):format(item.price), if not full and pearls >= item.price then GREEN else GREY)
		elseif owned[item.id] then
			local wearing = worn[item.kind] == item.id
			card.status.Text = if wearing then "Wearing" else "Owned"
			card.stroke.Enabled = wearing
			setButton(card.button, if wearing then "Take off" else "Wear", if wearing then GREY else GREEN)
		else
			card.status.Text = ("%d pearls"):format(item.price)
			setButton(card.button, ("Buy for %d"):format(item.price), if pearls >= item.price then GREEN else GREY)
		end
	end
end

local function build()
	gui = create("ScreenGui", {
		Name = "Shop",
		ResetOnSpawn = false,
		DisplayOrder = 5,
		Enabled = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	local window = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.92, 0.82),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.05,
		Parent = gui,
	}, {
		corner(UDim.new(0, 12)),
		create("UISizeConstraint", { MaxSize = Vector2.new(640, 460) }),
	})

	label({
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(0.5, 0, 0, 28),
		Font = Enum.Font.GothamBlack,
		TextSize = 22,
		Text = "SHOP",
		Parent = window,
	})
	pearlsLabel = label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -56, 0, 12),
		Size = UDim2.new(0.5, -60, 0, 28),
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = window,
	})
	local close = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		Size = UDim2.fromOffset(32, 32),
		BackgroundColor3 = CARD,
		Font = Enum.Font.GothamBold,
		Text = "X",
		TextColor3 = WHITE,
		TextSize = 16,
		Parent = window,
	}, { corner(UDim.new(0, 6)) })
	close.Activated:Connect(ShopUi.toggle)

	local tabBar = create("Frame", {
		Position = UDim2.fromOffset(16, 50),
		Size = UDim2.new(1, -32, 0, 30),
		BackgroundTransparency = 1,
		Parent = window,
	}, {
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for order, tab in TABS do
		local tabButton = create("TextButton", {
			LayoutOrder = order,
			Size = UDim2.fromOffset(112, 30),
			BackgroundColor3 = CARD,
			Font = Enum.Font.GothamBold,
			Text = tab.title,
			TextColor3 = WHITE,
			TextSize = 14,
			Parent = tabBar,
		}, { corner(UDim.new(0, 6)) })
		tabButton.Activated:Connect(function()
			currentKind = tab.kind
			render()
		end)
		tabButtons[tab.kind] = tabButton
	end

	local list = create("ScrollingFrame", {
		Position = UDim2.fromOffset(16, 92),
		Size = UDim2.new(1, -32, 1, -108),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = window,
	}, {
		create("UIGridLayout", {
			CellSize = UDim2.fromOffset(180, 156),
			CellPadding = UDim2.fromOffset(10, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for order, item in Catalog.items do
		makeCard(item, order, list)
	end

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

	-- The kiosk in the lobby (MapBuilder.luau) opens it too.
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "OpenShop" and not (gui and gui.Enabled) then
			ShopUi.toggle()
		end
	end)
end

return ShopUi
