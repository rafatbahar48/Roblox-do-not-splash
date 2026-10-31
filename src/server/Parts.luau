-- Helpers for building the map out of anchored parts, shared by MapBuilder
-- and LobbyBuilder.

local Parts = {}

-- An anchored part. props sets any other properties, after the size.
function Parts.block(parent, name, size, cframe, color, material, props)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for key, value in props do
			part[key] = value
		end
	end
	part.Parent = parent
	return part
end

-- A block filling the box between two corners.
function Parts.box(parent, name, min, max, color, material, props)
	return Parts.block(parent, name, max - min, CFrame.new((min + max) / 2), color, material, props)
end

return Parts
