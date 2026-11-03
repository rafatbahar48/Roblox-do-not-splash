-- Fits the HUD and the party banner to the screen. Their things are laid out
-- on a screen at least DESIGN big; on a smaller one (phones and small
-- windows), the frame holding them is made that big and shrunk to fit with a
-- UIScale, so everything keeps its place and nothing overlaps. On a big
-- screen it grows instead (Candy.TV_SCALE), and on a TV it keeps inside the
-- TV's safe area (Candy.TV_SAFE).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Candy = require(ReplicatedStorage.Shared.Candy)

-- Touch screens get a more compact layout (Hud.luau), so it needs less room.
local DESIGN = if UserInputService.TouchEnabled then Vector2.new(900, 480) else Vector2.new(900, 640)
local SMALLEST = 0.5

local ScreenFit = {}

-- A frame filling a ScreenGui, to put the things that should fit in. Returns
-- it and its UIScale.
function ScreenFit.frame(gui)
	local frame = Candy.create("Frame", {
		Name = "Fit",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	})
	local scale = Candy.create("UIScale", { Parent = frame })
	local function fit()
		local size = gui.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then
			return -- not on screen yet
		end
		local margin = if Candy.onTv() then Candy.TV_SAFE else 0
		local biggest = if Candy.bigScreen() then math.max(1, Candy.tvScale(size.Y)) else 1
		local room = 1 - 2 * margin
		local s = math.clamp(math.min(size.X * room / DESIGN.X, size.Y * room / DESIGN.Y), SMALLEST, biggest)
		scale.Scale = s
		frame.Position = UDim2.fromScale(margin, margin)
		frame.Size = UDim2.fromScale(room / s, room / s)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
	return frame, scale
end

return ScreenFit
