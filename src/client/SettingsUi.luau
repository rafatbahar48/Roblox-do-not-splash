-- The settings window: a row per setting in Config.Settings, each on one of
-- the UI kit's tiles, with the kit's ON/OFF toggle or its minus and plus
-- buttons for numbers. Settings.luau applies and saves them. Opened from the
-- HUD's dock.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Candy = require(ReplicatedStorage.Shared.Candy)
local Config = require(ReplicatedStorage.Shared.Config)
local Settings = require(script.Parent.Settings)
local Windows = require(script.Parent.Windows)

local player = Players.LocalPlayer

local INK = Candy.INK
local WIDTH = 600
local ROW = 70
local GAP = 10

local SettingsUi = {}

local gui
local rows = {} -- [setting id] = function that redraws the row

local create = Candy.create

local function toggleRow(row, setting)
	local toggle = create("ImageButton", {
		Name = "Toggle",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, -2),
		Size = UDim2.fromOffset(110, 49),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		ZIndex = 3,
		Parent = row,
	})
	toggle.Activated:Connect(function()
		Candy.click()
		Settings.set(setting.id, not Settings.get(setting.id))
	end)
	return function()
		Candy.setArt(toggle, if Settings.get(setting.id) then "toggle_on" else "toggle_off")
	end
end

local function numberRow(row, setting)
	local function stepper(art, x, delta)
		local button = create("ImageButton", {
			Name = art,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, x, 0.5, -2),
			Size = UDim2.fromOffset(46, 46),
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			ZIndex = 3,
			Parent = row,
		})
		Candy.setArt(button, art)
		button.Activated:Connect(function()
			Candy.click()
			local value = math.clamp(Settings.get(setting.id) + delta, setting.min, setting.max)
			Settings.set(setting.id, value)
		end)
		return button
	end
	local plus = stepper("plus", -14, setting.step)
	local value = Candy.text({
		Name = "Value",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -66, 0.5, -2),
		Size = UDim2.fromOffset(56, 30),
		TextSize = 24,
		Text = "",
		Parent = row,
	})
	local minus = stepper("minus", -128, -setting.step)
	return function()
		local current = Settings.get(setting.id)
		value.Text = tostring(current)
		minus.ImageTransparency = if current <= setting.min then 0.6 else 0
		plus.ImageTransparency = if current >= setting.max then 0.6 else 0
	end
end

local function build()
	gui = create("ScreenGui", {
		Name = "Settings",
		ResetOnSpawn = false,
		DisplayOrder = 5,
		Enabled = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	local backdrop = create("TextButton", {
		Name = "Backdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.5,
		AutoButtonColor = false,
		Text = "",
		Parent = gui,
	})
	backdrop.Activated:Connect(SettingsUi.close)

	local height = Candy.WINDOW_TOP + #Config.Settings * (ROW + GAP) + Candy.WINDOW_BOTTOM + 8
	local window, _, close = Candy.window(gui, { size = UDim2.fromOffset(WIDTH, height), title = "SETTINGS" })
	close.Activated:Connect(SettingsUi.close)
	Candy.fit(window, Vector2.new(WIDTH + 10, height + 10), 24)

	for i, setting in Config.Settings do
		local row = Candy.raised(window, {
			name = setting.id,
			position = UDim2.fromOffset(Candy.WINDOW_SIDE, Candy.WINDOW_TOP + (i - 1) * (ROW + GAP)),
			size = UDim2.new(1, -2 * Candy.WINDOW_SIDE, 0, ROW),
			lip = 6,
		})
		Candy.text({
			Name = "SettingName",
			Position = UDim2.fromOffset(22, 0),
			Size = UDim2.new(1, -200, 1, -4),
			TextSize = 22,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = setting.name,
			Parent = row,
		})
		rows[setting.id] = if setting.min then numberRow(row, setting) else toggleRow(row, setting)
		rows[setting.id]()
	end

	gui.Parent = player:WaitForChild("PlayerGui")
end

local closeOthers = Windows.add(function()
	SettingsUi.close()
end)

function SettingsUi.close()
	if gui then
		gui.Enabled = false
	end
end

function SettingsUi.toggle()
	if not gui then
		build()
	end
	if gui.Enabled then
		SettingsUi.close()
		return
	end
	closeOthers()
	gui.Enabled = true
end

function SettingsUi.start()
	Settings.changed:Connect(function(id)
		if rows[id] then
			rows[id]()
		end
	end)
end

return SettingsUi
