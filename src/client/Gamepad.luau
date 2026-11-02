-- Playing with a controller (a gamepad on PC, PlayStation or Xbox):
--
--   which input you are using (UserInputService.PreferredInput), so the
--   controller's hints only show while you use one;
--   button hints in the controller's own icons (Roblox's, so a PlayStation
--   pad shows PlayStation buttons and an Xbox pad Xbox ones);
--   the menus' selection: a menu picks a first button as it opens, B closes
--   it, and closing it hands the selection back to the menu under it.
--   Roblox moves the selection with the stick and D-pad and presses with A.
--
-- And on a console, no chat window (Roblox's console guidelines).

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")

local Candy = require(ReplicatedStorage.Shared.Candy)

local Gamepad = {}

local changed = Instance.new("BindableEvent")
Gamepad.changed = changed.Event -- you switched to or from a controller

-- Open menus, the newest last: { name, first, close, keep, selected }.
local menus = {}

function Gamepad.active()
	return UserInputService.PreferredInput == Enum.PreferredInput.Gamepad
end

-- Whether a gui object is on screen: it and everything it is in visible.
local function shown(object)
	local at = object
	while at do
		if at:IsA("LayerCollector") then
			return at.Enabled
		elseif at:IsA("GuiObject") and not at.Visible then
			return false
		end
		at = at.Parent
	end
	return false
end

-- Selects where you were in a menu, or its first button.
local function focus(menu)
	if not Gamepad.active() then
		return
	end
	local button = if menu.selected and shown(menu.selected) then menu.selected else nil
	if not button then
		local first = if type(menu.first) == "function" then menu.first() else menu.first
		button = if first and shown(first) then first else nil
	end
	GuiService.SelectedObject = button
end

-- Call as a menu closes: back to where you were in the menu under it.
function Gamepad.closed(name)
	for i, menu in menus do
		if menu.name == name then
			table.remove(menus, i)
			if i > #menus then -- it was on top
				local top = menus[#menus]
				if top then
					focus(top)
				else
					GuiService.SelectedObject = nil
				end
			end
			return
		end
	end
end

-- Call as a menu opens. first: the button to start on, or a function that
-- finds it. close: what B does (nil: nothing, it must be answered). keep:
-- false lets the selection go, and the menu with it (the HUD's buttons);
-- otherwise it is held in the menu.
function Gamepad.opened(name, first, close, keep)
	for i, menu in menus do
		if menu.name == name then
			table.remove(menus, i)
			break
		end
	end
	local top = menus[#menus]
	if top then
		top.selected = GuiService.SelectedObject
	end
	local menu = { name = name, first = first, close = close, keep = keep ~= false }
	table.insert(menus, menu)
	focus(menu)
end

-- A key hint on a button's corner: the key's letter on the kit's badge
-- while you use a keyboard (letter nil: none), and the controller button's
-- icon while you use a controller. Returns the icon.
function Gamepad.keyHint(parent, letter, keyCode, size, position, anchor)
	local badge = if letter and UserInputService.KeyboardEnabled then Candy.badge(parent, letter, size, position, anchor) else nil
	local icon = Candy.create("ImageLabel", {
		Name = "ButtonHint",
		AnchorPoint = anchor or Vector2.zero,
		Position = position,
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		ZIndex = 7,
		Parent = parent,
	})
	local function update()
		local active = Gamepad.active()
		icon.Image = UserInputService:GetImageForKeyCode(keyCode)
		icon.Visible = active
		if badge then
			badge.Visible = not active
		end
	end
	Gamepad.changed:Connect(update)
	update()
	return icon
end

-- B closes the menu on top, while there is one.
local function onBack(_, inputState)
	local top = menus[#menus]
	if inputState ~= Enum.UserInputState.Begin or not top then
		return Enum.ContextActionResult.Pass
	end
	if top.close then
		top.close()
	end
	return Enum.ContextActionResult.Sink
end

function Gamepad.start()
	if GuiService:IsTenFootInterface() then
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
		local window = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
		local inputBar = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")
		if window then
			window.Enabled = false
		end
		if inputBar then
			inputBar.Enabled = false
		end
	end

	ContextActionService:BindActionAtPriority("MenuBack", onBack, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.ButtonB)

	local wasActive = Gamepad.active()
	UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function()
		local active = Gamepad.active()
		if active == wasActive then
			return
		end
		wasActive = active
		if active then
			local top = menus[#menus]
			if top then
				focus(top)
			end
		else
			-- The mouse has it: no selection, and the HUD's buttons let go.
			for i = #menus, 1, -1 do
				if not menus[i].keep then
					table.remove(menus, i)
				end
			end
			GuiService.SelectedObject = nil
		end
		changed:Fire(active)
	end)

	-- Holds the selection in the menu on top when what was selected goes
	-- (hidden, or its tab changed), unless Roblox's menu is open.
	RunService.Heartbeat:Connect(function()
		local top = menus[#menus]
		if not top or not Gamepad.active() or GuiService.MenuIsOpen then
			return
		end
		local selected = GuiService.SelectedObject
		if selected and shown(selected) then
			return
		end
		if top.keep then
			focus(top)
		else
			Gamepad.closed(top.name)
		end
	end)
end

return Gamepad
