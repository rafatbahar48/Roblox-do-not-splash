-- How a skin looks on a character: it recolours body regions (see
-- Catalog.luau) and hides shirts and pants. Each recoloured part remembers
-- its own look in attributes and the clothing is tucked into a folder, so a
-- skin can be taken off again. Used on real characters (server/Cosmetics.luau)
-- and on the shop's little copies of your avatar (client/SkinPreview.luau).

local SkinLook = {}

local STASH_NAME = "StillWaterClothing"

local function regionOf(part)
	local name = part.Name
	if name == "Head" then
		return "head"
	elseif name == "UpperTorso" or name == "LowerTorso" or name == "Torso" then
		return "torso"
	elseif string.find(name, "Arm") or string.find(name, "Hand") then
		return "arms"
	elseif string.find(name, "Leg") or string.find(name, "Foot") then
		return "legs"
	end
	return nil
end

-- Takes a character's skin off: its own colours and clothes back.
function SkinLook.restore(character)
	for _, part in character:GetChildren() do
		if part:IsA("BasePart") and part:GetAttribute("OriginalColor") ~= nil then
			part.Color = part:GetAttribute("OriginalColor")
			part.Material = Enum.Material[part:GetAttribute("OriginalMaterial")]
			part.Transparency = part:GetAttribute("OriginalTransparency")
			part:SetAttribute("OriginalColor", nil)
			part:SetAttribute("OriginalMaterial", nil)
			part:SetAttribute("OriginalTransparency", nil)
		end
	end
	local stash = character:FindFirstChild(STASH_NAME)
	if stash then
		for _, clothing in stash:GetChildren() do
			clothing.Parent = character
		end
		stash:Destroy()
	end
end

-- Puts a skin (a Catalog item) on a character, or with nil takes it off.
function SkinLook.apply(character, skin)
	SkinLook.restore(character)
	if not skin then
		return
	end

	local stash = Instance.new("Folder")
	stash.Name = STASH_NAME
	for _, child in character:GetChildren() do
		if child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") then
			child.Parent = stash
		end
	end
	stash.Parent = character

	for _, part in character:GetChildren() do
		local region = part:IsA("BasePart") and regionOf(part)
		local look = region and skin[region]
		if look then
			part:SetAttribute("OriginalColor", part.Color)
			part:SetAttribute("OriginalMaterial", part.Material.Name)
			part:SetAttribute("OriginalTransparency", part.Transparency)
			part.Color = look.color
			if look.material then
				part.Material = look.material
			end
			if look.transparency then
				part.Transparency = look.transparency
			end
		end
	end
end

return SkinLook
