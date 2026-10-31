-- Which part of the map a point is in, for the client's lighting, music and
-- HUD. The map runs along +Z (server/MapBuilder.luau): the lobby (z < 0),
-- the cave at the start of stage 1 (Config.Cave), the forest's stages, and
-- the way out past the last one.

local Config = require(script.Parent.Config)
local Stages = require(script.Parent.Stages)

local Zones = {}

-- Where the way out begins: the end of the last stage.
Zones.exitZ = 0
for _, stage in Stages do
	Zones.exitZ += stage.length
end

-- "lobby", "cave", "forest" or "exit".
function Zones.at(position)
	local z = position.Z
	if z < 0 then
		return "lobby"
	elseif z >= Zones.exitZ then
		return "exit"
	elseif z < Config.Cave.Length and math.abs(position.X) < Config.Cave.HalfWidth + 6 then
		return "cave"
	end
	return "forest"
end

return Zones
