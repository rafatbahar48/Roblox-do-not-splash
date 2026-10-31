-- The menu and button art: parts of the SpriteCook UI kit "Still Water lobby
-- menus", packed into two atlases (art/ui/kit/atlas-panels.png and
-- atlas-icons.png) that are uploaded to Roblox. UiArtParts.luau says where
-- each part sits in its atlas.
--
-- After repacking (tools/pack-ui.ps1), upload the atlases again and paste
-- their new ids here.

local Parts = require(script.Parent.UiArtParts)

local ATLASES = {
	panels = "rbxassetid://134371202136266", -- art/ui/kit/atlas-panels.png
	icons = "rbxassetid://115281491013232", -- art/ui/kit/atlas-icons.png
}

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
	image.Image = ATLASES[part.atlas]
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
