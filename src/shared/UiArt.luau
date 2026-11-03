-- The menu and button art: parts of the SpriteCook UI kits "Silent Swamp
-- lantern menus" (the lantern-lit wood look) and "Still Water lobby menus"
-- (the parts not redone yet), packed into atlases (art/ui/kit/atlas-panels.png,
-- atlas-icons.png, atlas-event.png, the seasonal art, and atlas-boosts.png)
-- that are uploaded to Roblox. UiArtParts.luau says where each part sits in
-- its atlas.
--
-- After repacking (tools/pack-ui.ps1), upload the atlases again and paste
-- their new ids here. Until an atlas has an id, Studio shows it from its own
-- content folder (content/textures/SilentSwamp/atlas-<name>.png, copied there
-- by hand), so the art can be tried out before it is uploaded; a published
-- game without the ids shows no menu art at all.

local RunService = game:GetService("RunService")

local Parts = require(script.Parent.UiArtParts)

local ATLASES = {
	panels = "", -- art/ui/kit/atlas-panels.png
	icons = "", -- art/ui/kit/atlas-icons.png
	event = "", -- art/ui/kit/atlas-event.png
	boosts = "", -- art/ui/kit/atlas-boosts.png
}
local PREVIEW = "rbxasset://textures/SilentSwamp/atlas-%s.png"

local function atlas(name)
	local id = ATLASES[name]
	if id ~= "" then
		return id
	end
	return if RunService:IsStudio() then PREVIEW:format(name) else ""
end

local UiArt = {}

-- A part's size in its atlas, in pixels.
function UiArt.size(name)
	local part = Parts[name]
	return Vector2.new(part.w, part.h)
end

-- Shows a part on an ImageLabel or ImageButton. Parts with 9-slice borders
-- stretch without bending their corners; scale sizes the corners (1 is the
-- size they were packed at).
function UiArt.apply(image, name, scale)
	local part = Parts[name]
	image.Image = atlas(part.atlas)
	image.ImageRectOffset = Vector2.new(part.x, part.y)
	image.ImageRectSize = Vector2.new(part.w, part.h)
	if part.slice then
		local left, top, right, bottom = part.slice[1], part.slice[2], part.slice[3], part.slice[4]
		image.ScaleType = Enum.ScaleType.Slice
		image.SliceCenter = Rect.new(left, top, part.w - right, part.h - bottom)
		image.SliceScale = scale or 1
	else
		image.ScaleType = Enum.ScaleType.Stretch
	end
end

-- How far to shrink a stretching part's corners so they fit a thing this many
-- pixels tall.
function UiArt.fitScale(name, height)
	local part = Parts[name]
	if not part.slice or height <= 0 then
		return 1
	end
	return math.min(1, height / (part.slice[2] + part.slice[4] + 4))
end

return UiArt
